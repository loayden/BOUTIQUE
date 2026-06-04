import crypto from 'crypto'
import { NextResponse } from 'next/server'
import type { CatalogProduct } from '../../../lib/backend'

import {
  absoluteMediaURL,
  authenticatedUser,
  buildAnalytics,
  catalogStockProblem,
  codResult,
  createUserRecord,
  deleteCatalogProduct,
  defaultProfileForUser,
  enrichProductImages,
  findProfile,
  getBoutiques,
  getCatalog,
  getDiscoverContent,
  getLegalContent,
  getSupportContent,
  databaseHealthSummary,
  issueToken,
  normalizeOrderStatus,
  normalizeText,
  passwordHashNeedsUpgrade,
  promoResult,
  ProductValidationError,
  publicProfile,
  publicUser,
  readState,
  readUploadedProductImage,
  releaseCatalogStock,
  reserveCatalogStock,
  saveUploadedProductImage,
  upsertCart,
  upsertCatalogProduct,
  upsertNotification,
  upsertProfile,
  validateCatalogProduct,
  verifyPassword,
  visibleOrdersForUser,
  writeState,
} from '../../../lib/backend'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'
const experimentalCommerceEndpointsEnabled = configuredBoolean('AURELIEN_ENABLE_EXPERIMENTAL_ENDPOINTS')

type RouteContext = {
  params: Promise<{
    segments?: string[]
  }>
}

type OrderPlacementRequest = {
  id?: string
  items?: Array<{
    productId?: string
    quantity?: number
    size?: string | null
    color?: string | null
  }>
  totalPrice?: number
  total?: number
  status?: string
  subtotal?: number
  shippingCost?: number
  discount?: number
  promoCode?: string | null
  shippingCity?: string
  shippingAddress?: {
    name?: string
    street?: string
    city?: string
    postalCode?: string
    phone?: string
    email?: string | null
    apartment?: string | null
  } | null
  paymentMethodId?: string | null
  paymentMethod?: {
    type?: string
    displayName?: string
  } | null
  deliveryLocation?: string | null
  codFee?: number | null
  customerName?: string | null
  customerEmail?: string | null
  customerPhone?: string | null
  shippingMethodName?: string | null
}

type RouteState = Awaited<ReturnType<typeof readState>>
type RouteUser = NonNullable<Awaited<ReturnType<typeof authenticatedUser>>>

export async function GET(request: Request, context: RouteContext) {
  const segments = await resolvedSegments(context)

  if (isExperimentalCommerceRoute(segments) && !experimentalCommerceEndpointsEnabled) {
    return jsonError('This content is not available right now.', 404)
  }

  if (segments[0] == 'health') {
    const database = await databaseHealthSummary()
    return NextResponse.json({
      ok: database.reachable,
      service: 'BOUTIQUE API',
      storage: database.storage,
      database,
    }, {
      status: database.reachable ? 200 : 503,
      headers: {
        'Cache-Control': 'no-store',
      },
    })
  }

  if (segments[0] == 'uploads' && segments[1] == 'product-image' && segments[2]) {
    const image = await readUploadedProductImage(segments[2])
    if (!image) {
      return jsonError('Image not found.', 404)
    }

    return new Response(new Uint8Array(image.data), {
      headers: {
        'Content-Type': image.contentType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    })
  }

  if (segments[0] == 'products' && segments.length == 1) {
    const catalog = await getCatalog()
    return dynamicJSON({
      products: catalog.map((product) => enrichProductImages(request, product)),
    })
  }

  if (segments[0] == 'products' && segments.length == 2) {
    const catalog = await getCatalog()
    const product = catalog.find((item) => item._id == segments[1])
    if (!product) {
      return jsonError('Product not found.', 404)
    }
    return dynamicJSON(enrichProductImages(request, product))
  }

  if (segments[0] == 'products' && segments[2] == 'related') {
    const catalog = await getCatalog()
    const product = catalog.find((item) => item._id == segments[1])
    if (!product) {
      return jsonError('Product not found.', 404)
    }
    const related = catalog
      .filter((item) => item._id != product._id && item.category == product.category)
      .slice(0, 6)
      .map((item) => enrichProductImages(request, item))
    return dynamicJSON(related)
  }

  if (
    (segments[0] == 'boutiques' && segments.length == 1) ||
    (segments[0] == 'boutiques' && segments[1] == 'nearby')
  ) {
    const boutiques = await getBoutiques()
    return publicJSON(boutiques, 300)
  }

  if (segments[0] == 'boutiques' && segments.length == 2) {
    const boutiques = await getBoutiques()
    const boutique = boutiques.find((item) => item.id == segments[1])
    if (!boutique) {
      return jsonError('Boutique not found.', 404)
    }
    return publicJSON(boutique, 300)
  }

  if (segments[0] == 'boutiques' && segments[2] == 'stories') {
    return NextResponse.json([])
  }

  if (segments[0] == 'boutique' && segments[1] == 'products') {
    const catalog = await getCatalog()
    return dynamicJSON(
      catalog.map((product) => ({
        id: product._id,
        name: product.name,
        images: product.images.map((image) => absoluteMediaURL(request, image)),
        price: product.price,
        sizes: product.size,
        colors: product.colors,
        boutiqueId: 'aurelien-curated-house',
        description: product.description,
      })),
    )
  }

  if (segments[0] == 'support' && segments.length == 1) {
    const support = await getSupportContent()
    return publicJSON(support, 300)
  }

  if (segments[0] == 'support' && segments[1] == 'channels') {
    const support = await getSupportContent()
    return publicJSON(support.channels, 300)
  }

  if (segments[0] == 'support' && segments[1] == 'faqs') {
    const support = await getSupportContent()
    return publicJSON(support.faqs, 300)
  }

  if (segments[0] == 'legal' && segments.length == 1) {
    const legal = await getLegalContent()
    return publicJSON(legal, 300)
  }

  if (segments[0] == 'legal' && segments[1] == 'documents') {
    const legal = await getLegalContent()
    return publicJSON(legal.documents, 300)
  }

  if (segments[0] == 'legal' && segments.length == 2) {
    const legal = await getLegalContent()
    const document = legal.documents.find((item) => item.id == segments[1])
    if (!document) {
      return jsonError('Legal document not found.', 404)
    }
    return publicJSON(document, 300)
  }

  if (segments[0] == 'discover' && segments[1] == 'feed') {
    const discover = await getDiscoverContent()
    return publicJSON(discover.feed, 120)
  }

  if (segments[0] == 'discover' && segments[1] == 'drops') {
    const discover = await getDiscoverContent()
    return publicJSON(discover.drops, 120)
  }

  if (segments[0] == 'drops') {
    const discover = await getDiscoverContent()
    return publicJSON(
      discover.drops.map((drop, index) => ({
        id: stableUUID(index),
        title: String(drop.name ?? drop.title ?? 'Limited Drop'),
        description: String(drop.copy ?? drop.description ?? ''),
        endTime: String(drop.unlocksAt ?? new Date(Date.now() + 1000 * 60 * 60).toISOString()),
      })),
      120,
    )
  }

  if (segments[0] == 'discover' && segments[1] == 'challenges') {
    const discover = await getDiscoverContent()
    return publicJSON(discover.challenges, 120)
  }

  if (segments[0] == 'discover' && segments[1] == 'subscription' && segments[2] == 'plans') {
    const discover = await getDiscoverContent()
    return publicJSON(discover.subscriptionPlans, 120)
  }

  if (isProtectedGetRoute(segments) && !hasAuthorizationToken(request)) {
    return jsonError('Unauthorized', 401)
  }

  const state = await readState()
  const user = await authenticatedUser(request)

  if (segments[0] == 'account' && segments.length == 1) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      user: publicUser(user),
      profile: publicProfile(findProfile(state, user)),
    })
  }

  if (segments[0] == 'discover' && segments[1] == 'leaderboard') {
    return NextResponse.json(discoverLeaderboardFromState(state))
  }

  if (segments[0] == 'gamification' && segments[1] == 'leaderboard') {
    return NextResponse.json(
      discoverLeaderboardFromState(state).map((entry, index) => ({
        id: stableUUID(index + 20),
        rank: entry.rank,
        username: entry.name,
        points: entry.score,
      })),
    )
  }

  if (segments[0] == 'discover' && (segments[1] == 'me' || segments[1] == 'state')) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json(discoverUserStateForUser(state, user))
  }

  if (segments[0] == 'discover' && segments[1] == 'closet') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      productIds: state.discover.closetByUser[user.id] ?? [],
    })
  }

  if (segments[0] == 'discover' && segments[1] == 'style-dna') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const discover = await getDiscoverContent()
    return NextResponse.json(
      state.discover.styleDNAByUser[user.id] ?? discover.defaultStyleDNA,
    )
  }

  if (segments[0] == 'users' && segments[1] == 'me') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    if (segments[2] == 'profile') {
      return NextResponse.json({
        profile: publicProfile(findProfile(state, user)),
      })
    }
    return NextResponse.json(publicUser(user))
  }

  if (
    segments[0] == 'profile' ||
    (segments[0] == 'account' && segments[1] == 'profile')
  ) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      profile: publicProfile(findProfile(state, user)),
    })
  }

  if (segments[0] == 'notifications') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const notifications = state.notifications
      .filter((item) => item.userId == user.id)
      .sort((lhs, rhs) => rhs.timestamp.localeCompare(lhs.timestamp))
    return NextResponse.json(notifications)
  }

  if (segments[0] == 'wallet') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      savedAddresses: state.savedAddressesByUser[user.id] ?? [],
      paymentMethods: state.paymentMethodsByUser[user.id] ?? [],
    })
  }

  if (segments[0] == 'social' && segments[1] == 'users') {
    const customers = state.users.filter((item) => !item.isAdmin)
    return NextResponse.json(
      (customers.length ? customers : state.users).map((item, index) => ({
        id: item.id,
        name: item.name,
        username: item.email.split('@')[0] || `client${index + 1}`,
      })),
    )
  }

  if (segments[0] == 'stylist' && segments[1] == 'prompts') {
    return NextResponse.json([
      { id: 'outerwear', title: 'Outerwear edit', prompt: 'Build around one jacket and quiet contrast.', category: 'jackets' },
      { id: 'tailoring', title: 'Tailoring reset', prompt: 'Start from suits and soften with knitwear.', category: 'suits' },
      { id: 'denim', title: 'Denim uniform', prompt: 'Use denim as the base and keep footwear clean.', category: 'denim' },
    ])
  }

  if (segments[0] == 'gamification' && segments[1] == 'me') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      points: state.orders.filter((order) => order.userId == user.id).length * 100,
      badges: [
        { id: 'member', title: user.isAdmin ? 'Admin' : 'Member', icon: user.isAdmin ? 'shield.fill' : 'star.fill' },
      ],
    })
  }

  if (segments[0] == 'trybeforebuy' && segments[1] == 'eligibility') {
    return NextResponse.json({ eligible: true })
  }

  if (segments[0] == 'closet') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const catalog = await getCatalog()
    const productItems = (state.discover.closetByUser[user.id] ?? []).flatMap((productId) => {
      const product = catalog.find((candidate) => candidate._id == productId)
      if (!product) {
        return []
      }
      return [{
        id: product._id,
        productId: product._id,
        name: product.name,
        color: product.colors[0] ?? 'default',
        brand: 'BOUTIQUE',
        image: absoluteMediaURL(request, product.images[0] ?? '/uploads/main.jpg'),
      }]
    })
    return NextResponse.json([...(state.legacyClosetByUser[user.id] ?? []), ...productItems])
  }

  if (segments[0] == 'saved' && segments[1] == 'me') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const catalogById = new Map(
      (await getCatalog()).map((product) => [product._id, product] as const),
    )
    const products = (state.savedProductIDsByUser[user.id] ?? [])
      .flatMap((productId) => {
        const product = catalogById.get(productId)
        return product ? [enrichProductImages(request, product)] : []
      })
    return NextResponse.json({ products })
  }

  if (segments[0] == 'cart') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const catalog = await getCatalog()
    const cart = state.carts.find((item) => item.userId == user.id) ?? { userId: user.id, items: [] }
    const items = cart.items.flatMap((item) => {
      const product = catalog.find((candidate) => candidate._id == item.productId)
      if (!product) {
        return []
      }
      return [
        {
          _id: `${item.productId}:${item.size ?? 'one-size'}:${item.color ?? 'default'}`,
          productId: item.productId,
          name: product.name,
          price: product.price,
          image: absoluteMediaURL(request, product.images[0] ?? '/uploads/main.jpg'),
          size: item.size ?? null,
          color: item.color ?? null,
          quantity: item.quantity,
        },
      ]
    })
    return NextResponse.json({ items })
  }

  if (segments[0] == 'orders' && segments.length == 1) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      orders: visibleOrdersForUser(state, user),
    })
  }

  if (segments[0] == 'orders' && segments.length == 2) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const order = state.orders.find((item) => item.id == segments[1])
    if (!order || (!user.isAdmin && order.userId != user.id)) {
      return jsonError('Order not found.', 404)
    }
    return NextResponse.json({ order })
  }

  if (segments[0] == 'admin' && segments[1] == 'orders') {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({ orders: visibleOrdersForUser(state, user) })
  }

  if (segments[0] == 'admin' && segments[1] == 'users') {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json({
      users: state.users.map((item) => publicUser(item)),
    })
  }

  if (
    segments[0] == 'admin' &&
    (segments[1] == 'analytics' || segments[1] == 'stats')
  ) {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }
    return NextResponse.json(await buildAnalytics(state))
  }

  return jsonError('This content is not available right now.', 404)
}

export async function POST(request: Request, context: RouteContext) {
  const segments = await resolvedSegments(context)

  if (isExperimentalCommerceRoute(segments) && !experimentalCommerceEndpointsEnabled) {
    return jsonError('This action is not available right now.', 404)
  }

  if (isProtectedPostRoute(segments) && !hasAuthorizationToken(request)) {
    return jsonError('Unauthorized', 401)
  }

  if (segments[0] == 'orders' && segments[1] == 'validate-cod') {
    const body = (await request.json().catch(() => null)) as { governorate?: string } | null
    if (!body?.governorate?.trim()) {
      return jsonError('Governorate is required.', 400)
    }
    return NextResponse.json(codResult(body.governorate))
  }

  if (segments[0] == 'orders' && segments[1] == 'validate-promo') {
    const body = (await request.json().catch(() => null)) as { code?: string } | null
    return NextResponse.json(promoResult(body?.code ?? ''))
  }

  const state = await readState()
  const user = await authenticatedUser(request)

  if (segments[0] == 'auth' && segments[1] == 'signup') {
    const body = (await request.json().catch(() => null)) as
      | { name?: string; email?: string; password?: string; confirmPassword?: string; phone?: string | null }
      | null

    const name = body?.name?.trim()
    const email = body?.email?.trim().toLowerCase()
    const password = body?.password?.trim()
    const confirmPassword = body?.confirmPassword?.trim()

    if (!name || !email || !password) {
      return jsonError('Name, email, and password are required.', 400)
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return jsonError('Enter a valid email address.', 400)
    }

    if (password.length < 8) {
      return jsonError('Use a password with at least 8 characters.', 400)
    }

    if (confirmPassword != null && confirmPassword != password) {
      return jsonError('Password confirmation does not match.', 400)
    }

    if (state.users.some((candidate) => candidate.email == email)) {
      return jsonError('An account already exists for this email address.', 409)
    }

    const nextUser = createUserRecord({
      name,
      email,
      password,
      phone: body?.phone ?? null,
    })

    const nextState = {
      ...state,
      users: [nextUser, ...state.users],
      profiles: [defaultProfileForUser(nextUser), ...state.profiles],
    }
    await writeState(nextState)

    return NextResponse.json({
      user: publicUser(nextUser),
      token: issueToken(nextUser),
    })
  }

  if (segments[0] == 'auth' && (segments[1] == 'signin' || segments[1] == 'login')) {
    const body = (await request.json().catch(() => null)) as
      | { email?: string; password?: string }
      | null

    const email = body?.email?.trim().toLowerCase()
    const password = body?.password?.trim()

    if (!email || !password) {
      return jsonError('Email and password are required.', 400)
    }

    const matchedUser = state.users.find(
      (candidate) =>
        candidate.email == email && verifyPassword(password, candidate.passwordHash),
    )

    if (!matchedUser) {
      return jsonError('Invalid email or password.', 401)
    }

    if (passwordHashNeedsUpgrade(matchedUser.passwordHash)) {
      await writeState({
        ...state,
        users: state.users.map((candidate) =>
          candidate.id == matchedUser.id
            ? createUserRecord({
                name: candidate.name,
                email: candidate.email,
                password,
                phone: candidate.phone ?? null,
                isAdmin: candidate.isAdmin,
              })
            : candidate,
        ).map((candidate) =>
          candidate.email == matchedUser.email
            ? {
                ...candidate,
                id: matchedUser.id,
                createdAt: matchedUser.createdAt,
              }
            : candidate,
        ),
      })
    }

    return NextResponse.json({
      user: publicUser(matchedUser),
      token: issueToken(matchedUser),
    })
  }

  if (segments[0] == 'auth' && segments[1] == 'logout') {
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'auth' && segments[1] == 'refresh') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    return NextResponse.json({
      user: publicUser(user),
      token: issueToken(user),
    })
  }

  if (segments[0] == 'account' && segments[1] == 'delete') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const targetUser = state.users.find((item) => item.id == user.id)
    if (targetUser?.isAdmin) {
      const remainingAdmins = state.users.filter((item) => item.isAdmin && item.id != user.id)
      if (remainingAdmins.length == 0) {
        return jsonError('At least one administrator account must remain.', 409)
      }
    }

    await writeState(deleteUserOwnedState(state, user.id))
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'uploads' && segments[1] == 'product-image') {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }

    try {
      const formData = await request.formData()
      const file = formData.get('file')
      if (!(file instanceof File)) {
        return jsonError('Product image file is required.', 400)
      }

      const imagePath = await saveUploadedProductImage(file)
      return NextResponse.json({
        path: imagePath,
        url: absoluteMediaURL(request, imagePath),
      }, { status: 201 })
    } catch (error) {
      return validationError(error)
    }
  }

  if (segments[0] == 'products' && segments.length == 1) {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }

    try {
      const body = await request.json()
      const catalog = await getCatalog()
      const product = validateCatalogProduct(body, new Set(catalog.map((item) => item._id)))
      const nextState = upsertCatalogProduct(state, product)
      await writeState(nextState)
      return NextResponse.json(enrichProductImages(request, product), { status: 201 })
    } catch (error) {
      return validationError(error)
    }
  }

  if (segments[0] == 'saved' && segments[1] == 'me') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const body = (await request.json().catch(() => null)) as { productId?: string } | null
    const productId = body?.productId?.trim()
    if (!productId) {
      return jsonError('Product ID is required.', 400)
    }

    const catalog = await getCatalog()
    if (!catalog.some((product) => product._id == productId)) {
      return jsonError('Product not found.', 404)
    }

    const nextState = {
      ...state,
      savedProductIDsByUser: {
        ...state.savedProductIDsByUser,
        [user.id]: Array.from(new Set([productId, ...(state.savedProductIDsByUser[user.id] ?? [])])),
      },
    }
    await writeState(nextState)

    const catalogById = new Map(catalog.map((product) => [product._id, product] as const))
    const products = (nextState.savedProductIDsByUser[user.id] ?? [])
      .flatMap((savedId) => {
        const product = catalogById.get(savedId)
        return product ? [enrichProductImages(request, product)] : []
      })
    return NextResponse.json({ products }, { status: 201 })
  }

  if (segments[0] == 'wallet' && segments[1] == 'addresses') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const body = (await request.json().catch(() => null)) as {
      id?: string
      label?: string
      recipient?: string
      line1?: string
      apartment?: string | null
      city?: string
      phone?: string
      isPrimary?: boolean
    } | null

    const label = body?.label?.trim() ?? ''
    const recipient = body?.recipient?.trim() ?? ''
    const line1 = body?.line1?.trim() ?? ''
    const city = body?.city?.trim() ?? ''
    const phone = body?.phone?.trim() ?? ''

    if (!label || !recipient || !line1 || !city || !phone) {
      return jsonError('Complete address details are required.', 400)
    }

    const existingAddresses = state.savedAddressesByUser[user.id] ?? []
    const nextAddress = {
      id: body?.id?.trim() || `address-${crypto.randomUUID()}`,
      label,
      recipient,
      line1,
      apartment: body?.apartment?.trim() || null,
      city,
      phone,
      isPrimary: body?.isPrimary == true || existingAddresses.length == 0,
    }

    const nextAddresses = [
      nextAddress,
      ...existingAddresses
        .filter((address) => address.id != nextAddress.id)
        .map((address) => nextAddress.isPrimary ? { ...address, isPrimary: false } : address),
    ]

    await writeState({
      ...state,
      savedAddressesByUser: {
        ...state.savedAddressesByUser,
        [user.id]: nextAddresses,
      },
    })
    return NextResponse.json({ savedAddresses: nextAddresses }, { status: 201 })
  }

  if (segments[0] == 'cart') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const body = (await request.json().catch(() => null)) as
      | { productId?: string; size?: string | null; color?: string | null; quantity?: number }
      | null

    if (!body?.productId?.trim() || !body.quantity || body.quantity < 1) {
      return jsonError('A valid cart line is required.', 400)
    }

    const productId = body.productId.trim()
    const catalog = await getCatalog()
    const product = catalog.find((candidate) => candidate._id == productId)
    const selectionProblem = catalogSelectionProblem(product, body.size, body.color)
    if (selectionProblem) {
      return jsonError(selectionProblem, 400)
    }
    const stockProblem = catalogStockProblem(product, body.quantity)
    if (stockProblem) {
      return jsonError(stockProblem, 409)
    }

    const cart = state.carts.find((item) => item.userId == user.id) ?? {
      userId: user.id,
      items: [],
    }

    const lineKey = `${productId}:${body.size ?? ''}:${body.color ?? ''}`
    const nextItems = [...cart.items]
    const lineIndex = nextItems.findIndex(
      (item) => `${item.productId}:${item.size ?? ''}:${item.color ?? ''}` == lineKey,
    )

    if (lineIndex >= 0) {
      nextItems[lineIndex] = {
        ...nextItems[lineIndex],
        quantity: body.quantity,
      }
    } else {
      nextItems.push({
        productId,
        size: body.size ?? null,
        color: body.color ?? null,
        quantity: body.quantity,
      })
    }

    await writeState(
      upsertCart(state, {
        userId: user.id,
        items: nextItems,
      }),
    )

    return NextResponse.json({ success: true })
  }

  if (
    segments[0] == 'orders' &&
    (segments.length == 1 || (segments[1] == 'place' && segments.length == 2))
  ) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const body = (await request.json().catch(() => null)) as OrderPlacementRequest | null
    if (!body?.items?.length) {
      return jsonError('Order items are required.', 400)
    }

    const catalog = await getCatalog()
    const deliveryLocation =
      body.deliveryLocation?.trim() ||
      body.shippingAddress?.city?.trim() ||
      body.shippingCity?.trim() ||
      ''
    const customerName =
      body.customerName?.trim() ||
      body.shippingAddress?.name?.trim() ||
      user.name
    const customerEmail =
      body.customerEmail?.trim() ||
      body.shippingAddress?.email?.trim() ||
      user.email
    const customerPhone =
      body.customerPhone?.trim() ||
      body.shippingAddress?.phone?.trim() ||
      user.phone ||
      ''
    const streetAddress = body.shippingAddress?.street?.trim() || ''

    if (customerName.replace(/\s+/g, '').length < 2) {
      return jsonError('Customer name is required.', 400)
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(customerEmail)) {
      return jsonError('Enter a valid email address.', 400)
    }

    const phoneDigits = customerPhone.replace(/\D/g, '')
    if (phoneDigits.length != 11 || !phoneDigits.startsWith('01')) {
      return jsonError('Use an 11-digit Egyptian mobile number starting with 01.', 400)
    }

    if (streetAddress.length < 8) {
      return jsonError('Add a complete delivery address.', 400)
    }

    if (!deliveryLocation) {
      return jsonError('Delivery governorate is required.', 400)
    }

    const paymentMethodId =
      body.paymentMethodId?.trim() || body.paymentMethod?.type?.trim() || ''

    if (!['cod', 'vodafone_cash'].includes(paymentMethodId)) {
      return jsonError('Choose an active payment method.', 400)
    }

    const codValidation = codResult(deliveryLocation)
    if (paymentMethodId == 'cod') {
      if (!codValidation.eligible) {
        return jsonError('Cash on delivery is not available in this governorate.', 400)
      }
    }

    const requestedQuantities = new Map<string, number>()
    for (const item of body.items) {
      const productId = item.productId?.trim()
      if (!productId) {
        continue
      }
      requestedQuantities.set(productId, (requestedQuantities.get(productId) ?? 0) + Math.max(1, item.quantity ?? 1))
    }

    for (const [productId, quantity] of requestedQuantities) {
      const product = catalog.find((candidate) => candidate._id == productId)
      const stockProblem = catalogStockProblem(product, quantity)
      if (stockProblem) {
        return jsonError(stockProblem, 409)
      }
    }

    const orderId = body.id?.trim() || `order-${Date.now()}`
    if (state.orders.some((order) => order.id == orderId)) {
      return jsonError('Order id already exists.', 409)
    }

    const orderItems = body.items.flatMap((item) => {
      const product = catalog.find((candidate) => candidate._id == item.productId?.trim())
      if (!product) {
        return []
      }
      if (catalogSelectionProblem(product, item.size, item.color)) {
        return []
      }

      return [
        {
          productId: product._id,
          name: product.name,
          price: product.price,
          image: absoluteMediaURL(request, product.images[0] ?? '/uploads/main.jpg'),
          quantity: Math.max(1, item.quantity ?? 1),
          size: item.size ?? null,
          color: item.color ?? null,
        },
      ]
    })

    if (!orderItems.length) {
      return jsonError('Order items are invalid.', 400)
    }

    const subtotal = orderItems.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0,
    )
    const shippingMethodName = body.shippingMethodName?.trim() || 'Standard'
    const normalizedShippingMethod = shippingMethodName.toLowerCase()
    const shippingCost = normalizedShippingMethod.includes('same')
      ? 200
      : normalizedShippingMethod.includes('express')
        ? 120
        : 50
    const promo = promoResult(body.promoCode ?? '')
    const discount = promo.isValid ? promo.discount : 0
    const codFee = paymentMethodId == 'cod' ? codValidation.codFee : 0
    const totalPrice = Math.max(subtotal + shippingCost + codFee - discount, 0)

    const createdAt = new Date().toISOString()

    const nextOrder = {
      id: orderId,
      userId: user.id,
      items: orderItems,
      totalPrice,
      subtotal,
      shippingCost,
      discount,
      status: 'pending',
      createdAt,
      shippingCity: deliveryLocation,
      customer: {
        name: customerName,
        email: customerEmail,
        phone: customerPhone,
        address: streetAddress,
        apartment: body.shippingAddress?.apartment?.trim() || null,
        city: deliveryLocation,
        postalCode: body.shippingAddress?.postalCode?.trim() || '',
        country: 'Egypt',
        shippingMethod: shippingMethodName,
      },
      paymentMethodId,
      codFee,
    }

    const notification = {
      id: `notification-${orderId}`,
      userId: user.id,
      kind: 'orderUpdate',
      title: `Order ${orderId} confirmed`,
      message: 'Your order is now in the processing queue and visible in the order timeline.',
      timestamp: createdAt,
      emphasis: 'Order received',
      actionTitle: 'View Orders',
      destination: 'orders',
      isRead: false,
    }

    let nextState = reserveCatalogStock({
      ...state,
      orders: [nextOrder, ...state.orders.filter((item) => item.id != orderId)],
    }, orderItems.map((item) => ({ productId: item.productId, quantity: item.quantity })))
    nextState = upsertCart(nextState, { userId: user.id, items: [] })
    nextState = upsertNotification(nextState, notification)
    await writeState(nextState)

    return NextResponse.json({ orders: [nextOrder] }, { status: 201 })
  }

  if (
    (segments[0] == 'discover' && segments[1] == 'ai-stylist') ||
    (segments[0] == 'ai' && segments[1] == 'stylist')
  ) {
    const body = (await request.json().catch(() => null)) as
      | { message?: string; productIds?: string[] }
      | null

    const catalog = await getCatalog()
    return NextResponse.json({
      reply: stylistReply(body?.message ?? '', body?.productIds ?? [], catalog),
    })
  }

  if (
    (segments[0] == 'discover' && segments[1] == 'snap-match') ||
    (segments[0] == 'match' && segments[1] == 'snap')
  ) {
    const body = (await request.json().catch(() => null)) as { mood?: string; limit?: number } | null
    const catalog = await getCatalog()
    const query = normalizeText(body?.mood ?? '')
    const limit = Math.max(1, Math.min(body?.limit ?? 6, 20))
    const keywords = discoverMoodKeywords(query)

    const matchedProducts = catalog.filter((product) => productMatchesDiscoverMood(product, keywords))
    const matches = (matchedProducts.length ? matchedProducts : catalog)
      .slice(0, limit)
      .map((product) => enrichProductImages(request, product))

    return NextResponse.json({ products: matches })
  }

  if (segments[0] == 'discover' && segments[1] == 'closet') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { productIds?: string[] } | null
    const catalog = await getCatalog()
    const catalogIDs = new Set(catalog.map((product) => product._id))
    const productIds = Array.from(new Set((body?.productIds ?? []).map((id) => id.trim()).filter(Boolean)))
    const unknownProduct = productIds.find((id) => !catalogIDs.has(id))
    if (unknownProduct) {
      return jsonError('Select products from the live catalog only.', 400)
    }
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        closetByUser: {
          ...state.discover.closetByUser,
          [user.id]: productIds,
        },
      },
    }
    await writeState(nextState)
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'discover' && segments[1] == 'interactions') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as
      | { kind?: string; targetId?: string; isActive?: boolean }
      | null
    const targetId = body?.targetId?.trim()
    if (!targetId) {
      return jsonError('Interaction target is required.', 400)
    }

    const update = (current: string[] = []) => {
      const values = new Set(current)
      if (body?.isActive) {
        values.add(targetId)
      } else {
        values.delete(targetId)
      }
      return Array.from(values).sort()
    }

    const nextDiscover = { ...state.discover }
    switch (body?.kind) {
    case 'likedOutfit':
      nextDiscover.likedOutfitsByUser = {
        ...state.discover.likedOutfitsByUser,
        [user.id]: update(state.discover.likedOutfitsByUser[user.id]),
      }
      break
    case 'savedOutfit':
      nextDiscover.savedOutfitsByUser = {
        ...state.discover.savedOutfitsByUser,
        [user.id]: update(state.discover.savedOutfitsByUser[user.id]),
      }
      break
    case 'followedCreator':
      nextDiscover.followedCreatorsByUser = {
        ...state.discover.followedCreatorsByUser,
        [user.id]: update(state.discover.followedCreatorsByUser[user.id]),
      }
      break
    default:
      return jsonError('Unsupported discover interaction.', 400)
    }

    const nextState = {
      ...state,
      discover: nextDiscover,
    }
    await writeState(nextState)
    return NextResponse.json(discoverUserStateForUser(nextState, user))
  }

  if (segments[0] == 'discover' && segments[1] == 'try-before-buy' && segments[2] == 'reserve') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { productIds?: string[] } | null
    const catalog = await getCatalog()
    const validation = validateDiscoverProductIDs(body?.productIds ?? [], catalog)
    if ('error' in validation) {
      return jsonError(validation.error, validation.status)
    }
    const productIds = validation.productIds
    const reservation = {
      userId: user.id,
      productIds,
      createdAt: new Date().toISOString(),
    }
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        tryBeforeBuy: [
          reservation,
          ...state.discover.tryBeforeBuy,
        ],
      },
    }
    await writeState(nextState)
    return NextResponse.json(reservationReceipt(reservation))
  }

  if (segments[0] == 'discover' && segments[1] == 'subscription' && segments[2] == 'subscribe') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { planId?: string } | null
    if (!body?.planId?.trim()) {
      return jsonError('Plan id is required.', 400)
    }
    const discover = await getDiscoverContent()
    const planId = body.planId.trim()
    if (!discover.subscriptionPlans.some((plan) => String(plan.id) == planId)) {
      return jsonError('Choose an available subscription plan.', 400)
    }
    const assignment = {
      userId: user.id,
      planId,
      createdAt: new Date().toISOString(),
    }
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        subscriptionAssignments: [
          assignment,
          ...state.discover.subscriptionAssignments,
        ],
      },
    }
    await writeState(nextState)
    return NextResponse.json({
      subscribed: true,
      planId: assignment.planId,
      createdAt: assignment.createdAt,
    })
  }

  if (
    (segments[0] == 'discover' && segments[1] == 'seller-boost' && segments[2] == 'estimate') ||
    (segments[0] == 'product' && segments[1] == 'boost' && segments[2] == 'estimate')
  ) {
    const body = (await request.json().catch(() => null)) as { budget?: number; days?: number } | null
    const budget = Math.min(Math.max(body?.budget ?? 0, 100), 3000)
    const days = Math.min(Math.max(body?.days ?? 1, 1), 14)
    const estimatedReach = Math.round(budget * days * 12)
    return NextResponse.json({ estimatedReach })
  }

  if (segments[0] == 'discover' && segments[1] == 'seller-boost' && segments[2] == 'activate') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { budget?: number; days?: number } | null
    const budget = Math.min(Math.max(body?.budget ?? 400, 100), 3000)
    const days = Math.min(Math.max(body?.days ?? 3, 1), 14)
    const estimatedReach = Math.round(budget * days * 12)
    const boost = {
      userId: user.id,
      budget,
      days,
      estimatedReach,
      createdAt: new Date().toISOString(),
    }
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        boosts: [
          boost,
          ...state.discover.boosts,
        ],
      },
    }
    await writeState(nextState)
    return NextResponse.json(boostActivation(boost))
  }

  if (segments[0] == 'discover' && segments[1] == 'drops' && segments[3] == 'waitlist') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const discover = await getDiscoverContent()
    const dropId = segments[2]
    if (!discover.drops.some((drop) => String(drop.id) == dropId)) {
      return jsonError('Drop not found.', 404)
    }
    const currentWaitlist = state.discover.waitlists[dropId] ?? []
    const nextWaitlist = Array.from(new Set([...currentWaitlist, user.id]))
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        waitlists: {
          ...state.discover.waitlists,
          [dropId]: nextWaitlist,
        },
      },
    }
    await writeState(nextState)
    return NextResponse.json({ success: true, dropId, waitlistCount: nextWaitlist.length })
  }

  if (segments[0] == 'discover' && segments[1] == 'challenges' && segments[2] == 'vote') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { challengeId?: string } | null
    const challengeId = body?.challengeId?.trim()
    if (!challengeId) {
      return jsonError('Challenge id is required.', 400)
    }
    const discover = await getDiscoverContent()
    if (!discover.challenges.some((challenge) => String(challenge.id) == challengeId)) {
      return jsonError('Challenge not found.', 404)
    }

    const votes = state.discover.votesByChallenge[challengeId] ?? []
    const totalPoints = Array.from(new Set([...votes, user.id])).length * 25
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        votesByChallenge: {
          ...state.discover.votesByChallenge,
          [challengeId]: Array.from(new Set([...votes, user.id])),
        },
      },
    }
    await writeState(nextState)
    return NextResponse.json({
      pointsAwarded: votes.includes(user.id) ? 0 : 25,
      totalPoints,
    })
  }

  if (segments[0] == 'trybeforebuy' && segments[1] == 'request') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { productIds?: string[] } | null
    const catalog = await getCatalog()
    const validation = validateDiscoverProductIDs(body?.productIds ?? [], catalog)
    if ('error' in validation) {
      return jsonError(validation.error, validation.status)
    }
    const reservation = {
      userId: user.id,
      productIds: validation.productIds,
      createdAt: new Date().toISOString(),
    }
    await writeState({
      ...state,
      discover: {
        ...state.discover,
        tryBeforeBuy: [
          reservation,
          ...state.discover.tryBeforeBuy,
        ],
      },
    })
    return NextResponse.json(reservationReceipt(reservation))
  }

  if (segments[0] == 'subscription' && segments[1] == 'box') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { planId?: string } | null
    const discover = await getDiscoverContent()
    const planId =
      body?.planId?.trim() ||
      String(discover.subscriptionPlans[0]?.id ?? discover.subscriptionPlans[0]?.name ?? 'monthly-style-box')
    if (!discover.subscriptionPlans.some((plan) => String(plan.id ?? plan.name) == planId)) {
      return jsonError('Choose an available subscription plan.', 400)
    }
    const assignment = {
      userId: user.id,
      planId,
      createdAt: new Date().toISOString(),
    }

    await writeState({
      ...state,
      discover: {
        ...state.discover,
        subscriptionAssignments: [
          assignment,
          ...state.discover.subscriptionAssignments,
        ],
      },
    })
    return NextResponse.json({ subscribed: true, planId, createdAt: assignment.createdAt })
  }

  if (segments[0] == 'product' && segments[1] == 'boost' && segments.length == 2) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as { budget?: number; days?: number } | null
    const budget = Math.min(Math.max(body?.budget ?? 400, 100), 3000)
    const days = Math.min(Math.max(body?.days ?? 3, 1), 14)
    const estimatedReach = Math.round(budget * days * 12)
    const boost = {
      userId: user.id,
      budget,
      days,
      estimatedReach,
      createdAt: new Date().toISOString(),
    }
    await writeState({
      ...state,
      discover: {
        ...state.discover,
        boosts: [
          boost,
          ...state.discover.boosts,
        ],
      },
    })
    return NextResponse.json(boostActivation(boost))
  }

  if (segments[0] == 'closet' && segments.length == 1) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const body = (await request.json().catch(() => null)) as
      | { name?: string; color?: string; brand?: string; productIds?: string[] }
      | null
    const catalog = await getCatalog()
    const productIds = Array.from(new Set((body?.productIds ?? []).map((id) => id.trim()).filter(Boolean)))
    if (productIds.length > 0) {
      const catalogIDs = new Set(catalog.map((product) => product._id))
      const unknownProduct = productIds.find((id) => !catalogIDs.has(id))
      if (unknownProduct) {
        return jsonError('Select products from the live catalog only.', 400)
      }
      await writeState({
        ...state,
        discover: {
          ...state.discover,
          closetByUser: {
            ...state.discover.closetByUser,
            [user.id]: productIds,
          },
        },
      })
      return NextResponse.json({ success: true, productIds }, { status: 201 })
    }

    const name = body?.name?.trim()
    if (!name) {
      return jsonError('Closet item name is required.', 400)
    }

    const item = {
      id: crypto.randomUUID(),
      name,
      color: body?.color?.trim() || 'gray',
      brand: body?.brand?.trim() || 'BOUTIQUE',
    }
    const nextState = {
      ...state,
      legacyClosetByUser: {
        ...state.legacyClosetByUser,
        [user.id]: [item, ...(state.legacyClosetByUser[user.id] ?? [])],
      },
    }
    await writeState(nextState)
    return NextResponse.json(item, { status: 201 })
  }

  if (segments[0] == 'notifications' && segments[1] == 'read-all') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const nextState = {
      ...state,
      notifications: state.notifications.map((item) =>
        item.userId == user.id ? { ...item, isRead: true } : item,
      ),
    }
    await writeState(nextState)
    return NextResponse.json({ success: true })
  }

  return jsonError('This action is not available right now.', 404)
}

export async function PUT(request: Request, context: RouteContext) {
  const segments = await resolvedSegments(context)

  if (isExperimentalCommerceRoute(segments) && !experimentalCommerceEndpointsEnabled) {
    return jsonError('This action is not available right now.', 404)
  }

  if (!hasAuthorizationToken(request)) {
    return jsonError('Unauthorized', 401)
  }

  const state = await readState()
  const user = await authenticatedUser(request)

  if (!user) {
    return jsonError('Unauthorized', 401)
  }

  if (segments[0] == 'notifications' && segments[2] == 'read') {
    const notificationId = segments[1]?.trim()
    if (!notificationId) {
      return jsonError('Notification ID is required.', 400)
    }

    if (!state.notifications.some((item) => item.userId == user.id && item.id == notificationId)) {
      return jsonError('Notification not found.', 404)
    }

    const nextState = {
      ...state,
      notifications: state.notifications.map((item) =>
        item.userId == user.id && item.id == notificationId ? { ...item, isRead: true } : item,
      ),
    }
    await writeState(nextState)
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'wallet' && segments[1] == 'addresses' && segments[3] == 'primary') {
    const addressId = segments[2]?.trim()
    if (!addressId) {
      return jsonError('Address ID is required.', 400)
    }

    const currentAddresses = state.savedAddressesByUser[user.id] ?? []
    if (!currentAddresses.some((address) => address.id == addressId)) {
      return jsonError('Address not found.', 404)
    }

    const nextAddresses = currentAddresses.map((address) => ({
      ...address,
      isPrimary: address.id == addressId,
    }))

    await writeState({
      ...state,
      savedAddressesByUser: {
        ...state.savedAddressesByUser,
        [user.id]: nextAddresses,
      },
    })
    return NextResponse.json({ savedAddresses: nextAddresses })
  }

  if (segments[0] == 'cart') {
    const body = (await request.json().catch(() => null)) as
      | { productId?: string; size?: string | null; color?: string | null; quantity?: number }
      | null

    if (!body?.productId?.trim() || !body.quantity || body.quantity < 1) {
      return jsonError('A valid cart line is required.', 400)
    }

    const productId = body.productId.trim()
    const catalog = await getCatalog()
    const product = catalog.find((candidate) => candidate._id == productId)
    const selectionProblem = catalogSelectionProblem(product, body.size, body.color)
    if (selectionProblem) {
      return jsonError(selectionProblem, 400)
    }
    const stockProblem = catalogStockProblem(product, body.quantity)
    if (stockProblem) {
      return jsonError(stockProblem, 409)
    }

    const cart = state.carts.find((item) => item.userId == user.id) ?? {
      userId: user.id,
      items: [],
    }

    const lineKey = `${productId}:${body.size ?? ''}:${body.color ?? ''}`
    const nextItems = [...cart.items]
    const lineIndex = nextItems.findIndex(
      (item) => `${item.productId}:${item.size ?? ''}:${item.color ?? ''}` == lineKey,
    )

    if (lineIndex >= 0) {
      nextItems[lineIndex] = {
        ...nextItems[lineIndex],
        quantity: body.quantity,
      }
    } else {
      nextItems.push({
        productId,
        size: body.size ?? null,
        color: body.color ?? null,
        quantity: body.quantity,
      })
    }

    await writeState(
      upsertCart(state, {
        userId: user.id,
        items: nextItems,
      }),
    )

    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'products' && segments.length == 2) {
    if (!user.isAdmin) {
      return jsonError('Unauthorized', 401)
    }

    try {
      const body = await request.json()
      const product = validateCatalogProduct({ ...(body ?? {}), id: segments[1], _id: segments[1] })
      const nextState = upsertCatalogProduct(state, product)
      await writeState(nextState)
      return NextResponse.json(enrichProductImages(request, product))
    } catch (error) {
      return validationError(error)
    }
  }

  if (segments[0] == 'orders' && segments.length == 2) {
    if (!user.isAdmin) {
      return jsonError('Unauthorized', 401)
    }

    const order = state.orders.find((item) => item.id == segments[1])
    if (!order) {
      return jsonError('Order not found.', 404)
    }

    const body = (await request.json().catch(() => null)) as { status?: string } | null
    const status = normalizeOrderStatus(body?.status)
    if (!status) {
      return jsonError('Use a valid order status.', 400)
    }

    const nextOrder = { ...order, status }
    let nextState = {
      ...state,
      orders: state.orders.map((item) => (item.id == nextOrder.id ? nextOrder : item)),
    }

    const orderWasCancelled = order.status == 'cancelled'
    const orderIsCancelled = status == 'cancelled'
    const stockItems = order.items.map((item) => ({ productId: item.productId, quantity: item.quantity }))

    if (!orderWasCancelled && orderIsCancelled) {
      nextState = releaseCatalogStock(nextState, stockItems)
    }

    if (orderWasCancelled && !orderIsCancelled) {
      const catalog = await getCatalog()
      for (const item of stockItems) {
        const product = catalog.find((candidate) => candidate._id == item.productId)
        const stockProblem = catalogStockProblem(product, item.quantity)
        if (stockProblem) {
          return jsonError(stockProblem, 409)
        }
      }
      nextState = reserveCatalogStock(nextState, stockItems)
    }

    nextState = upsertNotification(nextState, {
      id: `notification-${nextOrder.id}-${status}-${Date.now()}`,
      userId: nextOrder.userId,
      kind: 'orderUpdate',
      title: `Order ${nextOrder.id} is ${status}`,
      message: `Your order status was updated to ${status}.`,
      timestamp: new Date().toISOString(),
      emphasis: 'Order update',
      actionTitle: 'View Orders',
      destination: 'orders',
      isRead: false,
    })

    await writeState(nextState)
    return NextResponse.json(nextOrder)
  }

  if (
    (segments[0] == 'users' && segments[1] == 'me' && segments[2] == 'profile') ||
    segments[0] == 'profile' ||
    (segments[0] == 'account' && segments[1] == 'profile')
  ) {
    const body = (await request.json().catch(() => null)) as
      | { name?: string; email?: string; tier?: string; city?: string; note?: string }
      | null

    const nextName = body?.name?.trim() || user.name
    const nextEmail = body?.email?.trim().toLowerCase() || user.email

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nextEmail)) {
      return jsonError('Enter a valid email address.', 400)
    }

    if (state.users.some((candidate) => candidate.id != user.id && candidate.email == nextEmail)) {
      return jsonError('An account already exists for this email address.', 409)
    }

    const nextProfile = {
      userId: user.id,
      name: nextName,
      email: nextEmail,
      tier: body?.tier?.trim() || (user.isAdmin ? 'Administrator' : 'Member'),
      city: body?.city?.trim() || 'Cairo',
      note: body?.note?.trim() || 'Manage your account preferences and order activity.',
    }

    const nextState = upsertProfile({
      ...state,
      users: state.users.map((candidate) =>
        candidate.id == user.id
          ? {
              ...candidate,
              name: nextName,
              email: nextEmail,
              updatedAt: new Date().toISOString(),
            }
          : candidate,
      ),
    }, nextProfile)
    await writeState(nextState)
    return NextResponse.json({
      profile: publicProfile(nextProfile),
      user: publicUser(
        nextState.users.find((candidate) => candidate.id == user.id) ?? {
          ...user,
          name: nextName,
          email: nextEmail,
        },
      ),
    })
  }

  if (segments[0] == 'discover' && segments[1] == 'style-dna') {
    const body = (await request.json().catch(() => null)) as
      | { style?: string; palette?: string; fit?: string }
      | null

    const discover = await getDiscoverContent()
    const nextState = {
      ...state,
      discover: {
        ...state.discover,
        styleDNAByUser: {
          ...state.discover.styleDNAByUser,
          [user.id]: {
            style: body?.style?.trim() || discover.defaultStyleDNA.style,
            palette: body?.palette?.trim() || discover.defaultStyleDNA.palette,
            fit: body?.fit?.trim() || discover.defaultStyleDNA.fit,
          },
        },
      },
    }
    await writeState(nextState)
    return NextResponse.json(nextState.discover.styleDNAByUser[user.id])
  }

  return jsonError('This action is not available right now.', 404)
}

export async function PATCH(request: Request, context: RouteContext) {
  return PUT(request, context)
}

export async function DELETE(request: Request, context: RouteContext) {
  const segments = await resolvedSegments(context)

  if (isExperimentalCommerceRoute(segments) && !experimentalCommerceEndpointsEnabled) {
    return jsonError('This action is not available right now.', 404)
  }

  if (!hasAuthorizationToken(request)) {
    return jsonError('Unauthorized', 401)
  }

  const state = await readState()
  const user = await authenticatedUser(request)

  if (segments[0] == 'account' && segments[1] == 'delete') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const targetUser = state.users.find((item) => item.id == user.id)
    if (targetUser?.isAdmin) {
      const remainingAdmins = state.users.filter((item) => item.isAdmin && item.id != user.id)
      if (remainingAdmins.length == 0) {
        return jsonError('At least one administrator account must remain.', 409)
      }
    }

    await writeState(deleteUserOwnedState(state, user.id))
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'users' && segments[1]) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const targetUserId = segments[1] == 'me' ? user.id : segments[1]
    if (!user.isAdmin && targetUserId != user.id) {
      return jsonError('Unauthorized', 401)
    }

    const targetUser = state.users.find((item) => item.id == targetUserId)
    if (targetUser?.isAdmin) {
      const remainingAdmins = state.users.filter((item) => item.isAdmin && item.id != targetUserId)
      if (remainingAdmins.length == 0) {
        return jsonError('At least one administrator account must remain.', 409)
      }
    }

    await writeState(deleteUserOwnedState(state, targetUserId))
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'notifications' && segments[1]) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    await writeState({
      ...state,
      notifications: state.notifications.filter(
        (item) => !(item.userId == user.id && item.id == segments[1]),
      ),
    })
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'wallet' && segments[1] == 'addresses' && segments[2]) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const addressId = segments[2].trim()
    const currentAddresses = state.savedAddressesByUser[user.id] ?? []
    const deletedWasPrimary = currentAddresses.some((address) => address.id == addressId && address.isPrimary)
    let nextAddresses = currentAddresses.filter((address) => address.id != addressId)
    if (deletedWasPrimary && nextAddresses.length > 0) {
      nextAddresses = nextAddresses.map((address, index) => ({
        ...address,
        isPrimary: index == 0,
      }))
    }

    await writeState({
      ...state,
      savedAddressesByUser: {
        ...state.savedAddressesByUser,
        [user.id]: nextAddresses,
      },
    })
    return NextResponse.json({ savedAddresses: nextAddresses })
  }

  if (segments[0] == 'saved' && segments[1] == 'me') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    const body = (await request.json().catch(() => null)) as { productId?: string } | null
    const productId = body?.productId?.trim()
    const nextProductIDs = productId
      ? (state.savedProductIDsByUser[user.id] ?? []).filter((savedId) => savedId != productId)
      : []

    const nextState = {
      ...state,
      savedProductIDsByUser: {
        ...state.savedProductIDsByUser,
        [user.id]: nextProductIDs,
      },
    }
    await writeState(nextState)

    const catalogById = new Map((await getCatalog()).map((product) => [product._id, product] as const))
    const products = nextProductIDs.flatMap((savedId) => {
      const product = catalogById.get(savedId)
      return product ? [enrichProductImages(request, product)] : []
    })
    return NextResponse.json({ products })
  }

  if (segments[0] == 'cart') {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }

    let productId: string | undefined = segments[1] == 'items' ? undefined : segments[1]
    let size: string | null | undefined
    let color: string | null | undefined

    if (!productId) {
      const body = (await request.json().catch(() => null)) as
        | { productId?: string; size?: string | null; color?: string | null }
        | null
      productId = body?.productId?.trim()
      size = body?.size
      color = body?.color
    }

    if (!productId) {
      await writeState(
        upsertCart(state, {
          userId: user.id,
          items: [],
        }),
      )
      return NextResponse.json({ success: true })
    }

    const cart = state.carts.find((item) => item.userId == user.id) ?? {
      userId: user.id,
      items: [],
    }

    const nextItems = cart.items.filter(
      (item) =>
        !(
          item.productId == productId &&
          (size === undefined || item.size == size) &&
          (color === undefined || item.color == color)
        ),
    )

    await writeState(
      upsertCart(state, {
        userId: user.id,
        items: nextItems,
      }),
    )
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'closet' && segments.length == 2) {
    if (!user) {
      return jsonError('Unauthorized', 401)
    }
    const current = state.discover.closetByUser[user.id] ?? []
    await writeState({
      ...state,
      legacyClosetByUser: {
        ...state.legacyClosetByUser,
        [user.id]: (state.legacyClosetByUser[user.id] ?? []).filter((item) => item.id != segments[1]),
      },
      discover: {
        ...state.discover,
        closetByUser: {
          ...state.discover.closetByUser,
          [user.id]: current.filter((id) => id != segments[1]),
        },
      },
    })
    return NextResponse.json({ success: true })
  }

  if (segments[0] == 'products' && segments.length == 2) {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }

    try {
      const nextState = await deleteCatalogProduct(state, segments[1])
      if (!nextState) {
        return jsonError('Product not found.', 404)
      }
      await writeState(nextState)
      return NextResponse.json({ success: true })
    } catch (error) {
      return validationError(error)
    }
  }

  if (segments[0] == 'orders' && segments[1]) {
    if (!user?.isAdmin) {
      return jsonError('Unauthorized', 401)
    }
    await writeState({
      ...state,
      orders: state.orders.filter((item) => item.id != segments[1]),
    })
    return NextResponse.json({ success: true })
  }

  return jsonError('This action is not available right now.', 404)
}

async function resolvedSegments(context: RouteContext): Promise<string[]> {
  const params = await context.params
  return params.segments ?? []
}

function jsonError(message: string, status: number) {
  return NextResponse.json({ message }, { status })
}

function deleteUserOwnedState(state: RouteState, targetUserId: string): RouteState {
  const releasableOrderItems = state.orders
    .filter((item) =>
      item.userId == targetUserId &&
      ['pending', 'confirmed', 'preparing'].includes(item.status),
    )
    .flatMap((order) =>
      order.items.map((item) => ({
        productId: item.productId,
        quantity: item.quantity,
      })),
    )
  const stockAdjustedState = releasableOrderItems.length
    ? releaseCatalogStock(state, releasableOrderItems)
    : state

  return {
    ...stockAdjustedState,
    users: stockAdjustedState.users.filter((item) => item.id != targetUserId),
    profiles: stockAdjustedState.profiles.filter((item) => item.userId != targetUserId),
    carts: stockAdjustedState.carts.filter((item) => item.userId != targetUserId),
    orders: stockAdjustedState.orders.filter((item) => item.userId != targetUserId),
    notifications: stockAdjustedState.notifications.filter((item) => item.userId != targetUserId),
    savedAddressesByUser: Object.fromEntries(
      Object.entries(stockAdjustedState.savedAddressesByUser).filter(([key]) => key != targetUserId),
    ),
    paymentMethodsByUser: Object.fromEntries(
      Object.entries(stockAdjustedState.paymentMethodsByUser).filter(([key]) => key != targetUserId),
    ),
    savedProductIDsByUser: Object.fromEntries(
      Object.entries(stockAdjustedState.savedProductIDsByUser).filter(([key]) => key != targetUserId),
    ),
    legacyClosetByUser: Object.fromEntries(
      Object.entries(stockAdjustedState.legacyClosetByUser).filter(([key]) => key != targetUserId),
    ),
    discover: {
      ...stockAdjustedState.discover,
      styleDNAByUser: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.styleDNAByUser).filter(([key]) => key != targetUserId),
      ),
      closetByUser: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.closetByUser).filter(([key]) => key != targetUserId),
      ),
      likedOutfitsByUser: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.likedOutfitsByUser).filter(([key]) => key != targetUserId),
      ),
      savedOutfitsByUser: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.savedOutfitsByUser).filter(([key]) => key != targetUserId),
      ),
      followedCreatorsByUser: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.followedCreatorsByUser).filter(([key]) => key != targetUserId),
      ),
      waitlists: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.waitlists).map(([key, values]) => [
          key,
          values.filter((value) => value != targetUserId),
        ]),
      ),
      votesByChallenge: Object.fromEntries(
        Object.entries(stockAdjustedState.discover.votesByChallenge).map(([key, values]) => [
          key,
          values.filter((value) => value != targetUserId),
        ]),
      ),
      subscriptionAssignments: stockAdjustedState.discover.subscriptionAssignments.filter(
        (item) => item.userId != targetUserId,
      ),
      boosts: stockAdjustedState.discover.boosts.filter((item) => item.userId != targetUserId),
      tryBeforeBuy: stockAdjustedState.discover.tryBeforeBuy.filter((item) => item.userId != targetUserId),
    },
  }
}

function publicJSON(payload: unknown, maxAgeSeconds: number) {
  return NextResponse.json(payload, {
    headers: {
      'Cache-Control': `public, max-age=0, s-maxage=${maxAgeSeconds}, stale-while-revalidate=86400`,
    },
  })
}

function dynamicJSON(payload: unknown) {
  return NextResponse.json(payload, {
    headers: {
      'Cache-Control': 'no-store',
    },
  })
}

function validationError(error: unknown) {
  if (error instanceof ProductValidationError) {
    return jsonError(error.message, error.status)
  }

  console.error(error)
  return jsonError('This action could not be completed right now.', 500)
}

function configuredBoolean(name: string): boolean {
  const rawValue = process.env[name]?.trim().toLowerCase()
  return rawValue == '1' || rawValue == 'true' || rawValue == 'yes' || rawValue == 'on'
}

function hasAuthorizationToken(request: Request): boolean {
  const header = request.headers.get('authorization') ?? ''
  return header.replace(/^Bearer\s+/i, '').trim().length > 0
}

function isProtectedGetRoute(segments: string[]): boolean {
  if (segments.length == 0) {
    return false
  }

  if (segments[0] == 'admin' || segments[0] == 'account') {
    return true
  }

  if (segments[0] == 'profile' || segments[0] == 'notifications' || segments[0] == 'wallet') {
    return true
  }

  if (segments[0] == 'users' && segments[1] == 'me') {
    return true
  }

  if (
    segments[0] == 'discover' &&
    ['me', 'state', 'closet', 'style-dna'].includes(segments[1] ?? '')
  ) {
    return true
  }

  if (segments[0] == 'gamification' && segments[1] == 'me') {
    return true
  }

  if (segments[0] == 'closet' || segments[0] == 'cart' || segments[0] == 'orders') {
    return true
  }

  if (segments[0] == 'saved' && segments[1] == 'me') {
    return true
  }

  return false
}

function isProtectedPostRoute(segments: string[]): boolean {
  if (segments.length == 0) {
    return false
  }

  if (segments[0] == 'auth') {
    return segments[1] == 'refresh'
  }

  if (segments[0] == 'orders' && (segments[1] == 'validate-cod' || segments[1] == 'validate-promo')) {
    return false
  }

  return true
}

function isExperimentalCommerceRoute(segments: string[]): boolean {
  if (segments.length == 0) {
    return false
  }

  if (segments[0] == 'social' || segments[0] == 'gamification' || segments[0] == 'closet') {
    return true
  }

  if (segments[0] == 'trybeforebuy' || segments[0] == 'subscription') {
    return true
  }

  if (segments[0] == 'product' && segments[1] == 'boost') {
    return true
  }

  if (segments[0] != 'discover') {
    return false
  }

  switch (segments[1]) {
  case 'challenges':
  case 'leaderboard':
  case 'closet':
  case 'subscription':
  case 'seller-boost':
  case 'try-before-buy':
    return true
  case 'drops':
    return segments[3] == 'waitlist'
  default:
    return false
  }
}

function catalogSelectionProblem(
  product: CatalogProduct | undefined,
  size: string | null | undefined,
  color: string | null | undefined,
): string | null {
  if (!product) {
    return 'Product not found.'
  }

  const requestedSize = size?.trim()
  if (
    requestedSize &&
    product.size.some((candidate) => normalizeText(candidate) == normalizeText(requestedSize)) == false
  ) {
    return 'Choose an available size.'
  }

  const requestedColor = color?.trim()
  if (
    requestedColor &&
    product.colors.some((candidate) => normalizeText(candidate) == normalizeText(requestedColor)) == false
  ) {
    return 'Choose an available color.'
  }

  return null
}

function discoverMoodKeywords(query: string): string[] {
  const moodKeywords: Record<string, string[]> = {
    minimal: ['minimal', 'cream', 'ivory', 'beige', 'white', 'knit', 'tailored', 'trouser', 'shirt'],
    street: ['street', 'denim', 'cargo', 'jacket', 'hoodie', 'sneaker', 'black'],
    formal: ['formal', 'suit', 'shirt', 'tailor', 'loafer', 'trouser', 'charcoal'],
    travel: ['travel', 'jacket', 'zip', 'cargo', 'bag', 'wallet', 'sneaker'],
    weekend: ['weekend', 'jeans', 'denim', 'polo', 'sweater', 'hoodie', 'sneaker'],
  }

  if (!query) {
    return []
  }

  return moodKeywords[query] ?? query.split(/\s+/).filter(Boolean)
}

function productMatchesDiscoverMood(product: CatalogProduct, keywords: string[]): boolean {
  if (!keywords.length) {
    return true
  }

  const searchable = [
    product.name,
    product.description,
    product.summary ?? '',
    product.story ?? '',
    product.category,
    ...product.colors,
    ...product.size,
  ]
    .map(normalizeText)
    .join(' ')

  return keywords.some((keyword) => searchable.includes(keyword))
}

function validateDiscoverProductIDs(
  rawProductIds: string[],
  catalog: CatalogProduct[],
): { productIds: string[] } | { error: string; status: number } {
  const catalogIds = new Set(catalog.map((product) => product._id))
  const productIds = Array.from(
    new Set(rawProductIds.map((id) => id.trim()).filter(Boolean)),
  ).sort()

  if (!productIds.length) {
    return { error: 'Select at least one live catalog item.', status: 400 }
  }

  if (productIds.some((id) => !catalogIds.has(id))) {
    return { error: 'Select products from the live catalog only.', status: 400 }
  }

  return { productIds }
}

function discoverLeaderboardFromState(state: RouteState) {
  const scores = new Map<string, number>()

  for (const user of state.users.filter((item) => !item.isAdmin)) {
    const orderPoints = state.orders.filter((order) => order.userId == user.id).length * 40
    const closetPoints = (state.discover.closetByUser[user.id] ?? []).length * 4
    const waitlistPoints = Object.values(state.discover.waitlists)
      .filter((waitlist) => waitlist.includes(user.id)).length * 8
    const subscriptionPoints = state.discover.subscriptionAssignments
      .some((assignment) => assignment.userId == user.id) ? 35 : 0
    const score = orderPoints + closetPoints + waitlistPoints + subscriptionPoints
    if (score > 0) {
      scores.set(user.id, score)
    }
  }

  for (const voters of Object.values(state.discover.votesByChallenge)) {
    for (const userId of new Set(voters)) {
      scores.set(userId, (scores.get(userId) ?? 0) + 25)
    }
  }

  return Array.from(scores.entries())
    .flatMap(([userId, score]) => {
      const user = state.users.find((candidate) => candidate.id == userId)
      if (!user || score <= 0) {
        return []
      }
      return [{ id: user.id, name: user.name, score }]
    })
    .sort((lhs, rhs) => rhs.score - lhs.score || lhs.name.localeCompare(rhs.name))
    .map((entry, index) => ({ ...entry, rank: index + 1 }))
}

function discoverUserStateForUser(state: RouteState, user: RouteUser) {
  const activeSubscription = state.discover.subscriptionAssignments
    .filter((assignment) => assignment.userId == user.id)
    .sort((lhs, rhs) => rhs.createdAt.localeCompare(lhs.createdAt))[0]
  const latestTryBeforeBuy = state.discover.tryBeforeBuy
    .filter((reservation) => reservation.userId == user.id)
    .sort((lhs, rhs) => rhs.createdAt.localeCompare(lhs.createdAt))[0]
  const latestBoost = state.discover.boosts
    .filter((boost) => boost.userId == user.id)
    .sort((lhs, rhs) => rhs.createdAt.localeCompare(lhs.createdAt))[0]

  return {
    styleDna: state.discover.styleDNAByUser[user.id] ?? null,
    closetProductIds: state.discover.closetByUser[user.id] ?? [],
    likedOutfitIds: state.discover.likedOutfitsByUser[user.id] ?? [],
    savedOutfitIds: state.discover.savedOutfitsByUser[user.id] ?? [],
    followedCreatorIds: state.discover.followedCreatorsByUser[user.id] ?? [],
    waitlistedDropIds: Object.entries(state.discover.waitlists)
      .filter(([, waitlist]) => waitlist.includes(user.id))
      .map(([dropId]) => dropId)
      .sort(),
    votedChallengeIds: Object.entries(state.discover.votesByChallenge)
      .filter(([, voters]) => voters.includes(user.id))
      .map(([challengeId]) => challengeId)
      .sort(),
    activeSubscription: activeSubscription
      ? {
        subscribed: true,
        planId: activeSubscription.planId,
        createdAt: activeSubscription.createdAt,
      }
      : null,
    latestTryBeforeBuy: latestTryBeforeBuy ? reservationReceipt(latestTryBeforeBuy) : null,
    latestBoost: latestBoost ? boostActivation(latestBoost) : null,
  }
}

function reservationReceipt(reservation: { userId: string; productIds: string[]; createdAt: string }) {
  const digest = crypto
    .createHash('sha256')
    .update(`${reservation.userId}|${reservation.createdAt}|${reservation.productIds.join('|')}`)
    .digest('hex')
    .slice(0, 12)

  return {
    id: `try-${reservation.userId}-${digest}`,
    productIds: reservation.productIds,
    status: 'requested',
    createdAt: reservation.createdAt,
  }
}

function boostActivation(boost: {
  budget: number
  days: number
  estimatedReach: number
  createdAt: string
}) {
  const digest = crypto
    .createHash('sha256')
    .update(`${boost.budget}|${boost.days}|${boost.createdAt}`)
    .digest('hex')
    .slice(0, 12)

  return {
    success: true,
    estimatedReach: boost.estimatedReach,
    campaignId: `boost-${digest}`,
    createdAt: boost.createdAt,
  }
}

function stylistReply(message: string, productIds: string[], catalog: CatalogProduct[]): string {
  const referenced = productIds
    .map((id) => catalog.find((item) => item._id == id))
    .filter((item): item is CatalogProduct => Boolean(item))
    .slice(0, 3)
  const messageWords = normalizeText(message)
    .split(/[^a-z0-9]+/i)
    .filter(Boolean)
  const keywords = Array.from(new Set([...discoverMoodKeywords(normalizeText(message)), ...messageWords]))
  const matched = catalog
    .filter((product) => productMatchesDiscoverMood(product, keywords))
    .slice(0, 3)
  const selected = (referenced.length ? referenced : matched.length ? matched : catalog.slice(0, 3))

  if (!selected.length) {
    return 'The live catalog is empty right now, so I cannot build a real outfit recommendation.'
  }

  const products = selected
    .map((product) => `${product.name} (EGP ${Math.round(product.price)})`)
    .join(', ')
  const sizes = Array.from(new Set(selected.flatMap((product) => product.size ?? []))).slice(0, 4)

  if (!sizes.length) {
    return `Use ${products}. These are live catalog pieces selected from your current Discover context.`
  }

  return `Use ${products}. Available sizes across this set include ${sizes.join(', ')}. These are live catalog pieces selected from your current Discover context.`
}

function stableUUID(index: number): string {
  return `00000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`
}
