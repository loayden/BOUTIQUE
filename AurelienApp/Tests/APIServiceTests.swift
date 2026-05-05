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
    }

    override func tearDown() {
        AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)
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
