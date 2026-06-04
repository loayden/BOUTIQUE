import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.local')
const baseURL = process.env.AURELIEN_SMOKE_BASE_URL?.trim() || 'http://127.0.0.1:3104/api'
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
    const source = await fs.readFile(envPath, 'utf8')
    return parseDotEnv(source)
  } catch {
    return {}
  }
}

async function request(endpoint, options = {}) {
  const response = await fetch(`${baseURL}${endpoint}`, options)
  const text = await response.text()
  let body

  try {
    body = JSON.parse(text)
  } catch {
    body = text
  }

  return { status: response.status, body }
}

function assert(condition, message, details) {
  if (!condition) {
    const error = new Error(message)
    error.details = details
    throw error
  }
}

async function main() {
  const fileEnv = await loadEnvFile()
  const adminEmail = process.env.AURELIEN_ADMIN_EMAIL || fileEnv.AURELIEN_ADMIN_EMAIL
  const adminPassword = process.env.AURELIEN_ADMIN_PASSWORD || fileEnv.AURELIEN_ADMIN_PASSWORD

  assert(adminEmail && adminPassword, 'Admin credentials are required for smoke tests.')

  const results = []
  const userEmail = `smoke-${Date.now()}@example.com`
  const userPassword = 'SmokePass123!'
  let userToken = null
  let adminToken = null
  let uploadedImageURL = null
  let productID = null
  let primaryAddressID = null
  let secondaryAddressID = null

  const push = (name, payload) => {
    results.push({ name, ...payload })
  }

  try {
    const products = await request('/products')
    push('products', { status: products.status, count: products.body?.products?.length ?? 0 })
    assert(products.status == 200, 'Products endpoint failed.', products)
    assert(Array.isArray(products.body?.products) && products.body.products.length > 0, 'Products endpoint returned no products.', products)

    const signup = await request('/auth/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Smoke User', email: userEmail, password: userPassword }),
    })
    push('signup', { status: signup.status })
    assert(signup.status == 200, 'Signup failed.', signup)

    const signin = await request('/auth/signin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: userEmail, password: userPassword }),
    })
    push('signin', { status: signin.status })
    assert(signin.status == 200 && typeof signin.body?.token == 'string', 'Signin failed.', signin)
    userToken = signin.body.token

    const profile = await request('/profile', {
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('profile', { status: profile.status })
    assert(profile.status == 200, 'Profile fetch failed.', profile)

    const addressCreate = await request('/wallet/addresses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${userToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id: `address-${Date.now()}`,
        label: 'Home',
        recipient: 'Smoke User',
        line1: '123 Nile Street',
        apartment: '4B',
        city: 'Cairo',
        phone: '01012345678',
        isPrimary: true,
      }),
    })
    push('wallet-address-add', { status: addressCreate.status, count: addressCreate.body?.savedAddresses?.length ?? 0 })
    assert(addressCreate.status == 201, 'Wallet address create failed.', addressCreate)
    primaryAddressID = addressCreate.body?.savedAddresses?.[0]?.id ?? null

    const secondaryAddressCreate = await request('/wallet/addresses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${userToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id: `address-secondary-${Date.now()}`,
        label: 'Studio',
        recipient: 'Smoke User',
        line1: '44 Garden City',
        apartment: '9A',
        city: 'Giza',
        phone: '01012345679',
        isPrimary: false,
      }),
    })
    push('wallet-address-add-secondary', {
      status: secondaryAddressCreate.status,
      count: secondaryAddressCreate.body?.savedAddresses?.length ?? 0,
    })
    assert(secondaryAddressCreate.status == 201, 'Secondary wallet address create failed.', secondaryAddressCreate)
    secondaryAddressID =
      secondaryAddressCreate.body?.savedAddresses?.find((address) => address.id != primaryAddressID)?.id ?? null
    assert(secondaryAddressID, 'Secondary address id missing after create.', secondaryAddressCreate)

    const addressPrimary = await request(`/wallet/addresses/${secondaryAddressID}/primary`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('wallet-address-primary', { status: addressPrimary.status })
    assert(addressPrimary.status == 200, 'Wallet primary address update failed.', addressPrimary)
    assert(
      addressPrimary.body?.savedAddresses?.some((address) => address.id == secondaryAddressID && address.isPrimary),
      'Wallet primary address did not persist.',
      addressPrimary,
    )

    const saved = await request('/saved/me', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${userToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ productId: products.body.products[0]._id }),
    })
    push('saved-add', { status: saved.status, count: saved.body?.products?.length ?? 0 })
    assert(saved.status == 201, 'Saved products add failed.', saved)

    const savedFetch = await request('/saved/me', {
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('saved-fetch', { status: savedFetch.status, count: savedFetch.body?.products?.length ?? 0 })
    assert(savedFetch.status == 200 && Array.isArray(savedFetch.body?.products) && savedFetch.body.products.length == 1, 'Saved products fetch failed.', savedFetch)

    const cartAdd = await request('/cart/items', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${userToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ productId: products.body.products[0]._id, quantity: 1, size: 'M', color: 'cream' }),
    })
    push('cart-add', { status: cartAdd.status })
    assert(cartAdd.status == 200, 'Cart add failed.', cartAdd)

    const cart = await request('/cart', {
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('cart', { status: cart.status, count: cart.body?.items?.length ?? 0 })
    assert(cart.status == 200 && Array.isArray(cart.body?.items) && cart.body.items.length == 1, 'Cart fetch failed.', cart)

    const order = await request('/orders', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${userToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        items: [{ productId: products.body.products[0]._id, quantity: 1, size: 'M', color: 'cream' }],
        shippingAddress: {
          name: 'Smoke User',
          street: '123 Nile Street, Zamalek',
          city: 'Cairo',
          postalCode: '11561',
          phone: '01012345678',
          email: userEmail,
        },
        deliveryLocation: 'Cairo',
        paymentMethodId: 'cod',
        shippingMethodName: 'Standard',
      }),
    })
    push('order-place', { status: order.status })
    assert(order.status == 201, 'Order creation failed.', order)

    const notifications = await request('/notifications', {
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('notifications', { status: notifications.status, count: notifications.body?.length ?? 0 })
    assert(
      notifications.status == 200 && Array.isArray(notifications.body) && notifications.body.length > 0,
      'Notifications fetch failed.',
      notifications,
    )
    const notificationID = notifications.body[0]?.id
    assert(notificationID, 'Notification id missing after order creation.', notifications)

    const notificationRead = await request(`/notifications/${notificationID}/read`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('notifications-read', { status: notificationRead.status })
    assert(notificationRead.status == 200, 'Notification read failed.', notificationRead)

    const notificationsReadAll = await request('/notifications/read-all', {
      method: 'POST',
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('notifications-read-all', { status: notificationsReadAll.status })
    assert(notificationsReadAll.status == 200, 'Notifications read-all failed.', notificationsReadAll)

    const notificationDelete = await request(`/notifications/${notificationID}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('notifications-delete', { status: notificationDelete.status })
    assert(notificationDelete.status == 200, 'Notification delete failed.', notificationDelete)

    const orders = await request('/orders', {
      headers: { Authorization: `Bearer ${userToken}` },
    })
    push('orders', { status: orders.status, count: orders.body?.orders?.length ?? 0 })
    assert(orders.status == 200 && Array.isArray(orders.body?.orders) && orders.body.orders.length == 1, 'Orders fetch failed.', orders)

    const adminSignin = await request('/auth/signin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: adminEmail, password: adminPassword }),
    })
    push('admin-signin', { status: adminSignin.status })
    assert(adminSignin.status == 200 && adminSignin.body?.user?.isAdmin === true, 'Admin signin failed.', adminSignin)
    adminToken = adminSignin.body.token

    const analytics = await request('/admin/analytics', {
      headers: { Authorization: `Bearer ${adminToken}` },
    })
    push('admin-analytics', { status: analytics.status, totalProducts: analytics.body?.totalProducts ?? null })
    assert(analytics.status == 200, 'Admin analytics failed.', analytics)

    const users = await request('/admin/users', {
      headers: { Authorization: `Bearer ${adminToken}` },
    })
    push('admin-users', { status: users.status, count: users.body?.users?.length ?? null })
    assert(users.status == 200, 'Admin users failed.', users)

    const imageBytes = await fs.readFile(sampleImagePath)
    const uploadForm = new FormData()
    uploadForm.append('file', new Blob([imageBytes], { type: 'image/jpeg' }), 'whitejacket.jpg')

    const uploadResponse = await fetch(`${baseURL}/uploads/product-image`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: uploadForm,
    })
    const uploadText = await uploadResponse.text()
    let uploadBody
    try {
      uploadBody = JSON.parse(uploadText)
    } catch {
      uploadBody = uploadText
    }

    push('admin-upload-image', { status: uploadResponse.status })
    assert(uploadResponse.status == 201 && typeof uploadBody?.url == 'string', 'Admin image upload failed.', uploadBody)
    uploadedImageURL = uploadBody.url

    productID = `smoke-product-${Date.now()}`
    const productPayload = {
      id: productID,
      name: 'Smoke Admin Product',
      category: 'jackets',
      price: 1999,
      summary: 'Admin smoke summary',
      story: 'Admin smoke story',
      images: [uploadedImageURL],
      imageNames: [uploadedImageURL],
      sizes: ['M', 'L'],
      size: ['M', 'L'],
      colors: ['black'],
      composition: '100% Cotton',
      care: 'Dry clean',
      delivery: '3 business days',
      returns: '14 day returns',
      featured: true,
      badge: 'Editorial Pick',
      inventoryCount: 4,
      isAvailable: true,
    }

    const created = await request('/products', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(productPayload),
    })
    push('admin-create-product', { status: created.status })
    assert(created.status == 201, 'Admin product create failed.', created)

    const updated = await request(`/products/${productID}`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ...productPayload, price: 2099, inventoryCount: 2 }),
    })
    push('admin-update-product', { status: updated.status })
    assert(updated.status == 200, 'Admin product update failed.', updated)

    const deleted = await request(`/products/${productID}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${adminToken}` },
    })
    push('admin-delete-product', { status: deleted.status })
    assert(deleted.status == 200, 'Admin product delete failed.', deleted)
  } finally {
    if (userToken) {
      if (primaryAddressID) {
        const deletedPrimaryAddress = await request(`/wallet/addresses/${primaryAddressID}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${userToken}` },
        }).catch(() => null)
        if (deletedPrimaryAddress) {
          push('cleanup-address-primary', { status: deletedPrimaryAddress.status })
        }
      }
      if (secondaryAddressID) {
        const deletedSecondaryAddress = await request(`/wallet/addresses/${secondaryAddressID}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${userToken}` },
        }).catch(() => null)
        if (deletedSecondaryAddress) {
          push('cleanup-address-secondary', { status: deletedSecondaryAddress.status })
        }
      }
      const deletedUser = await request('/users/me', {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${userToken}` },
      }).catch(() => null)
      if (deletedUser) {
        push('cleanup-user', { status: deletedUser.status })
      }
    }
  }

  console.log(JSON.stringify({ ok: true, baseURL, results }, null, 2))
}

main().catch((error) => {
  console.error(JSON.stringify({
    ok: false,
    message: error instanceof Error ? error.message : String(error),
    details: error && typeof error == 'object' && 'details' in error ? error.details : null,
  }, null, 2))
  process.exitCode = 1
})
