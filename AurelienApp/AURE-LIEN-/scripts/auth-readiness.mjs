import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.local')
const baseURL = (process.env.AURELIEN_SMOKE_BASE_URL?.trim() || 'http://127.0.0.1:3104/api').replace(/\/$/, '')
const timeoutMS = Number(process.env.AURELIEN_SMOKE_TIMEOUT_MS ?? 12000)

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

function bearer(token) {
  return {
    Authorization: `Bearer ${token}`,
  }
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

  assert(adminEmail && adminPassword, 'Admin credentials are required for auth readiness smoke.')

  const email = `auth-smoke-${Date.now()}@example.com`
  const password = 'SecurePass123!'
  const results = []
  let userToken = null

  const push = (name, response, extra = {}) => {
    results.push({
      name,
      status: response?.status ?? null,
      ok: response?.ok ?? false,
      ...extra,
    })
  }

  try {
    const publicProducts = await request('/products')
    push('guest-products', publicProducts, { count: publicProducts.body?.products?.length ?? null })
    assert(publicProducts.status == 200, 'Guest products browse must be public.', publicProducts)

    const publicDiscover = await request('/discover/feed')
    push('guest-discover-feed', publicDiscover, { count: Array.isArray(publicDiscover.body) ? publicDiscover.body.length : null })
    assert(publicDiscover.status == 200, 'Guest discover feed must be public.', publicDiscover)

    const accountWithoutAuth = await request('/account')
    push('account-without-auth', accountWithoutAuth)
    assert(accountWithoutAuth.status == 401, 'Account endpoint must require auth.', accountWithoutAuth)

    const signup = await request('/auth/signup', {
      method: 'POST',
      body: JSON.stringify({
        name: 'Auth Smoke',
        email,
        password,
        confirmPassword: password,
        phone: '01012345678',
      }),
    })
    push('signup', signup)
    assert(signup.status == 200 && typeof signup.body?.token == 'string', 'Signup must return a token.', signup)
    userToken = signup.body.token

    const login = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    push('login-alias', login)
    assert(login.status == 200 && typeof login.body?.token == 'string', '/auth/login must return a token.', login)
    userToken = login.body.token

    const refresh = await request('/auth/refresh', {
      method: 'POST',
      headers: bearer(userToken),
    })
    push('refresh', refresh)
    assert(refresh.status == 200 && typeof refresh.body?.token == 'string', 'Auth refresh must return a token.', refresh)
    userToken = refresh.body.token

    const account = await request('/account', {
      headers: bearer(userToken),
    })
    push('account', account)
    assert(account.status == 200 && account.body?.user?.email == email, 'Account endpoint must return the current user.', account)

    const nonAdminAnalytics = await request('/admin/analytics', {
      headers: bearer(userToken),
    })
    push('non-admin-admin-analytics', nonAdminAnalytics)
    assert(nonAdminAnalytics.status == 401, 'Non-admin users must not access admin analytics.', nonAdminAnalytics)

    const adminLogin = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email: adminEmail,
        password: adminPassword,
      }),
    })
    push('admin-login-alias', adminLogin, { isAdmin: adminLogin.body?.user?.isAdmin === true })
    assert(adminLogin.status == 200 && adminLogin.body?.user?.isAdmin === true, 'Admin login must preserve admin role.', adminLogin)

    const adminAnalytics = await request('/admin/analytics', {
      headers: bearer(adminLogin.body.token),
    })
    push('admin-analytics', adminAnalytics)
    assert(adminAnalytics.status == 200, 'Admin token must access admin analytics.', adminAnalytics)

    const deleteAccount = await request('/account/delete', {
      method: 'POST',
      headers: bearer(userToken),
    })
    push('account-delete', deleteAccount)
    assert(deleteAccount.status == 200, '/account/delete must delete the current account.', deleteAccount)
    userToken = null

    const deletedLogin = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    push('deleted-login-rejected', deletedLogin)
    assert(deletedLogin.status == 401, 'Deleted account must not be able to log in.', deletedLogin)

    console.log(JSON.stringify({ ok: true, baseURL, results }, null, 2))
  } finally {
    if (userToken) {
      const cleanup = await request('/users/me', {
        method: 'DELETE',
        headers: bearer(userToken),
      }).catch((error) => ({ status: null, ok: false, body: String(error) }))
      push('cleanup-user', cleanup)
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
