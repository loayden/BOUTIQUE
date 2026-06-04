import { spawnSync } from 'node:child_process'
import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.production.local')

const keys = [
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

function redacted(text, env) {
  let output = text
  for (const key of keys) {
    const value = env[key]
    if (value) {
      output = output.split(value).join('[redacted]')
    }
  }
  return output
}

function validate(env) {
  const missing = keys.filter((key) => !env[key])
  if (missing.length > 0) {
    throw new Error(`Missing production env values: ${missing.join(', ')}`)
  }

  if (env.AURELIEN_SECRETS_ROTATED !== 'YES' && process.env.AURELIEN_SECRETS_ROTATED !== 'YES') {
    throw new Error('Refusing to sync production env until AURELIEN_SECRETS_ROTATED=YES is set after rotating exposed secrets.')
  }

  if (process.env.AURELIEN_CONFIRM_PRODUCTION_ENV_UPDATE !== 'YES') {
    throw new Error('Dry run only. Set AURELIEN_CONFIRM_PRODUCTION_ENV_UPDATE=YES to update Vercel production env.')
  }
}

function syncKey(key, value, env) {
  const result = spawnSync(
    'npm',
    ['exec', '--yes', 'vercel', '--', 'env', 'add', key, 'production', '--force', '--sensitive', '--yes'],
    {
      cwd: rootDir,
      input: value,
      encoding: 'utf8',
      maxBuffer: 1024 * 1024,
    },
  )

  if (result.status !== 0) {
    const details = redacted(`${result.stdout ?? ''}\n${result.stderr ?? ''}`, env).trim()
    throw new Error(`Failed to sync ${key}${details ? `: ${details}` : ''}`)
  }

  console.log(`synced ${key}`)
}

async function main() {
  const fileEnv = await loadEnvFile()
  const env = {
    ...fileEnv,
    ...Object.fromEntries(keys.map((key) => [key, process.env[key]]).filter(([, value]) => value)),
    AURELIEN_SECRETS_ROTATED: process.env.AURELIEN_SECRETS_ROTATED ?? fileEnv.AURELIEN_SECRETS_ROTATED,
  }

  validate(env)

  for (const key of keys) {
    syncKey(key, env[key], env)
  }

  console.log('Production Vercel environment synced. Redeploy the API before running live smoke tests.')
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error))
  process.exitCode = 1
})
