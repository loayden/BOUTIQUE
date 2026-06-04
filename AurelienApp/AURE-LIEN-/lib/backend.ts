import crypto from 'crypto'
import { promises as fs } from 'fs'
import os from 'os'
import path from 'path'

const rootDirectory = process.cwd()
const publicV1Directory = path.join(rootDirectory, 'public', 'v1')
const dataDirectory = path.join(rootDirectory, 'data')
const stateFilePath = path.join(dataDirectory, 'state.json')
const uploadDirectory = path.resolve(
  process.env.AURELIEN_UPLOAD_DIR?.trim() || path.join(rootDirectory, 'public', 'uploads', 'admin'),
)
const uploadPublicPath = '/uploads/admin'

type MongoClientType = import('mongodb').MongoClient
type MongoStateCollectionType = import('mongodb').Collection<AppStateDocument>
type MongoUploadCollectionType = import('mongodb').Collection<UploadedImageDocument>

let mongoClientPromise: Promise<MongoClientType> | null = null
const staticJSONCache = new Map<string, Promise<unknown>>()
let localStateCache: { state: AppState; loadedAt: number } | null = null
const localStateCacheTTL = Number(process.env.AURELIEN_LOCAL_STATE_CACHE_MS ?? 1000)
const isProductionRuntime = process.env.NODE_ENV == 'production'

interface AppStateDocument {
  _id: 'main'
  state: AppState
  updatedAt: Date
}

interface UploadedImageDocument {
  _id: string
  contentType: string
  data: Buffer
  size: number
  createdAt: Date
}

export interface CatalogProduct {
  _id: string
  id?: string
  name: string
  category: string
  price: number
  images: string[]
  imageNames?: string[]
  imageFocalPoint?: {
    x: number
    y: number
  }
  size: string[]
  sizes?: string[]
  description: string
  summary?: string
  story?: string
  colors: string[]
  discount?: number
  badge?: string
  featured?: boolean
  composition?: string
  care?: string
  delivery?: string
  returns?: string
  inventory?: number
  stock?: number
  inventoryCount?: number
  available?: boolean
  inStock?: boolean
  isAvailable?: boolean
  rating?: number
  reviewCount?: number
}

export interface BoutiqueRecord {
  id: string
  name: string
  area: string
  governorate: string
  dispatchNote: string
  coordinate: {
    latitude: number
    longitude: number
  }
}

interface SupportContent {
  channels: Array<{
    id: string
    title: string
    subtitle: string
    detail: string
    systemImage: string
  }>
  faqs: Array<{
    id: string
    question: string
    answer: string
  }>
}

interface LegalContent {
  documents: Array<{
    id: string
    title: string
    intro: string
    sections: Array<{
      id: string
      heading: string
      body: string[]
    }>
  }>
}

interface DiscoverContent {
  feed: Array<Record<string, unknown>>
  drops: Array<Record<string, unknown>>
  challenges: Array<Record<string, unknown>>
  leaderboard: Array<Record<string, unknown>>
  subscriptionPlans: Array<Record<string, unknown>>
  defaultStyleDNA: {
    style: string
    palette: string
    fit: string
  }
}

interface StoredUser {
  id: string
  name: string
  email: string
  phone?: string
  passwordHash: string
  isAdmin: boolean
  createdAt: string
  updatedAt: string
}

interface StoredProfile {
  userId: string
  name: string
  email: string
  tier: string
  city: string
  note: string
}

interface StoredCartItem {
  productId: string
  size?: string | null
  color?: string | null
  quantity: number
}

interface StoredCart {
  userId: string
  items: StoredCartItem[]
}

interface StoredOrderItem {
  productId: string
  name: string
  price: number
  image: string
  quantity: number
  size?: string | null
  color?: string | null
}

interface StoredOrder {
  id: string
  userId: string
  items: StoredOrderItem[]
  totalPrice: number
  subtotal: number
  shippingCost: number
  discount: number
  status: string
  createdAt: string
  shippingCity: string
  customer: {
    name: string
    email: string
    phone: string
    address: string
    apartment?: string | null
    city: string
    postalCode: string
    country: string
    shippingMethod: string
  }
  paymentMethodId?: string | null
  codFee?: number
}

interface StoredNotification {
  id: string
  userId: string
  kind: string
  title: string
  message: string
  timestamp: string
  emphasis?: string | null
  actionTitle?: string | null
  destination?: string | null
  isRead: boolean
}

interface StoredSavedAddress {
  id: string
  label: string
  recipient: string
  line1: string
  apartment?: string | null
  city: string
  phone: string
  isPrimary: boolean
}

interface StoredPaymentMethod {
  id: string
  label: string
  brand: string
  last4: string
  expiry: string
  isPrimary: boolean
}

interface DiscoverState {
  styleDNAByUser: Record<string, { style: string; palette: string; fit: string }>
  closetByUser: Record<string, string[]>
  waitlists: Record<string, string[]>
  votesByChallenge: Record<string, string[]>
  likedOutfitsByUser: Record<string, string[]>
  savedOutfitsByUser: Record<string, string[]>
  followedCreatorsByUser: Record<string, string[]>
  subscriptionAssignments: Array<{ userId: string; planId: string; createdAt: string }>
  boosts: Array<{ userId: string; budget: number; days: number; estimatedReach: number; createdAt: string }>
  tryBeforeBuy: Array<{ userId: string; productIds: string[]; createdAt: string }>
}

interface LegacyClosetItem {
  id: string
  name: string
  color: string
  brand: string
}

interface AppState {
  users: StoredUser[]
  profiles: StoredProfile[]
  carts: StoredCart[]
  orders: StoredOrder[]
  notifications: StoredNotification[]
  savedAddressesByUser: Record<string, StoredSavedAddress[]>
  paymentMethodsByUser: Record<string, StoredPaymentMethod[]>
  savedProductIDsByUser: Record<string, string[]>
  catalogProducts: CatalogProduct[]
  deletedCatalogProductIDs: string[]
  discover: DiscoverState
  legacyClosetByUser: Record<string, LegacyClosetItem[]>
}

interface TokenPayload {
  sub: string
  email: string
  isAdmin: boolean
  exp: number
}

export class ProductValidationError extends Error {
  status = 400
}

const emptyState: AppState = {
  users: [],
  profiles: [],
  carts: [],
  orders: [],
  notifications: [],
  savedAddressesByUser: {},
  paymentMethodsByUser: {},
  savedProductIDsByUser: {},
  catalogProducts: [],
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

const codGovernorates = new Set(
  [
    'Cairo',
    'Giza',
    'Alexandria',
    'Beheira',
    'Qalyubia',
    'Dakahlia',
    'Sharqia',
    'Ismailia',
  ].map(normalizeText),
)

const promoRules: Record<string, { discount: number; message: string }> = {
  WELCOME50: {
    discount: 50,
    message: 'Welcome to BOUTIQUE. EGP 50 has been applied to this order.',
  },
  BOUTIQUE10: {
    discount: 10,
    message: 'BOUTIQUE10 applied successfully.',
  },
}

export async function getCatalog(): Promise<CatalogProduct[]> {
  try {
    const state = await readState()
    return state.catalogProducts.map(normalizeCatalogProduct)
  } catch (error) {
    console.error('Catalog persistence unavailable; serving bundled catalog fallback.', error)
    return bundledCatalogProducts()
  }
}

export async function getBoutiques(): Promise<BoutiqueRecord[]> {
  const payload = await readStaticJSON<{ boutiques: BoutiqueRecord[] }>('boutiques.json', { boutiques: [] })
  return payload.boutiques
}

export async function getSupportContent(): Promise<SupportContent> {
  return readStaticJSON<SupportContent>('support.json', { channels: [], faqs: [] })
}

export async function getLegalContent(): Promise<LegalContent> {
  return readStaticJSON<LegalContent>('legal.json', { documents: [] })
}

export async function getDiscoverContent(): Promise<DiscoverContent> {
  return readStaticJSON<DiscoverContent>('discover.json', {
    feed: [],
    drops: [],
    challenges: [],
    leaderboard: [],
    subscriptionPlans: [],
    defaultStyleDNA: {
      style: 'Minimal Tailored',
      palette: 'Neutrals',
      fit: 'Regular',
    },
  })
}

export async function databaseHealthSummary(): Promise<{
  storage: 'mongodb' | 'local-json'
  databaseName: string | null
  reachable: boolean
  seeded: boolean
  error?: string
}> {
  const uri = process.env.AURELIEN_MONGODB_URI?.trim()
  const databaseName = uri ? process.env.AURELIEN_MONGODB_DB?.trim() || 'aurelien' : null

  if (!uri) {
    return {
      storage: 'local-json',
      databaseName: null,
      reachable: true,
      seeded: false,
    }
  }

  try {
    const client = await mongoClient()
    if (!client) {
      return {
        storage: 'local-json',
        databaseName: null,
        reachable: true,
        seeded: false,
      }
    }

    const database = client.db(databaseName!)
    const ping = await database.command({ ping: 1 })
    const seeded = Boolean(
      await database.collection<AppStateDocument>('app_state').findOne(
        { _id: 'main' },
        { projection: { _id: 1 } },
      ),
    )

    return {
      storage: 'mongodb',
      databaseName,
      reachable: ping.ok === 1,
      seeded,
    }
  } catch (error) {
    return {
      storage: 'mongodb',
      databaseName,
      reachable: false,
      seeded: false,
      error: error instanceof Error ? error.message : 'Unknown MongoDB error.',
    }
  }
}

export async function readState(): Promise<AppState> {
  const collection = await stateCollection()
  let state: AppState

  if (collection) {
    const document = await collection.findOne({ _id: 'main' })
    if (document?.state) {
      state = normalizeState(document.state)
    } else {
      state = normalizeState(await readJSON(stateFilePath, emptyState))
      await collection.updateOne(
        { _id: 'main' },
        { $set: { state, updatedAt: new Date() } },
        { upsert: true },
      )
    }
  } else {
    const now = Date.now()
    if (localStateCache && now - localStateCache.loadedAt <= localStateCacheTTL) {
      return localStateCache.state
    }

    state = normalizeState(await readJSON(stateFilePath, emptyState))
  }

  let hydratedState = seedAdminUser(state)
  hydratedState = await seedCatalogProductsIfNeeded(hydratedState)

  if (hydratedState !== state) {
    await writeState(hydratedState)
    return hydratedState
  }

  if (!collection) {
    localStateCache = { state: hydratedState, loadedAt: Date.now() }
  }

  return hydratedState
}

export async function writeState(state: AppState): Promise<void> {
  const normalized = normalizeState(state)
  localStateCache = { state: normalized, loadedAt: Date.now() }
  const collection = await stateCollection()
  if (collection) {
    await collection.updateOne(
      { _id: 'main' },
      { $set: { state: normalized, updatedAt: new Date() } },
      { upsert: true },
    )
    return
  }

  await ensureDirectory(dataDirectory)
  await fs.writeFile(stateFilePath, JSON.stringify(normalized, null, 2), 'utf8')
}

export async function authenticatedUser(request: Request): Promise<StoredUser | null> {
  const header = request.headers.get('authorization') ?? ''
  const token = header.replace(/^Bearer\s+/i, '').trim()

  if (!token) {
    return null
  }

  const payload = decodeToken(token)
  if (!payload) {
    return null
  }

  const state = await readState()
  return state.users.find((candidate) => candidate.id == payload.sub) ?? null
}

export function issueToken(user: Pick<StoredUser, 'id' | 'email' | 'isAdmin'>): string {
  const payload: TokenPayload = {
    sub: user.id,
    email: user.email,
    isAdmin: user.isAdmin,
    exp: Date.now() + 1000 * 60 * 60 * 24 * 30,
  }

  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url')
  const signature = sign(encodedPayload)
  return `${encodedPayload}.${signature}`
}

export function publicUser(user: StoredUser): Record<string, unknown> {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone ?? null,
    isAdmin: user.isAdmin,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  }
}

export function publicProfile(profile: StoredProfile): Record<string, unknown> {
  return {
    name: profile.name,
    email: profile.email,
    tier: profile.tier,
    city: profile.city,
    note: profile.note,
  }
}

export function absoluteMediaURL(request: Request, assetPath: string): string {
  if (/^https?:\/\//i.test(assetPath)) {
    return assetPath
  }

  const origin = new URL(request.url).origin
  return `${origin}${assetPath.startsWith('/') ? assetPath : `/${assetPath}`}`
}

export function enrichProductImages(request: Request, product: CatalogProduct): CatalogProduct {
  const images = product.images.map((image) => absoluteMediaURL(request, image))
  return {
    ...product,
    images,
    imageNames: images,
  }
}

export function commerceImageObjectPosition(product: CatalogProduct): string {
  const focalPoint = product.imageFocalPoint ?? { x: 50, y: 18 }
  return `${focalPoint.x}% ${focalPoint.y}%`
}

export function validateCatalogProduct(input: unknown, existingIDs: Set<string> = new Set()): CatalogProduct {
  const body = isRecord(input) ? input : {}
  const id = stringValue(body.id) || stringValue(body._id) || `product-${crypto.randomUUID()}`
  const name = stringValue(body.name)
  const category = stringValue(body.category) || 'shirts'
  const price = numberValue(body.price)
  const images = stringArrayValue(body.imageNames ?? body.images)
  const sizes = stringArrayValue(body.sizes ?? body.size)
  const colorNames = colorNamesValue(body.colors)
  const summary = stringValue(body.summary) || stringValue(body.description)
  const story = stringValue(body.story) || summary
  const inventory = numberValue(body.inventoryCount ?? body.inventory ?? body.stock)
  const available = booleanValue(body.isAvailable ?? body.available ?? body.inStock)
  const imageFocalPoint = focalPointValue(body.imageFocalPoint ?? body.cardFocalPoint)

  if (!name) {
    throw new ProductValidationError('Product name is required.')
  }
  if (price == null || !Number.isFinite(price) || price <= 0) {
    throw new ProductValidationError('Enter a price greater than zero.')
  }
  if (!summary) {
    throw new ProductValidationError('Product summary is required.')
  }
  if (images.length == 0) {
    throw new ProductValidationError('At least one product image is required.')
  }
  if (sizes.length == 0) {
    throw new ProductValidationError('At least one product size is required.')
  }
  if (colorNames.length == 0) {
    throw new ProductValidationError('At least one product color is required.')
  }
  if (existingIDs.has(id) && !stringValue(body.id) && !stringValue(body._id)) {
    throw new ProductValidationError('Product ID already exists.')
  }

  return normalizeCatalogProduct({
    _id: id,
    id,
    name,
    category,
    price,
    images,
    imageNames: images,
    imageFocalPoint,
    size: sizes,
    sizes,
    description: summary,
    summary,
    story,
    colors: colorNames,
    badge: stringValue(body.badge) || undefined,
    featured: booleanValue(body.featured) ?? false,
    composition: stringValue(body.composition) || undefined,
    care: stringValue(body.care) || undefined,
    delivery: stringValue(body.delivery) || undefined,
    returns: stringValue(body.returns) || undefined,
    inventory,
    stock: inventory,
    inventoryCount: inventory,
    available,
    inStock: available,
    isAvailable: available,
    rating: numberValue(body.rating),
    reviewCount: numberValue(body.reviewCount ?? body.reviewsCount),
  })
}

export function upsertCatalogProduct(state: AppState, product: CatalogProduct): AppState {
  const normalizedProduct = normalizeCatalogProduct(product)
  return {
    ...state,
    catalogProducts: [
      normalizedProduct,
      ...state.catalogProducts.filter((item) => item._id != normalizedProduct._id),
    ],
    deletedCatalogProductIDs: state.deletedCatalogProductIDs.filter((id) => id != normalizedProduct._id),
  }
}

export async function deleteCatalogProduct(state: AppState, productID: string): Promise<AppState | null> {
  const cleanedID = productID.trim()
  if (!cleanedID) {
    throw new ProductValidationError('Product ID is required.')
  }

  if (state.catalogProducts.some((product) => product._id == cleanedID)) {
    return {
      ...state,
      catalogProducts: state.catalogProducts.filter((product) => product._id != cleanedID),
      savedProductIDsByUser: Object.fromEntries(
        Object.entries(state.savedProductIDsByUser).map(([userId, productIDs]) => [
          userId,
          productIDs.filter((productID) => productID != cleanedID),
        ]),
      ),
      deletedCatalogProductIDs: Array.from(new Set([...state.deletedCatalogProductIDs, cleanedID])),
      carts: state.carts.map((cart) => ({
        ...cart,
        items: cart.items.filter((item) => item.productId != cleanedID),
      })),
    }
  }

  return null
}

export async function saveUploadedProductImage(file: File): Promise<string> {
  if (!file.type.startsWith('image/')) {
    throw new ProductValidationError('Only image uploads are allowed.')
  }

  const extension = imageExtension(file.type, file.name)
  const bytes = Buffer.from(await file.arrayBuffer())
  const maxUploadBytes = 8 * 1024 * 1024
  if (bytes.byteLength == 0 || bytes.byteLength > maxUploadBytes) {
    throw new ProductValidationError('Product image must be between 1 byte and 8 MB.')
  }

  const fileName = `product-${Date.now()}-${crypto.randomUUID()}.${extension}`
  const uploadCollection = await uploadedImagesCollection()

  if (uploadCollection && process.env.AURELIEN_IMAGE_STORAGE?.trim() != 'filesystem') {
    await uploadCollection.insertOne({
      _id: fileName,
      contentType: file.type,
      data: bytes,
      size: bytes.byteLength,
      createdAt: new Date(),
    })
    return `/api/uploads/product-image/${fileName}`
  }

  await ensureDirectory(uploadDirectory)
  const destination = path.join(uploadDirectory, fileName)
  await fs.writeFile(destination, bytes)

  if (process.env.AURELIEN_PUBLIC_UPLOAD_BASE_URL?.trim()) {
    return `${process.env.AURELIEN_PUBLIC_UPLOAD_BASE_URL.trim().replace(/\/$/, '')}/${fileName}`
  }

  return `${uploadPublicPath}/${fileName}`
}

export async function readUploadedProductImage(fileName: string): Promise<UploadedImageDocument | null> {
  const cleanedFileName = path.basename(fileName)
  if (cleanedFileName != fileName || !/^product-[a-zA-Z0-9._-]+$/.test(cleanedFileName)) {
    return null
  }

  const uploadCollection = await uploadedImagesCollection()
  if (uploadCollection) {
    return uploadCollection.findOne({ _id: cleanedFileName })
  }

  try {
    const filePath = path.join(uploadDirectory, cleanedFileName)
    const data = await fs.readFile(filePath)
    return {
      _id: cleanedFileName,
      contentType: contentTypeForImage(cleanedFileName),
      data,
      size: data.byteLength,
      createdAt: new Date(0),
    }
  } catch {
    return null
  }
}

export function normalizeText(value: string): string {
  return value.trim().toLowerCase()
}

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString('base64url')
  const key = crypto.scryptSync(password, salt, 64).toString('base64url')
  return `scrypt$${salt}$${key}`
}

export function verifyPassword(password: string, storedHash: string): boolean {
  if (storedHash.startsWith('scrypt$')) {
    const [, salt, key] = storedHash.split('$')
    if (!salt || !key) {
      return false
    }

    const candidate = crypto.scryptSync(password, salt, 64)
    const expected = Buffer.from(key, 'base64url')
    return expected.length == candidate.length && crypto.timingSafeEqual(expected, candidate)
  }

  const legacyHash = crypto.createHash('sha256').update(password).digest('hex')
  const expected = Buffer.from(storedHash)
  const candidate = Buffer.from(legacyHash)
  return expected.length == candidate.length && crypto.timingSafeEqual(expected, candidate)
}

export function passwordHashNeedsUpgrade(storedHash: string): boolean {
  return !storedHash.startsWith('scrypt$')
}

export function createUserRecord(input: {
  name: string
  email: string
  password: string
  phone?: string | null
  isAdmin?: boolean
}): StoredUser {
  const now = new Date().toISOString()

  return {
    id: `user-${crypto.randomUUID()}`,
    name: input.name.trim(),
    email: input.email.trim().toLowerCase(),
    phone: input.phone?.trim() || undefined,
    passwordHash: hashPassword(input.password),
    isAdmin: input.isAdmin ?? false,
    createdAt: now,
    updatedAt: now,
  }
}

export function defaultProfileForUser(user: StoredUser): StoredProfile {
  return {
    userId: user.id,
    name: user.name,
    email: user.email,
    tier: user.isAdmin ? 'Administrator' : 'Member',
    city: 'Cairo',
    note: 'Manage your account preferences and order activity.',
  }
}

export function findProfile(state: AppState, user: StoredUser): StoredProfile {
  return (
    state.profiles.find((profile) => profile.userId == user.id) ??
    defaultProfileForUser(user)
  )
}

export function upsertProfile(state: AppState, profile: StoredProfile): AppState {
  const nextProfiles = state.profiles.filter((item) => item.userId != profile.userId)
  nextProfiles.push(profile)
  return { ...state, profiles: nextProfiles }
}

export function currentCart(state: AppState, userId: string): StoredCart {
  return state.carts.find((cart) => cart.userId == userId) ?? { userId, items: [] }
}

export function upsertCart(state: AppState, cart: StoredCart): AppState {
  const carts = state.carts.filter((item) => item.userId != cart.userId)
  carts.push(cart)
  return { ...state, carts }
}

export function upsertNotification(state: AppState, notification: StoredNotification): AppState {
  return {
    ...state,
    notifications: [notification, ...state.notifications.filter((item) => item.id != notification.id)],
  }
}

export function visibleOrdersForUser(state: AppState, user: StoredUser): StoredOrder[] {
  const source = user.isAdmin ? state.orders : state.orders.filter((order) => order.userId == user.id)
  return source.sort((lhs, rhs) => rhs.createdAt.localeCompare(lhs.createdAt))
}

export async function buildAnalytics(state: AppState): Promise<Record<string, unknown>> {
  const catalog = await getCatalog()
  const totalRevenue = state.orders.reduce((sum, order) => sum + order.totalPrice, 0)
  const todayKey = new Date().toISOString().slice(0, 10)
  const todayOrders = state.orders.filter((order) => order.createdAt.slice(0, 10) == todayKey)
  const pendingOrders = state.orders.filter((order) => order.status == 'pending').length
  const statusCounts = state.orders.reduce<Record<string, number>>((accumulator, order) => {
    accumulator[order.status] = (accumulator[order.status] ?? 0) + 1
    return accumulator
  }, {})

  const productMetrics = new Map<string, { name: string; quantity: number; revenue: number }>()
  for (const order of state.orders) {
    for (const item of order.items) {
      const metric = productMetrics.get(item.productId) ?? {
        name: item.name,
        quantity: 0,
        revenue: 0,
      }
      metric.quantity += item.quantity
      metric.revenue += item.price * item.quantity
      productMetrics.set(item.productId, metric)
    }
  }

  const revenueByMonth = state.orders.reduce<Record<string, number>>((accumulator, order) => {
    const month = order.createdAt.slice(0, 7)
    accumulator[month] = (accumulator[month] ?? 0) + order.totalPrice
    return accumulator
  }, {})

  const thirtyDaysAgo = new Date(Date.now() - 1000 * 60 * 60 * 24 * 30).toISOString()
  const newUsers = state.users.filter((user) => user.createdAt >= thirtyDaysAgo).length

  return {
    totalRevenue,
    todaySales: todayOrders.reduce((sum, order) => sum + order.totalPrice, 0),
    ordersToday: todayOrders.length,
    totalOrders: state.orders.length,
    totalCustomers: state.users.filter((user) => !user.isAdmin).length,
    newUsers,
    pendingOrders,
    lowStockProducts: catalog.filter((product) => {
      const inventory = product.inventoryCount ?? product.inventory ?? product.stock
      const available = product.isAvailable ?? product.available ?? product.inStock
      return available !== false && inventory != null && inventory > 0 && inventory <= 3
    }).length,
    bestSellingProducts: Array.from(productMetrics.entries())
      .map(([id, metric]) => ({
        id,
        name: metric.name,
        quantity: metric.quantity,
        revenue: metric.revenue,
      }))
      .sort((lhs, rhs) => rhs.quantity - lhs.quantity)
      .slice(0, 5),
    revenueByMonth: Object.entries(revenueByMonth)
      .sort(([lhs], [rhs]) => lhs.localeCompare(rhs))
      .map(([month, revenue]) => ({
        month,
        revenue,
      })),
    ordersByStatus: statusCounts,
    totalProducts: catalog.length,
  }
}

export function promoResult(code: string): { isValid: boolean; discount: number; message: string } {
  const rule = promoRules[code.trim().toUpperCase()]
  if (!rule) {
    return {
      isValid: false,
      discount: 0,
      message: 'That promo code is not valid right now.',
    }
  }

  return {
    isValid: true,
    discount: rule.discount,
    message: rule.message,
  }
}

const orderStatuses = new Set(['pending', 'confirmed', 'preparing', 'shipped', 'delivered', 'cancelled'])

export function normalizeOrderStatus(value: string | null | undefined): string | null {
  const status = value?.trim().toLowerCase()
  if (!status) {
    return null
  }
  if (status == 'processing' || status == 'packed' || status == 'packing') {
    return 'preparing'
  }
  return orderStatuses.has(status) ? status : null
}

export function catalogStockProblem(product: CatalogProduct | undefined, requestedQuantity: number): string | null {
  if (!product) {
    return 'Product not found.'
  }

  const quantity = Math.max(1, requestedQuantity)
  const inventory = product.inventoryCount ?? product.inventory ?? product.stock
  const available = product.isAvailable ?? product.available ?? product.inStock

  if (available === false || inventory === 0) {
    return `${product.name} is out of stock.`
  }

  if (inventory != null && quantity > inventory) {
    return `Only ${inventory} ${inventory == 1 ? 'piece' : 'pieces'} of ${product.name} are available.`
  }

  return null
}

export function reserveCatalogStock(
  state: AppState,
  items: Array<{ productId: string; quantity: number }>,
): AppState {
  const quantities = items.reduce<Record<string, number>>((accumulator, item) => {
    accumulator[item.productId] = (accumulator[item.productId] ?? 0) + Math.max(1, item.quantity)
    return accumulator
  }, {})

  return {
    ...state,
    catalogProducts: state.catalogProducts.map((product) => {
      const requestedQuantity = quantities[product._id]
      const inventory = product.inventoryCount ?? product.inventory ?? product.stock

      if (!requestedQuantity || inventory == null) {
        return product
      }

      const nextInventory = Math.max(0, inventory - requestedQuantity)
      const wasAvailable = product.isAvailable ?? product.available ?? product.inStock
      const nextAvailable = wasAvailable === false ? false : nextInventory > 0

      return {
        ...product,
        inventory: nextInventory,
        stock: nextInventory,
        inventoryCount: nextInventory,
        available: nextAvailable,
        inStock: nextAvailable,
        isAvailable: nextAvailable,
      }
    }),
  }
}

export function releaseCatalogStock(
  state: AppState,
  items: Array<{ productId: string; quantity: number }>,
): AppState {
  const quantities = items.reduce<Record<string, number>>((accumulator, item) => {
    accumulator[item.productId] = (accumulator[item.productId] ?? 0) + Math.max(1, item.quantity)
    return accumulator
  }, {})

  return {
    ...state,
    catalogProducts: state.catalogProducts.map((product) => {
      const releasedQuantity = quantities[product._id]
      const inventory = product.inventoryCount ?? product.inventory ?? product.stock

      if (!releasedQuantity || inventory == null) {
        return product
      }

      const nextInventory = inventory + releasedQuantity
      const wasAvailable = product.isAvailable ?? product.available ?? product.inStock
      const nextAvailable = wasAvailable === false ? false : nextInventory > 0

      return {
        ...product,
        inventory: nextInventory,
        stock: nextInventory,
        inventoryCount: nextInventory,
        available: nextAvailable,
        inStock: nextAvailable,
        isAvailable: nextAvailable,
      }
    }),
  }
}

export function codResult(governorate: string): { eligible: boolean; codFee: number } {
  const eligible = codGovernorates.has(normalizeText(governorate))
  return {
    eligible,
    codFee: eligible ? 20 : 0,
  }
}

async function readStaticJSON<T>(fileName: string, fallback: T): Promise<T> {
  const filePath = path.join(publicV1Directory, fileName)
  const cached = staticJSONCache.get(filePath)
  if (cached) {
    return cached as Promise<T>
  }

  const promise = readJSON(filePath, fallback)
  staticJSONCache.set(filePath, promise)
  return promise
}

async function bundledCatalogProducts(): Promise<CatalogProduct[]> {
  const payload = await readStaticJSON<{ products: CatalogProduct[] }>('products.json', { products: [] })
  return payload.products.map(normalizeCatalogProduct)
}

async function readJSON<T>(filePath: string, fallback: T): Promise<T> {
  try {
    const raw = await fs.readFile(filePath, 'utf8')
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

async function stateCollection(): Promise<MongoStateCollectionType | null> {
  const uri = process.env.AURELIEN_MONGODB_URI?.trim()
  if (!uri) {
    if (isProductionRuntime) {
      throw new Error('AURELIEN_MONGODB_URI must be configured in production.')
    }
    return null
  }

  const client = await mongoClient()
  if (!client) {
    return null
  }
  const databaseName = process.env.AURELIEN_MONGODB_DB?.trim() || 'aurelien'
  return client.db(databaseName).collection<AppStateDocument>('app_state')
}

async function uploadedImagesCollection(): Promise<MongoUploadCollectionType | null> {
  const client = await mongoClient()
  if (!client) {
    return null
  }

  const databaseName = process.env.AURELIEN_MONGODB_DB?.trim() || 'aurelien'
  return client.db(databaseName).collection<UploadedImageDocument>('uploaded_product_images')
}

async function mongoClient(): Promise<MongoClientType | null> {
  const uri = process.env.AURELIEN_MONGODB_URI?.trim()
  if (!uri) {
    if (isProductionRuntime) {
      throw new Error('AURELIEN_MONGODB_URI must be configured in production.')
    }
    return null
  }

  if (!mongoClientPromise) {
    const { MongoClient } = await import('mongodb')
    mongoClientPromise = new MongoClient(uri, mongoClientOptions()).connect()
  }

  try {
    return await mongoClientPromise
  } catch (error) {
    mongoClientPromise = null
    throw error
  }
}

function mongoClientOptions() {
  const numberFromEnv = (key: string, fallback: number) => {
    const value = Number(process.env[key]?.trim())
    return Number.isFinite(value) && value > 0 ? value : fallback
  }

  return {
    maxPoolSize: numberFromEnv('AURELIEN_MONGODB_MAX_POOL_SIZE', 5),
    serverSelectionTimeoutMS: numberFromEnv('AURELIEN_MONGODB_SERVER_SELECTION_TIMEOUT_MS', 8000),
    connectTimeoutMS: numberFromEnv('AURELIEN_MONGODB_CONNECT_TIMEOUT_MS', 8000),
  }
}

function normalizeState(state: Partial<AppState> | undefined): AppState {
  const source = state ?? {}
  const discover = source.discover ?? emptyState.discover

  return {
    users: source.users ?? [],
    profiles: source.profiles ?? [],
    carts: source.carts ?? [],
    orders: source.orders ?? [],
    notifications: source.notifications ?? [],
    savedAddressesByUser: source.savedAddressesByUser ?? {},
    paymentMethodsByUser: source.paymentMethodsByUser ?? {},
    savedProductIDsByUser: source.savedProductIDsByUser ?? {},
    catalogProducts: (source.catalogProducts ?? []).map(normalizeCatalogProduct),
    deletedCatalogProductIDs: source.deletedCatalogProductIDs ?? [],
    legacyClosetByUser: source.legacyClosetByUser ?? {},
    discover: {
      styleDNAByUser: discover.styleDNAByUser ?? {},
      closetByUser: discover.closetByUser ?? {},
      waitlists: discover.waitlists ?? {},
      votesByChallenge: discover.votesByChallenge ?? {},
      likedOutfitsByUser: discover.likedOutfitsByUser ?? {},
      savedOutfitsByUser: discover.savedOutfitsByUser ?? {},
      followedCreatorsByUser: discover.followedCreatorsByUser ?? {},
      subscriptionAssignments: discover.subscriptionAssignments ?? [],
      boosts: discover.boosts ?? [],
      tryBeforeBuy: discover.tryBeforeBuy ?? [],
    },
  }
}

async function seedCatalogProductsIfNeeded(state: AppState): Promise<AppState> {
  if (state.catalogProducts.length > 0) {
    return state
  }

  const deletedIDs = new Set(state.deletedCatalogProductIDs)
  const bundledProducts = (await bundledCatalogProducts()).filter((product) => !deletedIDs.has(product._id))
  if (!bundledProducts.length) {
    return state
  }

  return {
    ...state,
    catalogProducts: bundledProducts,
  }
}

function normalizeCatalogProduct(product: CatalogProduct): CatalogProduct {
  const images = stringArrayValue(product.imageNames ?? product.images)
  const sizes = stringArrayValue(product.sizes ?? product.size)
  const colors = colorNamesValue(product.colors)
  const summary = product.summary || product.description || product.name
  const inventory = product.inventoryCount ?? product.inventory ?? product.stock
  const available = product.isAvailable ?? product.available ?? product.inStock
  const imageFocalPoint = focalPointValue(product.imageFocalPoint) ?? { x: 50, y: 18 }

  return {
    ...product,
    _id: product._id || product.id || `product-${crypto.randomUUID()}`,
    id: product.id || product._id,
    images,
    imageNames: images,
    imageFocalPoint,
    size: sizes,
    sizes,
    description: summary,
    summary,
    story: product.story || summary,
    colors,
    inventory,
    stock: inventory,
    inventoryCount: inventory,
    available,
    inStock: available,
    isAvailable: available,
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value == 'object' && value != null && !Array.isArray(value)
}

function stringValue(value: unknown): string {
  return typeof value == 'string' ? value.trim() : ''
}

function numberValue(value: unknown): number | undefined {
  if (typeof value == 'number') {
    return Number.isFinite(value) ? value : undefined
  }
  if (typeof value == 'string' && value.trim()) {
    const parsed = Number(value.trim())
    return Number.isFinite(parsed) ? parsed : undefined
  }
  return undefined
}

function booleanValue(value: unknown): boolean | undefined {
  if (typeof value == 'boolean') {
    return value
  }
  if (typeof value == 'string') {
    const normalized = value.trim().toLowerCase()
    if (['true', 'yes', '1'].includes(normalized)) {
      return true
    }
    if (['false', 'no', '0'].includes(normalized)) {
      return false
    }
  }
  return undefined
}

function focalPointValue(value: unknown): { x: number; y: number } | undefined {
  if (!isRecord(value)) {
    return undefined
  }

  const x = numberValue(value.x)
  const y = numberValue(value.y)
  if (x == null || y == null) {
    return undefined
  }

  return {
    x: Math.min(100, Math.max(0, x)),
    y: Math.min(100, Math.max(0, y)),
  }
}

function stringArrayValue(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value
      .map((item) => stringValue(item))
      .filter(Boolean)
  }

  if (typeof value == 'string') {
    return value
      .split(/[,\n]/)
      .map((item) => item.trim())
      .filter(Boolean)
  }

  return []
}

function colorNamesValue(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value
    .map((item) => {
      if (typeof item == 'string') {
        return item.trim()
      }
      if (isRecord(item)) {
        return stringValue(item.name) || stringValue(item.id)
      }
      return ''
    })
    .filter(Boolean)
}

function imageExtension(contentType: string, fileName: string): string {
  switch (contentType.toLowerCase()) {
  case 'image/png':
    return 'png'
  case 'image/webp':
    return 'webp'
  case 'image/heic':
  case 'image/heif':
    return 'heic'
  default: {
    const ext = path.extname(fileName).replace('.', '').toLowerCase()
    return ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].includes(ext) ? ext : 'jpg'
  }
  }
}

function contentTypeForImage(fileName: string): string {
  switch (path.extname(fileName).toLowerCase()) {
  case '.png':
    return 'image/png'
  case '.webp':
    return 'image/webp'
  case '.heic':
  case '.heif':
    return 'image/heic'
  case '.jpg':
  case '.jpeg':
  default:
    return 'image/jpeg'
  }
}

function sign(encodedPayload: string): string {
  return crypto
    .createHmac('sha256', authSecret())
    .update(encodedPayload)
    .digest('base64url')
}

function decodeToken(token: string): TokenPayload | null {
  const [encodedPayload, signature] = token.split('.')
  if (!encodedPayload || !signature) {
    return null
  }

  if (sign(encodedPayload) != signature) {
    return null
  }

  try {
    const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8')) as TokenPayload
    if (payload.exp < Date.now()) {
      return null
    }
    return payload
  } catch {
    return null
  }
}

function authSecret(): string {
  const configured = process.env.AURELIEN_AUTH_SECRET?.trim()
  if (configured) {
    return configured
  }

  if (process.env.NODE_ENV == 'production') {
    throw new Error('AURELIEN_AUTH_SECRET must be configured in production.')
  }

  return crypto
    .createHash('sha256')
    .update(`${rootDirectory}:${os.hostname()}:${process.env.USER ?? 'aurelien'}`)
    .digest('hex')
}

function seedAdminUser(state: AppState): AppState {
  const adminEmail = process.env.AURELIEN_ADMIN_EMAIL?.trim().toLowerCase()
  const adminPassword = process.env.AURELIEN_ADMIN_PASSWORD?.trim()

  if (!adminEmail || !adminPassword) {
    return state
  }

  const existingAdmin = state.users.find((user) => user.email == adminEmail)
  if (existingAdmin) {
    const passwordIsCurrent = verifyPassword(adminPassword, existingAdmin.passwordHash)
    const needsHashUpgrade = passwordHashNeedsUpgrade(existingAdmin.passwordHash)
    const shouldUpdateUser =
      !existingAdmin.isAdmin ||
      !passwordIsCurrent ||
      needsHashUpgrade ||
      existingAdmin.name != 'BOUTIQUE Administrator'

    const nextAdminUser: StoredUser = shouldUpdateUser
      ? {
          ...createUserRecord({
            name: 'BOUTIQUE Administrator',
            email: adminEmail,
            password: adminPassword,
            phone: existingAdmin.phone ?? null,
            isAdmin: true,
          }),
          id: existingAdmin.id,
          createdAt: existingAdmin.createdAt,
        }
      : existingAdmin

    const nextProfile = defaultProfileForUser(nextAdminUser)
    const profileNeedsUpdate = !state.profiles.some((profile) =>
      profile.userId == nextAdminUser.id &&
      profile.email == nextProfile.email &&
      profile.name == nextProfile.name &&
      profile.tier == nextProfile.tier,
    )

    if (!shouldUpdateUser && !profileNeedsUpdate) {
      return state
    }

    return {
      ...state,
      users: state.users.map((user) => (user.id == existingAdmin.id ? nextAdminUser : user)),
      profiles: [
        nextProfile,
        ...state.profiles.filter((profile) => profile.userId != nextAdminUser.id),
      ],
    }
  }

  const adminUser = createUserRecord({
    name: 'BOUTIQUE Administrator',
    email: adminEmail,
    password: adminPassword,
    isAdmin: true,
  })

  return {
    ...state,
    users: [adminUser, ...state.users],
    profiles: [defaultProfileForUser(adminUser), ...state.profiles],
  }
}

async function ensureDirectory(directoryPath: string): Promise<void> {
  await fs.mkdir(directoryPath, { recursive: true })
}
