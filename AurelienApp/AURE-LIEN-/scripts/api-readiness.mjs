import process from 'node:process'

const baseURL = (process.env.AURELIEN_SMOKE_BASE_URL?.trim() || 'http://127.0.0.1:3104/api').replace(/\/$/, '')
const imageSampleLimit = Number(process.env.AURELIEN_SMOKE_IMAGE_SAMPLE_LIMIT ?? 12)
const requestTimeoutMS = Number(process.env.AURELIEN_SMOKE_TIMEOUT_MS ?? 10000)

const requiredRoutes = [
  { name: 'api-index', endpoint: '', validate: validateAPIIndex },
  { name: 'health', endpoint: '/health', validate: validateHealth },
  { name: 'products', endpoint: '/products', validate: validateProducts },
  { name: 'boutiques', endpoint: '/boutiques', validate: validateArrayPayload },
  { name: 'discover-feed', endpoint: '/discover/feed', validate: validateArrayPayload },
  { name: 'support-channels', endpoint: '/support/channels', validate: validateArrayPayload },
  { name: 'support-faqs', endpoint: '/support/faqs', validate: validateArrayPayload },
  { name: 'legal-documents', endpoint: '/legal/documents', validate: validateArrayPayload },
]

async function fetchJSON(endpoint) {
  const response = await fetchWithTimeout(`${baseURL}${endpoint}`, {
    headers: {
      Accept: 'application/json',
    },
  })
  const text = await response.text()
  let body = null

  try {
    body = text ? JSON.parse(text) : null
  } catch {
    body = text
  }

  return {
    endpoint,
    status: response.status,
    ok: response.ok,
    body,
  }
}

async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), requestTimeoutMS)

  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    })
  } finally {
    clearTimeout(timeout)
  }
}

function validateAPIIndex(body) {
  assertRecord(body, 'API index must be a JSON object.')
  assert(typeof body.service == 'string' && body.service.length > 0, 'API index must expose a service name.')
}

function validateHealth(body) {
  assertRecord(body, 'Health response must be a JSON object.')
  assert(typeof body.service == 'string' && body.service.length > 0, 'Health response must expose a service name.')
  assertRecord(body.database, 'Health response must include database details.')
  assert(typeof body.database.reachable == 'boolean', 'Health database details must include reachable boolean.')
}

function validateArrayPayload(body, routeName) {
  assert(Array.isArray(body), `${routeName} must return an array.`)
}

function validateProducts(body) {
  assertRecord(body, 'Products response must be a JSON object.')
  assert(Array.isArray(body.products), 'Products response must include a products array.')
  assert(body.products.length > 0, 'Products response must include at least one product.')

  const invalidProducts = []
  const imageURLs = new Set()

  for (const product of body.products) {
    if (!isRecord(product)) {
      invalidProducts.push('non-object product')
      continue
    }

    const id = stringValue(product._id) || stringValue(product.id) || stringValue(product.name) || 'unknown'
    const images = arrayValue(product.images).concat(arrayValue(product.imageNames)).map(stringValue).filter(Boolean)
    if (images.length == 0) {
      invalidProducts.push(id)
      continue
    }

    imageURLs.add(resolveURL(images[0]))
  }

  assert(
    invalidProducts.length == 0,
    `Every product must include at least one image. Missing images: ${invalidProducts.slice(0, 8).join(', ')}`,
  )

  return {
    productCount: body.products.length,
    imageURLs: Array.from(imageURLs),
  }
}

async function validateImageURLs(imageURLs) {
  const sampledURLs = imageURLs.slice(0, Math.max(0, imageSampleLimit))
  const results = []
  const failures = []

  for (const imageURL of sampledURLs) {
    try {
      const response = await fetchWithTimeout(imageURL, {
        method: 'GET',
        headers: {
          Accept: 'image/*,*/*;q=0.8',
        },
      })
      const contentType = response.headers.get('content-type') ?? ''
      const ok = response.ok && contentType.toLowerCase().startsWith('image/')
      const result = {
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
      const result = {
        url: imageURL,
        status: null,
        contentType: null,
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      }
      results.push(result)
      failures.push(result)
    }
  }

  return { results, failures }
}

function resolveURL(value) {
  return new URL(value, baseURL.replace(/\/api$/, '')).toString()
}

function arrayValue(value) {
  return Array.isArray(value) ? value : []
}

function stringValue(value) {
  return typeof value == 'string' ? value.trim() : ''
}

function isRecord(value) {
  return typeof value == 'object' && value != null && !Array.isArray(value)
}

function assertRecord(value, message) {
  assert(isRecord(value), message)
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message)
  }
}

async function main() {
  const startedAt = new Date().toISOString()
  const routeResults = []
  const failures = []
  let productImageURLs = []

  for (const route of requiredRoutes) {
    try {
      const response = await fetchJSON(route.endpoint)
      const payload = {
        name: route.name,
        endpoint: route.endpoint || '/',
        status: response.status,
        ok: response.ok,
      }

      if (!response.ok) {
        throw new Error(`${route.name} returned HTTP ${response.status}`)
      }

      const validationResult = route.validate(response.body, route.name)
      if (route.name == 'products') {
        payload.productCount = validationResult.productCount
        productImageURLs = validationResult.imageURLs
      }

      routeResults.push(payload)
    } catch (error) {
      const failure = {
        name: route.name,
        endpoint: route.endpoint || '/',
        message: error instanceof Error ? error.message : String(error),
      }
      routeResults.push({ ...failure, ok: false })
      failures.push(failure)
    }
  }

  const imageCheck = await validateImageURLs(productImageURLs)
  failures.push(...imageCheck.failures.map((failure) => ({
    name: 'product-image',
    endpoint: failure.url,
    message: `Product image returned ${failure.status ?? 'network error'} with content-type ${failure.contentType ?? 'unknown'}.`,
  })))

  const report = {
    ok: failures.length == 0,
    baseURL,
    startedAt,
    routeResults,
    imageSample: imageCheck.results,
    failures,
  }

  console.log(JSON.stringify(report, null, 2))

  if (!report.ok) {
    process.exitCode = 1
  }
}

main().catch((error) => {
  console.error(JSON.stringify({
    ok: false,
    baseURL,
    message: error instanceof Error ? error.message : String(error),
  }, null, 2))
  process.exitCode = 1
})
