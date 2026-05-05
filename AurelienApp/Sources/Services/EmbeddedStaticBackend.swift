import CryptoKit
import Foundation

actor EmbeddedStaticBackend {
    static let shared = EmbeddedStaticBackend()

    private let defaults = UserDefaults.standard
    private let stateStorageKey = "aurelien.embeddedStaticBackend.state"
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var cachedState: EmbeddedBackendState?
    private var cachedCatalog: [EmbeddedCatalogProduct]?
    private var cachedBoutiques: [EmbeddedBoutiqueRecord]?
    private var cachedDiscover: EmbeddedDiscoverContent?
    private var cachedSupport: SupportContentPayload?
    private var cachedLegal: LegalContentPayload?
    private var cachedSeedUserEmails: Set<String>?

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = Self.fractionalDateFormatter.date(from: value) {
                return date
            }

            if let date = Self.plainDateFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date string: \(value)"
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = decoder
        self.encoder = encoder
    }

    func bundledContentFile(named fileName: String) throws -> Data {
        try bundledData(named: fileName, subdirectories: ["v1"])
    }

    func performRequest(endpoint: String, method: String, body: Data?, token: String?) async throws -> Data {
        let path = normalizedPath(endpoint)
        let segments = path.split(separator: "/").map(String.init)
        let method = method.uppercased()

        switch method {
        case "GET":
            return try await handleGet(segments: segments, token: token)
        case "POST":
            return try await handlePost(segments: segments, body: body, token: token)
        case "PUT":
            return try await handlePut(segments: segments, body: body, token: token)
        case "PATCH":
            return try await handlePut(segments: segments, body: body, token: token)
        case "DELETE":
            return try await handleDelete(segments: segments, body: body, token: token)
        default:
            throw APIError.httpError(405, "This action is not available right now.")
        }
    }
}

private extension EmbeddedStaticBackend {
    static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let plainDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func normalizedPath(_ endpoint: String) -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    func bundledData(named fileName: String, subdirectories: [String]) throws -> Data {
        let bundle = Bundle.main
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        for subdirectory in [nil] + subdirectories.map(Optional.some) {
            if let url = bundle.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: subdirectory) {
                return try Data(contentsOf: url)
            }
        }

        throw APIError.notFound("Bundled content \(fileName) is missing.")
    }

    func bundledJSON<T: Decodable>(_ type: T.Type, fileName: String, subdirectories: [String]) throws -> T {
        let data = try bundledData(named: fileName, subdirectories: subdirectories)
        return try decoder.decode(T.self, from: data)
    }

    func currentState() throws -> EmbeddedBackendState {
        if let cachedState {
            return cachedState
        }

        if let cachedData = defaults.data(forKey: stateStorageKey),
           let decoded = try? decoder.decode(EmbeddedBackendState.self, from: cachedData) {
            let normalized = upgradeSeedCredentialsIfNeeded(decoded.normalized())
            try persistState(normalized)
            return normalized
        }

        let seeded = upgradeSeedCredentialsIfNeeded((try? bundledJSON(EmbeddedBackendState.self, fileName: "state.json", subdirectories: ["data"]))?.normalized()
            ?? .empty
        )
        try persistState(seeded)
        return seeded
    }

    func persistState(_ state: EmbeddedBackendState) throws {
        cachedState = state
        let data = try encoder.encode(state)
        defaults.set(data, forKey: stateStorageKey)
    }

    func catalog() throws -> [EmbeddedCatalogProduct] {
        let bundledCatalog: [EmbeddedCatalogProduct]
        if let cachedCatalog {
            bundledCatalog = cachedCatalog
        } else {
            let payload = try bundledJSON(EmbeddedCatalogPayload.self, fileName: "products.json", subdirectories: ["v1"])
            bundledCatalog = payload.products.map(\.normalized)
            cachedCatalog = bundledCatalog
        }

        let state = try currentState()
        let hiddenIDs = state.deletedCatalogProductIDs
        let createdProducts = state.catalogProducts.map(\.normalized)
        let createdIDs = Set(createdProducts.map(\.id))
        let visibleBundledCatalog = bundledCatalog.filter {
            hiddenIDs.contains($0.id) == false &&
            createdIDs.contains($0.id) == false
        }
        return createdProducts + visibleBundledCatalog
    }

    func boutiques() throws -> [EmbeddedBoutiqueRecord] {
        if let cachedBoutiques {
            return cachedBoutiques
        }

        let payload = try bundledJSON(EmbeddedBoutiquePayload.self, fileName: "boutiques.json", subdirectories: ["v1"])
        cachedBoutiques = payload.boutiques
        return payload.boutiques
    }

    func discoverContent() throws -> EmbeddedDiscoverContent {
        if let cachedDiscover {
            return cachedDiscover
        }

        let discover = try bundledJSON(EmbeddedDiscoverContent.self, fileName: "discover.json", subdirectories: ["v1"])
        cachedDiscover = discover
        return discover
    }

    func supportContent() throws -> SupportContentPayload {
        if let cachedSupport {
            return cachedSupport
        }

        let content = try bundledJSON(SupportContentPayload.self, fileName: "support.json", subdirectories: ["v1"])
        cachedSupport = content
        return content
    }

    func legalContent() throws -> LegalContentPayload {
        if let cachedLegal {
            return cachedLegal
        }

        let content = try bundledJSON(LegalContentPayload.self, fileName: "legal.json", subdirectories: ["v1"])
        cachedLegal = content
        return content
    }

    func seedUserEmails() -> Set<String> {
        if let cachedSeedUserEmails {
            return cachedSeedUserEmails
        }

        let seededState = try? bundledJSON(EmbeddedBackendState.self, fileName: "state.json", subdirectories: ["data"])
        let emails = seededState?.users.map { $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } ?? []

        let set = Set(emails)
        cachedSeedUserEmails = set
        return set
    }

    func discoverMoodKeywords(_ query: String) -> [String] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else { return [] }

        let moodKeywords: [String: [String]] = [
            "minimal": ["minimal", "cream", "ivory", "beige", "white", "knit", "tailored", "trouser", "shirt"],
            "street": ["street", "denim", "cargo", "jacket", "hoodie", "sneaker", "black"],
            "formal": ["formal", "suit", "shirt", "tailor", "loafer", "trouser", "charcoal"],
            "travel": ["travel", "jacket", "zip", "cargo", "bag", "wallet", "sneaker"],
            "weekend": ["weekend", "jeans", "denim", "polo", "sweater", "hoodie", "sneaker"]
        ]

        return moodKeywords[normalized] ?? normalized.split(separator: " ").map(String.init)
    }

    func stableUUIDString(seed: String) -> String {
        let digest = SHA256.hash(data: Data(seed.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        let padded = digest.padding(toLength: 32, withPad: "0", startingAt: 0)
        let start = padded.startIndex
        let part1End = padded.index(start, offsetBy: 8)
        let part2End = padded.index(part1End, offsetBy: 4)
        let part3End = padded.index(part2End, offsetBy: 4)
        let part4End = padded.index(part3End, offsetBy: 4)
        return [
            String(padded[start..<part1End]),
            String(padded[part1End..<part2End]),
            String(padded[part2End..<part3End]),
            String(padded[part3End..<part4End]),
            String(padded[part4End...].prefix(12))
        ].joined(separator: "-")
    }

    func product(_ product: EmbeddedCatalogProduct, matches keywords: [String]) -> Bool {
        guard keywords.isEmpty == false else { return true }
        let searchable = ([product.name, product.description, product.category] + product.colors + product.size)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: " ")
        return keywords.contains { searchable.contains($0) }
    }

    func updatedInteractionSet(_ current: [String], targetID: String, isActive: Bool) -> [String] {
        var set = Set(current)
        if isActive {
            set.insert(targetID)
        } else {
            set.remove(targetID)
        }
        return Array(set).sorted()
    }

    func requireUser(token: String?, state: EmbeddedBackendState) throws -> EmbeddedStoredUser {
        guard let user = authenticatedUser(token: token, state: state) else {
            throw APIError.unauthorized("Unauthorized")
        }
        return user
    }

    func requireAdmin(token: String?, state: EmbeddedBackendState) throws -> EmbeddedStoredUser {
        let user = try requireUser(token: token, state: state)
        guard user.isAdmin else {
            throw APIError.unauthorized("Unauthorized")
        }
        return user
    }

    func authenticatedUser(token: String?, state: EmbeddedBackendState) -> EmbeddedStoredUser? {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.hasPrefix("embedded-static."),
              token.count > "embedded-static.".count else {
            return nil
        }

        let userID = String(token.dropFirst("embedded-static.".count))
        return state.users.first(where: { $0.id == userID })
    }

    func issueToken(for user: EmbeddedStoredUser) -> String {
        "embedded-static.\(user.id)"
    }

    func hashPassword(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func upgradeSeedCredentialsIfNeeded(_ state: EmbeddedBackendState) -> EmbeddedBackendState {
        var state = state
        state.users = state.users.map { user in
            guard EmbeddedSeedAdminCredentials.email.isEmpty == false,
                  user.email.caseInsensitiveCompare(EmbeddedSeedAdminCredentials.email) == .orderedSame,
                  EmbeddedSeedAdminCredentials.migratablePasswordHashes.contains(user.passwordHash) else {
                return user
            }

            return EmbeddedStoredUser(
                id: user.id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                passwordHash: EmbeddedSeedAdminCredentials.currentPasswordHash,
                isAdmin: user.isAdmin,
                createdAt: user.createdAt,
                updatedAt: Date()
            )
        }
        return state
    }

    func publicUser(_ user: EmbeddedStoredUser) -> User {
        User(
            id: user.id,
            name: user.name,
            email: user.email,
            phone: user.phone,
            isAdmin: user.isAdmin,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
    }

    func profile(for user: EmbeddedStoredUser, state: EmbeddedBackendState) -> ClientProfile {
        if let stored = state.profiles.first(where: { $0.userId == user.id }) {
            return ClientProfile(
                name: stored.name,
                email: stored.email,
                tier: stored.tier,
                city: stored.city,
                note: stored.note
            )
        }

        return ClientProfile(
            name: user.name,
            email: user.email,
            tier: user.isAdmin ? "Administrator" : "Member",
            city: "Cairo",
            note: "Manage your account preferences and order activity."
        )
    }

    func validatedCatalogProduct(
        from product: Product,
        existingIDs: Set<String>,
        allowExistingID: Bool = false
    ) throws -> EmbeddedCatalogProduct {
        let identifier = product.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = product.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = product.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let story = product.story.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = summary.isEmpty ? story : summary
        let images = product.imageNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let sizes = product.sizes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let colors = product.colors
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard identifier.isEmpty == false else {
            throw APIError.httpError(400, "Product ID is required.")
        }
        guard allowExistingID || existingIDs.contains(identifier) == false else {
            throw APIError.httpError(409, "A product with this ID already exists.")
        }
        guard name.isEmpty == false else {
            throw APIError.httpError(400, "Product name is required.")
        }
        guard product.price.isFinite, product.price > 0 else {
            throw APIError.httpError(400, "Product price must be greater than zero.")
        }
        guard description.isEmpty == false else {
            throw APIError.httpError(400, "Product summary is required.")
        }
        guard images.isEmpty == false else {
            throw APIError.httpError(400, "At least one product image is required.")
        }
        guard sizes.isEmpty == false else {
            throw APIError.httpError(400, "At least one product size is required.")
        }
        guard colors.isEmpty == false else {
            throw APIError.httpError(400, "At least one product color is required.")
        }

        return EmbeddedCatalogProduct(
            id: identifier,
            name: name,
            category: product.category.rawValue,
            price: product.price,
            images: images,
            size: sizes,
            description: description,
            colors: colors,
            composition: product.composition.trimmingCharacters(in: .whitespacesAndNewlines),
            care: product.care.trimmingCharacters(in: .whitespacesAndNewlines),
            delivery: product.delivery.trimmingCharacters(in: .whitespacesAndNewlines),
            returns: product.returns.trimmingCharacters(in: .whitespacesAndNewlines),
            discount: nil,
            badge: product.badge?.rawValue,
            featured: product.featured,
            rating: product.rating,
            reviewCount: product.reviewCount,
            inventoryCount: product.inventoryCount,
            isAvailable: product.isAvailable
        )
    }

    func visibleOrders(for user: EmbeddedStoredUser, state: EmbeddedBackendState) -> [EmbeddedStoredOrder] {
        let source = user.isAdmin ? state.orders : state.orders.filter { $0.userId == user.id }
        return source.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func currentCart(for userID: String, state: EmbeddedBackendState) -> EmbeddedStoredCart {
        state.carts.first(where: { $0.userId == userID }) ?? EmbeddedStoredCart(userId: userID, items: [])
    }

    func cartEnvelope(for user: EmbeddedStoredUser, state: EmbeddedBackendState) throws -> EmbeddedCartEnvelope {
        let catalog = try catalog()
        let cart = currentCart(for: user.id, state: state)

        let items = cart.items.compactMap { item -> EmbeddedCartLinePayload? in
            guard let product = catalog.first(where: { $0.id == item.productId }) else {
                return nil
            }

            return EmbeddedCartLinePayload(
                id: "\(item.productId):\(item.size ?? "one-size"):\(item.color ?? "default")",
                productId: item.productId,
                name: product.name,
                price: product.price,
                image: product.images.first ?? "/uploads/main.jpg",
                size: item.size,
                color: item.color,
                quantity: max(1, item.quantity)
            )
        }

        return EmbeddedCartEnvelope(items: items)
    }

    func validateDiscoverProductIDs(_ rawProductIDs: [String]) throws -> [String] {
        let catalogIDs = Set(try catalog().map(\.id))
        let productIDs = Array(
            Set(
                rawProductIDs
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            )
        )
        guard productIDs.isEmpty == false else {
            throw APIError.httpError(400, "Select at least one live catalog item.")
        }
        guard productIDs.allSatisfy({ catalogIDs.contains($0) }) else {
            throw APIError.httpError(400, "Select products from the live catalog only.")
        }
        return productIDs.sorted()
    }

    func discoverUserState(for user: EmbeddedStoredUser, state: EmbeddedBackendState) throws -> DiscoverUserState {
        let waitlistedDropIDs = state.discover.waitlists
            .filter { Set($0.value).contains(user.id) }
            .map(\.key)
            .sorted()
        let votedChallengeIDs = state.discover.votesByChallenge
            .filter { Set($0.value).contains(user.id) }
            .map(\.key)
            .sorted()
        let activeSubscription = state.discover.subscriptionAssignments
            .filter { $0.userId == user.id }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .first
            .map {
                DiscoverSubscriptionStatus(
                    subscribed: true,
                    planID: $0.planId,
                    createdAt: $0.createdAt
                )
            }
        let latestReservation = state.discover.tryBeforeBuy
            .filter { $0.userId == user.id }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .first
            .map(reservationReceipt)
        let latestBoost = state.discover.boosts
            .filter { $0.userId == user.id }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .first
            .map(boostActivation)

        return DiscoverUserState(
            styleDNA: state.discover.styleDNAByUser[user.id],
            closetProductIDs: state.discover.closetByUser[user.id] ?? [],
            waitlistedDropIDs: waitlistedDropIDs,
            votedChallengeIDs: votedChallengeIDs,
            likedOutfitIDs: state.discover.likedOutfitsByUser[user.id] ?? [],
            savedOutfitIDs: state.discover.savedOutfitsByUser[user.id] ?? [],
            followedCreatorIDs: state.discover.followedCreatorsByUser[user.id] ?? [],
            activeSubscription: activeSubscription,
            latestTryBeforeBuy: latestReservation,
            latestBoost: latestBoost
        )
    }

    func discoverLeaderboard(from state: EmbeddedBackendState) -> [DiscoverLeaderboardData] {
        var scores: [String: Int] = [:]

        for user in state.users where user.isAdmin == false {
            let orderPoints = state.orders.filter { $0.userId == user.id }.count * 40
            let closetPoints = (state.discover.closetByUser[user.id] ?? []).count * 4
            let waitlistPoints = state.discover.waitlists.values.filter { Set($0).contains(user.id) }.count * 8
            let subscriptionPoints = state.discover.subscriptionAssignments.contains { $0.userId == user.id } ? 35 : 0
            scores[user.id, default: 0] += orderPoints + closetPoints + waitlistPoints + subscriptionPoints
        }

        for voters in state.discover.votesByChallenge.values {
            for userID in Set(voters) {
                scores[userID, default: 0] += 25
            }
        }

        return scores
            .compactMap { userID, score -> (String, String, Int)? in
                guard score > 0,
                      let user = state.users.first(where: { $0.id == userID }) else {
                    return nil
                }
                return (userID, user.name, score)
            }
            .sorted {
                if $0.2 == $1.2 {
                    return $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending
                }
                return $0.2 > $1.2
            }
            .enumerated()
            .map { index, entry in
                DiscoverLeaderboardData(
                    id: entry.0,
                    rank: index + 1,
                    name: entry.1,
                    score: entry.2
                )
            }
    }

    func reservationReceipt(_ reservation: EmbeddedTryBeforeBuyReservation) -> DiscoverReservationReceipt {
        let createdAt = reservation.createdAt ?? Date()
        let timestamp = Int(createdAt.timeIntervalSince1970)
        let seed = "\(reservation.userId)|\(timestamp)|\(reservation.productIds.sorted().joined(separator: "|"))"
        let digest = SHA256.hash(data: Data(seed.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
            .prefix(12)
        return DiscoverReservationReceipt(
            id: "try-\(reservation.userId)-\(timestamp)-\(digest)",
            productIDs: reservation.productIds,
            status: "requested",
            createdAt: createdAt
        )
    }

    func boostActivation(_ boost: EmbeddedBoostAssignment) -> DiscoverBoostActivation {
        let createdAt = boost.createdAt ?? Date()
        return DiscoverBoostActivation(
            success: true,
            estimatedReach: boost.estimatedReach,
            campaignID: "boost-\(Int(createdAt.timeIntervalSince1970))",
            createdAt: createdAt
        )
    }

    func stylistReply(for request: EmbeddedDiscoverStylistRequest, catalog: [EmbeddedCatalogProduct]) -> String {
        let requestedProducts = request.productIds
            .compactMap { productID in catalog.first(where: { $0.id == productID }) }
            .prefix(3)
        let messageKeywords = Set(
            discoverMoodKeywords(request.message)
                + request.message
                    .lowercased()
                    .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                    .map(String.init)
        )
        let matchedProducts = catalog
            .filter { product($0, matches: Array(messageKeywords)) }
            .prefix(3)
        let recommendations = requestedProducts.isEmpty ? Array(matchedProducts) : Array(requestedProducts)
        let finalProducts = recommendations.isEmpty ? Array(catalog.prefix(3)) : recommendations

        guard finalProducts.isEmpty == false else {
            return "The live catalog is empty right now, so I cannot build a real outfit recommendation."
        }

        let productCopy = finalProducts
            .map { "\($0.name) (EGP \(Int($0.price.rounded())))" }
            .joined(separator: ", ")
        var seenSizes = Set<String>()
        let fitNote = finalProducts
            .flatMap(\.size)
            .filter { seenSizes.insert($0).inserted }
            .prefix(4)
            .joined(separator: ", ")

        if fitNote.isEmpty {
            return "Use \(productCopy). These are live catalog pieces selected from your current Discover context."
        }

        return "Use \(productCopy). Available sizes across this set include \(fitNote). These are live catalog pieces selected from your current Discover context."
    }

    func updateCartLine(
        productId: String,
        size: String?,
        color: String?,
        quantity: Int,
        for user: EmbeddedStoredUser,
        state: EmbeddedBackendState
    ) -> EmbeddedBackendState {
        let lineKey = "\(productId):\(size ?? ""):\(color ?? "")"
        let current = currentCart(for: user.id, state: state)
        var nextItems = current.items

        if let index = nextItems.firstIndex(where: { "\( $0.productId):\($0.size ?? ""):\($0.color ?? "")" == lineKey }) {
            nextItems[index].quantity = quantity
        } else {
            nextItems.append(
                EmbeddedStoredCartItem(
                    productId: productId,
                    size: size,
                    color: color,
                    quantity: quantity
                )
            )
        }

        return upsertCart(
            EmbeddedStoredCart(userId: user.id, items: nextItems),
            into: state
        )
    }

    func upsertCart(_ cart: EmbeddedStoredCart, into state: EmbeddedBackendState) -> EmbeddedBackendState {
        var next = state
        next.carts.removeAll { $0.userId == cart.userId }
        next.carts.append(cart)
        return next
    }

    func upsertProfile(_ profile: EmbeddedStoredProfile, into state: EmbeddedBackendState) -> EmbeddedBackendState {
        var next = state
        next.profiles.removeAll { $0.userId == profile.userId }
        next.profiles.append(profile)
        return next
    }

    func upsertNotification(_ notification: EmbeddedStoredNotification, into state: EmbeddedBackendState) -> EmbeddedBackendState {
        var next = state
        next.notifications.removeAll { $0.id == notification.id }
        next.notifications.insert(notification, at: 0)
        return next
    }

    func codResult(governorate: String) -> EmbeddedCODValidationPayload {
        let normalized = governorate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let eligibleGovernorates = Set([
            "cairo",
            "giza",
            "alexandria",
            "beheira",
            "qalyubia",
            "dakahlia",
            "sharqia",
            "ismailia"
        ])
        let eligible = eligibleGovernorates.contains(normalized)
        return EmbeddedCODValidationPayload(eligible: eligible, codFee: eligible ? 20 : 0)
    }

    func promoResult(code: String) -> PromoValidationResult {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "WELCOME50":
            return PromoValidationResult(isValid: true, discount: 50, message: "Welcome to BOUTIQUE. EGP 50 has been applied to this order.")
        case "BOUTIQUE10":
            return PromoValidationResult(isValid: true, discount: 10, message: "BOUTIQUE10 applied successfully.")
        default:
            return PromoValidationResult(isValid: false, discount: 0, message: "That promo code is not valid right now.")
        }
    }

    func normalizedOrderStatus(_ value: String) -> String? {
        let status = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch status {
        case "pending", "confirmed", "preparing", "shipped", "delivered", "cancelled":
            return status
        case "processing", "packed", "packing":
            return "preparing"
        default:
            return nil
        }
    }

    func validateStock(productID: String, quantity: Int, catalog: [EmbeddedCatalogProduct]) throws {
        guard let product = catalog.first(where: { $0.id == productID }) else {
            throw APIError.notFound("Product not found.")
        }

        let requestedQuantity = max(1, quantity)
        if product.isAvailable == false || product.inventoryCount == 0 {
            throw APIError.httpError(409, "\(product.name) is out of stock.")
        }

        if let inventory = product.inventoryCount, requestedQuantity > inventory {
            throw APIError.httpError(
                409,
                "Only \(inventory) \(inventory == 1 ? "piece" : "pieces") of \(product.name) are available."
            )
        }
    }

    func reserveStock(for items: [EmbeddedStoredOrderItem], in state: EmbeddedBackendState) -> EmbeddedBackendState {
        var next = state
        let quantities = items.reduce(into: [String: Int]()) { partialResult, item in
            partialResult[item.productId, default: 0] += max(1, item.quantity)
        }

        next.catalogProducts = next.catalogProducts.map { product in
            guard let quantity = quantities[product.id],
                  let inventory = product.inventoryCount else {
                return product
            }

            let nextInventory = max(0, inventory - quantity)
            let nextAvailable = product.isAvailable == false ? false : nextInventory > 0
            return product.updatingInventory(nextInventory, isAvailable: nextAvailable)
        }

        return next
    }

    func releaseStock(for items: [EmbeddedStoredOrderItem], in state: EmbeddedBackendState) -> EmbeddedBackendState {
        var next = state
        let quantities = items.reduce(into: [String: Int]()) { partialResult, item in
            partialResult[item.productId, default: 0] += max(1, item.quantity)
        }

        next.catalogProducts = next.catalogProducts.map { product in
            guard let quantity = quantities[product.id],
                  let inventory = product.inventoryCount else {
                return product
            }

            let nextInventory = inventory + quantity
            let nextAvailable = product.isAvailable == false ? false : nextInventory > 0
            return product.updatingInventory(nextInventory, isAvailable: nextAvailable)
        }

        return next
    }

    func analytics(state: EmbeddedBackendState) throws -> EmbeddedAnalyticsPayload {
        let totalRevenue = state.orders.reduce(0) { $0 + $1.totalPrice }
        let todayKey = Date().ISO8601Format().prefix(10)
        let todayOrders = state.orders.filter { order in
            guard let createdAt = order.createdAt else { return false }
            return createdAt.ISO8601Format().prefix(10) == todayKey
        }

        let pendingOrders = state.orders.filter { $0.status.lowercased() == "pending" }.count
        let newUsersCutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        var productMetrics: [String: EmbeddedBestSellingProduct] = [:]
        var revenueByMonth: [String: Double] = [:]
        var ordersByStatus: [String: Int] = [:]

        for order in state.orders {
            let monthKey = order.createdAt.map { Self.plainDateFormatter.string(from: $0).prefix(7) } ?? "unknown"
            revenueByMonth[String(monthKey), default: 0] += order.totalPrice
            ordersByStatus[order.status, default: 0] += 1

            for item in order.items {
                let existing = productMetrics[item.productId] ?? EmbeddedBestSellingProduct(
                    id: item.productId,
                    name: item.name,
                    quantity: 0,
                    revenue: 0
                )
                productMetrics[item.productId] = EmbeddedBestSellingProduct(
                    id: existing.id,
                    name: existing.name,
                    quantity: existing.quantity + item.quantity,
                    revenue: existing.revenue + (item.price * Double(item.quantity))
                )
            }
        }

        return EmbeddedAnalyticsPayload(
            totalRevenue: totalRevenue,
            todaySales: todayOrders.reduce(0) { $0 + $1.totalPrice },
            ordersToday: todayOrders.count,
            totalOrders: state.orders.count,
            totalCustomers: state.users.filter { $0.isAdmin == false }.count,
            newUsers: state.users.filter { ($0.createdAt ?? .distantPast) >= newUsersCutoff }.count,
            pendingOrders: pendingOrders,
            lowStockProducts: try catalog().filter { product in
                guard product.isAvailable != false,
                      let inventory = product.inventoryCount else {
                    return false
                }
                return inventory > 0 && inventory <= 3
            }.count,
            bestSellingProducts: Array(productMetrics.values)
                .sorted { lhs, rhs in
                    if lhs.quantity == rhs.quantity {
                        return lhs.name < rhs.name
                    }
                    return lhs.quantity > rhs.quantity
                }
                .prefix(5)
                .map { $0 },
            revenueByMonth: revenueByMonth.keys.sorted().map { key in
                EmbeddedRevenuePoint(month: key, revenue: revenueByMonth[key] ?? 0)
            },
            ordersByStatus: ordersByStatus
        )
    }

    func stylistPrompts() -> [StylistPrompt] {
        [
            StylistPrompt(
                id: "prompt-tailored",
                title: "Tailored Evening",
                prompt: "Build a composed evening look with sharp outerwear and a restrained palette.",
                category: .suits
            ),
            StylistPrompt(
                id: "prompt-bomber",
                title: "City Bomber",
                prompt: "Start with a bomber, then balance it with relaxed denim or knitwear.",
                category: .jackets
            ),
            StylistPrompt(
                id: "prompt-daily",
                title: "Daily Layers",
                prompt: "Keep the fit practical and premium with one lighter layer and one soft foundation.",
                category: .shirts
            )
        ]
    }

    func socialUsers(from state: EmbeddedBackendState) -> [EmbeddedSocialUser] {
        state.users
            .filter { $0.isAdmin == false }
            .map { user in
                EmbeddedSocialUser(
                    id: user.id,
                    name: user.name,
                    username: user.email.split(separator: "@").first.map(String.init) ?? user.name.lowercased().replacingOccurrences(of: " ", with: "")
                )
            }
    }

    func gamificationPayload(for user: EmbeddedStoredUser, state: EmbeddedBackendState) -> EmbeddedGamificationPayload {
        let personalOrders = state.orders.filter { $0.userId == user.id }
        let personalVotes = state.discover.votesByChallenge.values.filter { $0.contains(user.id) }.count
        let points = personalOrders.count * 20 + personalVotes * 25

        var badges: [EmbeddedBadgePayload] = []
        if personalOrders.isEmpty == false {
            badges.append(EmbeddedBadgePayload(id: "badge-order", title: "First Order", icon: "shippingbox.fill"))
        }
        if personalVotes > 0 {
            badges.append(EmbeddedBadgePayload(id: "badge-vote", title: "Style Vote", icon: "hand.thumbsup.fill"))
        }
        if user.isAdmin {
            badges.append(EmbeddedBadgePayload(id: "badge-admin", title: "Admin", icon: "crown.fill"))
        }
        if badges.isEmpty {
            badges.append(EmbeddedBadgePayload(id: "badge-new", title: "New Member", icon: "sparkles"))
        }

        return EmbeddedGamificationPayload(points: points, badges: badges)
    }

    func legacyLeaderboard(from discover: EmbeddedDiscoverContent) -> [EmbeddedLegacyLeaderboardEntry] {
        discover.leaderboard.enumerated().map { index, entry in
            EmbeddedLegacyLeaderboardEntry(
                id: UUID(),
                rank: entry.rank ?? (index + 1),
                username: entry.name,
                points: entry.score
            )
        }
    }

    func legacyDrops(from discover: EmbeddedDiscoverContent) -> [EmbeddedLegacyDrop] {
        discover.drops.map { drop in
            EmbeddedLegacyDrop(
                title: drop.name,
                description: drop.copy,
                endTime: drop.unlocksAt
            )
        }
    }
}

private extension EmbeddedStaticBackend {
    func handleGet(segments: [String], token: String?) async throws -> Data {
        let state = try currentState()

        if segments == ["products"] {
            return try encode(EmbeddedCatalogPayload(products: try catalog()))
        }

        if segments.count == 2, segments.first == "products" {
            let productID = segments[1]
            guard let product = try catalog().first(where: { $0.id == productID }) else {
                throw APIError.notFound("Product not found.")
            }
            return try encode(product)
        }

        if segments.count == 3, segments.first == "products", segments[2] == "related" {
            let productID = segments[1]
            let catalog = try catalog()
            guard let product = catalog.first(where: { $0.id == productID }) else {
                throw APIError.notFound("Product not found.")
            }

            let related = catalog
                .filter { $0.id != product.id && $0.category == product.category }
                .prefix(6)
            return try encode(Array(related))
        }

        if segments == ["boutiques"] || segments == ["boutiques", "nearby"] {
            return try encode(try boutiques())
        }

        if segments.count == 2, segments.first == "boutiques" {
            guard let boutique = try boutiques().first(where: { $0.id == segments[1] }) else {
                throw APIError.notFound("Boutique not found.")
            }
            return try encode(boutique)
        }

        if segments.count == 3, segments.first == "boutiques", segments[2] == "stories" {
            return try encode([String]())
        }

        if segments == ["support", "channels"] {
            return try encode(try supportContent().channels)
        }

        if segments == ["support", "faqs"] {
            return try encode(try supportContent().faqs)
        }

        if segments == ["legal", "documents"] {
            return try encode(try legalContent().documents)
        }

        if segments == ["discover", "feed"] {
            return try encode(try discoverContent().feed)
        }

        if segments == ["discover", "drops"] || segments == ["drops"] {
            if segments == ["drops"] {
                return try encode(legacyDrops(from: try discoverContent()))
            }
            return try encode(try discoverContent().drops)
        }

        if segments == ["discover", "challenges"] {
            return try encode(try discoverContent().challenges)
        }

        if segments == ["discover", "leaderboard"] || segments == ["gamification", "leaderboard"] {
            let leaderboard = discoverLeaderboard(from: state)
            if segments.first == "gamification" {
                return try encode(
                    leaderboard.map {
                        EmbeddedLegacyLeaderboardEntry(
                            id: UUID(uuidString: stableUUIDString(seed: $0.id)) ?? UUID(),
                            rank: $0.rank,
                            username: $0.name,
                            points: $0.score
                        )
                    }
                )
            }
            return try encode(leaderboard)
        }

        if segments == ["discover", "subscription", "plans"] {
            return try encode(try discoverContent().subscriptionPlans)
        }

        if segments == ["discover", "me"] || segments == ["discover", "state"] {
            let user = try requireUser(token: token, state: state)
            return try encode(try discoverUserState(for: user, state: state))
        }

        if segments == ["discover", "closet"] {
            let user = try requireUser(token: token, state: state)
            return try encode(
                EmbeddedDiscoverClosetPayload(
                    productIds: state.discover.closetByUser[user.id] ?? []
                )
            )
        }

        if segments == ["discover", "style-dna"] {
            let user = try requireUser(token: token, state: state)
            let defaultProfile = try discoverContent().defaultStyleDNA
            let profile = state.discover.styleDNAByUser[user.id] ?? defaultProfile
            return try encode(profile)
        }

        if segments == ["users", "me"] {
            let user = try requireUser(token: token, state: state)
            return try encode(publicUser(user))
        }

        if segments == ["users", "me", "profile"] ||
            segments == ["profile"] ||
            segments == ["account", "profile"] {
            let user = try requireUser(token: token, state: state)
            return try encode(EmbeddedProfileEnvelope(profile: profile(for: user, state: state)))
        }

        if segments == ["notifications"] {
            let user = try requireUser(token: token, state: state)
            let notifications = state.notifications
                .filter { $0.userId == user.id }
                .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
                .map(\.nativeNotification)
            return try encode(notifications)
        }

        if segments == ["cart"] {
            let user = try requireUser(token: token, state: state)
            return try encode(try cartEnvelope(for: user, state: state))
        }

        if segments == ["orders"] {
            let user = try requireUser(token: token, state: state)
            return try encode(EmbeddedOrdersEnvelope(orders: visibleOrders(for: user, state: state)))
        }

        if segments == ["orders", "me"] {
            let user = try requireUser(token: token, state: state)
            let orders = visibleOrders(for: user, state: state).map(\.nativeOrder)
            return try encode(orders)
        }

        if segments.count == 2, segments.first == "orders" {
            let user = try requireUser(token: token, state: state)
            guard let order = state.orders.first(where: { $0.id == segments[1] && (user.isAdmin || $0.userId == user.id) }) else {
                throw APIError.notFound("Order not found.")
            }
            return try encode(EmbeddedSingleOrderEnvelope(order: order))
        }

        if segments == ["admin", "orders"] {
            let user = try requireAdmin(token: token, state: state)
            return try encode(EmbeddedOrdersEnvelope(orders: visibleOrders(for: user, state: state)))
        }

        if segments == ["boutique", "orders"] {
            let user = try requireAdmin(token: token, state: state)
            return try encode(visibleOrders(for: user, state: state).map(\.nativeOrder))
        }

        if segments == ["admin", "users"] {
            _ = try requireAdmin(token: token, state: state)
            return try encode(EmbeddedAdminUsersEnvelope(users: state.users.map(publicUser)))
        }

        if segments == ["admin", "analytics"] || segments == ["admin", "stats"] {
            _ = try requireAdmin(token: token, state: state)
            return try encode(try analytics(state: state))
        }

        if segments == ["social", "users"] {
            return try encode(socialUsers(from: state))
        }

        if segments == ["stylist", "prompts"] {
            return try encode(stylistPrompts())
        }

        if segments == ["gamification", "me"] {
            let user = try requireUser(token: token, state: state)
            return try encode(gamificationPayload(for: user, state: state))
        }

        if segments == ["trybeforebuy", "eligibility"] {
            return try encode(EmbeddedEligibilityPayload(eligible: true))
        }

        if segments == ["closet"] {
            let user = try requireUser(token: token, state: state)
            let catalog = try catalog()
            let productItems: [EmbeddedLegacyClosetItem] = (state.discover.closetByUser[user.id] ?? []).compactMap { productID in
                guard let product = catalog.first(where: { $0.id == productID }) else {
                    return nil
                }
                return EmbeddedLegacyClosetItem(
                    id: product.id,
                    name: product.name,
                    color: product.colors.first ?? "default",
                    brand: "BOUTIQUE"
                )
            }
            return try encode((state.legacyClosetByUser[user.id] ?? []) + productItems)
        }

        if segments == ["saved", "me"] {
            return try encode([Product]())
        }

        if segments == ["boutique", "products"] {
            return try encode(try catalog().map(\.nativeProduct))
        }

        throw APIError.notFound("This content is not available right now.")
    }

    func handlePost(segments: [String], body: Data?, token: String?) async throws -> Data {
        var state = try currentState()

        if segments == ["auth", "signup"] {
            let request = try decode(SignupCredentials.self, from: body)
            let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = request.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let password = request.password.trimmingCharacters(in: .whitespacesAndNewlines)

            guard name.isEmpty == false, email.isEmpty == false, password.isEmpty == false else {
                throw APIError.httpError(400, "Name, email, and password are required.")
            }

            if state.users.contains(where: { $0.email == email }) {
                throw APIError.httpError(409, "An account already exists for this email address.")
            }

            let user = EmbeddedStoredUser(
                id: "user-\(UUID().uuidString.lowercased())",
                name: name,
                email: email,
                phone: request.phone?.trimmingCharacters(in: .whitespacesAndNewlines),
                passwordHash: hashPassword(password),
                isAdmin: false,
                createdAt: Date(),
                updatedAt: Date()
            )

            state.users.insert(user, at: 0)
            state.profiles.insert(
                EmbeddedStoredProfile(
                    userId: user.id,
                    name: user.name,
                    email: user.email,
                    tier: "Member",
                    city: "Cairo",
                    note: "Manage your account preferences and order activity."
                ),
                at: 0
            )
            try persistState(state)

            return try encode(
                AuthResponse(
                    user: publicUser(user),
                    token: issueToken(for: user)
                )
            )
        }

        if segments == ["auth", "signin"] {
            let request = try decode(LoginCredentials.self, from: body)
            let email = request.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let password = request.password.trimmingCharacters(in: .whitespacesAndNewlines)

            guard email.isEmpty == false, password.isEmpty == false else {
                throw APIError.httpError(400, "Email and password are required.")
            }

            guard let matchedUser = state.users.first(where: { candidate in
                candidate.email == email &&
                candidate.passwordHash == hashPassword(password)
            }) else {
                throw APIError.unauthorized("Invalid email or password.")
            }

            return try encode(
                AuthResponse(
                    user: publicUser(matchedUser),
                    token: issueToken(for: matchedUser)
                )
            )
        }

        if segments == ["auth", "logout"] {
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments == ["auth", "refresh"] {
            let user = try requireUser(token: token, state: state)
            return try encode(EmbeddedTokenRefreshPayload(token: issueToken(for: user)))
        }

        if segments == ["products"] {
            _ = try requireAdmin(token: token, state: state)
            let product = try decode(Product.self, from: body)
            let storedProduct = try validatedCatalogProduct(from: product, existingIDs: Set(try catalog().map(\.id)))

            state.catalogProducts.insert(storedProduct, at: 0)
            try persistState(state)
            return try encode(storedProduct.nativeProduct)
        }

        if segments == ["orders", "validate-cod"] {
            let request = try decode(EmbeddedGovernorateRequest.self, from: body)
            guard request.governorate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw APIError.httpError(400, "Governorate is required.")
            }
            return try encode(codResult(governorate: request.governorate))
        }

        if segments == ["orders", "validate-promo"] {
            let request = (try? decode(PromoValidationRequest.self, from: body)) ?? PromoValidationRequest(code: "")
            return try encode(promoResult(code: request.code))
        }

        if segments == ["cart"] || segments == ["cart", "items"] {
            let user = try requireUser(token: token, state: state)
            let request = try decode(CartItem.self, from: body)

            guard request.productId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  request.quantity > 0 else {
                throw APIError.httpError(400, "A valid cart line is required.")
            }

            let productID = request.productId.trimmingCharacters(in: .whitespacesAndNewlines)
            try validateStock(productID: productID, quantity: request.quantity, catalog: try catalog())
            state = updateCartLine(
                productId: productID,
                size: request.size,
                color: request.color,
                quantity: request.quantity,
                for: user,
                state: state
            )
            try persistState(state)

            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments == ["orders"] || segments == ["orders", "place"] {
            let user = try requireUser(token: token, state: state)
            let request = try decode(EmbeddedOrderPlacementRequest.self, from: body)

            guard request.items.isEmpty == false else {
                throw APIError.httpError(400, "Order items are required.")
            }

            let catalog = try catalog()
            let deliveryLocation = request.deliveryLocation?.trimmedNonEmpty
                ?? request.shippingAddress?.city?.trimmedNonEmpty
                ?? request.shippingCity.trimmedNonEmpty
                ?? ""
            let customerName = request.customerName?.trimmedNonEmpty
                ?? request.shippingAddress?.name?.trimmedNonEmpty
                ?? user.name
            let customerEmail = request.customerEmail?.trimmedNonEmpty
                ?? request.shippingAddress?.email?.trimmedNonEmpty
                ?? user.email
            let customerPhone = request.customerPhone?.trimmedNonEmpty
                ?? request.shippingAddress?.phone?.trimmedNonEmpty
                ?? user.phone
                ?? ""
            let streetAddress = request.shippingAddress?.street?.trimmedNonEmpty ?? ""

            guard customerName.split(separator: " ").joined().count >= 2 else {
                throw APIError.httpError(400, "Customer name is required.")
            }

            guard customerEmail.embeddedIsValidEmailAddress else {
                throw APIError.httpError(400, "Enter a valid email address.")
            }

            guard customerPhone.embeddedIsValidEgyptianMobileNumber else {
                throw APIError.httpError(400, "Use an 11-digit Egyptian mobile number starting with 01.")
            }

            guard streetAddress.count >= 8 else {
                throw APIError.httpError(400, "Add a complete delivery address.")
            }

            guard deliveryLocation.trimmedNonEmpty != nil else {
                throw APIError.httpError(400, "Delivery governorate is required.")
            }

            let paymentMethodID = request.paymentMethodId?.trimmedNonEmpty
                ?? request.paymentMethod?.type?.trimmedNonEmpty
                ?? ""

            guard ["cod", "vodafone_cash"].contains(paymentMethodID) else {
                throw APIError.httpError(400, "Choose an active payment method.")
            }

            let codValidation = codResult(governorate: deliveryLocation)
            if paymentMethodID == "cod", codValidation.eligible == false {
                throw APIError.httpError(400, "Cash on delivery is not available in this governorate.")
            }

            let requestedQuantities = request.items.reduce(into: [String: Int]()) { partialResult, item in
                partialResult[item.productId, default: 0] += max(1, item.quantity)
            }
            for (productID, quantity) in requestedQuantities {
                try validateStock(productID: productID, quantity: quantity, catalog: catalog)
            }

            let orderItems: [EmbeddedStoredOrderItem] = request.items.compactMap { item in
                guard let product = catalog.first(where: { $0.id == item.productId }) else { return nil }
                return EmbeddedStoredOrderItem(
                    productId: product.id,
                    name: product.name,
                    price: product.price,
                    image: product.images.first ?? "/uploads/main.jpg",
                    quantity: max(1, item.quantity),
                    size: item.size,
                    color: item.color
                )
            }

            guard orderItems.isEmpty == false else {
                throw APIError.httpError(400, "Order items are invalid.")
            }

            let subtotal = orderItems.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
            let shippingMethodName = request.shippingMethodName?.trimmedNonEmpty ?? "Standard"
            let normalizedShippingMethod = shippingMethodName.lowercased()
            let shippingCost: Double
            if normalizedShippingMethod.contains("same") {
                shippingCost = 200
            } else if normalizedShippingMethod.contains("express") {
                shippingCost = 120
            } else {
                shippingCost = 50
            }
            let promo = request.promoCode.map(promoResult(code:))
            let discount = promo?.isValid == true ? (promo?.discount ?? 0) : 0
            let codFee = paymentMethodID == "cod" ? codValidation.codFee : 0
            let totalPrice = max(subtotal + shippingCost + codFee - discount, 0)
            let createdAt = Date()
            let orderID = request.id.trimmedNonEmpty ?? "order-\(Int(createdAt.timeIntervalSince1970))"

            let order = EmbeddedStoredOrder(
                id: orderID,
                userId: user.id,
                items: orderItems,
                totalPrice: totalPrice,
                subtotal: subtotal,
                shippingCost: shippingCost,
                discount: discount,
                status: "pending",
                createdAt: createdAt,
                shippingCity: deliveryLocation,
                customer: EmbeddedStoredOrderCustomer(
                    name: customerName,
                    email: customerEmail,
                    phone: customerPhone,
                    address: streetAddress,
                    apartment: request.shippingAddress?.apartment?.trimmedNonEmpty,
                    city: deliveryLocation,
                    postalCode: request.shippingAddress?.postalCode?.trimmedNonEmpty ?? "",
                    country: "Egypt",
                    shippingMethod: shippingMethodName
                ),
                paymentMethodId: paymentMethodID.isEmpty ? nil : paymentMethodID,
                codFee: codFee
            )

            let notification = EmbeddedStoredNotification(
                id: "notification-\(orderID)",
                userId: user.id,
                kind: "orderUpdate",
                title: "Order \(orderID) confirmed",
                message: "Your order is now in the processing queue and visible in the order timeline.",
                timestamp: createdAt,
                emphasis: "Order received",
                actionTitle: "View Orders",
                destination: "orders",
                isRead: false
            )

            state = reserveStock(for: orderItems, in: state)
            state.orders.removeAll { $0.id == orderID }
            state.orders.insert(order, at: 0)
            state = upsertCart(EmbeddedStoredCart(userId: user.id, items: []), into: state)
            state = upsertNotification(notification, into: state)
            try persistState(state)

            return try encode(EmbeddedOrdersEnvelope(orders: [order]))
        }

        if segments == ["discover", "ai-stylist"] || segments == ["ai", "stylist"] {
            let request = (try? decode(EmbeddedDiscoverStylistRequest.self, from: body)) ?? EmbeddedDiscoverStylistRequest(message: "", productIds: [])
            return try encode(EmbeddedReplyPayload(reply: stylistReply(for: request, catalog: try catalog())))
        }

        if segments == ["discover", "snap-match"] || segments == ["discover", "match"] || segments == ["match", "snap"] {
            let request = (try? decode(EmbeddedDiscoverSnapMatchRequest.self, from: body)) ?? EmbeddedDiscoverSnapMatchRequest(mood: "", limit: 6)
            let query = request.mood.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let limit = max(1, min(request.limit, 20))
            let catalogProducts = try catalog()
            let keywords = discoverMoodKeywords(query)
            let matched = catalogProducts.filter { product($0, matches: keywords) }
            let products = matched.isEmpty ? catalogProducts : matched
            return try encode(EmbeddedCatalogPayload(products: Array(products.prefix(limit))))
        }

        if segments == ["discover", "closet"] {
            let user = try requireUser(token: token, state: state)
            let request = (try? decode(EmbeddedDiscoverClosetSelectionRequest.self, from: body)) ?? EmbeddedDiscoverClosetSelectionRequest(productIds: [])
            let catalogIDs = Set(try catalog().map(\.id))
            let productIds = Array(Set(request.productIds.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }))
            guard productIds.allSatisfy({ catalogIDs.contains($0) }) else {
                throw APIError.httpError(400, "Select products from the live catalog only.")
            }
            state.discover.closetByUser[user.id] = productIds
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments == ["discover", "interactions"] {
            let user = try requireUser(token: token, state: state)
            let request = try decode(EmbeddedDiscoverInteractionRequest.self, from: body)
            let targetID = request.targetId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard targetID.isEmpty == false else {
                throw APIError.httpError(400, "Interaction target is required.")
            }

            switch request.kind {
            case "likedOutfit":
                state.discover.likedOutfitsByUser[user.id] = updatedInteractionSet(
                    state.discover.likedOutfitsByUser[user.id] ?? [],
                    targetID: targetID,
                    isActive: request.isActive
                )
            case "savedOutfit":
                state.discover.savedOutfitsByUser[user.id] = updatedInteractionSet(
                    state.discover.savedOutfitsByUser[user.id] ?? [],
                    targetID: targetID,
                    isActive: request.isActive
                )
            case "followedCreator":
                state.discover.followedCreatorsByUser[user.id] = updatedInteractionSet(
                    state.discover.followedCreatorsByUser[user.id] ?? [],
                    targetID: targetID,
                    isActive: request.isActive
                )
            default:
                throw APIError.httpError(400, "Unsupported discover interaction.")
            }

            try persistState(state)
            return try encode(try discoverUserState(for: user, state: state))
        }

        if segments == ["discover", "try-before-buy", "reserve"] {
            let user = try requireUser(token: token, state: state)
            let request = (try? decode(EmbeddedDiscoverClosetSelectionRequest.self, from: body)) ?? EmbeddedDiscoverClosetSelectionRequest(productIds: [])
            let productIds = try validateDiscoverProductIDs(request.productIds)
            let reservation = EmbeddedTryBeforeBuyReservation(userId: user.id, productIds: productIds, createdAt: Date())
            state.discover.tryBeforeBuy.insert(reservation, at: 0)
            try persistState(state)
            return try encode(reservationReceipt(reservation))
        }

        if segments == ["discover", "subscription", "subscribe"] {
            let user = try requireUser(token: token, state: state)
            let request = try decode(EmbeddedDiscoverPlanRequest.self, from: body)
            guard request.planId.trimmedNonEmpty != nil else {
                throw APIError.httpError(400, "Plan id is required.")
            }
            let planIDs = Set(try discoverContent().subscriptionPlans.map(\.id))
            guard planIDs.contains(request.planId) else {
                throw APIError.httpError(400, "Choose an available subscription plan.")
            }
            let assignment = EmbeddedSubscriptionAssignment(
                userId: user.id,
                planId: request.planId,
                createdAt: Date()
            )
            state.discover.subscriptionAssignments.insert(
                assignment,
                at: 0
            )
            try persistState(state)
            return try encode(
                DiscoverSubscriptionStatus(
                    subscribed: true,
                    planID: assignment.planId,
                    createdAt: assignment.createdAt
                )
            )
        }

        if segments == ["discover", "seller-boost", "estimate"] || segments == ["product", "boost", "estimate"] {
            let request = (try? decode(EmbeddedBoostRequest.self, from: body)) ?? EmbeddedBoostRequest(budget: 0, days: 1)
            let budget = min(max(request.budget, 100), 3_000)
            let days = min(max(request.days, 1), 14)
            let estimatedReach = max(0, Int((budget * Double(days) * 12).rounded()))
            return try encode(EmbeddedEstimatedReachPayload(estimatedReach: estimatedReach))
        }

        if segments == ["discover", "seller-boost", "activate"] || segments == ["product", "boost"] {
            let user = try requireUser(token: token, state: state)
            let request = (try? decode(EmbeddedBoostRequest.self, from: body)) ?? EmbeddedBoostRequest(budget: 400, days: 3)
            let budget = min(max(request.budget, 100), 3_000)
            let days = min(max(request.days, 1), 14)
            let estimatedReach = max(0, Int((budget * Double(days) * 12).rounded()))
            let boost = EmbeddedBoostAssignment(
                userId: user.id,
                budget: budget,
                days: days,
                estimatedReach: estimatedReach,
                createdAt: Date()
            )
            state.discover.boosts.insert(boost, at: 0)
            try persistState(state)
            return try encode(boostActivation(boost))
        }

        if segments.count == 4,
           segments[0] == "discover",
           segments[1] == "drops",
           segments[3] == "waitlist" {
            let user = try requireUser(token: token, state: state)
            let dropId = segments[2]
            let dropIDs = Set(try discoverContent().drops.map(\.id))
            guard dropIDs.contains(dropId) else {
                throw APIError.notFound("Drop not found.")
            }
            var waitlist = Set(state.discover.waitlists[dropId] ?? [])
            waitlist.insert(user.id)
            state.discover.waitlists[dropId] = Array(waitlist)
            try persistState(state)
            return try encode(
                DiscoverDropWaitlistReceipt(
                    success: true,
                    dropID: dropId,
                    waitlistCount: waitlist.count
                )
            )
        }

        if segments == ["discover", "challenges", "vote"] || segments == ["gamification", "vote"] {
            let user = try requireUser(token: token, state: state)
            let request = try decode(EmbeddedChallengeVoteRequest.self, from: body)
            guard request.challengeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw APIError.httpError(400, "Challenge id is required.")
            }

            let challengeId = request.challengeId
            let challengeIDs = Set(try discoverContent().challenges.map(\.id))
            guard challengeIDs.contains(challengeId) else {
                throw APIError.notFound("Challenge not found.")
            }
            var voters = Set(state.discover.votesByChallenge[challengeId] ?? [])
            let inserted = voters.insert(user.id).inserted
            state.discover.votesByChallenge[challengeId] = Array(voters)
            try persistState(state)
            return try encode(
                DiscoverVoteOutcome(
                    pointsAwarded: inserted ? 25 : 0,
                    totalPoints: voters.count * 25
                )
            )
        }

        if segments == ["notifications", "read-all"] {
            let user = try requireUser(token: token, state: state)
            state.notifications = state.notifications.map { notification in
                guard notification.userId == user.id else { return notification }
                return notification.markedRead()
            }
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments == ["trybeforebuy", "request"] {
            let user = try requireUser(token: token, state: state)
            let request = (try? decode(EmbeddedDiscoverClosetSelectionRequest.self, from: body)) ?? EmbeddedDiscoverClosetSelectionRequest(productIds: [])
            let productIds = try validateDiscoverProductIDs(request.productIds)
            let reservation = EmbeddedTryBeforeBuyReservation(userId: user.id, productIds: productIds, createdAt: Date())
            state.discover.tryBeforeBuy.insert(reservation, at: 0)
            try persistState(state)
            return try encode(reservationReceipt(reservation))
        }

        if segments == ["subscription", "box"] {
            let user = try requireUser(token: token, state: state)
            let request = (try? decode(EmbeddedDiscoverPlanRequest.self, from: body)) ?? EmbeddedDiscoverPlanRequest(planId: "")
            let discover = try discoverContent()
            let planId = request.planId.trimmedNonEmpty
                ?? discover.subscriptionPlans.first?.id
                ?? "monthly-style-box"
            let assignment = EmbeddedSubscriptionAssignment(
                userId: user.id,
                planId: planId,
                createdAt: Date()
            )
            state.discover.subscriptionAssignments.insert(assignment, at: 0)
            try persistState(state)
            return try encode(
                DiscoverSubscriptionStatus(
                    subscribed: true,
                    planID: assignment.planId,
                    createdAt: assignment.createdAt
                )
            )
        }

        if segments == ["closet"] {
            let user = try requireUser(token: token, state: state)
            let request = try decode(EmbeddedLegacyClosetCreateRequest.self, from: body)
            let item = EmbeddedLegacyClosetItem(
                id: UUID().uuidString,
                name: request.name,
                color: request.color,
                brand: request.brand
            )
            state.legacyClosetByUser[user.id, default: []].append(item)
            try persistState(state)
            return try encode(item)
        }

        throw APIError.notFound("This action is not available right now.")
    }

    func handlePut(segments: [String], body: Data?, token: String?) async throws -> Data {
        var state = try currentState()
        let user = try requireUser(token: token, state: state)

        if segments.first == "products", segments.count == 2 {
            _ = try requireAdmin(token: token, state: state)
            let product = try decode(Product.self, from: body)
            guard product.id == segments[1] else {
                throw APIError.httpError(400, "Product ID does not match the update route.")
            }

            let storedProduct = try validatedCatalogProduct(
                from: product,
                existingIDs: Set(try catalog().map(\.id)),
                allowExistingID: true
            )

            state.catalogProducts.removeAll { $0.id == storedProduct.id }
            state.catalogProducts.insert(storedProduct, at: 0)
            state.deletedCatalogProductIDs.remove(storedProduct.id)
            try persistState(state)
            return try encode(storedProduct.nativeProduct)
        }

        if segments.first == "orders", segments.count == 2 {
            _ = try requireAdmin(token: token, state: state)
            let request = try decode(EmbeddedOrderStatusUpdateRequest.self, from: body)
            guard let status = normalizedOrderStatus(request.status) else {
                throw APIError.httpError(400, "Use a valid order status.")
            }

            guard let orderIndex = state.orders.firstIndex(where: { $0.id == segments[1] }) else {
                throw APIError.notFound("Order not found.")
            }

            let currentOrder = state.orders[orderIndex]
            let wasCancelled = currentOrder.status.lowercased() == "cancelled"
            let isCancelled = status == "cancelled"

            if wasCancelled && !isCancelled {
                let catalog = try catalog()
                for item in currentOrder.items {
                    try validateStock(productID: item.productId, quantity: item.quantity, catalog: catalog)
                }
                state = reserveStock(for: currentOrder.items, in: state)
            }

            if !wasCancelled && isCancelled {
                state = releaseStock(for: currentOrder.items, in: state)
            }

            let updatedOrder = currentOrder.updating(status: status)
            state.orders[orderIndex] = updatedOrder
            state = upsertNotification(
                EmbeddedStoredNotification(
                    id: "notification-\(updatedOrder.id)-\(status)-\(Int(Date().timeIntervalSince1970))",
                    userId: updatedOrder.userId,
                    kind: "orderUpdate",
                    title: "Order \(updatedOrder.id) is \(status)",
                    message: "Your order status was updated to \(status).",
                    timestamp: Date(),
                    emphasis: "Order update",
                    actionTitle: "View Orders",
                    destination: "orders",
                    isRead: false
                ),
                into: state
            )
            try persistState(state)
            return try encode(updatedOrder)
        }

        if segments == ["users", "me", "profile"] ||
            segments == ["profile"] ||
            segments == ["account", "profile"] {
            let request = try decode(EmbeddedProfileUpdateRequest.self, from: body)
            let profile = EmbeddedStoredProfile(
                userId: user.id,
                name: request.name.trimmedNonEmpty ?? user.name,
                email: request.email.trimmedNonEmpty ?? user.email,
                tier: request.tier.trimmedNonEmpty ?? (user.isAdmin ? "Administrator" : "Member"),
                city: request.city.trimmedNonEmpty ?? "Cairo",
                note: request.note.trimmedNonEmpty ?? "Manage your account preferences and order activity."
            )
            state = upsertProfile(profile, into: state)
            try persistState(state)
            return try encode(EmbeddedProfileEnvelope(profile: ClientProfile(
                name: profile.name,
                email: profile.email,
                tier: profile.tier,
                city: profile.city,
                note: profile.note
            )))
        }

        if segments == ["discover", "style-dna"] {
            let request = try decode(DiscoverStyleDNAProfile.self, from: body)
            state.discover.styleDNAByUser[user.id] = request
            try persistState(state)
            return try encode(request)
        }

        if segments == ["cart", "items"] {
            let request = try decode(CartItem.self, from: body)
            guard request.productId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw APIError.httpError(400, "A valid cart line is required.")
            }

            let productID = request.productId.trimmingCharacters(in: .whitespacesAndNewlines)
            try validateStock(productID: productID, quantity: max(1, request.quantity), catalog: try catalog())
            state = updateCartLine(
                productId: productID,
                size: request.size,
                color: request.color,
                quantity: max(1, request.quantity),
                for: user,
                state: state
            )
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        throw APIError.notFound("This action is not available right now.")
    }

    func handleDelete(segments: [String], body: Data?, token: String?) async throws -> Data {
        var state = try currentState()

        if segments.first == "cart" {
            let user = try requireUser(token: token, state: state)
        let request = body.flatMap { try? decode(EmbeddedCartDeleteRequest.self, from: $0) }

            if segments.count == 1, request == nil {
                state = upsertCart(EmbeddedStoredCart(userId: user.id, items: []), into: state)
                try persistState(state)
                return try encode(EmbeddedSuccessPayload(success: true))
            }

            let current = currentCart(for: user.id, state: state)
            let nextItems: [EmbeddedStoredCartItem]

            if let request {
                nextItems = current.items.filter { item in
                    !(item.productId == request.productId &&
                      (request.size == nil || item.size == request.size) &&
                      (request.color == nil || item.color == request.color))
                }
            } else if segments.count >= 2 {
                let rawIdentifier = segments[1]
                let parts = rawIdentifier.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                let productID = parts.first ?? rawIdentifier
                let size = parts.count > 1 ? parts[1] : nil
                let color = parts.count > 2 ? parts[2] : nil
                nextItems = current.items.filter { item in
                    !(item.productId == productID &&
                      (size == nil || size == item.size || size == "one-size") &&
                      (color == nil || color == item.color || color == "default"))
                }
            } else {
                nextItems = []
            }

            state = upsertCart(EmbeddedStoredCart(userId: user.id, items: nextItems), into: state)
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments.first == "orders", segments.count == 2 {
            _ = try requireAdmin(token: token, state: state)
            state.orders.removeAll { $0.id == segments[1] }
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments.first == "products", segments.count == 2 {
            _ = try requireAdmin(token: token, state: state)
            let productID = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard productID.isEmpty == false else {
                throw APIError.httpError(400, "Product ID is required.")
            }

            if state.catalogProducts.contains(where: { $0.id == productID }) {
                state.catalogProducts.removeAll { $0.id == productID }
                try persistState(state)
                return try encode(EmbeddedSuccessPayload(success: true))
            }

            let bundledProductIDs = Set((cachedCatalog ?? (try? catalog()) ?? []).map(\.id))
            guard bundledProductIDs.contains(productID) else {
                throw APIError.notFound("Product not found.")
            }

            state.deletedCatalogProductIDs.insert(productID)
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        if segments.first == "closet", segments.count == 2 {
            let user = try requireUser(token: token, state: state)
            state.legacyClosetByUser[user.id, default: []].removeAll { $0.id == segments[1] }
            state.discover.closetByUser[user.id, default: []].removeAll { $0 == segments[1] }
            try persistState(state)
            return try encode(EmbeddedSuccessPayload(success: true))
        }

        throw APIError.notFound("This action is not available right now.")
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data?) throws -> T {
        guard let data else {
            throw APIError.httpError(400, "A request body is required.")
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct EmbeddedCatalogPayload: Codable {
    let products: [EmbeddedCatalogProduct]
}

private struct EmbeddedBoutiquePayload: Codable {
    let boutiques: [EmbeddedBoutiqueRecord]
}

private struct EmbeddedDiscoverContent: Codable {
    let feed: [EmbeddedDiscoverFeedItem]
    let drops: [EmbeddedDiscoverDrop]
    let challenges: [EmbeddedDiscoverChallenge]
    let leaderboard: [EmbeddedDiscoverLeaderboardEntry]
    let subscriptionPlans: [EmbeddedDiscoverPlan]
    let defaultStyleDNA: DiscoverStyleDNAProfile
}

private struct EmbeddedDiscoverFeedItem: Codable {
    let id: String
    let creatorId: String
    let creatorName: String
    let title: String
    let caption: String
    let score: Int
    let productIds: [String]
}

private struct EmbeddedDiscoverDrop: Codable {
    let id: String
    let name: String
    let copy: String
    let stock: Int
    let unlocksAt: Date
}

private struct EmbeddedDiscoverChallenge: Codable {
    let id: String
    let title: String
    let prompt: String
    let rewardPoints: Int
}

private struct EmbeddedDiscoverLeaderboardEntry: Codable {
    let id: String
    let rank: Int?
    let name: String
    let score: Int
}

private struct EmbeddedDiscoverPlan: Codable {
    let id: String
    let title: String
    let interval: String
    let price: Double
    let currency: String
    let details: String
}

private struct EmbeddedCatalogProduct: Codable {
    let id: String
    let name: String
    let category: String
    let price: Double
    let images: [String]
    let size: [String]
    let description: String
    let colors: [String]
    let composition: String?
    let care: String?
    let delivery: String?
    let returns: String?
    let discount: Double?
    let badge: String?
    let featured: Bool?
    let rating: Double?
    let reviewCount: Int?
    let inventoryCount: Int?
    let isAvailable: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case category
        case price
        case images
        case size
        case description
        case colors
        case composition
        case care
        case delivery
        case returns
        case discount
        case badge
        case featured
        case rating
        case reviewCount
        case inventoryCount
        case isAvailable
    }

    var normalized: EmbeddedCatalogProduct {
        EmbeddedCatalogProduct(
            id: id,
            name: name,
            category: category,
            price: price,
            images: images.map(EmbeddedBackendState.normalizedAssetPath),
            size: size,
            description: description,
            colors: colors,
            composition: composition,
            care: care,
            delivery: delivery,
            returns: returns,
            discount: discount,
            badge: badge,
            featured: featured,
            rating: rating,
            reviewCount: reviewCount,
            inventoryCount: inventoryCount,
            isAvailable: isAvailable
        )
    }

    func updatingInventory(_ inventoryCount: Int, isAvailable: Bool) -> EmbeddedCatalogProduct {
        EmbeddedCatalogProduct(
            id: id,
            name: name,
            category: category,
            price: price,
            images: images,
            size: size,
            description: description,
            colors: colors,
            composition: composition,
            care: care,
            delivery: delivery,
            returns: returns,
            discount: discount,
            badge: badge,
            featured: featured,
            rating: rating,
            reviewCount: reviewCount,
            inventoryCount: inventoryCount,
            isAvailable: isAvailable
        )
    }

    var nativeProduct: Product {
        let resolvedCategory = EmbeddedProductCategoryResolver.resolve(category) ?? .shirts
        return Product(
            id: id,
            name: name,
            category: resolvedCategory,
            price: price,
            summary: description,
            story: description,
            imageNames: images,
            sizes: size,
            colors: colors.map { Colorway(name: $0.capitalized, hex: Colorway.hex(for: $0)) },
            composition: composition ?? "Details from static inventory.",
            care: care ?? "See care guidance at delivery.",
            delivery: delivery ?? "Availability confirmed after order review.",
            returns: returns ?? "Store policy applies.",
            badge: badge.flatMap(ProductBadge.init(rawValue:)),
            featured: featured ?? (badge != nil),
            rating: rating,
            reviewCount: reviewCount,
            inventoryCount: inventoryCount,
            isAvailable: isAvailable
        )
    }
}

private struct EmbeddedBoutiqueRecord: Codable {
    let id: String
    let name: String
    let area: String
    let governorate: String
    let dispatchNote: String
    let coordinate: EmbeddedCoordinate
}

private struct EmbeddedCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

private struct EmbeddedBackendState: Codable {
    var users: [EmbeddedStoredUser]
    var profiles: [EmbeddedStoredProfile]
    var carts: [EmbeddedStoredCart]
    var orders: [EmbeddedStoredOrder]
    var notifications: [EmbeddedStoredNotification]
    var discover: EmbeddedDiscoverState
    var legacyClosetByUser: [String: [EmbeddedLegacyClosetItem]]
    var catalogProducts: [EmbeddedCatalogProduct]
    var deletedCatalogProductIDs: Set<String>

    static let empty = EmbeddedBackendState(
        users: [],
        profiles: [],
        carts: [],
        orders: [],
        notifications: [],
        discover: .empty,
        legacyClosetByUser: [:],
        catalogProducts: [],
        deletedCatalogProductIDs: []
    )

    init(
        users: [EmbeddedStoredUser],
        profiles: [EmbeddedStoredProfile],
        carts: [EmbeddedStoredCart],
        orders: [EmbeddedStoredOrder],
        notifications: [EmbeddedStoredNotification],
        discover: EmbeddedDiscoverState,
        legacyClosetByUser: [String: [EmbeddedLegacyClosetItem]],
        catalogProducts: [EmbeddedCatalogProduct] = [],
        deletedCatalogProductIDs: Set<String> = []
    ) {
        self.users = users
        self.profiles = profiles
        self.carts = carts
        self.orders = orders
        self.notifications = notifications
        self.discover = discover
        self.legacyClosetByUser = legacyClosetByUser
        self.catalogProducts = catalogProducts
        self.deletedCatalogProductIDs = deletedCatalogProductIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decodeIfPresent([EmbeddedStoredUser].self, forKey: .users) ?? []
        profiles = try container.decodeIfPresent([EmbeddedStoredProfile].self, forKey: .profiles) ?? []
        carts = try container.decodeIfPresent([EmbeddedStoredCart].self, forKey: .carts) ?? []
        orders = try container.decodeIfPresent([EmbeddedStoredOrder].self, forKey: .orders) ?? []
        notifications = try container.decodeIfPresent([EmbeddedStoredNotification].self, forKey: .notifications) ?? []
        discover = try container.decodeIfPresent(EmbeddedDiscoverState.self, forKey: .discover) ?? .empty
        legacyClosetByUser = try container.decodeIfPresent([String: [EmbeddedLegacyClosetItem]].self, forKey: .legacyClosetByUser) ?? [:]
        catalogProducts = try container.decodeIfPresent([EmbeddedCatalogProduct].self, forKey: .catalogProducts) ?? []
        deletedCatalogProductIDs = try container.decodeIfPresent(Set<String>.self, forKey: .deletedCatalogProductIDs) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case users
        case profiles
        case carts
        case orders
        case notifications
        case discover
        case legacyClosetByUser
        case catalogProducts
        case deletedCatalogProductIDs
    }

    func normalized() -> EmbeddedBackendState {
        EmbeddedBackendState(
            users: users,
            profiles: profiles,
            carts: carts,
            orders: orders.map(\.normalized),
            notifications: notifications,
            discover: discover,
            legacyClosetByUser: legacyClosetByUser,
            catalogProducts: catalogProducts.map(\.normalized),
            deletedCatalogProductIDs: deletedCatalogProductIDs
        )
    }

    static func normalizedAssetPath(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return rawValue }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url.path.isEmpty ? trimmed : url.path
        }

        return trimmed
    }
}

private struct EmbeddedDiscoverState: Codable {
    var styleDNAByUser: [String: DiscoverStyleDNAProfile]
    var closetByUser: [String: [String]]
    var waitlists: [String: [String]]
    var votesByChallenge: [String: [String]]
    var likedOutfitsByUser: [String: [String]]
    var savedOutfitsByUser: [String: [String]]
    var followedCreatorsByUser: [String: [String]]
    var subscriptionAssignments: [EmbeddedSubscriptionAssignment]
    var boosts: [EmbeddedBoostAssignment]
    var tryBeforeBuy: [EmbeddedTryBeforeBuyReservation]

    static let empty = EmbeddedDiscoverState(
        styleDNAByUser: [:],
        closetByUser: [:],
        waitlists: [:],
        votesByChallenge: [:],
        likedOutfitsByUser: [:],
        savedOutfitsByUser: [:],
        followedCreatorsByUser: [:],
        subscriptionAssignments: [],
        boosts: [],
        tryBeforeBuy: []
    )

    init(
        styleDNAByUser: [String: DiscoverStyleDNAProfile],
        closetByUser: [String: [String]],
        waitlists: [String: [String]],
        votesByChallenge: [String: [String]],
        likedOutfitsByUser: [String: [String]],
        savedOutfitsByUser: [String: [String]],
        followedCreatorsByUser: [String: [String]],
        subscriptionAssignments: [EmbeddedSubscriptionAssignment],
        boosts: [EmbeddedBoostAssignment],
        tryBeforeBuy: [EmbeddedTryBeforeBuyReservation]
    ) {
        self.styleDNAByUser = styleDNAByUser
        self.closetByUser = closetByUser
        self.waitlists = waitlists
        self.votesByChallenge = votesByChallenge
        self.likedOutfitsByUser = likedOutfitsByUser
        self.savedOutfitsByUser = savedOutfitsByUser
        self.followedCreatorsByUser = followedCreatorsByUser
        self.subscriptionAssignments = subscriptionAssignments
        self.boosts = boosts
        self.tryBeforeBuy = tryBeforeBuy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        styleDNAByUser = try container.decodeIfPresent([String: DiscoverStyleDNAProfile].self, forKey: .styleDNAByUser) ?? [:]
        closetByUser = try container.decodeIfPresent([String: [String]].self, forKey: .closetByUser) ?? [:]
        waitlists = try container.decodeIfPresent([String: [String]].self, forKey: .waitlists) ?? [:]
        votesByChallenge = try container.decodeIfPresent([String: [String]].self, forKey: .votesByChallenge) ?? [:]
        likedOutfitsByUser = try container.decodeIfPresent([String: [String]].self, forKey: .likedOutfitsByUser) ?? [:]
        savedOutfitsByUser = try container.decodeIfPresent([String: [String]].self, forKey: .savedOutfitsByUser) ?? [:]
        followedCreatorsByUser = try container.decodeIfPresent([String: [String]].self, forKey: .followedCreatorsByUser) ?? [:]
        subscriptionAssignments = try container.decodeIfPresent([EmbeddedSubscriptionAssignment].self, forKey: .subscriptionAssignments) ?? []
        boosts = try container.decodeIfPresent([EmbeddedBoostAssignment].self, forKey: .boosts) ?? []
        tryBeforeBuy = try container.decodeIfPresent([EmbeddedTryBeforeBuyReservation].self, forKey: .tryBeforeBuy) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case styleDNAByUser
        case closetByUser
        case waitlists
        case votesByChallenge
        case likedOutfitsByUser
        case savedOutfitsByUser
        case followedCreatorsByUser
        case subscriptionAssignments
        case boosts
        case tryBeforeBuy
    }
}

private struct EmbeddedStoredUser: Codable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let passwordHash: String
    let isAdmin: Bool
    let createdAt: Date?
    let updatedAt: Date?
}

private enum EmbeddedSeedAdminCredentials {
    static let email = ""
    static let migratablePasswordHashes: Set<String> = []
    static let currentPasswordHash = ""
}

private struct EmbeddedStoredProfile: Codable {
    let userId: String
    let name: String
    let email: String
    let tier: String
    let city: String
    let note: String
}

private struct EmbeddedStoredCart: Codable {
    let userId: String
    var items: [EmbeddedStoredCartItem]
}

private struct EmbeddedStoredCartItem: Codable {
    let productId: String
    let size: String?
    let color: String?
    var quantity: Int
}

private struct EmbeddedStoredOrder: Codable {
    let id: String
    let userId: String
    let items: [EmbeddedStoredOrderItem]
    let totalPrice: Double
    let subtotal: Double
    let shippingCost: Double
    let discount: Double
    let status: String
    let createdAt: Date?
    let shippingCity: String
    let customer: EmbeddedStoredOrderCustomer
    let paymentMethodId: String?
    let codFee: Double?

    var normalized: EmbeddedStoredOrder {
        EmbeddedStoredOrder(
            id: id,
            userId: userId,
            items: items.map(\.normalized),
            totalPrice: totalPrice,
            subtotal: subtotal,
            shippingCost: shippingCost,
            discount: discount,
            status: status,
            createdAt: createdAt,
            shippingCity: shippingCity,
            customer: customer,
            paymentMethodId: paymentMethodId,
            codFee: codFee
        )
    }

    func updating(status: String) -> EmbeddedStoredOrder {
        EmbeddedStoredOrder(
            id: id,
            userId: userId,
            items: items,
            totalPrice: totalPrice,
            subtotal: subtotal,
            shippingCost: shippingCost,
            discount: discount,
            status: status,
            createdAt: createdAt,
            shippingCity: shippingCity,
            customer: customer,
            paymentMethodId: paymentMethodId,
            codFee: codFee
        )
    }

    var nativeOrder: Order {
        Order(
            id: id,
            createdAt: createdAt,
            status: OrderStatus(rawValue: status.lowercased()) ?? .pending,
            total: totalPrice,
            subtotal: subtotal,
            shippingCost: shippingCost,
            discount: discount,
            lines: items.map(\.nativeLine),
            shippingCity: shippingCity,
            shippingAddress: customer.nativeShippingAddress,
            paymentMethod: paymentMethodId.map { PaymentMethod(type: $0, displayName: $0.capitalized) },
            customerName: customer.name,
            customerEmail: customer.email,
            customerPhone: customer.phone,
            shippingMethodName: customer.shippingMethod
        )
    }
}

private struct EmbeddedStoredOrderItem: Codable {
    let productId: String
    let name: String
    let price: Double
    let image: String
    let quantity: Int
    let size: String?
    let color: String?

    var normalized: EmbeddedStoredOrderItem {
        EmbeddedStoredOrderItem(
            productId: productId,
            name: name,
            price: price,
            image: EmbeddedBackendState.normalizedAssetPath(image),
            quantity: quantity,
            size: size,
            color: color
        )
    }

    var nativeLine: OrderLine {
        OrderLine(
            id: productId,
            name: name,
            imageName: EmbeddedBackendState.normalizedAssetPath(image),
            quantity: quantity,
            price: price,
            size: size,
            color: color,
            product: nil
        )
    }
}

private struct EmbeddedStoredOrderCustomer: Codable {
    let name: String
    let email: String
    let phone: String
    let address: String
    let apartment: String?
    let city: String
    let postalCode: String
    let country: String
    let shippingMethod: String

    var nativeShippingAddress: ShippingAddress {
        ShippingAddress(
            name: name,
            street: address,
            city: city,
            postalCode: postalCode,
            phone: phone,
            email: email,
            apartment: apartment
        )
    }
}

private struct EmbeddedStoredNotification: Codable {
    let id: String
    let userId: String
    let kind: String
    let title: String
    let message: String
    let timestamp: Date?
    let emphasis: String?
    let actionTitle: String?
    let destination: String?
    let isRead: Bool

    func markedRead() -> EmbeddedStoredNotification {
        EmbeddedStoredNotification(
            id: id,
            userId: userId,
            kind: kind,
            title: title,
            message: message,
            timestamp: timestamp,
            emphasis: emphasis,
            actionTitle: actionTitle,
            destination: destination,
            isRead: true
        )
    }

    var nativeNotification: ClientNotification {
        ClientNotification(
            id: id,
            kind: ClientNotificationKind(rawValue: kind) ?? .support,
            title: title,
            message: message,
            timestamp: timestamp.map { Self.timestampFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "Just now",
            emphasis: emphasis,
            actionTitle: actionTitle,
            destination: destination.flatMap(NotificationDestination.init(rawValue:)),
            isRead: isRead
        )
    }

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

private struct EmbeddedSubscriptionAssignment: Codable {
    let userId: String
    let planId: String
    let createdAt: Date?
}

private struct EmbeddedBoostAssignment: Codable {
    let userId: String
    let budget: Double
    let days: Int
    let estimatedReach: Int
    let createdAt: Date?
}

private struct EmbeddedTryBeforeBuyReservation: Codable {
    let userId: String
    let productIds: [String]
    let createdAt: Date?
}

private struct EmbeddedCartEnvelope: Codable {
    let items: [EmbeddedCartLinePayload]
}

private struct EmbeddedCartLinePayload: Codable {
    let id: String
    let productId: String
    let name: String
    let price: Double
    let image: String
    let size: String?
    let color: String?
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productId
        case name
        case price
        case image
        case size
        case color
        case quantity
    }
}

private struct EmbeddedOrdersEnvelope: Codable {
    let orders: [EmbeddedStoredOrder]
}

private struct EmbeddedSingleOrderEnvelope: Codable {
    let order: EmbeddedStoredOrder
}

private struct EmbeddedAdminUsersEnvelope: Codable {
    let users: [User]
}

private struct EmbeddedProfileEnvelope: Codable {
    let profile: ClientProfile
}

private struct EmbeddedSuccessPayload: Codable {
    let success: Bool
}

private struct EmbeddedTokenRefreshPayload: Codable {
    let token: String
}

private struct EmbeddedReplyPayload: Codable {
    let reply: String
}

private struct EmbeddedEstimatedReachPayload: Codable {
    let estimatedReach: Int
}

private struct EmbeddedBoostActivationPayload: Codable {
    let success: Bool
    let estimatedReach: Int
}

private struct EmbeddedGovernorateRequest: Codable {
    let governorate: String
}

private struct EmbeddedCODValidationPayload: Codable {
    let eligible: Bool
    let codFee: Double
}

private struct EmbeddedProfileUpdateRequest: Codable {
    let name: String
    let email: String
    let tier: String
    let city: String
    let note: String
}

private struct EmbeddedDiscoverStylistRequest: Codable {
    let message: String
    let productIds: [String]
}

private struct EmbeddedDiscoverSnapMatchRequest: Codable {
    let mood: String
    let limit: Int
}

private struct EmbeddedDiscoverClosetSelectionRequest: Codable {
    let productIds: [String]
}

private struct EmbeddedDiscoverClosetPayload: Codable {
    let productIds: [String]
}

private struct EmbeddedDiscoverInteractionRequest: Codable {
    let kind: String
    let targetId: String
    let isActive: Bool
}

private struct EmbeddedDiscoverPlanRequest: Codable {
    let planId: String
}

private struct EmbeddedCartDeleteRequest: Codable {
    let productId: String
    let size: String?
    let color: String?
}

private struct EmbeddedBoostRequest: Codable {
    let budget: Double
    let days: Int
}

private struct EmbeddedChallengeVoteRequest: Codable {
    let challengeId: String
}

private struct EmbeddedSocialUser: Codable {
    let id: String
    let name: String
    let username: String
}

private struct EmbeddedBadgePayload: Codable {
    let id: String
    let title: String
    let icon: String
}

private struct EmbeddedGamificationPayload: Codable {
    let points: Int
    let badges: [EmbeddedBadgePayload]
}

private struct EmbeddedLegacyLeaderboardEntry: Codable {
    let id: UUID
    let rank: Int
    let username: String
    let points: Int
}

private struct EmbeddedEligibilityPayload: Codable {
    let eligible: Bool
}

private struct EmbeddedRequestAcceptedPayload: Codable {
    let success: Bool
}

private struct EmbeddedSubscribedPayload: Codable {
    let subscribed: Bool
}

private struct EmbeddedLegacyDrop: Codable {
    let title: String
    let description: String
    let endTime: Date
}

private struct EmbeddedLegacyClosetItem: Codable {
    let id: String
    let name: String
    let color: String
    let brand: String

    init(id: String, name: String, color: String, brand: String) {
        self.id = id
        self.name = name
        self.color = color
        self.brand = brand
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = try container.decode(UUID.self, forKey: .id).uuidString
        }
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(String.self, forKey: .color)
        brand = try container.decode(String.self, forKey: .brand)
    }
}

private struct EmbeddedLegacyClosetCreateRequest: Codable {
    let name: String
    let color: String
    let brand: String
}

private struct EmbeddedBestSellingProduct: Codable {
    let id: String
    let name: String
    let quantity: Int
    let revenue: Double
}

private struct EmbeddedRevenuePoint: Codable {
    let month: String
    let revenue: Double
}

private struct EmbeddedAnalyticsPayload: Codable {
    let totalRevenue: Double
    let todaySales: Double
    let ordersToday: Int
    let totalOrders: Int
    let totalCustomers: Int
    let newUsers: Int
    let pendingOrders: Int
    let lowStockProducts: Int
    let bestSellingProducts: [EmbeddedBestSellingProduct]
    let revenueByMonth: [EmbeddedRevenuePoint]
    let ordersByStatus: [String: Int]
}

private struct EmbeddedOrderPlacementRequest: Codable {
    let id: String
    let items: [EmbeddedOrderPlacementItem]
    let totalPrice: Double?
    let status: String
    let subtotal: Double
    let shippingCost: Double
    let discount: Double
    let promoCode: String?
    let shippingCity: String
    let shippingAddress: EmbeddedOrderShippingAddress?
    let paymentMethod: EmbeddedOrderPaymentMethod?
    let paymentMethodId: String?
    let deliveryLocation: String?
    let codFee: Double
    let customerName: String?
    let customerEmail: String?
    let customerPhone: String?
    let shippingMethodName: String?
}

private struct EmbeddedOrderPlacementItem: Codable {
    let productId: String
    let quantity: Int
    let size: String?
    let color: String?
}

private struct EmbeddedOrderShippingAddress: Codable {
    let name: String?
    let street: String?
    let city: String?
    let postalCode: String?
    let phone: String?
    let email: String?
    let apartment: String?
}

private struct EmbeddedOrderPaymentMethod: Codable {
    let type: String?
    let displayName: String?
}

private struct EmbeddedOrderStatusUpdateRequest: Codable {
    let status: String
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var embeddedIsValidEmailAddress: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    var embeddedIsValidEgyptianMobileNumber: Bool {
        let digits = filter(\.isNumber)
        return digits.count == 11 && digits.hasPrefix("01")
    }
}

private enum EmbeddedProductCategoryResolver {
    static func resolve(_ rawValue: String?) -> ProductCategory? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "shirts", "shirt": return .shirts
        case "knitwear", "knits", "knit": return .knitwear
        case "pants", "pant", "trousers", "trouser": return .pants
        case "denim": return .denim
        case "accessories", "accessory": return .accessories
        case "footwear", "shoe", "shoes": return .footwear
        case "bags", "bag": return .bags
        case "belts", "belt": return .belts
        case "sunglasses", "glass", "glasses": return .sunglasses
        case "loafers", "loafer": return .loafers
        case "sneakers", "sneaker": return .sneakers
        case "boots", "boot": return .boots
        case "suits", "suit": return .suits
        case "coats", "coat": return .coats
        case "jackets", "jacket", "jackets-coats": return .jackets
        case "korean": return .korean
        case "jeans", "baggy": return .jeans
        case "lifestyle": return .lifestyle
        default: return nil
        }
    }
}
