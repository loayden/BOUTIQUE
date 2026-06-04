import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.production.local')

const requiredKeys = [
  'AURELIEN_AUTH_SECRET',
  'AURELIEN_ADMIN_EMAIL',
  'AURELIEN_ADMIN_PASSWORD',
  'AURELIEN_MONGODB_URI',
  'AURELIEN_MONGODB_DB',
  'AURELIEN_IMAGE_STORAGE',
  'AURELIEN_ENABLE_EXPERIMENTAL_ENDPOINTS',
]

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

    const key = line.slice(0, separatorIndex).trim()
    let value = line.slice(separatorIndex + 1).trim()
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    result[key] = value
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

function valueFor(env, key) {
  return process.env[key] ?? env[key] ?? ''
}

function isPlaceholder(value) {
  return !value ||
    /replace-with|your-|example\.com|placeholder|changeme|todo/i.test(value) ||
    value.includes('<') ||
    value.includes('>')
}

function validateMongoURI(value) {
  if (isPlaceholder(value)) {
    return 'must be set to a real rotated MongoDB connection string'
  }

  let parsed
  try {
    parsed = new URL(value)
  } catch {
    return 'must be a valid MongoDB URI'
  }

  if (parsed.protocol !== 'mongodb:' && parsed.protocol !== 'mongodb+srv:') {
    return 'must use mongodb:// or mongodb+srv://'
  }

  const host = parsed.hostname.toLowerCase()
  if (['localhost', '127.0.0.1', '::1'].includes(host)) {
    return 'must not point at a local database in production'
  }

  if (!parsed.username || !parsed.password) {
    return 'must include a dedicated production database username and password'
  }

  return null
}

function validate(env) {
  const failures = []
  const warnings = []

  for (const key of requiredKeys) {
    if (!valueFor(env, key)) {
      failures.push(`${key} is missing`)
    }
  }

  const authSecret = valueFor(env, 'AURELIEN_AUTH_SECRET')
  if (isPlaceholder(authSecret) || authSecret.length < 32) {
    failures.push('AURELIEN_AUTH_SECRET must be a fresh random secret with at least 32 characters')
  }

  const adminEmail = valueFor(env, 'AURELIEN_ADMIN_EMAIL')
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(adminEmail)) {
    failures.push('AURELIEN_ADMIN_EMAIL must be a valid email address')
  }

  const adminPassword = valueFor(env, 'AURELIEN_ADMIN_PASSWORD')
  if (isPlaceholder(adminPassword) || adminPassword.length < 12) {
    failures.push('AURELIEN_ADMIN_PASSWORD must be rotated and at least 12 characters')
  }

  const mongoFailure = validateMongoURI(valueFor(env, 'AURELIEN_MONGODB_URI'))
  if (mongoFailure) {
    failures.push(`AURELIEN_MONGODB_URI ${mongoFailure}`)
  }

  if (isPlaceholder(valueFor(env, 'AURELIEN_MONGODB_DB'))) {
    failures.push('AURELIEN_MONGODB_DB must be set')
  }

  if (valueFor(env, 'AURELIEN_IMAGE_STORAGE') !== 'mongodb') {
    failures.push('AURELIEN_IMAGE_STORAGE must be mongodb for Vercel production persistence')
  }

  if (valueFor(env, 'AURELIEN_ENABLE_EXPERIMENTAL_ENDPOINTS') !== 'false') {
    failures.push('AURELIEN_ENABLE_EXPERIMENTAL_ENDPOINTS must be false for App Store release')
  }

  if (process.env.AURELIEN_SECRETS_ROTATED !== 'YES') {
    warnings.push('AURELIEN_SECRETS_ROTATED=YES was not set; do not sync production until exposed secrets are rotated')
  }

  return { failures, warnings }
}

async function main() {
  const fileEnv = await loadEnvFile()
  const { failures, warnings } = validate(fileEnv)

  const report = {
    ok: failures.length === 0,
    source: Object.keys(fileEnv).length > 0 ? envPath : 'process.env',
    checkedKeys: requiredKeys,
    warnings,
    failures,
  }

  console.log(JSON.stringify(report, null, 2))
  if (!report.ok) {
    process.exitCode = 1
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error))
  process.exitCode = 1
})
