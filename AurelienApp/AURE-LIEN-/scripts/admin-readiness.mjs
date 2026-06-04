import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.local')
const baseURL = (process.env.AURELIEN_SMOKE_BASE_URL?.trim() || 'http://127.0.0.1:3104/api').replace(/\/$/, '')
const timeoutMS = Number(process.env.AURELIEN_SMOKE_TIMEOUT_MS ?? 15000)
const sampleImagePath = path.join(rootDir, 'public', 'uploads', 'whitejacket.jpg')

function parseDotEnv(source) {
  const result = {}
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) {
      continue
    }

    const separatorIndex = line.indexOf('=')
    if (separatorIndex < 0) {
      continue
    }

    result[line.slice(0, separatorIndex).trim()] = line.slice(separatorIndex + 1).trim()
  }
  return result
}

async function loadEnvFile() {
  try {
    return parseDotEnv(await fs.readFile(envPath, 'utf8'))
  } catch {
    return {}
  }
}

async function request(endpoint, options = {}) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMS)

  try {
    const response = await fetch(`${baseURL}${endpoint}`, {
      ...options,
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        ...(options.body && !(options.body instanceof FormData) ? { 'Content-Type': 'application/json' } : {}),
        ...(options.headers ?? {}),
      },
    })
    const text = await response.text()
    let body = null
    try {
      body = text ? JSON.parse(text) : null
    } catch {
      body = text
    }
    return { endpoint, status: response.status, ok: response.ok, body }
  } finally {
    clearTimeout(timeout)
  }
}

function bearer(token) {
  return { Authorization: `Bearer ${token}` }
}

function assert(condition, message, details) {
  if (!condition) {
    const error = new Error(message)
    error.details = details
    throw error
  }
}

function firstProduct(payload) {
  const products = Array.isArray(payload?.products) ? payload.products : Array.isArray(payload) ? payload : []
  return products[0]
}

async function fetchImage(url) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMS)
  try {
    const response = await fetch(url, { signal: controller.signal })
    return {
      status: response.status,
      contentType: response.headers.get('content-type') ?? '',
    }
  } finally {
    clearTimeout(timeout)
  }
}

async function main() {
  const fileEnv = await loadEnvFile()
  const adminEmail = process.env.AURELIEN_ADMIN_EMAIL || fileEnv.AURELIEN_ADMIN_EMAIL
  const adminPassword = process.env.AURELIEN_ADMIN_PASSWORD || fileEnv.AURELIEN_ADMIN_PASSWORD
  assert(adminEmail && adminPassword, 'Admin credentials are required for admin readiness smoke.')

  const runID = Date.now()
  const customerEmail = `admin-smoke-${runID}@example.com`
  const customerPassword = 'SecurePass123!'
  const productID = `admin-smoke-product-${runID}`
  const orderID = `admin-smoke-order-${runID}`
  const results = []

  let customerToken = null
  let adminToken = null
  let createdProduct = false
  let uploadedImageURL = null

  const push = (name, response, extra = {}) => {
    results.push({
      name,
      status: response?.status ?? null,
      ok: response?.ok ?? false,
      ...extra,
    })
  }

  try {
    const products = await request('/products')
    const baseProduct = firstProduct(products.body)
    push('public-products', products, { count: products.body?.products?.length ?? null })
    assert(products.status == 200 && baseProduct, 'Public products must be available before admin smoke.', products)

    const signup = await request('/auth/signup', {
      method: 'POST',
      body: JSON.stringify({
        name: 'Admin Smoke Customer',
        email: customerEmail,
        password: customerPassword,
        confirmPassword: customerPassword,
        phone: '01012345678',
      }),
    })
    push('customer-signup', signup)
    assert(signup.status == 200 && typeof signup.body?.token == 'string', 'Customer signup must return a token.', signup)
    customerToken = signup.body.token

    const deniedCreate = await request('/products', {
      method: 'POST',
      headers: bearer(customerToken),
      body: JSON.stringify({
        id: `${productID}-denied`,
        name: 'Denied Product',
        category: 'jackets',
        price: 999,
        summary: 'Should not save',
        imageNames: [baseProduct.images?.[0] ?? baseProduct.imageNames?.[0]],
        sizes: ['M'],
        colors: ['black'],
      }),
    })
    push('non-admin-product-create-denied', deniedCreate)
    assert(deniedCreate.status == 401, 'Non-admin users must not create products.', deniedCreate)

    const adminLogin = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email: adminEmail, password: adminPassword }),
    })
    push('admin-login', adminLogin, { isAdmin: adminLogin.body?.user?.isAdmin === true })
    assert(adminLogin.status == 200 && adminLogin.body?.user?.isAdmin === true, 'Admin login must preserve admin role.', adminLogin)
    adminToken = adminLogin.body.token

    const adminUsers = await request('/admin/users', { headers: bearer(adminToken) })
    push('admin-users', adminUsers, { count: adminUsers.body?.users?.length ?? null })
    assert(adminUsers.status == 200 && Array.isArray(adminUsers.body?.users), 'Admin users endpoint must return users.', adminUsers)

    const adminOrders = await request('/admin/orders', { headers: bearer(adminToken) })
    push('admin-orders', adminOrders, { count: adminOrders.body?.orders?.length ?? null })
    assert(adminOrders.status == 200 && Array.isArray(adminOrders.body?.orders), 'Admin orders endpoint must return orders.', adminOrders)

    const analytics = await request('/admin/analytics', { headers: bearer(adminToken) })
    push('admin-analytics', analytics, { totalProducts: analytics.body?.totalProducts ?? null })
    assert(analytics.status == 200, 'Admin analytics endpoint must be reachable.', analytics)

    const imageBytes = await fs.readFile(sampleImagePath)
    const uploadForm = new FormData()
    uploadForm.append('file', new Blob([imageBytes], { type: 'image/jpeg' }), 'whitejacket.jpg')
    const upload = await request('/uploads/product-image', {
      method: 'POST',
      headers: bearer(adminToken),
      body: uploadForm,
    })
    push('admin-upload-image', upload)
    assert(upload.status == 201 && typeof upload.body?.url == 'string', 'Admin image upload must return a URL.', upload)
    uploadedImageURL = upload.body.url

    const uploadedImage = await fetchImage(uploadedImageURL)
    results.push({ name: 'admin-uploaded-image-fetch', status: uploadedImage.status, contentType: uploadedImage.contentType })
    assert(uploadedImage.status == 200 && uploadedImage.contentType.startsWith('image/'), 'Uploaded image URL must serve image bytes.', uploadedImage)

    const productPayload = {
      id: productID,
      name: 'Admin Smoke Product',
      category: 'jackets',
      price: 1999,
      summary: 'Admin smoke product summary',
      story: 'Admin smoke product story',
      imageNames: [uploadedImageURL],
      sizes: ['M', 'L'],
      colors: ['black'],
      composition: '100% cotton',
      care: 'Dry clean only',
      delivery: 'Delivered in 3 business days',
      returns: '14 day returns',
      featured: true,
      badge: 'Editorial Pick',
      inventoryCount: 4,
      isAvailable: true,
    }

    const created = await request('/products', {
      method: 'POST',
      headers: bearer(adminToken),
      body: JSON.stringify(productPayload),
    })
    push('admin-create-product', created)
    assert(created.status == 201 && created.body?._id == productID, 'Admin product create must persist the requested product.', created)
    createdProduct = true

    const publicCreated = await request(`/products/${productID}`)
    push('public-created-product', publicCreated, { imageCount: publicCreated.body?.images?.length ?? null })
    assert(publicCreated.status == 200, 'Created product must be visible in public product detail.', publicCreated)
    assert(publicCreated.body?.images?.[0] == uploadedImageURL, 'Created product must keep uploaded image URL.', publicCreated)

    const updated = await request(`/products/${productID}`, {
      method: 'PUT',
      headers: bearer(adminToken),
      body: JSON.stringify({
        ...productPayload,
        name: 'Admin Smoke Product Updated',
        category: 'footwear',
        price: 2099,
        inventoryCount: 2,
        isAvailable: false,
      }),
    })
    push('admin-update-product', updated)
    assert(updated.status == 200, 'Admin product update must succeed.', updated)
    assert(updated.body?.price == 2099, 'Updated product price must persist.', updated)
    assert(updated.body?.inventoryCount == 2, 'Updated product inventory must persist.', updated)
    assert(updated.body?.isAvailable === false, 'Updated product availability must persist.', updated)

    const order = await request('/orders', {
      method: 'POST',
      headers: bearer(customerToken),
      body: JSON.stringify({
        id: orderID,
        items: [{
          productId: baseProduct._id,
          quantity: 1,
          size: baseProduct.size?.[0] ?? baseProduct.sizes?.[0] ?? 'M',
          color: baseProduct.colors?.[0] ?? 'black',
        }],
        totalPrice: baseProduct.price,
        subtotal: baseProduct.price,
        shippingCost: 0,
        discount: 0,
        shippingAddress: {
          name: 'Admin Smoke Customer',
          street: '1 Test Street',
          city: 'Cairo',
          postalCode: '00000',
          phone: '01012345678',
          email: customerEmail,
        },
        deliveryLocation: 'Cairo',
        paymentMethod: { type: 'cod', displayName: 'Cash on Delivery' },
      }),
    })
    push('customer-create-order', order)
    assert(order.status == 201, 'Customer order creation must succeed before admin status update.', order)

    const updatedOrder = await request(`/orders/${orderID}`, {
      method: 'PUT',
      headers: bearer(adminToken),
      body: JSON.stringify({ status: 'preparing' }),
    })
    push('admin-update-order-status', updatedOrder)
    assert(updatedOrder.status == 200 && updatedOrder.body?.status == 'preparing', 'Admin order status update must persist.', updatedOrder)

    const deleted = await request(`/products/${productID}`, {
      method: 'DELETE',
      headers: bearer(adminToken),
    })
    push('admin-delete-product', deleted)
    assert(deleted.status == 200, 'Admin product delete must succeed.', deleted)
    createdProduct = false

    const deletedProduct = await request(`/products/${productID}`)
    push('public-deleted-product', deletedProduct)
    assert(deletedProduct.status == 404, 'Deleted products must not remain in public product detail.', deletedProduct)

    const uploadedImageAfterDelete = await fetchImage(uploadedImageURL)
    results.push({
      name: 'uploaded-image-persists-after-product-delete',
      status: uploadedImageAfterDelete.status,
      contentType: uploadedImageAfterDelete.contentType,
    })
    assert(uploadedImageAfterDelete.status == 200, 'Uploaded image should remain accessible independently of product deletion.', uploadedImageAfterDelete)

    console.log(JSON.stringify({ ok: true, baseURL, results }, null, 2))
  } finally {
    if (createdProduct && adminToken) {
      const cleanup = await request(`/products/${productID}`, {
        method: 'DELETE',
        headers: bearer(adminToken),
      }).catch((error) => ({ status: null, ok: false, body: String(error) }))
      push('cleanup-product', cleanup)
    }

    if (customerToken) {
      const cleanup = await request('/users/me', {
        method: 'DELETE',
        headers: bearer(customerToken),
      }).catch((error) => ({ status: null, ok: false, body: String(error) }))
      push('cleanup-customer', cleanup)
    }
  }
}

main().catch((error) => {
  console.error(JSON.stringify({
    ok: false,
    baseURL,
    message: error instanceof Error ? error.message : String(error),
    details: error && typeof error == 'object' && 'details' in error ? error.details : null,
  }, null, 2))
  process.exitCode = 1
})
