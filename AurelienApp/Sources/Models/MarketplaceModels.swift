import Foundation

typealias Outfit = DiscoverFeedItemData

struct MarketplaceProduct: Identifiable, Codable {
    let id: String
    let name: String
    let images: [String]
    let price: Double
    let sizes: [String]
    let colors: [String]
    let boutiqueId: String
    let description: String?
}

struct MarketplaceBoutique: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let image: String?
}

struct MarketplaceUser: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let savedItems: [String]
}

struct MarketplaceCartItem: Identifiable, Codable {
    let id: String
    let productId: String
    let quantity: Int
    let size: String?
    let color: String?
}

struct MarketplaceOrder: Identifiable, Codable {
    let id: String
    let userId: String
    let items: [MarketplaceCartItem]
    let total: Double
    let status: String
    let createdAt: Date
}

struct FeedPost: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let caption: String?
}

struct Story: Identifiable, Codable, Hashable {
    let id: String
    let title: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageURL = "imageUrl"
    }
}

struct ChatSession: Identifiable, Codable, Hashable {
    let id: String
    let stylistID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case stylistID = "stylistId"
    }
}

struct Event: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startsAt: Date?
}

struct Appointment: Identifiable, Codable, Hashable {
    let id: String
    let scheduledAt: Date?
    let note: String?
}

struct Review: Identifiable, Codable, Hashable {
    let id: String
    let authorName: String?
    let rating: Int?
    let comment: String?
}

// ROOT CAUSE #4: Auth token refresh response model
struct AuthRefreshResponse: Codable {
    let token: String
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
}
