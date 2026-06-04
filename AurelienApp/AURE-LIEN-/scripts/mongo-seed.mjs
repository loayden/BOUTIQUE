import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import process from 'node:process'
import { MongoClient } from 'mongodb'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.local')
const productsPath = path.join(rootDir, 'public', 'v1', 'products.json')

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
  const force = process.argv.includes('--force')

  if (!uri) {
    throw new Error('AURELIEN_MONGODB_URI is required for seeding.')
  }

  const rawProducts = await fs.readFile(productsPath, 'utf8')
  const productPayload = JSON.parse(rawProducts)
  const seedState = {
    users: [],
    profiles: [],
    carts: [],
    orders: [],
    notifications: [],
    catalogProducts: Array.isArray(productPayload.products) ? productPayload.products : [],
    deletedCatalogProductIDs: [],
    legacyClosetByUser: {},
    discover: {
      styleDNAByUser: {},
      closetByUser: {},
      waitlists: {},
      votesByChallenge: {},
      likedOutfitsByUser: {},
      savedOutfitsByUser: {},
      followedCreatorsByUser: {},
      subscriptionAssignments: [],
      boosts: [],
      tryBeforeBuy: [],
    },
  }

  const client = new MongoClient(uri)
  await client.connect()

  try {
    const database = client.db(databaseName)
    await database.collection('uploaded_product_images').createIndex({ createdAt: -1 })

    const collection = database.collection('app_state')
    const existing = await collection.findOne({ _id: 'main' }, { projection: { _id: 1 } })

    if (existing && !force) {
      console.log(`MongoDB already seeded in database "${databaseName}". Use --force to overwrite app_state/main.`)
      return
    }

    await collection.updateOne(
      { _id: 'main' },
      {
        $set: {
          state: seedState,
          updatedAt: new Date(),
        },
      },
      { upsert: true },
    )

    console.log(
      `Seeded MongoDB database "${databaseName}" from ${path.relative(rootDir, productsPath)} with a clean app state scaffold.`,
    )
  } finally {
    await client.close()
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
