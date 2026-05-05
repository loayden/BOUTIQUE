
import Foundation

enum ProductCategory: String, CaseIterable, Hashable, Identifiable, Codable {
    case shirts
    case knitwear
    case pants
    case denim
    case accessories
    case footwear
    case bags
    case belts
    case sunglasses
    case loafers
    case sneakers
    case boots
    case suits
    case coats
    case jackets
    case korean
    case jeans
    case lifestyle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shirts: return "Shirts"
        case .knitwear: return "Knitwear"
        case .pants: return "Pants"
        case .denim: return "Denim"
        case .accessories: return "Accessories"
        case .footwear: return "Footwear"
        case .bags: return "Bags"
        case .belts: return "Belts"
        case .sunglasses: return "Sunglasses"
        case .loafers: return "Loafers"
        case .sneakers: return "Sneakers"
        case .boots: return "Boots"
        case .suits: return "Suits"
        case .coats: return "Coats"
        case .jackets: return "Jackets"
        case .korean: return "Korean"
        case .jeans: return "Jeans"
        case .lifestyle: return "Lifestyle"
        }
    }

    var subtitle: String {
        switch self {
        case .shirts: return "Relaxed refinement for daily dressing."
        case .knitwear: return "Soft architectural layers for colder light."
        case .pants: return "Tailored lines and relaxed silhouettes."
        case .denim: return "Clean foundations with a darker tone."
        case .accessories: return "The finishing details of a boutique wardrobe."
        case .footwear: return "Solid footing with a composed stance."
        case .bags: return "Compact leather essentials for daily carry."
        case .belts: return "Quiet utility with premium hardware."
        case .sunglasses: return "Sharp frames for strong presence."
        case .loafers: return "Soft structure for evening ease."
        case .sneakers: return "Minimal sport reworked for luxury."
        case .boots: return "Durable construction with refined lines."
        case .suits: return "Controlled tailoring with warm, quiet structure."
        case .coats: return "Strong outer layers for colder movement."
        case .jackets: return "Leather and tailoring for transitional light."
        case .korean: return "Relaxed silhouettes and draped proportion."
        case .jeans: return "Relaxed cargo and baggy silhouettes."
        case .lifestyle: return "Objects and pieces for a considered life."
        }
    }

    var heroImageName: String {
        switch self {
        case .shirts: return "shirts.jpg"
        case .knitwear: return "Knitwear.jpg"
        case .pants: return "denim.jpg"
        case .denim: return "denim.jpg"
        case .accessories: return "sunglasses.jpg"
        case .footwear: return "Sneakers.jpg"
        case .bags: return "Bags & Wallets.jpg"
        case .belts: return "Belts.jpg"
        case .sunglasses: return "sunglasses.jpg"
        case .loafers: return "Loafers.jpg"
        case .sneakers: return "Sneakers.jpg"
        case .boots: return "boots.jpg"
        case .suits: return "Suits.jpg"
        case .coats: return "Jackets & Coats.jpg"
        case .jackets: return "Jackets & Coats.jpg"
        case .korean: return "korean.jpg"
        case .jeans: return "denim.jpg"
        case .lifestyle: return "main.jpg"
        }
    }
}

enum ProductBadge: String, Hashable, Codable {
    case newArrival = "New Arrival"
    case editorialPick = "Editorial Pick"
    case bestselling = "Best Seller"
}

struct Colorway: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let hex: UInt

    init(name: String, hex: UInt) {
        self.id = name.lowercased()
        self.name = name
        self.hex = hex
    }

    static func hex(for name: String) -> UInt {
        switch name.lowercased() {
        case "black": return 0x111111
        case "white", "cream", "ivory": return 0xEFE3CF
        case "brown", "tan", "camel": return 0x8B6840
        case "navy", "midnight": return 0x1A1F2F
        case "grey", "gray", "charcoal": return 0x4E4A45
        case "green", "olive": return 0x55624A
        default: return 0xC9A86A
        }
    }
}

struct Product: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let category: ProductCategory
    let price: Double
    let summary: String
    let story: String
    let imageNames: [String]
    var images: [String] { imageNames }
    let sizes: [String]
    let colors: [Colorway]
    let composition: String
    let care: String
    let delivery: String
    let returns: String
    let badge: ProductBadge?
    let featured: Bool
    let rating: Double?
    let reviewCount: Int?
    let inventoryCount: Int?
    let isAvailable: Bool?

    init(
        id: String,
        name: String,
        category: ProductCategory,
        price: Double,
        summary: String,
        story: String,
        imageNames: [String],
        sizes: [String],
        colors: [Colorway],
        composition: String,
        care: String,
        delivery: String,
        returns: String,
        badge: ProductBadge?,
        featured: Bool,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        inventoryCount: Int? = nil,
        isAvailable: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.price = price
        self.summary = summary
        self.story = story
        self.imageNames = imageNames
        self.sizes = sizes
        self.colors = colors
        self.composition = composition
        self.care = care
        self.delivery = delivery
        self.returns = returns
        self.badge = badge
        self.featured = featured
        self.rating = rating
        self.reviewCount = reviewCount
        self.inventoryCount = inventoryCount
        self.isAvailable = isAvailable
    }

    var heroImageName: String { imageNames.first ?? category.heroImageName }

    var resolvedInventoryCount: Int? {
        inventoryCount.map { max($0, 0) }
    }

    var isInStock: Bool {
        guard isAvailable != false else { return false }
        guard let resolvedInventoryCount else { return true }
        return resolvedInventoryCount > 0
    }

    var isLowStock: Bool {
        guard let resolvedInventoryCount else { return false }
        return isInStock && resolvedInventoryCount <= 3
    }

    var stockLabel: String {
        guard isAvailable != false else { return "Out of stock" }
        guard let resolvedInventoryCount else { return "Available" }
        if resolvedInventoryCount == 0 { return "Out of stock" }
        if resolvedInventoryCount <= 3 { return "\(resolvedInventoryCount) left" }
        return "\(resolvedInventoryCount) in stock"
    }
    
    var isValid: Bool {
        !id.isEmpty &&
        !name.isEmpty &&
        !price.isNaN &&
        !price.isInfinite &&
        !imageNames.isEmpty
    }
}

extension Product {
    static let excludedNames: Set<String> = [
        "Reversible Leather Belt",
        "Pebbled Leather Tote"
    ]

    var isExcluded: Bool {
        Self.excludedNames.contains(name)
    }
}

struct CollectionFeature: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
    let category: ProductCategory
}

struct HeroMoment: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
}

struct BrandPromise: Identifiable, Hashable, Codable {
    let id: String
    let eyebrow: String
    let title: String
    let body: String
}

struct BrandStat: Identifiable, Hashable, Codable {
    let id: String
    let value: String
    let label: String
    let note: String?

    init(id: String, value: String, label: String, note: String? = nil) {
        self.id = id
        self.value = value
        self.label = label
        self.note = note
    }
}

struct BrandPillar: Identifiable, Hashable, Codable {
    let id: String
    let number: String
    let title: String
    let body: String
}

struct ClientJourneyStep: Identifiable, Hashable, Codable {
    let id: String
    let number: String
    let title: String
    let subtitle: String
    let description: String
}

struct PlatformPerspective: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let title: String
    let description: String
}

struct PartnershipStandard: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let title: String
    let description: String
}

struct LookbookChapter: Identifiable, Hashable, Codable {
    let id: String
    let chapter: String
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let category: ProductCategory
    let featuredProductIDs: [String]
}

enum SortOption: String, CaseIterable, Identifiable, Codable {
    case featured
    case newest
    case priceLowToHigh
    case priceHighToLow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured: return "Featured"
        case .newest: return "Newest"
        case .priceLowToHigh: return "Price: Low to High"
        case .priceHighToLow: return "Price: High to Low"
        }
    }
}

enum PriceBand: String, CaseIterable, Identifiable, Codable {
    case under1000
    case from1000To5000
    case from5000To10000
    case above10000

    var id: String { rawValue }

    var title: String {
        switch self {
        case .under1000: return "Under 1,000 EGP"
        case .from1000To5000: return "1,000 - 5,000 EGP"
        case .from5000To10000: return "5,000 - 10,000 EGP"
        case .above10000: return "10,000+ EGP"
        }
    }

    func contains(_ value: Double) -> Bool {
        switch self {
        case .under1000: return value < 1000
        case .from1000To5000: return value >= 1000 && value < 5000
        case .from5000To10000: return value >= 5000 && value < 10000
        case .above10000: return value >= 10000
        }
    }
}

struct BagLine: Identifiable, Hashable, Codable {
    let id: String
    let product: Product
    var size: String
    var color: Colorway
    var quantity: Int

    var subtotal: Double {
        product.price * Double(quantity)
    }
}

struct OrderLine: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let imageName: String
    let quantity: Int
    let price: Double
    let size: String?
    let color: String?
    var product: Product? = nil
}

enum OrderStatus: String, CaseIterable, Hashable, Codable {
    case pending
    case confirmed
    case preparing
    case shipped
    case delivered
    case cancelled

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .preparing: return "Preparing"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }
    
    var displayName: String {
        title
    }

    var trackingIndex: Int? {
        Self.trackingFlow.firstIndex(of: self)
    }

    var isTerminal: Bool {
        self == .delivered || self == .cancelled
    }

    static let trackingFlow: [OrderStatus] = [.pending, .confirmed, .preparing, .shipped, .delivered]
}

struct Order: Identifiable, Hashable, Codable {
    let id: String
    let createdAt: Date?
    let status: OrderStatus
    let total: Double
    let subtotal: Double
    let shippingCost: Double
    let discount: Double
    var lines: [OrderLine]
    var items: [OrderLine] { lines }
    let shippingCity: String
    var shippingAddress: ShippingAddress? = nil
    var paymentMethod: PaymentMethod? = nil
    var customerName: String? = nil
    var customerEmail: String? = nil
    var customerPhone: String? = nil
    var shippingMethodName: String? = nil
}

struct ShippingAddress: Hashable, Codable {
    let name: String
    let street: String
    let city: String
    let postalCode: String
    let phone: String
    var email: String? = nil
    var apartment: String? = nil
}

struct PaymentMethod: Hashable, Codable {
    let type: String
    let displayName: String
}

struct ClientProfile: Hashable, Codable {
    let name: String
    let email: String
    let tier: String
    let city: String
    let note: String
}

struct CheckoutForm: Hashable, Codable {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var city: String = "Cairo"
    var address: String = ""
    var apartment: String = ""
    var shippingMethod: String = "Premium Courier"

    var isValid: Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = phone.filter(\.isNumber)

        return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        normalizedEmail.contains("@") &&
        normalizedEmail.split(separator: "@").last?.contains(".") == true &&
        digits.count >= 10 &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CatalogHomeContent: Hashable, Codable {
    let heroStories: [CatalogHomeHero]
    let promotions: [CatalogHomePromotion]
}

struct CatalogHomeHero: Identifiable, Hashable, Codable {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let detail: String
    let imageName: String
    let buttonTitle: String
}

struct CatalogHomePromotion: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
}

struct CatalogCollectionsContent: Hashable, Codable {
    let collections: [CollectionFeature]
}

struct SupportContentPayload: Hashable, Codable {
    let channels: [SupportChannel]
    let faqs: [FAQItem]
}

struct LegalContentPayload: Hashable, Codable {
    let documents: [LegalDocument]
}
