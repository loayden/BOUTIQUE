import Foundation

// MARK: - Notifications
enum ClientNotificationKind: String, Codable, Hashable, CaseIterable {
    case orderUpdate
    case promotion
    case recommendation
    case support

    var title: String {
        switch self {
        case .orderUpdate: return "Order Update"
        case .promotion: return "Promotion"
        case .recommendation: return "Recommendation"
        case .support: return "Support"
        }
    }

    var systemImage: String {
        switch self {
        case .orderUpdate: return "shippingbox"
        case .promotion: return "sparkles"
        case .recommendation: return "wand.and.stars"
        case .support: return "message"
        }
    }
}

enum NotificationDestination: String, Codable, Hashable {
    case orders
    case shop
    case discover
    case wishlist
    case support
    case stylist
    case wallet
}

struct ClientNotification: Identifiable, Hashable, Codable {
    let id: String
    let kind: ClientNotificationKind
    let title: String
    let message: String
    let timestamp: String
    let emphasis: String?
    let actionTitle: String?
    let destination: NotificationDestination?
    var isRead: Bool
}

struct SavedAddress: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let recipient: String
    let line1: String
    let apartment: String?
    let city: EgyptGovernorate
    let phone: String
    let isPrimary: Bool

    var summary: String {
        [line1, apartment.map { $0 }, city.rawValue]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct StoredPaymentMethod: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let brand: String
    let last4: String
    let expiry: String
    let isPrimary: Bool

    var maskedTitle: String {
        "\(brand) •••• \(last4)"
    }
}

struct FAQItem: Identifiable, Hashable, Codable {
    let id: String
    let question: String
    let answer: String
}

struct SupportChannel: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let systemImage: String
}

struct StylistPrompt: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let prompt: String
    let category: ProductCategory?
}

struct LegalSection: Identifiable, Hashable, Codable {
    let id: String
    let heading: String
    let body: [String]
}

struct LegalDocument: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let intro: String
    let sections: [LegalSection]
}

extension ProductBadge: CaseIterable, Identifiable {
    static var allCases: [ProductBadge] {
        [.newArrival, .editorialPick, .bestselling]
    }

    var id: String { rawValue }
}

extension Product {
    var ratingDisplayValue: String? {
        guard let rating, rating.isFinite else { return nil }
        return String(format: "%.1f", rating)
    }

    var reviewVolumeText: String? {
        guard let reviewCount, reviewCount > 0 else { return nil }
        return "\(reviewCount) reviews"
    }

    var availabilityNote: String {
        if let isAvailable {
            return isAvailable ? "In stock" : "Currently unavailable"
        }

        if let inventoryCount {
            return inventoryCount > 0 ? "\(inventoryCount) left in stock" : "Out of stock"
        }

        return "Availability pending"
    }

    var serviceHighlights: [String] {
        [
            availabilityNote,
            "Orders are confirmed only after server approval.",
            "Tracked support stays available after checkout."
        ]
    }
}
