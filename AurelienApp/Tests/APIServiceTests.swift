import XCTest
@testable import BOUTIQUE

@MainActor
final class CommerceHardeningTests: XCTestCase {
    private let api = APIService.shared
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    override func setUp() {
        super.setUp()
        AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)
        UserDefaults.standard.removeObject(forKey: "aurelien.currentUser")
        UserDefaults.standard.removeObject(forKey: "aurelien.authToken")
    }

    override func tearDown() {
        AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)
        UserDefaults.standard.removeObject(forKey: "aurelien.currentUser")
        UserDefaults.standard.removeObject(forKey: "aurelien.authToken")
        super.tearDown()
    }

    func testCartAddUpdateRemoveUsesVariantState() async throws {
        let session = try await createUser()
        let product = try await firstOrderableProduct()
        let size = try XCTUnwrap(product.sizes.first)
        let color = try XCTUnwrap(product.colors.first?.name)

        try await backendRequest(
            endpoint: "/cart/items",
            method: "POST",
            body: CartItem(productId: product.id, size: size, color: color, quantity: 1),
            token: session.token
        )
        let added = try await cart(token: session.token)
        let addedLine = try XCTUnwrap(added.items.first { $0.productId == product.id && $0.size == size && $0.color == color })
        XCTAssertEqual(addedLine.quantity, 1)
        XCTAssertEqual(addedLine.price, product.price, accuracy: 0.001)

        try await backendRequest(
            endpoint: "/cart/items",
            method: "PATCH",
            body: CartItem(productId: product.id, size: size, color: color, quantity: 3),
            token: session.token
        )
        let updated = try await cart(token: session.token)
        let updatedLine = try XCTUnwrap(updated.items.first { $0.productId == product.id && $0.size == size && $0.color == color })
        XCTAssertEqual(updatedLine.quantity, 3)

        try await backendRequest(
            endpoint: "/cart/items",
            method: "DELETE",
            body: RemoveCartItemRequest(productId: product.id, size: size, color: color),
            token: session.token
        )
        let removed = try await cart(token: session.token)
        XCTAssertFalse(removed.items.contains { $0.productId == product.id && $0.size == size && $0.color == color })
    }

    func testSavedProductsPersistPerAccount() async throws {
        let session = try await createUser()
        let product = try await firstOrderableProduct()
        AuthTokenStore.save(session.token, for: AuthTokenStore.serviceKey)

        let saved = try await api.saveProduct(productId: product.id, userId: session.user.id)
        XCTAssertTrue(saved.contains { $0.id == product.id })

        let fetched = try await api.fetchSavedProducts(userId: session.user.id)
        XCTAssertEqual(Set(fetched.map(\.id)), [product.id])

        let cleared = try await api.removeSavedProduct(productId: product.id, userId: session.user.id)
        XCTAssertFalse(cleared.contains { $0.id == product.id })
    }

    func testSavedAddressesPersistPerAccount() async throws {
        let session = try await createUser()
        AuthTokenStore.save(session.token, for: AuthTokenStore.serviceKey)

        let created = SavedAddress(
            id: "address-\(UUID().uuidString.lowercased())",
            label: "Home",
            recipient: "Test Shopper",
            line1: "12 Nile Street",
            apartment: "4B",
            city: .cairo,
            phone: "01012345678",
            isPrimary: true
        )

        let addresses = try await api.createSavedAddress(created)
        XCTAssertEqual(addresses.first?.id, created.id)
        XCTAssertTrue(addresses.first?.isPrimary == true)

        let wallet = try await api.fetchWalletSnapshot()
        XCTAssertTrue(wallet.savedAddresses.contains(where: { $0.id == created.id }))

        let cleared = try await api.deleteSavedAddress(id: created.id)
        XCTAssertFalse(cleared.contains { $0.id == created.id })
    }

    func testSavedAddressPrimaryTransitionPersistsPerAccount() async throws {
        let session = try await createUser()
        AuthTokenStore.save(session.token, for: AuthTokenStore.serviceKey)

        let home = SavedAddress(
            id: "address-home-\(UUID().uuidString.lowercased())",
            label: "Home",
            recipient: "Test Shopper",
            line1: "12 Nile Street",
            apartment: "4B",
            city: .cairo,
            phone: "01012345678",
            isPrimary: true
        )
        let studio = SavedAddress(
            id: "address-studio-\(UUID().uuidString.lowercased())",
            label: "Studio",
            recipient: "Test Shopper",
            line1: "44 Garden City",
            apartment: "9A",
            city: .giza,
            phone: "01012345679",
            isPrimary: false
        )

        _ = try await api.createSavedAddress(home)
        _ = try await api.createSavedAddress(studio)

        let promoted = try await api.setPrimarySavedAddress(id: studio.id)
        XCTAssertTrue(promoted.contains { $0.id == studio.id && $0.isPrimary })
        XCTAssertFalse(promoted.contains { $0.id == home.id && $0.isPrimary })

        let wallet = try await api.fetchWalletSnapshot()
        XCTAssertTrue(wallet.savedAddresses.contains { $0.id == studio.id && $0.isPrimary })
        XCTAssertFalse(wallet.savedAddresses.contains { $0.id == home.id && $0.isPrimary })
    }

    func testNotificationsReadAndDeletePersist() async throws {
        let session = try await createUser()
        AuthTokenStore.save(session.token, for: AuthTokenStore.serviceKey)
        let product = try await firstOrderableProduct()
        let size = try XCTUnwrap(product.sizes.first)
        let color = try XCTUnwrap(product.colors.first?.name)
        let shippingAddress = ShippingAddress(
            name: "Test Shopper",
            street: "12 Nile Street",
            city: "Cairo",
            postalCode: "11511",
            phone: "01012345678",
            email: session.user.email
        )
        let orderRequest = TestOrderPlacementRequest(
            id: "notification-order-\(UUID().uuidString.lowercased())",
            items: [
                TestOrderItemRequest(
                    productId: product.id,
                    quantity: 1,
                    size: size,
                    color: color
                )
            ],
            status: "pending",
            subtotal: product.price,
            shippingCost: 0,
            discount: 0,
            shippingCity: "Cairo",
            shippingAddress: shippingAddress,
            paymentMethod: PaymentMethod(type: "cod", displayName: "Cash on delivery"),
            paymentMethodId: "cod",
            promoCode: nil,
            deliveryLocation: "Cairo",
            codFee: 0,
            customerName: shippingAddress.name,
            customerEmail: session.user.email,
            customerPhone: shippingAddress.phone,
            shippingMethodName: "Standard"
        )

        _ = try await backendRequest(
            endpoint: "/orders",
            method: "POST",
            body: orderRequest,
            token: session.token
        )

        let fetched = try await api.fetchNotifications()
        let notification = try XCTUnwrap(fetched.first)
        XCTAssertFalse(notification.isRead)

        try await api.markNotificationRead(id: notification.id)
        let markedRead = try await api.fetchNotifications()
        XCTAssertTrue(markedRead.contains { $0.id == notification.id && $0.isRead })

        try await api.deleteNotification(id: notification.id)
        let cleared = try await api.fetchNotifications()
        XCTAssertFalse(cleared.contains { $0.id == notification.id })
    }

    func testOrderCreationRecomputesTotalsServerSide() async throws {
        let session = try await createUser()
        let product = try await firstOrderableProduct()
        let size = try XCTUnwrap(product.sizes.first)
        let color = try XCTUnwrap(product.colors.first?.name)
        let quantity = 2
        let shippingAddress = ShippingAddress(
            name: "Test Shopper",
            street: "12 Nile Street",
            city: "Cairo",
            postalCode: "11511",
            phone: "01012345678",
            email: session.user.email
        )
        let tamperedOrder = TestOrderPlacementRequest(
            id: "test-order-\(UUID().uuidString)",
            items: [
                TestOrderItemRequest(
                    productId: product.id,
                    quantity: quantity,
                    size: size,
                    color: color
                )
            ],
            status: "pending",
            subtotal: 1,
            shippingCost: 0,
            discount: 0,
            shippingCity: "Cairo",
            shippingAddress: shippingAddress,
            paymentMethod: PaymentMethod(type: "cod", displayName: "Cash on delivery"),
            paymentMethodId: "cod",
            promoCode: nil,
            deliveryLocation: "Cairo",
            codFee: 9_999,
            customerName: shippingAddress.name,
            customerEmail: session.user.email,
            customerPhone: "01012345678",
            shippingMethodName: "Standard"
        )

        let data = try await backendRequest(
            endpoint: "/orders",
            method: "POST",
            body: tamperedOrder,
            token: session.token
        )
        let created = try XCTUnwrap(try decoder.decode(TestOrdersEnvelope.self, from: data).orders.first)

        XCTAssertEqual(created.subtotal, product.price * Double(quantity), accuracy: 0.001)
        let createdLine = try XCTUnwrap(created.lines.first)
        XCTAssertEqual(createdLine.price, product.price, accuracy: 0.001)
        XCTAssertNotEqual(created.totalPrice, 1)
        XCTAssertGreaterThanOrEqual(created.total, created.subtotal)
    }

    func testCheckoutFieldValidatorsRejectBadInput() {
        XCTAssertTrue("client@example.com".isValidEmailAddress)
        XCTAssertFalse("client@example".isValidEmailAddress)
        XCTAssertFalse("client.example.com".isValidEmailAddress)
        XCTAssertTrue("01012345678".isValidEgyptianMobile)
        XCTAssertFalse("0112345678".isValidEgyptianMobile)
        XCTAssertFalse("02012345678".isValidEgyptianMobile)
    }

    func testSharedAppBackgroundUsesWarmCreamCanvas() {
        XCTAssertEqual(UIColor(BrandPalette.background).rgbHexString, "F7F7F4")
    }

    func testCommerceProductCardsUseFourByFiveImageRatio() {
        XCTAssertEqual(Double(ProductCardView.imageAspectRatio), 0.8, accuracy: 0.001)
        XCTAssertEqual(Double(ProductDetailView.commerceImageAspectRatio), 0.8, accuracy: 0.001)
    }

    func testProductDetailStickyCTAReservesBottomClearance() {
        XCTAssertGreaterThanOrEqual(Double(ProductDetailView.stickyBarBottomPadding), 24)
        XCTAssertGreaterThanOrEqual(Double(ProductDetailView.stickyBarContentPadding), 160)
    }

    func testRemoteAssetURLResolvesUploadsAgainstAPIOrigin() throws {
        let resolved = APIConfig.resolvedRemoteAssetURLString(
            for: "/uploads/whitejacket.jpg",
            usesEmbeddedStaticBackend: false,
            apiOriginURL: try XCTUnwrap(URL(string: "https://boutique-api-one.vercel.app/api")),
            contentOriginURL: try XCTUnwrap(URL(string: "https://boutique-api-one.vercel.app/v1"))
        )

        XCTAssertEqual(resolved, "https://boutique-api-one.vercel.app/uploads/whitejacket.jpg")
    }

    func testRemoteAssetURLResolvesBareFilenameIntoUploadsPath() throws {
        let resolved = APIConfig.resolvedRemoteAssetURLString(
            for: "shirts.jpg",
            usesEmbeddedStaticBackend: false,
            apiOriginURL: try XCTUnwrap(URL(string: "https://boutique-api-one.vercel.app/api")),
            contentOriginURL: try XCTUnwrap(URL(string: "https://boutique-api-one.vercel.app/v1"))
        )

        XCTAssertEqual(resolved, "https://boutique-api-one.vercel.app/uploads/shirts.jpg")
    }

    func testRemoteAssetURLEncodesSpacesInUploadPath() throws {
        let resolved = APIConfig.resolvedRemoteAssetURLString(
            for: "/uploads/Cream Zip-Up Harrington Jacket.jpg",
            usesEmbeddedStaticBackend: false,
            apiOriginURL: try XCTUnwrap(URL(string: "http://127.0.0.1:3000/api")),
            contentOriginURL: try XCTUnwrap(URL(string: "https://raw.githubusercontent.com/loayden/BOUTIQUE/main/AurelienApp/AURE-LIEN-/public/v1"))
        )

        XCTAssertEqual(resolved, "http://127.0.0.1:3000/uploads/Cream%20Zip-Up%20Harrington%20Jacket.jpg")
    }

    func testRemoteAssetURLRebasesLocalhostUploadsOntoActiveAPIOrigin() throws {
        let resolved = APIConfig.resolvedRemoteAssetURLString(
            for: "http://localhost:3000/uploads/whitejacket.jpg",
            usesEmbeddedStaticBackend: false,
            apiOriginURL: try XCTUnwrap(URL(string: "http://127.0.0.1:3000/api")),
            contentOriginURL: try XCTUnwrap(URL(string: "https://raw.githubusercontent.com/loayden/BOUTIQUE/main/AurelienApp/AURE-LIEN-/public/v1"))
        )

        XCTAssertEqual(resolved, "http://127.0.0.1:3000/uploads/whitejacket.jpg")
    }

    func testGuestLaunchAfterOnboardingRoutesIntoMainApp() {
        XCTAssertEqual(
            AppLaunchDestination.resolve(
                showSplash: false,
                didCompleteOnboarding: true,
                isAuthenticated: false
            ),
            .mainApp
        )
    }

    func testPublicRouteFallsBackFromAdminForNonAdminUsers() {
        XCTAssertEqual(AppExperiencePolicy.publicRoute(for: .admin, isAdmin: false), .profile)
        XCTAssertEqual(AppExperiencePolicy.publicRoute(for: .orders, isAdmin: false), .orders)
        XCTAssertEqual(
            AppExperiencePolicy.publicRoute(for: .orders, isAdmin: false, isAuthenticated: false),
            .login
        )
        XCTAssertEqual(
            AppExperiencePolicy.publicRoute(for: .wallet, isAdmin: false, isAuthenticated: false),
            .login
        )
        XCTAssertEqual(
            AppExperiencePolicy.publicRoute(for: .notifications, isAdmin: false, isAuthenticated: false),
            .login
        )
    }

    func testDiscoverSurfaceExcludesCommunityInPublicRelease() {
        XCTAssertEqual(DiscoverSurface.allCases, [.feed, .drops])
    }

    func testDeleteAccountRemovesUserAndInvalidatesSession() async throws {
        let session = try await createUser()

        _ = try await EmbeddedStaticBackend.shared.performRequest(
            endpoint: "/users/me",
            method: "DELETE",
            body: nil,
            token: session.token
        )

        do {
            _ = try await backendRequest(
                endpoint: "/auth/signin",
                method: "POST",
                body: LoginCredentials(email: session.user.email, password: "SecurePass123!"),
                token: nil
            )
            XCTFail("Deleted account should not be able to sign in.")
        } catch APIError.unauthorized {
            // Expected.
        }
    }

    func testDeleteCurrentAccountLocallyClearsSessionAndScopedState() {
        let store = AurelienStore(startBackgroundTasks: false, restorePersistedSession: true)
        let user = User(
            id: "delete-me",
            name: "Client",
            email: "client@example.com",
            phone: nil,
            isAdmin: false,
            createdAt: nil,
            updatedAt: nil
        )
        let address = SavedAddress(
            id: "address",
            label: "Home",
            recipient: "Client",
            line1: "12 Nile Street",
            apartment: nil,
            city: .cairo,
            phone: "01012345678",
            isPrimary: true
        )

        store.login(user: user, token: "embedded-static.delete-me")
        store.recentQueries = ["blazer"]
        store.wishlist = ["product-1"]
        store.savedAddresses = [address]
        store.selectedTab = .account

        store.completeLocalAccountDeletion()

        XCTAssertNil(store.currentUser)
        XCTAssertNil(store.authToken)
        XCTAssertTrue(store.recentQueries.isEmpty)
        XCTAssertTrue(store.wishlist.isEmpty)
        XCTAssertTrue(store.savedAddresses.isEmpty)
        XCTAssertEqual(store.selectedTab, .home)
    }

    func testReleaseReadinessRequiresPrivacyManifestAndHTTPSProductionURLs() {
        let issues = ReleaseReadinessValidator.issues(
            apiBaseURL: "http://localhost:3000/api",
            staticContentBaseURL: Optional<String>.none,
            privacyManifestPresent: false,
            privacyPolicyURL: "http://example.com/privacy",
            supportURL: Optional<String>.none
        )

        XCTAssertTrue(issues.contains(.missingPrivacyManifest))
        XCTAssertTrue(issues.contains(.invalidAPIBaseURL))
        XCTAssertTrue(issues.contains(.invalidStaticContentBaseURL))
        XCTAssertTrue(issues.contains(.invalidPrivacyPolicyURL))
        XCTAssertTrue(issues.contains(.invalidSupportURL))
    }

    func testAppBundleIncludesPrivacyManifest() {
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    }

    func testAppBundleDoesNotShipEmbeddedCommerceFixtures() {
        ["products", "discover", "collections", "home", "support", "legal", "state"].forEach { name in
            XCTAssertNil(Bundle.main.url(forResource: name, withExtension: "json"))
        }
    }

    func testStoreDoesNotRestorePersistedUserWithoutSessionToken() throws {
        let staleUser = User(
            id: "stale-user",
            name: "Stale User",
            email: "stale@example.com",
            phone: nil,
            isAdmin: false,
            createdAt: nil,
            updatedAt: nil
        )
        let staleUserData = try JSONEncoder().encode(staleUser)
        UserDefaults.standard.set(staleUserData, forKey: "aurelien.currentUser")
        UserDefaults.standard.removeObject(forKey: "aurelien.authToken")
        AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)

        let store = AurelienStore(startBackgroundTasks: false, restorePersistedSession: false)

        XCTAssertNil(store.currentUser)
        XCTAssertNil(store.authToken)
    }

    func testTokenPayloadDecoderUsesPayloadSegmentAndExpirationUnits() throws {
        let payload = [
            "sub": "user-123",
            "email": "client@example.com",
            "isAdmin": false,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ] as [String: Any]
        let token = try jwtLikeToken(payload: payload)

        let decoded = try XCTUnwrap(DecodedAuthTokenPayload(token: token))
        XCTAssertEqual(decoded.sub, "user-123")
        XCTAssertEqual(decoded.email, "client@example.com")
        XCTAssertGreaterThan(decoded.expirationDate, Date())
    }

    func testUnauthorizedResponseClearsStoredToken() async {
        AuthTokenStore.save("embedded-static.missing-user", for: AuthTokenStore.serviceKey)

        do {
            _ = try await api.fetchCart(userId: "missing-user")
            XCTFail("Expected missing embedded user token to be rejected.")
        } catch APIError.unauthorized {
            XCTAssertNil(AuthTokenStore.value(for: AuthTokenStore.serviceKey))
        } catch {
            XCTFail("Expected unauthorized, got \(error).")
        }
    }

    func testFailedSigninDoesNotClearExistingSessionToken() async throws {
        let session = try await createUser()
        AuthTokenStore.save(session.token, for: AuthTokenStore.serviceKey)

        do {
            _ = try await api.login(email: session.user.email, password: "WrongPassword123!")
            XCTFail("Expected wrong password to be rejected.")
        } catch APIError.unauthorized {
            XCTAssertEqual(AuthTokenStore.value(for: AuthTokenStore.serviceKey), session.token)
        } catch {
            XCTFail("Expected unauthorized, got \(error).")
        }
    }

    func testSigninUsesStoredPasswordHashNotBypass() async throws {
        let session = try await createUser()

        do {
            try await backendRequest(
                endpoint: "/auth/signin",
                method: "POST",
                body: LoginCredentials(email: session.user.email, password: "not-the-password"),
                token: nil
            )
            XCTFail("Signin should not accept an arbitrary password.")
        } catch APIError.unauthorized {
            // Expected: stored password verification is enforced.
        }

        let data = try await backendRequest(
            endpoint: "/auth/signin",
            method: "POST",
            body: LoginCredentials(email: session.user.email, password: "SecurePass123!"),
            token: nil
        )
        let response = try decoder.decode(AuthResponse.self, from: data)
        XCTAssertEqual(response.user.email, session.user.email)
        XCTAssertNotNil(response.token)
    }

    private func createUser() async throws -> TestSession {
        let email = "commerce-\(UUID().uuidString.lowercased())@example.com"
        let credentials = SignupCredentials(
            name: "Test Shopper",
            email: email,
            password: "SecurePass123!",
            confirmPassword: "SecurePass123!",
            phone: "01012345678"
        )
        let data = try await backendRequest(
            endpoint: "/auth/signup",
            method: "POST",
            body: credentials,
            token: nil
        )
        let response = try decoder.decode(AuthResponse.self, from: data)
        return TestSession(user: response.user, token: try XCTUnwrap(response.token))
    }

    private func firstOrderableProduct() async throws -> Product {
        let products = try await api.fetchProducts()
        return try XCTUnwrap(products.first { product in
            product.isInStock &&
            product.sizes.isEmpty == false &&
            product.colors.isEmpty == false &&
            (product.inventoryCount ?? 10) >= 5
        })
    }

    @discardableResult
    private func backendRequest<T: Encodable>(
        endpoint: String,
        method: String,
        body: T,
        token: String?
    ) async throws -> Data {
        let data = try encoder.encode(body)
        return try await EmbeddedStaticBackend.shared.performRequest(
            endpoint: endpoint,
            method: method,
            body: data,
            token: token
        )
    }

    private func cart(token: String) async throws -> TestCartResponse {
        let data = try await EmbeddedStaticBackend.shared.performRequest(
            endpoint: "/cart",
            method: "GET",
            body: nil,
            token: token
        )
        return try decoder.decode(TestCartResponse.self, from: data)
    }

    private func jwtLikeToken(payload: [String: Any]) throws -> String {
        let headerData = try JSONSerialization.data(withJSONObject: ["alg": "HS256", "typ": "JWT"])
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        return "\(base64URL(headerData)).\(base64URL(payloadData)).signature"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension UIColor {
    var rgbHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}

private struct TestSession {
    let user: User
    let token: String
}

private struct RemoveCartItemRequest: Encodable {
    let productId: String
    let size: String?
    let color: String?
}

private struct TestCartResponse: Decodable {
    let items: [TestCartItem]
}

private struct TestCartItem: Decodable {
    let productId: String
    let size: String?
    let color: String?
    let quantity: Int
    let price: Double
}

private struct TestOrderPlacementRequest: Encodable {
    let id: String
    let items: [TestOrderItemRequest]
    let status: String
    let subtotal: Double
    let shippingCost: Double
    let discount: Double
    let shippingCity: String
    let shippingAddress: ShippingAddress
    let paymentMethod: PaymentMethod
    let paymentMethodId: String
    let promoCode: String?
    let deliveryLocation: String
    let codFee: Double
    let customerName: String
    let customerEmail: String
    let customerPhone: String
    let shippingMethodName: String
}

private struct TestOrderItemRequest: Encodable {
    let productId: String
    let quantity: Int
    let size: String?
    let color: String?
}

private struct TestOrdersEnvelope: Decodable {
    let orders: [TestOrder]
}

private struct TestOrder: Decodable {
    let totalPrice: Double
    let subtotal: Double
    let shippingCost: Double
    let discount: Double
    let lines: [TestOrderLine]

    enum CodingKeys: String, CodingKey {
        case totalPrice
        case subtotal
        case shippingCost
        case discount
        case lines = "items"
    }

    var total: Double {
        totalPrice
    }
}

private struct TestOrderLine: Decodable {
    let productId: String
    let price: Double
    let quantity: Int
    let size: String?
    let color: String?
}
