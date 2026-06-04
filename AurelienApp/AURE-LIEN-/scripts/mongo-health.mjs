import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import process from 'node:process'
import { MongoClient } from 'mongodb'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.local')

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
    const value = line.slice(separatorIndex + 1).trim()
    result[key] = value
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

async function main() {
  const fileEnv = await loadEnvFile()
  const uri = process.env.AURELIEN_MONGODB_URI || fileEnv.AURELIEN_MONGODB_URI
  const databaseName = process.env.AURELIEN_MONGODB_DB || fileEnv.AURELIEN_MONGODB_DB || 'aurelien'

  if (!uri) {
    throw new Error('AURELIEN_MONGODB_URI is required for health checks.')
  }

  const client = new MongoClient(uri)
  await client.connect()

  try {
    const database = client.db(databaseName)
    const ping = await database.command({ ping: 1 })
    const stateDocument = await database.collection('app_state').findOne(
      { _id: 'main' },
      { projection: { _id: 1, updatedAt: 1, 'state.catalogProducts': 1 } },
    )
    const uploadCount = await database.collection('uploaded_product_images').countDocuments()
    const productCount = Array.isArray(stateDocument?.state?.catalogProducts)
      ? stateDocument.state.catalogProducts.length
      : 0

    console.log(JSON.stringify({
      ok: ping.ok === 1,
      database: databaseName,
      appStateSeeded: Boolean(stateDocument),
      productCount,
      uploadCount,
      updatedAt: stateDocument?.updatedAt ?? null,
    }, null, 2))
  } finally {
    await client.close()
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
