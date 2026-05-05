import Foundation
import Observation
import Security
import SwiftUI

@MainActor
@Observable
final class AurelienStore {
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private var lastRoutePushAt = Date.distantPast
    @ObservationIgnored private var authInvalidationObserver: NSObjectProtocol?

    var products: [Product] {
        didSet {
            trendingQueries = Self.deriveTrendingQueries(from: products)
            persist(trendingQueries, key: StorageKey.trendingQueries)
        }
    }
    var profile: ClientProfile {
        didSet {
            persist(profile, key: StorageKey.clientProfile)
        }
    }
    
    // MARK: - User & Auth
    var currentUser: User?
    var authToken: String?
    var isAuthenticated: Bool { currentUser != nil }
    var isAdmin: Bool { currentUser?.isAdmin ?? false }
    

    // MARK: - Navigation (Coordinator)
    var selectedTab: AppTab = .home {
        didSet {
            defaults.set(selectedTab.rawValue, forKey: StorageKey.selectedTab)
        }
    }
    var navigationPath: [AppRoute] = [] {
        didSet {
            persist(navigationPath, key: StorageKey.navigationPath)
        }
    }
    var homeNavigationPath = NavigationPath() {
        didSet { persistNavigationPath(homeNavigationPath, for: .home) }
    }
    var discoverNavigationPath = NavigationPath() {
        didSet { persistNavigationPath(discoverNavigationPath, for: .discover) }
    }
    var shopNavigationPath = NavigationPath() {
        didSet { persistNavigationPath(shopNavigationPath, for: .shop) }
    }
    var bagNavigationPath = NavigationPath() {
        didSet { persistNavigationPath(bagNavigationPath, for: .bag) }
    }
    var accountNavigationPath = NavigationPath() {
        didSet { persistNavigationPath(accountNavigationPath, for: .account) }
    }
    var selectedCategory: ProductCategory? {
        didSet { persist(selectedCategory, key: StorageKey.selectedCategory) }
    }
    var selectedBadge: ProductBadge? {
        didSet { persist(selectedBadge, key: StorageKey.selectedBadge) }
    }
    var selectedPriceBand: PriceBand? {
        didSet { persist(selectedPriceBand, key: StorageKey.selectedPriceBand) }
    }
    var selectedSort: SortOption = .featured {
        didSet { persist(selectedSort, key: StorageKey.selectedSort) }
    }
    var activeSheet: AppSheet?

    // Deep linking support
    func handleDeepLink(_ route: AppRoute) {
        pushRoute(route)
    }

    func pushRoute(_ route: AppRoute) {
        let now = Date()
        if now.timeIntervalSince(lastRoutePushAt) < 0.2 {
            return
        }
        lastRoutePushAt = now

        if navigationPath.last != route {
            navigationPath.append(route)
        }

        var path = path(for: selectedTab)
        path.append(route)
        setPath(path, for: selectedTab)

        if navigationPath.count > 24 {
            navigationPath.removeFirst(navigationPath.count - 24)
        }
    }

    // Navigation safety: pop to root, safe pop
    func popToRoot() {
        navigationPath.removeAll()
    }
    func safePop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        popLast(in: selectedTab)
    }

    // Restore navigation state
    func restoreNavigationState() {
        let tabRaw = defaults.string(forKey: StorageKey.selectedTab)
            ?? defaults.string(forKey: "selectedTab")
        if let tabRaw {
            if tabRaw == "profile" {
                selectedTab = .account
            } else if let tab = AppTab(rawValue: tabRaw) {
                selectedTab = tab
            }
        }

        let pathKey = Self.storageKey(StorageKey.navigationPath, userId: currentUser?.id)
        if let restoredPath = Self.loadValue([AppRoute].self, key: pathKey) {
            navigationPath = restoredPath
        }

        homeNavigationPath = Self.loadNavigationPath(key: Self.storageKey(Self.navigationStorageKey(for: .home), userId: currentUser?.id))
        discoverNavigationPath = Self.loadNavigationPath(key: Self.storageKey(Self.navigationStorageKey(for: .discover), userId: currentUser?.id))
        shopNavigationPath = Self.loadNavigationPath(key: Self.storageKey(Self.navigationStorageKey(for: .shop), userId: currentUser?.id))
        bagNavigationPath = Self.loadNavigationPath(key: Self.storageKey(Self.navigationStorageKey(for: .bag), userId: currentUser?.id))
        accountNavigationPath = Self.loadNavigationPath(key: Self.storageKey(Self.navigationStorageKey(for: .account), userId: currentUser?.id))
    }

    // MARK: - Search
    var recentQueries: [String] {
        didSet { persist(recentQueries, key: StorageKey.recentQueries) }
    }
    var trendingQueries: [String]

    // MARK: - Wishlist
    var wishlist: Set<String> {
        didSet { persist(Array(wishlist), key: StorageKey.wishlist) }
    }

    // MARK: - Client Services
    var notifications: [ClientNotification] {
        didSet { persist(notifications, key: StorageKey.notifications) }
    }
    var savedAddresses: [SavedAddress] {
        didSet { persist(savedAddresses, key: StorageKey.savedAddresses) }
    }
    var paymentMethods: [StoredPaymentMethod] {
        didSet { persist(paymentMethods, key: StorageKey.paymentMethods) }
    }
    
    // MARK: - Cart (Bag)
    var bag: [BagLine] {
        didSet { persist(bag, key: StorageKey.bag) }
    }
    
    // MARK: - Orders
    var orders: [Order] {
        didSet { persist(orders, key: StorageKey.orders) }
    }
    
    // MARK: - Checkout
    var latestCheckoutOrder: Order? {
        didSet { persist(latestCheckoutOrder, key: StorageKey.latestCheckoutOrder) }
    }
    var isCheckingOut = false
    
    // MARK: - Admin
    var adminUsers: [User] = []
    var adminOrders: [Order] = []
    var adminProducts: [Product] = []
    var analytics: AnalyticsData?

    private static func colorways(_ names: [String]) -> [Colorway] {
        let resolved = names.map { name in
            let hex: UInt
            switch name.lowercased() {
            case "black": hex = 0x111111
            case "white", "cream", "ivory": hex = 0xEFE3CF
            case "brown", "tan", "camel", "mocha": hex = 0x8B6840
            case "navy", "midnight", "indigo": hex = 0x1A1F2F
            case "grey", "gray", "charcoal": hex = 0x4E4A45
            case "blue": hex = 0x2F6DB5
            case "beige": hex = 0xD8C3A5
            default: hex = 0xC9A86A
            }
            return Colorway(name: name.capitalized, hex: hex)
        }
        return resolved.isEmpty ? [Colorway(name: "Default", hex: 0xC9A86A)] : resolved
    }

    enum AppSheet: String, Identifiable, Codable, Hashable {
        case auth
        case checkout

        var id: String { rawValue }
    }

    #if DEBUG
    static var previewCatalogProducts: [Product] {
        [
            Product(
                id: "p-jc-003",
                name: "Wool-Blend Trench Coat",
                category: .jackets,
                price: 1500,
                summary: "A modern trench with a tailored shoulder.",
                story: "A modern trench with a tailored shoulder.",
                imageNames: ["/uploads/whitejacket.jpg", "/uploads/peig_leather_jacket.jpg"],
                sizes: ["M", "L", "XL"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .editorialPick,
                featured: true
            ),
            Product(
                id: "p-jc-007",
                name: "Navy Embroidered Bomber",
                category: .jackets,
                price: 1000,
                summary: "Navy Embroidered Bomber",
                story: "Navy Embroidered Bomber",
                imageNames: ["/uploads/italian_jacket3.jpg", "/uploads/italian_jacket.jpg", "/uploads/italian_jacket2.jpg"],
                sizes: ["M", "L", "XL"],
                colors: colorways(["camel", "navy"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .bestselling,
                featured: true
            ),
            Product(
                id: "p-jc-011",
                name: "Urban Brown Leather Jacket",
                category: .jackets,
                price: 1500,
                summary: "Urban Brown Leather Jacket",
                story: "Urban Brown Leather Jacket",
                imageNames: ["/uploads/brownleather2.jpg", "/uploads/brown_wind_jacket.jpg"],
                sizes: ["M", "L", "XL"],
                colors: colorways(["brown"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .newArrival,
                featured: true
            ),
            Product(
                id: "p-jc-012",
                name: "Dark Urban Bomber Jacket",
                category: .jackets,
                price: 1500,
                summary: "Dark Urban Bomber Jacket",
                story: "Dark Urban Bomber Jacket",
                imageNames: ["/uploads/black.jpg", "/uploads/black_wind_jacket.jpg"],
                sizes: ["M", "L", "XL"],
                colors: colorways(["black"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-jc-014",
                name: "Gray Urban Bomber Jacket",
                category: .jackets,
                price: 1500,
                summary: "Gray Urban Bomber Jacket",
                story: "Gray Urban Bomber Jacket",
                imageNames: ["/uploads/greyjacket.jpg", "/uploads/greyjacket2.jpg"],
                sizes: ["M", "L", "XL"],
                colors: colorways(["gray"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-jc-016",
                name: "Cream Geometric Quilted Shacket",
                category: .jackets,
                price: 1470,
                summary: "Cream quilted shacket with a geometric matelasse pattern.",
                story: "Cream quilted shacket with a geometric matelasse pattern.",
                imageNames: ["/uploads/Cream Geometric Quilted Shacket.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["cream", "gray"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .editorialPick,
                featured: true
            ),
            Product(
                id: "p-jc-017",
                name: "Cream Zip-Up Harrington Jacket",
                category: .jackets,
                price: 1470,
                summary: "Minimal cream harrington jacket with a clean zip-front profile.",
                story: "Minimal cream harrington jacket with a clean zip-front profile.",
                imageNames: ["/uploads/Cream Zip-Up Harrington Jacket.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .newArrival,
                featured: true
            ),
            Product(
                id: "p-jc-018",
                name: "Textured Waffle-Knit Zip Jacket",
                category: .jackets,
                price: 1200,
                summary: "Lightweight zip jacket in a cream waffle-knit texture.",
                story: "Lightweight zip jacket in a cream waffle-knit texture.",
                imageNames: ["/uploads/Textured Waffle-Knit Zip Jacket.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-su-001",
                name: "Minimal Cream Street Set",
                category: .suits,
                price: 2149,
                summary: "Minimal Cream Street Set",
                story: "Minimal Cream Street Set",
                imageNames: ["/uploads/whitesuit.jpg", "/uploads/peig_suit2.jpg"],
                sizes: ["38", "40", "42", "44"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .editorialPick,
                featured: true
            ),
            Product(
                id: "p-su-003",
                name: "Mocha Casual Street Set",
                category: .suits,
                price: 2149,
                summary: "Mocha Casual Street Set",
                story: "Mocha Casual Street Set",
                imageNames: ["/uploads/brownsuit.jpg", "/uploads/brown_suit.jpg"],
                sizes: ["38", "40", "42"],
                colors: colorways(["mocha"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-sh-003",
                name: "Black & White Striped Polo Sweater",
                category: .shirts,
                price: 1080,
                summary: "Striped rib-knit polo sweater in black and white.",
                story: "Striped rib-knit polo sweater in black and white.",
                imageNames: ["/uploads/Black & White Striped Polo Sweater.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["black", "white"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .newArrival,
                featured: true
            ),
            Product(
                id: "p-sh-004",
                name: "Cream Polo Collar Sweatshirt",
                category: .shirts,
                price: 1470,
                summary: "Relaxed cream sweatshirt finished with a polo collar.",
                story: "Relaxed cream sweatshirt finished with a polo collar.",
                imageNames: ["/uploads/Cream Polo Collar Sweatshirt.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .editorialPick,
                featured: true
            ),
            Product(
                id: "p-sh-005",
                name: "Poker Face Tan Ribbed Polo",
                category: .shirts,
                price: 680,
                summary: "Tan ribbed polo with a clean open-collar neckline.",
                story: "Tan ribbed polo with a clean open-collar neckline.",
                imageNames: ["/uploads/Poker Face Tan Ribbed Polo.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["tan"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-kn-001",
                name: "Dark Charcoal Chenille Turtleneck",
                category: .knitwear,
                price: 870,
                summary: "Soft chenille turtleneck in a dark charcoal tone.",
                story: "Soft chenille turtleneck in a dark charcoal tone.",
                imageNames: ["/uploads/Dark Charcoal Chenille Turtleneck.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["charcoal"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .newArrival,
                featured: true
            ),
            Product(
                id: "p-kn-002",
                name: "Balenciaga Gradient Logo Sweater",
                category: .knitwear,
                price: 1200,
                summary: "Brown-to-camel gradient sweater with tonal Balenciaga branding.",
                story: "Brown-to-camel gradient sweater with tonal Balenciaga branding.",
                imageNames: ["/uploads/Balenciaga Gradient Logo Sweater.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["brown", "camel"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .editorialPick,
                featured: true
            ),
            Product(
                id: "p-kn-003",
                name: "Beige Essential Rib-Knit Sweater",
                category: .knitwear,
                price: 870,
                summary: "Beige rib-knit sweater with contrast tipped trim.",
                story: "Beige rib-knit sweater with contrast tipped trim.",
                imageNames: ["/uploads/Beige Essential Rib-Knit Sweater.jpg"],
                sizes: ["M"],
                colors: colorways(["beige", "white"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-kn-004",
                name: "Charcoal Quarter-Zip Pullover",
                category: .knitwear,
                price: 870,
                summary: "Charcoal pullover with a clean quarter-zip neckline.",
                story: "Charcoal pullover with a clean quarter-zip neckline.",
                imageNames: ["/uploads/Charcoal Quarter-Zip Pullover.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["charcoal"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-kn-005",
                name: "Essential Turtleneck Sweater (Ivory)",
                category: .knitwear,
                price: 680,
                summary: "Essential ivory turtleneck sweater with a clean minimalist finish.",
                story: "Essential ivory turtleneck sweater with a clean minimalist finish.",
                imageNames: ["/uploads/Essential Turtleneck Sweater (Ivory).jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .bestselling,
                featured: true
            ),
            Product(
                id: "p-kn-006",
                name: "Tommy Hilfiger Striped Hoodie (Tan:Brown)",
                category: .knitwear,
                price: 870,
                summary: "Striped knit hoodie in tan, brown, and white.",
                story: "Striped knit hoodie in tan, brown, and white.",
                imageNames: ["/uploads/Tommy Hilfiger Striped Hoodie (Tan:Brown).jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["tan", "brown", "white"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-denim-001",
                name: "Classic Blue Denim Jeans (Pull & Bear)",
                category: .denim,
                price: 1155,
                summary: "Classic blue denim jeans in a relaxed straight fit.",
                story: "Classic blue denim jeans in a relaxed straight fit.",
                imageNames: ["/uploads/Classic Blue Denim Jeans (Pull & Bear).jpg"],
                sizes: ["30", "32", "34", "36", "38"],
                colors: colorways(["blue"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .bestselling,
                featured: true
            ),
            Product(
                id: "p-denim-002",
                name: "Dark Indigo Denim Jeans",
                category: .denim,
                price: 1155,
                summary: "Dark indigo denim jeans with a clean tapered line.",
                story: "Dark indigo denim jeans with a clean tapered line.",
                imageNames: ["/uploads/Dark Indigo Denim Jeans.jpg"],
                sizes: ["30", "32", "34", "36", "38"],
                colors: colorways(["indigo"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-denim-003",
                name: "Levi's Classic Blue Jeans",
                category: .denim,
                price: 1155,
                summary: "Classic blue Levi's jeans for everyday wear.",
                story: "Classic blue Levi's jeans for everyday wear.",
                imageNames: ["/uploads/Levi's Classic Blue Jeans.jpg"],
                sizes: ["30", "32", "34", "36", "38"],
                colors: colorways(["blue"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .bestselling,
                featured: true
            ),
            Product(
                id: "p-denim-004",
                name: "Light Wash Vintage Denim (Pull & Bear)",
                category: .denim,
                price: 1155,
                summary: "Light wash vintage denim with a relaxed cropped fit.",
                story: "Light wash vintage denim with a relaxed cropped fit.",
                imageNames: ["/uploads/Light Wash Vintage Denim (Pull & Bear).jpg"],
                sizes: ["30", "32", "34", "36", "38"],
                colors: colorways(["blue"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-denim-005",
                name: "Medium Wash Levi's Cropped Jeans",
                category: .denim,
                price: 700,
                summary: "Medium wash cropped Levi's jeans with a classic five-pocket shape.",
                story: "Medium wash cropped Levi's jeans with a classic five-pocket shape.",
                imageNames: ["/uploads/Medium Wash Levi's Cropped Jeans.jpg"],
                sizes: ["30", "32", "34", "36", "38"],
                colors: colorways(["blue"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-korean-001",
                name: "Camo Wool Trousers (Gray)",
                category: .korean,
                price: 1200,
                summary: "Gray wool trousers with a cropped modern silhouette.",
                story: "Gray wool trousers with a cropped modern silhouette.",
                imageNames: ["/uploads/Camo Wool Trousers (Gray).jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["gray"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .newArrival,
                featured: true
            ),
            Product(
                id: "p-korean-002",
                name: "Black Elastic-Waist Trousers",
                category: .korean,
                price: 1080,
                summary: "Relaxed black trousers with an elasticated back waist.",
                story: "Relaxed black trousers with an elasticated back waist.",
                imageNames: ["/uploads/Black Elastic-Waist Trousers.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["black"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-korean-003",
                name: "Diesel Elastic-Back Chino (Cream)",
                category: .korean,
                price: 1100,
                summary: "Cream chino with a structured straight leg and elastic-back waist.",
                story: "Cream chino with a structured straight leg and elastic-back waist.",
                imageNames: ["/uploads/Diesel Elastic-Back Chino (Cream).jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .editorialPick,
                featured: true
            ),
            Product(
                id: "p-korean-004",
                name: "Diesel Stretch Chino (Beige)",
                category: .korean,
                price: 1100,
                summary: "Beige stretch chino with a tapered easy-wear fit.",
                story: "Beige stretch chino with a tapered easy-wear fit.",
                imageNames: ["/uploads/Diesel Stretch Chino (Beige).jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["beige"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-baggy-001",
                name: "Black Tapered Cargo Pants",
                category: .jeans,
                price: 1200,
                summary: "Tapered black cargo pants with adjustable hems.",
                story: "Tapered black cargo pants with adjustable hems.",
                imageNames: ["/uploads/Black Tapered Cargo Pants.jpg"],
                sizes: ["M", "L", "XL", "2XL"],
                colors: colorways(["black"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .bestselling,
                featured: true
            ),
            Product(
                id: "p-baggy-002",
                name: "Ribbed Cargo Knit Pant (Cream)",
                category: .jeans,
                price: 1200,
                summary: "Cream ribbed knit pants with oversized cargo pockets.",
                story: "Cream ribbed knit pants with oversized cargo pockets.",
                imageNames: ["/uploads/Ribbed Cargo Knit Pant (Cream).jpg"],
                sizes: ["M"],
                colors: colorways(["cream"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: nil,
                featured: false
            ),
            Product(
                id: "p-baggy-003",
                name: "Medium Wash Cargo Denim Jeans",
                category: .jeans,
                price: 1155,
                summary: "Medium wash denim jeans with utility cargo paneling.",
                story: "Medium wash denim jeans with utility cargo paneling.",
                imageNames: ["/uploads/Medium Wash Cargo Denim Jeans.jpg"],
                sizes: ["30", "32", "34", "36", "38"],
                colors: colorways(["blue"]),
                composition: "Details from in-store inventory.",
                care: "Follow care guidance provided at delivery.",
                delivery: "Delivery across Egypt.",
                returns: "Returns available within policy window.",
                badge: .newArrival,
                featured: true
            )
        ]
    }
    #endif

    init() {
        Self.bootstrapSensitiveStorageIfNeeded()
        let loadedToken = KeychainStore.value(for: StorageKey.authToken) ?? Self.loadValue(String.self, key: StorageKey.authToken)
        let loadedUser = Self.loadValue(User.self, key: StorageKey.currentUser)
            ?? Self.restoreUserFromToken(loadedToken)
        currentUser = loadedUser
        authToken = loadedToken
        let userScoped = loadedUser?.id

        products = []
        trendingQueries = Self.loadValue([String].self, key: StorageKey.trendingQueries)
            ?? []
        profile = Self.loadValue(ClientProfile.self, key: Self.storageKey(StorageKey.clientProfile, userId: userScoped))
            ?? Self.defaultProfile(for: loadedUser)

        let loadedRecentQueries = Self.loadValue([String].self, key: Self.storageKey(StorageKey.recentQueries, userId: userScoped))
        let persistedWishlist = Self.loadValue([String].self, key: Self.storageKey(StorageKey.wishlist, userId: userScoped))
        let persistedBag = Self.loadValue([BagLine].self, key: Self.storageKey(StorageKey.bag, userId: userScoped))
        let persistedOrders = Self.loadValue([Order].self, key: Self.storageKey(StorageKey.orders, userId: userScoped))
        recentQueries = loadedRecentQueries ?? []
        wishlist = Set(persistedWishlist ?? [])
        bag = persistedBag ?? []
        orders = persistedOrders ?? []
        notifications = Self.loadValue([ClientNotification].self, key: Self.storageKey(StorageKey.notifications, userId: userScoped)) ?? []
        savedAddresses = Self.loadValue([SavedAddress].self, key: Self.storageKey(StorageKey.savedAddresses, userId: userScoped)) ?? []
        paymentMethods = Self.loadValue([StoredPaymentMethod].self, key: Self.storageKey(StorageKey.paymentMethods, userId: userScoped)) ?? []
        latestCheckoutOrder = Self.loadValue(Order.self, key: Self.storageKey(StorageKey.latestCheckoutOrder, userId: userScoped))
        selectedCategory = Self.loadValue(ProductCategory.self, key: Self.storageKey(StorageKey.selectedCategory, userId: userScoped))
        selectedBadge = Self.loadValue(ProductBadge.self, key: Self.storageKey(StorageKey.selectedBadge, userId: userScoped))
        selectedPriceBand = Self.loadValue(PriceBand.self, key: Self.storageKey(StorageKey.selectedPriceBand, userId: userScoped))
        selectedSort = Self.loadValue(SortOption.self, key: Self.storageKey(StorageKey.selectedSort, userId: userScoped)) ?? .featured
        if let loadedUser {
            Self.saveValue(loadedUser, key: StorageKey.currentUser)
        }
        if let loadedToken, !loadedToken.isEmpty {
            KeychainStore.save(loadedToken, for: StorageKey.authToken)
            UserDefaults.standard.removeObject(forKey: StorageKey.authToken)
        }
        authInvalidationObserver = NotificationCenter.default.addObserver(
            forName: .aurelienAuthSessionInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self else { return }

                if let invalidatedToken = notification.userInfo?[AuthSessionInvalidationUserInfo.token] as? String {
                    guard let authToken = self.authToken, authToken == invalidatedToken else {
                        return
                    }
                }

                self.logout()
            }
        }
        restoreNavigationState()

        Task {
            await refreshCatalogFromBackend()
            await hydrateAuthenticatedSession()
        }
    }

    deinit {
        if let authInvalidationObserver {
            NotificationCenter.default.removeObserver(authInvalidationObserver)
        }
    }

    
    // Add similar didSet for other critical state as needed

    var featuredProducts: [Product] {
        products.filter(\.featured).prefix(8).map { $0 }
    }

    var wishlistedProducts: [Product] {
        products.filter { $0.isValid && wishlist.contains($0.id) && !$0.isExcluded }
    }

    var bagCount: Int {
        bag.reduce(0) { $0 + $1.quantity }
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var subtotal: Double {
        bag.reduce(0) { $0 + $1.subtotal }
    }

    var shippingCost: Double {
        bag.isEmpty ? 0 : 95
    }

    var total: Double {
        subtotal + shippingCost
    }

    var firstBagAvailabilityIssue: String? {
        for line in bag {
            if line.product.isInStock == false {
                return "\(line.product.name) is out of stock."
            }

            if let availableQuantity = line.product.resolvedInventoryCount,
               line.quantity > availableQuantity {
                return "Only \(availableQuantity) \(availableQuantity == 1 ? "piece" : "pieces") of \(line.product.name) are available."
            }
        }

        return nil
    }

    var primaryAddress: SavedAddress? {
        savedAddresses.first(where: \.isPrimary) ?? savedAddresses.first
    }

    var primaryPaymentMethod: StoredPaymentMethod? {
        paymentMethods.first(where: \.isPrimary) ?? paymentMethods.first
    }

    var personalizedProducts: [Product] {
        let prioritizedCategories = preferredCategories
        let excludedIDs = Set(wishlist).union(bag.map { $0.product.id })

        let preferred = products.filter { product in
            product.isValid && prioritizedCategories.contains(product.category) && !excludedIDs.contains(product.id)
        }

        if preferred.count >= 6 {
            return Array(preferred.prefix(6))
        }

        let fallback = products.filter { product in
            product.isValid && !excludedIDs.contains(product.id)
        }
        return Array((preferred + fallback).uniqued(by: \.id).prefix(6))
    }

    func openCategory(_ category: ProductCategory?) {
        selectedCategory = category
    }

    func present(_ sheet: AppSheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func path(for tab: AppTab) -> NavigationPath {
        switch tab {
        case .home:
            return homeNavigationPath
        case .discover:
            return discoverNavigationPath
        case .shop:
            return shopNavigationPath
        case .bag:
            return bagNavigationPath
        case .account:
            return accountNavigationPath
        }
    }

    func setPath(_ path: NavigationPath, for tab: AppTab) {
        switch tab {
        case .home:
            homeNavigationPath = path
        case .discover:
            discoverNavigationPath = path
        case .shop:
            shopNavigationPath = path
        case .bag:
            bagNavigationPath = path
        case .account:
            accountNavigationPath = path
        }
    }

    func popToRoot(in tab: AppTab) {
        setPath(NavigationPath(), for: tab)
        if tab == selectedTab {
            navigationPath.removeAll()
        }
    }

    private func popLast(in tab: AppTab) {
        var path = path(for: tab)
        guard !path.isEmpty else { return }
        path.removeLast()
        setPath(path, for: tab)
    }

    func filteredProducts(searchText: String = "") -> [Product] {
        let loweredQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var result = products.filter { product in
            guard product.isValid else { return false }
            let matchesCategory = selectedCategory.map { product.category == $0 } ?? true
            let matchesBadge = selectedBadge.map { product.badge == $0 } ?? true
            let matchesPrice = selectedPriceBand.map { $0.contains(product.price) } ?? true
            let matchesQuery =
                loweredQuery.isEmpty ||
                product.name.lowercased().contains(loweredQuery) ||
                product.summary.lowercased().contains(loweredQuery) ||
                product.category.title.lowercased().contains(loweredQuery)

            return !product.isExcluded && matchesCategory && matchesBadge && matchesPrice && matchesQuery
        }

        switch selectedSort {
        case .featured:
            result.sort { lhs, rhs in
                if lhs.featured == rhs.featured {
                    return lhs.price > rhs.price
                }
                return lhs.featured && !rhs.featured
            }
        case .newest:
            result.reverse()
        case .priceLowToHigh:
            result.sort { $0.price < $1.price }
        case .priceHighToLow:
            result.sort { $0.price > $1.price }
        }

        return result
    }

    func relatedProducts(for product: Product) -> [Product] {
        products
            .filter { $0.isValid && !$0.isExcluded && $0.id != product.id && ($0.category == product.category || $0.featured) }
            .prefix(6)
            .map { $0 }
    }

    func isWishlisted(_ product: Product) -> Bool {
        wishlist.contains(product.id)
    }

    func toggleWishlist(for product: Product) {
        if wishlist.contains(product.id) {
            wishlist.remove(product.id)
        } else {
            wishlist.insert(product.id)
            sendSmartNotification(
                kind: .recommendation,
                title: "\(product.name) saved to your list",
                message: "We will use this preference to refine your outfit feed and stylist suggestions.",
                emphasis: "Preference updated",
                actionTitle: "Open Wishlist",
                destination: .wishlist
            )
        }
        BrandHaptics.selection()
    }

    func addToBag(product: Product, size: String, color: Colorway) {
        Task {
            do {
                try await addCartLine(product: product, size: size, color: color)
                sendSmartNotification(
                    kind: .promotion,
                    title: "\(product.name) added to bag",
                    message: "Try before you buy is available for selected products from your bag.",
                    emphasis: "Checkout accelerator",
                    actionTitle: "Open Bag",
                    destination: .shop
                )
                BrandHaptics.softImpact()
            } catch {
                if let apiError = error as? APIError,
                   case .unauthorized = apiError {
                    present(.auth)
                }
                sendSmartNotification(
                    kind: .orderUpdate,
                    title: "Bag update failed",
                    message: (error as? APIError)?.errorDescription ?? error.localizedDescription,
                    emphasis: "Action needed",
                    actionTitle: isAuthenticated ? "Open Bag" : "Sign In",
                    destination: isAuthenticated ? .shop : nil
                )
            }
        }
    }

    func addToCart(_ product: Product) {
        guard !product.isExcluded, product.isInStock else { return }
        let size = product.sizes.first ?? "Not specified"
        let color = product.colors.first ?? Colorway(name: "Not specified", hex: 0xC9A96E)
        addToBag(product: product, size: size, color: color)
    }

    func updateQuantity(for line: BagLine, delta: Int) {
        Task {
            do {
                try await updateCartLineQuantity(line, quantity: max(line.quantity + delta, 0))
                BrandHaptics.selection()
            } catch {
                print("Failed to update cart quantity: \(error)")
            }
        }
    }

    func removeFromBag(_ line: BagLine) {
        Task {
            do {
                try await removeCartLine(line)
                BrandHaptics.heavyImpact()
            } catch {
                print("Failed to remove cart line: \(error)")
            }
        }
    }

    func rememberQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentQueries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentQueries.insert(trimmed, at: 0)
        recentQueries = Array(recentQueries.prefix(6))
    }

    func removeRecentQuery(_ query: String) {
        recentQueries.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
    }

    func clearRecentQueries() {
        recentQueries.removeAll()
    }

    func checkoutSeed() -> CheckoutForm {
        let recipientName = primaryAddress?.recipient ?? profile.name
        let nameParts = recipientName.components(separatedBy: " ")

        return CheckoutForm(
            firstName: nameParts.first ?? "",
            lastName: nameParts.dropFirst().joined(separator: " "),
            email: profile.email,
            phone: primaryAddress?.phone ?? "",
            city: (primaryAddress?.city ?? .cairo).rawValue,
            address: primaryAddress?.line1 ?? "",
            apartment: primaryAddress?.apartment ?? "",
            shippingMethod: "Premium Courier"
        )
    }

    func buildOrder(
        from form: CheckoutForm,
        paymentMethod: PaymentMethod? = nil,
        shippingCost overrideShippingCost: Double? = nil,
        discount overrideDiscount: Double = 0,
        shippingMethodName overrideShippingMethodName: String? = nil,
        total overrideTotal: Double? = nil
    ) -> Order {
        let fullName = [form.firstName, form.lastName]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = bag.map { line in
            OrderLine(
                id: line.id,
                name: line.product.name,
                imageName: line.product.heroImageName,
                quantity: line.quantity,
                price: line.product.price,
                size: line.size,
                color: line.color.name,
                product: line.product
            )
        }

        let resolvedShippingCost = overrideShippingCost ?? shippingCost
        let resolvedTotal = overrideTotal ?? max(subtotal + resolvedShippingCost - overrideDiscount, 0)

        return Order(
            id: "AUR-\(Int(Date().timeIntervalSince1970))",
            createdAt: Date(),
            status: .pending,
            total: resolvedTotal,
            subtotal: subtotal,
            shippingCost: resolvedShippingCost,
            discount: overrideDiscount,
            lines: lines,
            shippingCity: form.city,
            shippingAddress: ShippingAddress(
                name: fullName,
                street: form.address,
                city: form.city,
                postalCode: "",
                phone: form.phone,
                email: form.email,
                apartment: form.apartment.isEmpty ? nil : form.apartment
            ),
            paymentMethod: paymentMethod,
            customerName: fullName,
            customerEmail: form.email,
            customerPhone: form.phone,
            shippingMethodName: overrideShippingMethodName ?? form.shippingMethod
        )
    }

    @discardableResult
    func commitPlacedOrder(_ order: Order) -> Order {
        orders.insert(order, at: 0)
        latestCheckoutOrder = order
        bag.removeAll()
        appendNotification(
            ClientNotification(
                id: "notification-order-\(order.id)",
                kind: .orderUpdate,
                title: "Order \(order.id) has been placed.",
                message: "Your order is now recorded in the account timeline and support can confirm delivery windows from the orders screen.",
                timestamp: "Just now",
                emphasis: "Order confirmed",
                actionTitle: "View Orders",
                destination: .orders,
                isRead: false
            )
        )
        BrandHaptics.notificationSuccess()
        return order
    }

    func paymentMethod(for storedID: String?) -> PaymentMethod? {
        guard let storedID, let stored = paymentMethods.first(where: { $0.id == storedID }) else {
            return nil
        }

        return PaymentMethod(type: stored.brand.lowercased(), displayName: stored.maskedTitle)
    }

    func markNotificationRead(_ notification: ClientNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
    }

    func markAllNotificationsRead() {
        notifications = notifications.map { notification in
            var updated = notification
            updated.isRead = true
            return updated
        }
    }

    func removeNotification(_ notification: ClientNotification) {
        notifications.removeAll { $0.id == notification.id }
    }

    @discardableResult
    func addAddress(
        label: String,
        recipient: String,
        line1: String,
        apartment: String,
        city: EgyptGovernorate.RawValue,
        phone: String,
        isPrimary: Bool
    ) -> SavedAddress {
        if isPrimary {
            savedAddresses = savedAddresses.map { address in
                SavedAddress(
                    id: address.id,
                    label: address.label,
                    recipient: address.recipient,
                    line1: address.line1,
                    apartment: address.apartment,
                    city: address.city,
                    phone: address.phone,
                    isPrimary: false
                )
            }
        }

        let address = SavedAddress(
            id: "address-\(UUID().uuidString.lowercased())",
            label: label,
            recipient: recipient,
            line1: line1,
            apartment: apartment.isEmpty ? nil : apartment,
            city: EgyptGovernorate(rawValue: city) ?? .cairo,
            phone: phone,
            isPrimary: isPrimary || savedAddresses.isEmpty
        )

        savedAddresses.insert(address, at: 0)
        BrandHaptics.notificationSuccess()
        return address
    }

    func deleteAddress(id: String) {
        let deletedWasPrimary = savedAddresses.first(where: { $0.id == id })?.isPrimary == true
        savedAddresses.removeAll { $0.id == id }

        if deletedWasPrimary, let first = savedAddresses.first {
            setPrimaryAddress(id: first.id)
        }
    }

    func setPrimaryAddress(id: String) {
        savedAddresses = savedAddresses.map { address in
            SavedAddress(
                id: address.id,
                label: address.label,
                recipient: address.recipient,
                line1: address.line1,
                apartment: address.apartment,
                city: address.city,
                phone: address.phone,
                isPrimary: address.id == id
            )
        }
    }

    func addPaymentMethod(
        label: String,
        brand: String,
        last4: String,
        expiry: String,
        isPrimary: Bool
    ) {
        if isPrimary {
            paymentMethods = paymentMethods.map { method in
                StoredPaymentMethod(
                    id: method.id,
                    label: method.label,
                    brand: method.brand,
                    last4: method.last4,
                    expiry: method.expiry,
                    isPrimary: false
                )
            }
        }

        let method = StoredPaymentMethod(
            id: "payment-\(UUID().uuidString.lowercased())",
            label: label,
            brand: brand,
            last4: last4,
            expiry: expiry,
            isPrimary: isPrimary || paymentMethods.isEmpty
        )

        paymentMethods.insert(method, at: 0)
        BrandHaptics.notificationSuccess()
    }

    func deletePaymentMethod(id: String) {
        let deletedWasPrimary = paymentMethods.first(where: { $0.id == id })?.isPrimary == true
        paymentMethods.removeAll { $0.id == id }

        if deletedWasPrimary, let first = paymentMethods.first {
            setPrimaryPaymentMethod(id: first.id)
        }
    }

    func setPrimaryPaymentMethod(id: String) {
        paymentMethods = paymentMethods.map { method in
            StoredPaymentMethod(
                id: method.id,
                label: method.label,
                brand: method.brand,
                last4: method.last4,
                expiry: method.expiry,
                isPrimary: method.id == id
            )
        }
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        Self.saveValue(value, key: Self.storageKey(key, userId: currentUser?.id))
    }

    private func persistNavigationPath(_ path: NavigationPath, for tab: AppTab) {
        let persistedKey = Self.storageKey(Self.navigationStorageKey(for: tab), userId: currentUser?.id)
        guard let codable = path.codable,
              let data = try? encoder.encode(codable) else {
            defaults.removeObject(forKey: persistedKey)
            return
        }
        defaults.set(data, forKey: persistedKey)
    }

    private static func storageKey(_ key: String, userId: String?) -> String {
        guard let userId else { return key }
        return "\(key).user.\(userId)"
    }

    private static func navigationStorageKey(for tab: AppTab) -> String {
        "\(StorageKey.navigationPath).\(tab.rawValue)"
    }

    private static func bootstrapSensitiveStorageIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: StorageKey.firstLaunchBootstrapComplete) == false else { return }

        defaults.removeObject(forKey: StorageKey.currentUser)
        defaults.removeObject(forKey: StorageKey.authToken)
        defaults.removeObject(forKey: "aurelien.orders")
        defaults.removeObject(forKey: "aurelien.bag")
        KeychainStore.deleteValue(for: StorageKey.authToken)

        defaults.set(true, forKey: StorageKey.firstLaunchBootstrapComplete)
    }

    private static func loadValue<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func saveValue<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func restoreUserFromToken(_ token: String?) -> User? {
        guard let token,
              token.isEmpty == false,
              let payload = DecodedAuthTokenPayload(token: token),
              payload.expirationDate > Date() else {
            return nil
        }

        let fallbackName = payload.email
            .split(separator: "@")
            .first
            .map { String($0).replacingOccurrences(of: ".", with: " ").capitalized }

        return User(
            id: payload.sub,
            name: fallbackName ?? "Client",
            email: payload.email,
            phone: nil,
            isAdmin: payload.isAdmin,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private static func loadNavigationPath(key: String) -> NavigationPath {
        guard let data = UserDefaults.standard.data(forKey: key),
              let representation = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else {
            return NavigationPath()
        }
        return NavigationPath(representation)
    }

    private enum StorageKey {
        static let wishlist = "aurelien.wishlist"
        static let bag = "aurelien.bag"
        static let orders = "aurelien.orders"
        static let recentQueries = "aurelien.recentQueries"
        static let currentUser = "aurelien.currentUser"
        static let authToken = "aurelien.authToken"
        static let notifications = "aurelien.notifications"
        static let savedAddresses = "aurelien.savedAddresses"
        static let paymentMethods = "aurelien.paymentMethods"
        static let selectedTab = "aurelien.selectedTab"
        static let navigationPath = "aurelien.navigationPath"
        static let lastBackgroundTimestamp = "aurelien.lastBackgroundTimestamp"
        static let firstLaunchBootstrapComplete = "aurelien.firstLaunchBootstrapComplete"
        static let catalogProducts = "aurelien.catalog.products"
        static let catalogLastSync = "aurelien.catalog.lastSync"
        static let trendingQueries = "aurelien.trendingQueries"
        static let clientProfile = "aurelien.clientProfile"
        static let profileLastSync = "aurelien.profile.lastSync"
        static let latestCheckoutOrder = "aurelien.latestCheckoutOrder"
        static let selectedCategory = "aurelien.selectedCategory"
        static let selectedBadge = "aurelien.selectedBadge"
        static let selectedPriceBand = "aurelien.selectedPriceBand"
        static let selectedSort = "aurelien.selectedSort"
    }

    // MARK: - Auth Methods
    func login(user: User, token: String) {
        currentUser = user
        authToken = token
        loadSessionPreferences(for: user.id)

        Self.saveValue(user, key: StorageKey.currentUser)

        if token.isEmpty {
            KeychainStore.deleteValue(for: StorageKey.authToken)
        } else {
            KeychainStore.save(token, for: StorageKey.authToken)
        }

        defaults.removeObject(forKey: StorageKey.authToken)

        Task {
            await hydrateAuthenticatedSession(forceRefresh: true)
        }
    }

    private func loadSessionPreferences(for userId: String) {
        recentQueries = Self.loadValue([String].self, key: Self.storageKey(StorageKey.recentQueries, userId: userId)) ?? []
        wishlist = Set(Self.loadValue([String].self, key: Self.storageKey(StorageKey.wishlist, userId: userId)) ?? [])
        bag = Self.loadValue([BagLine].self, key: Self.storageKey(StorageKey.bag, userId: userId)) ?? []
        orders = Self.loadValue([Order].self, key: Self.storageKey(StorageKey.orders, userId: userId)) ?? []
        notifications = Self.loadValue([ClientNotification].self, key: Self.storageKey(StorageKey.notifications, userId: userId)) ?? []
        savedAddresses = Self.loadValue([SavedAddress].self, key: Self.storageKey(StorageKey.savedAddresses, userId: userId)) ?? []
        paymentMethods = Self.loadValue([StoredPaymentMethod].self, key: Self.storageKey(StorageKey.paymentMethods, userId: userId)) ?? []
        profile = Self.loadValue(ClientProfile.self, key: Self.storageKey(StorageKey.clientProfile, userId: userId))
            ?? Self.defaultProfile(for: currentUser)
        latestCheckoutOrder = Self.loadValue(Order.self, key: Self.storageKey(StorageKey.latestCheckoutOrder, userId: userId))
        selectedCategory = Self.loadValue(ProductCategory.self, key: Self.storageKey(StorageKey.selectedCategory, userId: userId))
        selectedBadge = Self.loadValue(ProductBadge.self, key: Self.storageKey(StorageKey.selectedBadge, userId: userId))
        selectedPriceBand = Self.loadValue(PriceBand.self, key: Self.storageKey(StorageKey.selectedPriceBand, userId: userId))
        selectedSort = Self.loadValue(SortOption.self, key: Self.storageKey(StorageKey.selectedSort, userId: userId)) ?? .featured
        restoreNavigationState()
    }

    func hydrateAuthenticatedSession(forceRefresh: Bool = false) async {
        guard let user = currentUser else {
            profile = Self.defaultProfile(for: nil)
            bag = []
            orders = []
            return
        }

        do {
            if products.isEmpty || forceRefresh {
                _ = try await loadCatalog(forceRefresh: forceRefresh)
            }

            async let remoteProfile = APIService.shared.fetchClientProfile(userId: user.id)
            async let remoteOrders = APIService.shared.fetchUserOrders(userId: user.id)
            async let remoteCart = APIService.shared.fetchCart(userId: user.id)

            profile = try await remoteProfile
            orders = try await remoteOrders
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            applyRemoteCart(try await remoteCart)
        } catch {
            print("Failed to hydrate authenticated session: \(error)")
        }
    }

    func logout() {
        currentUser = nil
        authToken = nil
        orders = []
        recentQueries = []
        wishlist = []
        bag = []
        notifications = []
        savedAddresses = []
        paymentMethods = []
        profile = Self.defaultProfile(for: nil)
        latestCheckoutOrder = nil
        selectedCategory = nil
        selectedBadge = nil
        selectedPriceBand = nil
        selectedSort = .featured
        activeSheet = nil
        homeNavigationPath = NavigationPath()
        discoverNavigationPath = NavigationPath()
        shopNavigationPath = NavigationPath()
        bagNavigationPath = NavigationPath()
        accountNavigationPath = NavigationPath()

        defaults.removeObject(forKey: StorageKey.currentUser)
        defaults.removeObject(forKey: StorageKey.authToken)
        KeychainStore.deleteValue(for: StorageKey.authToken)
        defaults.removeObject(forKey: StorageKey.selectedTab)
    }

    // MARK: - App Lifecycle
    func handleAppDidEnterBackground() {
        defaults.set(Date().timeIntervalSince1970, forKey: StorageKey.lastBackgroundTimestamp)
        if let currentUser {
            Self.saveValue(currentUser, key: StorageKey.currentUser)
        }
        if let authToken, authToken.isEmpty == false {
            KeychainStore.save(authToken, for: StorageKey.authToken)
        }
        persist(navigationPath, key: StorageKey.navigationPath)
        persistNavigationPath(homeNavigationPath, for: .home)
        persistNavigationPath(discoverNavigationPath, for: .discover)
        persistNavigationPath(shopNavigationPath, for: .shop)
        persistNavigationPath(bagNavigationPath, for: .bag)
        persistNavigationPath(accountNavigationPath, for: .account)
        APIService.shared.cancelAllRequests()
    }

    func handleAppDidBecomeActive() {
        let backgroundTime = defaults.double(forKey: StorageKey.lastBackgroundTimestamp)
        guard backgroundTime > 0 else { return }

        let elapsed = Date().timeIntervalSince1970 - backgroundTime
        Task {
            await refreshCatalogFromBackend(forceRefresh: elapsed > 60 * 10)
            await refreshProfileFromBackend(forceRefresh: elapsed > 60 * 10)
        }

        if elapsed > 60 * 60 * 12 {
            sendSmartNotification(
                kind: .recommendation,
                title: "Welcome back. Your discover feed is ready.",
                message: "We prepared fresh outfit recommendations and updated limited drops while you were away.",
                emphasis: "New feed refresh",
                actionTitle: "Open Discover",
                destination: .discover
            )
        }
    }

    // MARK: - Smart Notifications
    func sendSmartNotification(
        kind: ClientNotificationKind,
        title: String,
        message: String,
        emphasis: String? = nil,
        actionTitle: String? = nil,
        destination: NotificationDestination? = nil
    ) {
        let notification = ClientNotification(
            id: "notification-\(UUID().uuidString.lowercased())",
            kind: kind,
            title: title,
            message: message,
            timestamp: "Just now",
            emphasis: emphasis,
            actionTitle: actionTitle,
            destination: destination,
            isRead: false
        )
        notifications.insert(notification, at: 0)
        if notifications.count > 80 {
            notifications = Array(notifications.prefix(80))
        }
    }
    
    // MARK: - Backend Sync
    private func applyRemoteCart(_ cart: Cart) {
        let mappedLines = cart.items.compactMap { item -> BagLine? in
            guard let product = products.first(where: { $0.id == item.productId }) else {
                return nil
            }

            let resolvedSize = item.size ?? product.sizes.first ?? "Not specified"
            let resolvedColorName = item.color ?? product.colors.first?.name ?? "Not specified"
            let resolvedColor = product.colors.first(where: { $0.name.caseInsensitiveCompare(resolvedColorName) == .orderedSame })
                ?? Colorway(name: resolvedColorName, hex: Colorway.hex(for: resolvedColorName))

            return BagLine(
                id: item.id,
                product: product,
                size: resolvedSize,
                color: resolvedColor,
                quantity: item.quantity
            )
        }

        bag = mappedLines
    }

    func refreshCartFromBackend() async {
        guard let userId = currentUser?.id else {
            bag = []
            return
        }

        do {
            let cart = try await APIService.shared.fetchCart(userId: userId)
            applyRemoteCart(cart)
        } catch {
            print("Failed to refresh cart: \(error)")
        }
    }

    func addCartLine(product: Product, size: String, color: Colorway) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.unauthorized("Please sign in to manage your bag.")
        }

        let requestedQuantity = quantityForCartLine(productID: product.id, size: size, color: color.name) + 1
        try validateCartAvailability(product: product, requestedQuantity: requestedQuantity)

        let cart = try await APIService.shared.addToCart(
            userId: userId,
            productId: product.id,
            size: size,
            color: color.name,
            quantity: requestedQuantity
        )
        applyRemoteCart(cart)
    }

    func updateCartLineQuantity(_ line: BagLine, quantity: Int) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.unauthorized("Please sign in to manage your bag.")
        }

        if quantity <= 0 {
            let cart = try await APIService.shared.removeFromCart(
                userId: userId,
                productId: line.product.id,
                size: line.size,
                color: line.color.name
            )
            applyRemoteCart(cart)
            return
        }

        try validateCartAvailability(product: line.product, requestedQuantity: quantity)

        let cart = try await APIService.shared.updateCartItem(
            userId: userId,
            productId: line.product.id,
            size: line.size,
            color: line.color.name,
            quantity: quantity
        )
        applyRemoteCart(cart)
    }

    private func validateCartAvailability(product: Product, requestedQuantity: Int) throws {
        guard product.isInStock else {
            throw APIError.httpError(409, "\(product.name) is out of stock.")
        }

        if let availableQuantity = product.resolvedInventoryCount,
           requestedQuantity > availableQuantity {
            throw APIError.httpError(
                409,
                "Only \(availableQuantity) \(availableQuantity == 1 ? "piece" : "pieces") of \(product.name) are available."
            )
        }
    }

    func removeCartLine(_ line: BagLine) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.unauthorized("Please sign in to manage your bag.")
        }

        let cart = try await APIService.shared.removeFromCart(
            userId: userId,
            productId: line.product.id,
            size: line.size,
            color: line.color.name
        )
        applyRemoteCart(cart)
    }

    func clearCartFromBackend() async throws {
        guard let userId = currentUser?.id else {
            bag = []
            return
        }

        let cart = try await APIService.shared.clearCart(userId: userId)
        applyRemoteCart(cart)
    }

    private func quantityForCartLine(productID: String, size: String, color: String) -> Int {
        bag.first(where: {
            $0.product.id == productID &&
            $0.size == size &&
            $0.color.name.caseInsensitiveCompare(color) == .orderedSame
        })?.quantity ?? 0
    }

    @discardableResult
    func loadCatalog(forceRefresh: Bool = false) async throws -> [Product] {
        if !forceRefresh, !products.isEmpty {
            return products
        }

        let fetched = try await APIService.shared.fetchProducts()
            .filter { $0.isValid && !$0.isExcluded }

        products = fetched
        return fetched
    }

    func refreshCatalogFromBackend(forceRefresh: Bool = false) async {
        do {
            _ = try await loadCatalog(forceRefresh: forceRefresh)
        } catch {
            print("Failed to refresh catalog: \(error)")
        }
    }

    func refreshProfileFromBackend(forceRefresh: Bool = false) async {
        guard let user = currentUser else {
            profile = Self.defaultProfile(for: nil)
            return
        }

        do {
            profile = try await APIService.shared.fetchClientProfile(userId: user.id)
        } catch {
            if profile.email.isEmpty {
                profile = Self.defaultProfile(for: user)
            }
            print("Failed to refresh profile: \(error)")
        }
    }
    
    // MARK: - Admin Methods
    func fetchAdminData() async {
        guard isAdmin else { return }
        
        async let usersTask = APIService.shared.fetchUsers()
        async let ordersTask = APIService.shared.fetchOrders()
        async let productsTask = APIService.shared.fetchProducts()
        async let analyticsTask = APIService.shared.fetchAnalytics()

        adminUsers = (try? await usersTask) ?? adminUsers
        adminOrders = (try? await ordersTask) ?? adminOrders
        adminProducts = (try? await productsTask) ?? adminProducts
        analytics = try? await analyticsTask
    }

    @discardableResult
    func createAdminProduct(_ product: Product) async throws -> Product {
        guard isAdmin else {
            throw APIError.unauthorized("Only administrator accounts can add products.")
        }

        let created = try await APIService.shared.createProduct(product)
        products.removeAll { $0.id == created.id }
        products.insert(created, at: 0)
        adminProducts.removeAll { $0.id == created.id }
        adminProducts.insert(created, at: 0)
        return created
    }

    @discardableResult
    func updateAdminProduct(_ product: Product) async throws -> Product {
        guard isAdmin else {
            throw APIError.unauthorized("Only administrator accounts can edit products.")
        }

        let updated = try await APIService.shared.updateProduct(product)
        replaceProduct(updated)
        return updated
    }

    func deleteAdminProduct(id: String) async throws {
        guard isAdmin else {
            throw APIError.unauthorized("Only administrator accounts can delete products.")
        }

        try await APIService.shared.deleteProduct(id: id)
        products.removeAll { $0.id == id }
        adminProducts.removeAll { $0.id == id }
        wishlist.remove(id)
        bag.removeAll { $0.product.id == id }
    }

    @discardableResult
    func updateAdminOrderStatus(id: String, status: OrderStatus) async throws -> Order {
        guard isAdmin else {
            throw APIError.unauthorized("Only administrator accounts can update order status.")
        }

        let updated = try await APIService.shared.updateOrderStatus(id: id, status: status)
        replaceOrder(updated)
        await refreshCatalogFromBackend(forceRefresh: true)
        return updated
    }

    private func replaceProduct(_ product: Product) {
        replaceProduct(product, in: &products)
        replaceProduct(product, in: &adminProducts)

        bag = bag.compactMap { line in
            guard line.product.id == product.id else { return line }
            guard product.isInStock else { return nil }
            let cappedQuantity = min(line.quantity, product.resolvedInventoryCount ?? line.quantity)
            return BagLine(
                id: line.id,
                product: product,
                size: line.size,
                color: line.color,
                quantity: cappedQuantity
            )
        }
    }

    private func replaceProduct(_ product: Product, in products: inout [Product]) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.insert(product, at: 0)
        }
    }

    private func replaceOrder(_ order: Order) {
        replaceOrder(order, in: &orders)
        replaceOrder(order, in: &adminOrders)
    }

    private func replaceOrder(_ order: Order, in orders: inout [Order]) {
        if let index = orders.firstIndex(where: { $0.id == order.id }) {
            orders[index] = order
        } else {
            orders.insert(order, at: 0)
        }
    }

    private static var defaultBag: [BagLine] {
        []
    }

    private var preferredCategories: [ProductCategory] {
        var counts: [ProductCategory: Int] = [:]

        for product in wishlistedProducts {
            counts[product.category, default: 0] += 2
        }

        for line in bag {
            counts[line.product.category, default: 0] += 1
        }

        let sorted = counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.title < rhs.key.title
                }
                return lhs.value > rhs.value
            }
            .map(\.key)

        return sorted.isEmpty ? storeDefaultCategories : sorted
    }

    private func appendNotification(_ notification: ClientNotification) {
        notifications.insert(notification, at: 0)
    }

    private var storeDefaultCategories: [ProductCategory] {
        [.jackets, .suits, .sneakers]
    }

    private static func defaultProfile(for user: User?) -> ClientProfile {
        guard let user else {
            return AppDefaults.guestProfile
        }

        return ClientProfile(
            name: user.name,
            email: user.email,
            tier: user.isAdmin ? "Administrator" : "Member",
            city: "Cairo",
            note: "Manage your account preferences and order activity."
        )
    }

    private static func deriveTrendingQueries(from products: [Product]) -> [String] {
        let categoryQueries = products
            .map { $0.category.title }
            .uniqued(by: \.self)
            .prefix(5)
        if categoryQueries.isEmpty == false {
            return Array(categoryQueries)
        }
        return []
    }
}

private extension Array {
    func uniqued<Value: Hashable>(by keyPath: KeyPath<Element, Value>) -> [Element] {
        var seen = Set<Value>()
        return filter { element in
            let value = element[keyPath: keyPath]
            return seen.insert(value).inserted
        }
    }
}

struct DecodedAuthTokenPayload: Decodable {
    let sub: String
    let email: String
    let isAdmin: Bool
    let exp: TimeInterval

    var expirationDate: Date {
        if exp > 10_000_000_000 {
            return Date(timeIntervalSince1970: exp / 1000)
        }
        return Date(timeIntervalSince1970: exp)
    }

    init?(token: String) {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Self.base64URLDecodedData(String(parts.count >= 3 ? parts[1] : parts[0])),
              let payload = try? JSONDecoder().decode(Self.self, from: payloadData) else {
            return nil
        }

        self = payload
    }

    private static func base64URLDecodedData(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }

        return Data(base64Encoded: base64)
    }
}

private enum KeychainStore {
    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func value(for key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func deleteValue(for key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.shereenmagdy.aurelien",
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}
