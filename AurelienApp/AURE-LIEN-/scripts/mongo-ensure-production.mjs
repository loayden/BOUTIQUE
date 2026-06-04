import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import process from 'node:process'
import { MongoClient } from 'mongodb'

const rootDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const envPath = path.resolve(rootDir, process.env.AURELIEN_ENV_FILE || '.env.local')
const productsPath = path.join(rootDir, 'public', 'v1', 'products.json')
const publicDir = path.join(rootDir, 'public')

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

function mongoOptions() {
  const serverSelectionTimeoutMS = Number(process.env.AURELIEN_MONGODB_SERVER_SELECTION_TIMEOUT_MS ?? 10000)
  const connectTimeoutMS = Number(process.env.AURELIEN_MONGODB_CONNECT_TIMEOUT_MS ?? 10000)
  return {
    maxPoolSize: Number(process.env.AURELIEN_MONGODB_MAX_POOL_SIZE ?? 5),
    serverSelectionTimeoutMS,
    connectTimeoutMS,
  }
}

async function ensureCollection(database, name, validator) {
  const collections = await database.listCollections({ name }).toArray()
  if (collections.length == 0) {
    await database.createCollection(name, {
      validator,
      validationLevel: 'moderate',
      validationAction: 'warn',
    })
    return 'created'
  }

  try {
    await database.command({
      collMod: name,
      validator,
      validationLevel: 'moderate',
      validationAction: 'warn',
    })
    return 'updated'
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    if (/not allowed|unauthorized|requires authentication/i.test(message)) {
      return 'exists-validation-skip-insufficient-privilege'
    }
    throw error
  }
}

async function ensureIndex(collection, key) {
  const expected = JSON.stringify(key)
  const existing = await collection.indexes()
  if (existing.some((index) => JSON.stringify(index.key) == expected)) {
    return false
  }
  await collection.createIndex(key)
  return true
}

async function ensureSeedState(database) {
  const collection = database.collection('app_state')
  const existing = await collection.findOne({ _id: 'main' }, { projection: { _id: 1 } })
  if (existing) {
    return false
  }

  const productPayload = JSON.parse(await fs.readFile(productsPath, 'utf8'))
  const seedState = {
    users: [],
    profiles: [],
    carts: [],
    orders: [],
    notifications: [],
    savedAddressesByUser: {},
    paymentMethodsByUser: {},
    savedProductIDsByUser: {},
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

  await collection.updateOne(
    { _id: 'main' },
    { $set: { state: seedState, updatedAt: new Date() } },
    { upsert: true },
  )
  return true
}

async function validateCatalogImages(products, uploadedImages) {
  const missingImages = []
  const missingFiles = []

  for (const product of products) {
    const productID = stringValue(product._id) || stringValue(product.id) || stringValue(product.name) || 'unknown'
    const images = arrayValue(product.images).concat(arrayValue(product.imageNames)).map(stringValue).filter(Boolean)
    if (images.length == 0) {
      missingImages.push(productID)
      continue
    }

    for (const image of images) {
      if (/^https?:\/\//i.test(image)) {
        continue
      }

      if (image.startsWith('/api/uploads/product-image/')) {
        const fileName = path.basename(image)
        if (!uploadedImages.has(fileName)) {
          missingFiles.push(`${productID}: ${image}`)
        }
        continue
      }

      const relativePath = image.startsWith('/') ? image.slice(1) : path.join('uploads', image)
      try {
        await fs.access(path.join(publicDir, relativePath))
      } catch {
        missingFiles.push(`${productID}: ${image}`)
      }
    }
  }

  return { missingImages, missingFiles }
}

function arrayValue(value) {
  return Array.isArray(value) ? value : []
}

function stringValue(value) {
  return typeof value == 'string' ? value.trim() : ''
}

async function main() {
  const fileEnv = await loadEnvFile()
  const uri = process.env.AURELIEN_MONGODB_URI || fileEnv.AURELIEN_MONGODB_URI
  const databaseName = process.env.AURELIEN_MONGODB_DB || fileEnv.AURELIEN_MONGODB_DB || 'aurelien'

  if (!uri) {
    throw new Error('AURELIEN_MONGODB_URI is required for production Mongo validation.')
  }

  const client = new MongoClient(uri, mongoOptions())
  await client.connect()

  try {
    const database = client.db(databaseName)
    const ping = await database.command({ ping: 1 })

    const appStateValidator = {
      $jsonSchema: {
        bsonType: 'object',
        required: ['_id', 'state', 'updatedAt'],
        properties: {
          _id: { enum: ['main'] },
          state: { bsonType: 'object' },
          updatedAt: { bsonType: 'date' },
        },
      },
    }

    const uploadValidator = {
      $jsonSchema: {
        bsonType: 'object',
        required: ['_id', 'contentType', 'data', 'size', 'createdAt'],
        properties: {
          _id: {
            bsonType: 'string',
            pattern: '^product-[A-Za-z0-9._-]+$',
          },
          contentType: {
            bsonType: 'string',
            pattern: '^image/',
          },
          data: { bsonType: 'binData' },
          size: { bsonType: ['int', 'long', 'double'] },
          createdAt: { bsonType: 'date' },
        },
      },
    }

    const appStateCollectionStatus = await ensureCollection(database, 'app_state', appStateValidator)
    const uploadCollectionStatus = await ensureCollection(database, 'uploaded_product_images', uploadValidator)
    const seededNow = await ensureSeedState(database)

    const appState = database.collection('app_state')
    const uploads = database.collection('uploaded_product_images')

    await ensureIndex(appState, { updatedAt: -1 })
    await ensureIndex(uploads, { createdAt: -1 })
    await ensureIndex(uploads, { contentType: 1 })
    await ensureIndex(uploads, { size: 1 })

    const stateDocument = await appState.findOne({ _id: 'main' })
    const products = arrayValue(stateDocument?.state?.catalogProducts)
    const deletedIDs = new Set(arrayValue(stateDocument?.state?.deletedCatalogProductIDs).map(stringValue))
    const activeProducts = products.filter((product) => !deletedIDs.has(stringValue(product?._id)))
    const uploadedImageIDs = new Set(
      (await uploads.find({}, { projection: { _id: 1 } }).toArray()).map((image) => stringValue(image._id)),
    )
    const imageValidation = await validateCatalogImages(activeProducts, uploadedImageIDs)

    const duplicateProductIDs = products
      .map((product) => stringValue(product?._id))
      .filter(Boolean)
      .filter((id, index, values) => values.indexOf(id) != index)

    const invalidProducts = activeProducts
      .filter((product) => !stringValue(product.name) || typeof product.price != 'number' || product.price <= 0)
      .map((product) => stringValue(product._id) || stringValue(product.name) || 'unknown')

    const failures = [
      ...imageValidation.missingImages.map((id) => `Product has no images: ${id}`),
      ...imageValidation.missingFiles.map((entry) => `Product image target missing: ${entry}`),
      ...duplicateProductIDs.map((id) => `Duplicate product id: ${id}`),
      ...invalidProducts.map((id) => `Invalid product basics: ${id}`),
    ]

    const report = {
      ok: ping.ok === 1 && failures.length == 0,
      database: databaseName,
      appStateCollectionStatus,
      uploadCollectionStatus,
      seededNow,
      productCount: products.length,
      activeProductCount: activeProducts.length,
      deletedProductCount: deletedIDs.size,
      uploadCount: uploadedImageIDs.size,
      indexes: {
        app_state: (await appState.indexes()).map((index) => index.name),
        uploaded_product_images: (await uploads.indexes()).map((index) => index.name),
      },
      failures,
    }

    console.log(JSON.stringify(report, null, 2))
    if (!report.ok) {
      process.exitCode = 1
    }
  } finally {
    await client.close()
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
