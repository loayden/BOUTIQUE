import process from 'node:process'

const baseURL = (process.env.AURELIEN_SMOKE_BASE_URL?.trim() || 'http://127.0.0.1:3104/api').replace(/\/$/, '')
const timeoutMS = Number(process.env.AURELIEN_SMOKE_TIMEOUT_MS ?? 15000)

async function request(endpoint, options = {}) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMS)

  try {
    const response = await fetch(`${baseURL}${endpoint}`, {
      ...options,
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        ...(options.body ? { 'Content-Type': 'application/json' } : {}),
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

async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMS)

  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    })
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

function productsFrom(payload) {
  return Array.isArray(payload?.products) ? payload.products : Array.isArray(payload) ? payload : []
}

function stringArray(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item == 'string' && item.trim()).map((item) => item.trim()) : []
}

function productImages(product) {
  return [...stringArray(product?.images), ...stringArray(product?.imageNames)]
}

function productSizes(product) {
  return [...stringArray(product?.size), ...stringArray(product?.sizes)]
}

function productColors(product) {
  return stringArray(product?.colors)
}

function productInventory(product) {
  const raw = product?.inventoryCount ?? product?.inventory ?? product?.stock
  return typeof raw == 'number' ? raw : null
}

function productIsSellable(product, quantity = 1) {
  if (!product || typeof product._id != 'string') {
    return false
  }

  if (product.isAvailable === false || product.available === false || product.inStock === false) {
    return false
  }

  const inventory = productInventory(product)
  if (inventory != null && inventory < quantity) {
    return false
  }

  return productImages(product).length > 0
}

function chooseCommerceProduct(products) {
  return products.find((product) => productIsSellable(product, 2)) ?? products.find((product) => productIsSellable(product, 1))
}

function resolveMediaURL(value) {
  return new URL(value, baseURL.replace(/\/api$/, '')).toString()
}

async function validateProductImages(products) {
  const failures = []
  const results = []

  for (const product of products) {
    const firstImage = productImages(product)[0]
    const productID = product?._id ?? product?.id ?? product?.name ?? 'unknown-product'
    if (!firstImage) {
      failures.push({ productID, message: 'Product has no listing image.' })
      continue
    }

    const imageURL = resolveMediaURL(firstImage)
    try {
      const response = await fetchWithTimeout(imageURL, {
        method: 'GET',
        headers: { Accept: 'image/*,*/*;q=0.8' },
      })
      const contentType = response.headers.get('content-type') ?? ''
      const ok = response.ok && contentType.toLowerCase().startsWith('image/')
      const result = {
        productID,
        url: imageURL,
        status: response.status,
        contentType,
        ok,
      }
      results.push(result)
      if (!ok) {
        failures.push(result)
      }
    } catch (error) {
      failures.push({
        productID,
        url: imageURL,
        status: null,
        contentType: null,
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      })
    }
  }

  return { results, failures }
}

function cartLineFor(items, product, selection) {
  return (items ?? []).find((item) =>
    item.productId == product._id &&
    (selection.size == null || item.size == selection.size) &&
    (selection.color == null || item.color == selection.color)
  )
}

async function main() {
  const runID = Date.now()
  const email = `ecommerce-smoke-${runID}@example.com`
  const password = 'SecurePass123!'
  const results = []

  let token = null
  let selectedProduct = null
  let selection = null
  let createdOrderID = null

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
    const catalog = productsFrom(products.body)
    push('browse-products', products, { count: catalog.length })
    assert(products.status == 200 && catalog.length > 0, 'Products must be browseable.', products)

    const imageCheck = await validateProductImages(catalog)
    results.push({
      name: 'product-card-images',
      checked: imageCheck.results.length,
      failures: imageCheck.failures.length,
      ok: imageCheck.failures.length == 0,
    })
    assert(imageCheck.failures.length == 0, 'Every catalog product must have a reachable listing image.', imageCheck.failures)

    selectedProduct = chooseCommerceProduct(catalog)
    assert(selectedProduct, 'At least one sellable product with a listing image is required.', { productCount: catalog.length })

    selection = {
      size: productSizes(selectedProduct)[0] ?? null,
      color: productColors(selectedProduct)[0] ?? null,
    }

    const productDetail = await request(`/products/${selectedProduct._id}`)
    push('product-detail', productDetail, { productID: selectedProduct._id })
    assert(productDetail.status == 200 && productDetail.body?._id == selectedProduct._id, 'Product detail must return the selected product.', productDetail)

    const related = await request(`/products/${selectedProduct._id}/related`)
    push('related-products', related, { count: Array.isArray(related.body) ? related.body.length : null })
    assert(related.status == 200 && Array.isArray(related.body), 'Related products must return an array.', related)

    const cod = await request('/orders/validate-cod', {
      method: 'POST',
      body: JSON.stringify({ governorate: 'Cairo' }),
    })
    push('validate-cod', cod, { eligible: cod.body?.eligible ?? null, codFee: cod.body?.codFee ?? null })
    assert(cod.status == 200 && cod.body?.eligible === true && typeof cod.body?.codFee == 'number', 'COD validation must be available for Cairo.', cod)

    const promo = await request('/orders/validate-promo', {
      method: 'POST',
      body: JSON.stringify({ code: 'WELCOME50' }),
    })
    push('validate-promo', promo, { valid: promo.body?.isValid ?? null, discount: promo.body?.discount ?? null })
    assert(promo.status == 200 && promo.body?.isValid === true && promo.body?.discount > 0, 'Promo validation must return the current public promo.', promo)

    const signup = await request('/auth/signup', {
      method: 'POST',
      body: JSON.stringify({
        name: 'Ecommerce Smoke',
        email,
        password,
        confirmPassword: password,
        phone: '01012345678',
      }),
    })
    push('signup', signup)
    assert(signup.status == 200 && typeof signup.body?.token == 'string', 'Signup must return a customer token.', signup)
    token = signup.body.token

    const login = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    push('login', login)
    assert(login.status == 200 && typeof login.body?.token == 'string', 'Login must return a customer token.', login)
    token = login.body.token

    const account = await request('/account', { headers: bearer(token) })
    push('account-session', account)
    assert(account.status == 200 && account.body?.user?.email == email, 'Account must load for the logged-in customer.', account)

    const savedInitial = await request('/saved/me', { headers: bearer(token) })
    push('wishlist-initial', savedInitial, { count: savedInitial.body?.products?.length ?? null })
    assert(savedInitial.status == 200 && Array.isArray(savedInitial.body?.products), 'Wishlist initial state must be readable.', savedInitial)

    const savedAdd = await request('/saved/me', {
      method: 'POST',
      headers: bearer(token),
      body: JSON.stringify({ productId: selectedProduct._id }),
    })
    push('wishlist-add', savedAdd, { count: savedAdd.body?.products?.length ?? null })
    assert(savedAdd.status == 201 && savedAdd.body?.products?.some((item) => item._id == selectedProduct._id), 'Wishlist add must persist the selected product.', savedAdd)

    const savedRemove = await request('/saved/me', {
      method: 'DELETE',
      headers: bearer(token),
      body: JSON.stringify({ productId: selectedProduct._id }),
    })
    push('wishlist-remove', savedRemove, { count: savedRemove.body?.products?.length ?? null })
    assert(savedRemove.status == 200 && !savedRemove.body?.products?.some((item) => item._id == selectedProduct._id), 'Wishlist remove must persist.', savedRemove)

    const cartInitial = await request('/cart', { headers: bearer(token) })
    push('cart-initial', cartInitial, { count: cartInitial.body?.items?.length ?? null })
    assert(cartInitial.status == 200 && Array.isArray(cartInitial.body?.items), 'Cart initial state must be readable.', cartInitial)

    const addPayload = {
      productId: selectedProduct._id,
      quantity: 1,
      size: selection.size,
      color: selection.color,
    }

    const cartAdd = await request('/cart/items', {
      method: 'POST',
      headers: bearer(token),
      body: JSON.stringify(addPayload),
    })
    push('cart-add', cartAdd)
    assert(cartAdd.status == 200, 'Cart add must succeed.', cartAdd)

    const cartAfterAdd = await request('/cart', { headers: bearer(token) })
    const addedLine = cartLineFor(cartAfterAdd.body?.items, selectedProduct, selection)
    push('cart-after-add', cartAfterAdd, { count: cartAfterAdd.body?.items?.length ?? null, quantity: addedLine?.quantity ?? null })
    assert(cartAfterAdd.status == 200 && addedLine?.quantity == 1, 'Cart fetch must show the added product.', cartAfterAdd)

    const cartUpdate = await request('/cart/items', {
      method: 'PATCH',
      headers: bearer(token),
      body: JSON.stringify({ ...addPayload, quantity: 2 }),
    })
    push('cart-update-quantity', cartUpdate)
    assert(cartUpdate.status == 200, 'Cart quantity update must succeed.', cartUpdate)

    const cartAfterUpdate = await request('/cart', { headers: bearer(token) })
    const updatedLine = cartLineFor(cartAfterUpdate.body?.items, selectedProduct, selection)
    push('cart-after-update', cartAfterUpdate, { quantity: updatedLine?.quantity ?? null })
    assert(cartAfterUpdate.status == 200 && updatedLine?.quantity == 2, 'Cart fetch must show the updated quantity.', cartAfterUpdate)

    const cartRemove = await request('/cart/items', {
      method: 'DELETE',
      headers: bearer(token),
      body: JSON.stringify({
        productId: selectedProduct._id,
        size: selection.size,
        color: selection.color,
      }),
    })
    push('cart-remove', cartRemove)
    assert(cartRemove.status == 200, 'Cart line remove must succeed.', cartRemove)

    const cartAfterRemove = await request('/cart', { headers: bearer(token) })
    push('cart-after-remove', cartAfterRemove, { count: cartAfterRemove.body?.items?.length ?? null })
    assert(
      cartAfterRemove.status == 200 && !cartLineFor(cartAfterRemove.body?.items, selectedProduct, selection),
      'Removed cart line must not remain in cart.',
      cartAfterRemove,
    )

    const cartReAdd = await request('/cart/items', {
      method: 'POST',
      headers: bearer(token),
      body: JSON.stringify(addPayload),
    })
    push('cart-readd-for-checkout', cartReAdd)
    assert(cartReAdd.status == 200, 'Cart re-add before checkout must succeed.', cartReAdd)

    const orderID = `ecommerce-smoke-order-${runID}`
    const order = await request('/orders', {
      method: 'POST',
      headers: bearer(token),
      body: JSON.stringify({
        id: orderID,
        items: [addPayload],
        shippingAddress: {
          name: 'Ecommerce Smoke',
          street: '12 Nile Corniche, Zamalek',
          city: 'Cairo',
          postalCode: '11561',
          phone: '01012345678',
          email,
        },
        deliveryLocation: 'Cairo',
        shippingMethodName: 'Standard',
        paymentMethod: { type: 'cod', displayName: 'Cash on Delivery' },
        promoCode: 'WELCOME50',
      }),
    })
    push('checkout-create-order', order, { orderID })
    assert(order.status == 201 && order.body?.orders?.[0]?.id == orderID, 'Checkout must create an order.', order)
    createdOrderID = orderID

    const cartAfterCheckout = await request('/cart', { headers: bearer(token) })
    push('cart-after-checkout', cartAfterCheckout, { count: cartAfterCheckout.body?.items?.length ?? null })
    assert(cartAfterCheckout.status == 200 && cartAfterCheckout.body?.items?.length == 0, 'Checkout must clear the customer cart.', cartAfterCheckout)

    const orders = await request('/orders', { headers: bearer(token) })
    push('order-history', orders, { count: orders.body?.orders?.length ?? null })
    assert(orders.status == 200 && orders.body?.orders?.some((item) => item.id == createdOrderID), 'Order history must include the placed order.', orders)

    const orderDetail = await request(`/orders/${createdOrderID}`, { headers: bearer(token) })
    push('order-detail', orderDetail, { orderID: createdOrderID })
    assert(orderDetail.status == 200 && orderDetail.body?.order?.id == createdOrderID, 'Order detail must return the placed order.', orderDetail)

    const logout = await request('/auth/logout', {
      method: 'POST',
      headers: bearer(token),
    })
    push('logout', logout)
    assert(logout.status == 200, 'Logout must be reachable.', logout)

    const cleanup = await request('/account/delete', {
      method: 'POST',
      headers: bearer(token),
    })
    push('account-delete-cleanup', cleanup)
    assert(cleanup.status == 200, 'Smoke customer cleanup must delete the account.', cleanup)
    token = null

    console.log(JSON.stringify({
      ok: true,
      baseURL,
      productID: selectedProduct._id,
      orderID: createdOrderID,
      selection,
      results,
    }, null, 2))
  } finally {
    if (token) {
      const cleanup = await request('/account/delete', {
        method: 'POST',
        headers: bearer(token),
      }).catch((error) => ({ status: null, ok: false, body: String(error) }))
      push('cleanup-account-delete', cleanup)
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
