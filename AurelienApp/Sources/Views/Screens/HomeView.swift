import SwiftUI

struct HomeView: View {
    @Environment(AurelienStore.self) private var store
    @Binding var selectedTab: AppTab

    @State private var showMenuSheet = false
    @State private var showAddressSheet = false
    @State private var showSearchSheet = false
    @State private var activeHeroIndex = 0
    @State private var homeContent: CatalogHomeContent?
    @State private var homeCollections: [CollectionFeature] = []

    @SceneStorage("home.selectedAddress") private var selectedAddressID: String?
    @SceneStorage("home.didLoadCatalog") private var didLoadCatalog = false

    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var loadError: String?

    private var selectedAddress: SavedAddress? {
        if let selectedAddressID,
           let selected = store.savedAddresses.first(where: { $0.id == selectedAddressID }) {
            return selected
        }
        return store.primaryAddress
    }

    private var visibleProducts: [Product] {
        store.products.filter { $0.isValid && !$0.isExcluded }
    }

    private var newArrivals: [Product] {
        Array(visibleProducts.prefix(8))
    }

    private var trendingNow: [Product] {
        Array(visibleProducts.shuffled().prefix(8))
    }

    private var featuredProducts: [Product] {
        let prioritized = visibleProducts.sorted { lhs, rhs in
            if lhs.featured == rhs.featured {
                return lhs.price > rhs.price
            }
            return lhs.featured && !rhs.featured
        }
        return Array(prioritized.prefix(8))
    }

    private var bestSellers: [Product] {
        let prioritized = visibleProducts.filter { $0.badge == .bestselling || $0.featured }
        return Array((prioritized.isEmpty ? featuredProducts : prioritized).prefix(4))
    }

    private var personalizedProducts: [Product] {
        let affinityCategories = Set(store.wishlistedProducts.map(\.category) + store.bag.map { $0.product.category })
        let excludedIDs = Set(store.wishlistedProducts.map(\.id) + store.bag.map { $0.product.id })
        let scoped = visibleProducts.filter { product in
            !excludedIDs.contains(product.id) && (affinityCategories.isEmpty || affinityCategories.contains(product.category))
        }

        if scoped.isEmpty {
            return Array(featuredProducts.prefix(6))
        }
        return Array(scoped.prefix(6))
    }

    private var personalizedTitle: String {
        if store.wishlistedProducts.isEmpty && store.bag.isEmpty {
            return "Picked for your first order."
        }
        return "Picked from your saved pieces and bag."
    }

    private var lookbookChapters: [LookbookChapter] {
        homeCollections.enumerated().map { index, collection in
            let matchingProducts = visibleProducts.filter { $0.category == collection.category }
            return LookbookChapter(
                id: "lookbook-\(collection.category.rawValue)",
                chapter: "Chapter \(index + 1)",
                title: "\(collection.category.title) Edit",
                subtitle: collection.subtitle,
                description: matchingProducts.first?.summary ?? "Fresh picks from the live catalog.",
                imageName: matchingProducts.first?.heroImageName ?? collection.category.heroImageName,
                category: collection.category,
                featuredProductIDs: matchingProducts.prefix(4).map(\.id)
            )
        }
    }

    private var categoryShortcuts: [HomeCategoryShortcut] {
        [
            .init(title: "Jackets", category: .jackets, symbol: "hanger"),
            .init(title: "Coats", category: .coats, symbol: "wind"),
            .init(title: "Suits", category: .suits, symbol: "person.crop.rectangle"),
            .init(title: "Shirts", category: .shirts, symbol: "tshirt"),
            .init(title: "Denim", category: .denim, symbol: "scissors"),
            .init(title: "Korean", category: .korean, symbol: "star"),
            .init(title: "Baggy", category: .jeans, symbol: "bag"),
            .init(title: "Footwear", category: .footwear, symbol: "shoeprints.fill"),
            .init(title: "Accessories", category: .accessories, symbol: "eyeglasses")
        ]
    }

    private var heroStories: [HomeHeroStory] {
        guard let homeContent else {
            return []
        }

        return homeContent.heroStories.enumerated().map { index, story in
            HomeHeroStory(
                id: story.id,
                eyebrow: story.eyebrow,
                title: story.title,
                subtitle: story.subtitle,
                detail: story.detail,
                imageName: story.imageName,
                buttonTitle: story.buttonTitle,
                action: index == 1 ? openDiscover : openShop
            )
        }
    }

    private var marketplaceSignals: [HomeMarketplaceSignal] {
        [
            .init(id: "signal-delivery", value: "1-2h", label: "Cairo dispatch"),
            .init(id: "signal-catalog", value: "\(visibleProducts.count)", label: "Live products"),
            .init(id: "signal-support", value: "24/7", label: "Client support")
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let viewport = PhoneViewport(width: proxy.size.width)
            let topInset = proxy.safeAreaInsets.top

            ZStack {
                AmbientBackdrop()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                        HomeTopHeader(
                            topInset: topInset,
                            openMenu: { showMenuSheet = true },
                            bagCount: store.bagCount,
                            openBag: openBag
                        )

                        commerceCommandDeck

                        if let loadError {
                            HomeInlineErrorBanner(
                                message: loadError,
                                retry: { Task { await refreshContent() } }
                            )
                        }

                        commerceHeroShowcase

                        marketplacePulseStrip

                        categoryStrip

                        commerceProductShelf(
                            eyebrow: "Recommended",
                            title: personalizedTitle,
                            copy: "Fresh pieces from the live catalog, sorted for quicker shopping.",
                            products: personalizedProducts
                        )

                        featuredCampaignSection

                        commerceProductGrid(
                            eyebrow: "Best Sellers",
                            title: "Most wanted pieces this week.",
                            copy: "Compare the products customers are moving toward first.",
                            products: bestSellers
                        )

                        commerceProductShelf(
                            eyebrow: "Trending Now",
                            title: "Pieces getting attention now.",
                            copy: "Swipe through current interest without leaving the home feed.",
                            products: trendingNow
                        )

                        commerceProductGrid(
                            eyebrow: "New Arrivals",
                            title: "Latest products just added.",
                            copy: "New catalog additions ready to view, save, or add to bag.",
                            products: newArrivals
                        )

                        if homeCollections.isEmpty {
                            EmptyStatePanel(
                                title: "Categories are unavailable",
                                copy: "The app could not load category highlights. Open shop to browse all products.",
                                buttonTitle: "Browse Shop"
                            ) {
                                openShop()
                            }
                        } else {
                            categoryGrid
                        }

                        NavigationLink(value: AppRoute.stylist) {
                            stylistCard
                        }
                        .buttonStyle(.plain)

                        lookbookStrip

                        Color.clear
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, viewport.bottomPadding)
                }
                .overlay {
                    if isLoading {
                        HomeLoadingOverlay()
                    }
                }
                .refreshable {
                    await refreshContent()
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showMenuSheet) {
            HomeMenuSheet(selectedTab: $selectedTab)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(BrandPalette.backgroundWarm)
        }
        .sheet(isPresented: $showAddressSheet) {
            AddressSelectionSheet(
                addresses: store.savedAddresses,
                selectedAddressID: Binding(
                    get: { selectedAddressID },
                    set: { selectedAddressID = $0 }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(BrandPalette.backgroundWarm)
        }
        .sheet(isPresented: $showSearchSheet) {
            NavigationStack {
                SearchView()
            }
        }
        .task {
            if selectedAddressID == nil {
                selectedAddressID = store.primaryAddress?.id ?? store.savedAddresses.first?.id
            }

            if visibleProducts.isEmpty == false {
                if homeContent != nil, homeCollections.isEmpty == false {
                    didLoadCatalog = true
                    isLoading = false
                    return
                }
            }

            if didLoadCatalog, visibleProducts.isEmpty == false, homeContent != nil, homeCollections.isEmpty == false {
                isLoading = false
                return
            }

            await refreshContent(showBlockingLoader: visibleProducts.isEmpty)
        }
    }

    private var curatedBrowseCard: some View {
        Button(action: openShop) {
            VStack(alignment: .leading, spacing: 14) {
                Text("CURATED BROWSE")
                    .font(BrandFont.mobileCaption())
                    .tracking(3)
                    .foregroundStyle(BrandPalette.gold)

                Text("Full Shop")
                    .font(BrandFont.serif(24, relativeTo: .title2))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("\(visibleProducts.count) products · \(store.bagCount) in bag")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                HStack(spacing: 10) {
                    Capsule()
                        .fill(BrandPalette.surfaceRaised)
                        .frame(height: 28)
                        .overlay(
                            Text("Featured")
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(BrandPalette.textPrimary)
                        )

                    Spacer()

                    Image(systemName: "sparkles")
                        .foregroundStyle(BrandPalette.gold)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.sheet, tone: .gold, material: true)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private var categoryStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandSectionHeader(
                eyebrow: "Categories",
                title: "Shop by department.",
                copy: "Start with the category you want, then filter inside Shop.",
                actionTitle: "Browse Shop"
            ) {
                openShop()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(categoryShortcuts) { item in
                    Button {
                        openCategory(item.category)
                    } label: {
                        HomeCategoryShortcutTile(item: item)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private var commerceCommandDeck: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BOUTIQUE")
                        .font(BrandFont.mobileCaption())
                        .tracking(2.6)
                        .foregroundStyle(BrandPalette.gold)

                    Text("Luxury menswear, ready now.")
                        .font(BrandFont.serif(24, relativeTo: .title2))
                        .foregroundStyle(BrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(visibleProducts.count)")
                        .font(BrandFont.serif(24, relativeTo: .title2))
                        .foregroundStyle(BrandPalette.textPrimary)
                    Text("Products")
                        .font(BrandFont.mobileCaption())
                        .tracking(1.8)
                        .foregroundStyle(BrandPalette.textSecondary)
                }
            }

            HomeSearchBar(action: openSearch)

            HStack(spacing: 12) {
                LocationBar(city: selectedAddress?.city.rawValue ?? "Cairo", action: { showAddressSheet = true })

                Button(action: openShop) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shop")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)
                        Text("All products")
                            .font(.caption)
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    HomeQuickLinkChip(title: "New In", systemImage: "sparkles", action: openShop)
                    HomeQuickLinkChip(title: "Wishlist", systemImage: "heart", action: { openRoute(.wishlist) })
                    HomeQuickLinkChip(title: "Alerts", systemImage: "bell", action: { openRoute(.notifications) })
                    HomeQuickLinkChip(title: "Stylist", systemImage: "wand.and.stars", action: { openRoute(.stylist) })
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(18)
        .brandPanel(cornerRadius: BrandRadius.sheet, tone: .shadow, material: true)
    }

    @ViewBuilder
    private var commerceHeroShowcase: some View {
        if heroStories.isEmpty {
            if let featuredProduct = featuredProducts.first {
                VStack(alignment: .leading, spacing: 12) {
                    BrandSectionHeader(
                        eyebrow: "Featured",
                        title: "Featured from the live catalog.",
                        copy: "Open the product, save it, or add it to your bag."
                    )

                    NavigationLink(value: featuredProduct) {
                        HomeFeaturedProductSpotlight(product: featuredProduct)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            } else {
                EmptyStatePanel(
                    title: "Featured content unavailable",
                    copy: "Open the full shop to continue browsing the live catalog while home content refreshes.",
                    buttonTitle: "Browse Shop"
                ) {
                    openShop()
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("FEATURED")
                        .font(BrandFont.mobileCaption())
                        .tracking(3)
                        .foregroundStyle(BrandPalette.gold)

                    Spacer()

                    Text("Live home content")
                        .font(BrandFont.mobileCaption2())
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                heroCarousel
            }
        }
    }

    @ViewBuilder
    private var featuredCampaignSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandSectionHeader(
                eyebrow: "Campaigns",
                title: "Campaigns worth opening.",
                copy: "Promotions and category edits stay close to the products they sell."
            )

            if homeContent?.promotions.first != nil {
                promotionalBanner
                    .frame(minHeight: 150)
            }

            if homeCollections.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(homeCollections.prefix(3)) { collection in
                            Button {
                                openCategory(collection.category)
                            } label: {
                                HomeCampaignSummaryCard(collection: collection)
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            } else if homeContent?.promotions.first == nil {
                curatedBrowseCard
            }
        }
    }

    @ViewBuilder
    private func commerceProductShelf(
        eyebrow: String,
        title: String,
        copy: String,
        products: [Product]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandSectionHeader(
                eyebrow: eyebrow,
                title: title,
                copy: copy,
                actionTitle: "See All"
            ) {
                openShop()
            }

            if products.isEmpty {
                EmptyStatePanel(
                    title: "Products unavailable",
                    copy: "This section will populate as soon as matching catalog items are available.",
                    buttonTitle: "Browse Shop"
                ) {
                    openShop()
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(products) { product in
                        ProductCardView(product: product, style: .grid, compact: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func commerceProductGrid(
        eyebrow: String,
        title: String,
        copy: String,
        products: [Product]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandSectionHeader(
                eyebrow: eyebrow,
                title: title,
                copy: copy,
                actionTitle: "See All"
            ) {
                openShop()
            }

            if products.isEmpty {
                EmptyStatePanel(
                    title: "Products unavailable",
                    copy: "There are no items to compare here right now. Open the full shop instead.",
                    buttonTitle: "Browse Shop"
                ) {
                    openShop()
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(products) { product in
                        ProductCardView(product: product, style: .grid, compact: false)
                    }
                }
            }
        }
    }

    private func campaignRail(cardWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                HomeCampaignCard(
                    eyebrow: "New Season",
                    title: "Quiet outerwear.",
                    subtitle: "Leather, wool, and tailored movement.",
                    imageName: "Jackets & Coats.jpg",
                    width: cardWidth,
                    backgroundTone: .shadow,
                    buttonTitle: "Shop Now",
                    action: { openCategory(.jackets) }
                )

                HomeCampaignCard(
                    eyebrow: "Private Client",
                    title: "Evening tailoring.",
                    subtitle: "Warm essentials in a calmer editorial card.",
                    imageName: "Suits.jpg",
                    width: cardWidth,
                    backgroundTone: .chrome,
                    buttonTitle: "Explore",
                    action: openDiscover
                )
            }
        }
    }

    private func productRail(eyebrow: String, title: String, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: eyebrow,
                title: title,
                copy: nil,
                actionTitle: "See All"
            ) {
                openShop()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(products) { product in
                        ProductCardView(product: product, style: .list)
                            .frame(width: UIScreen.main.bounds.width - 32)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    @ViewBuilder
    private var promotionalBanner: some View {
        if let promotion = homeContent?.promotions.first {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BrandPalette.gold, BrandPalette.goldWarm, BrandPalette.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text(promotion.title)
                        .font(BrandFont.serif(28, relativeTo: .title2))
                        .foregroundStyle(BrandPalette.accentForeground)

                    Text(promotion.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.accentForeground.opacity(0.82))

                    Button(action: openShop) {
                        Text("Explore")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(BrandPalette.surfaceRaised.opacity(0.72))
                                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
                .padding(20)
            }
            .frame(height: 150)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Departments",
                title: "Shop by category.",
                copy: "Open the category and continue shopping in the live catalog."
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(homeCollections) { collection in
                    Button {
                        openCategory(collection.category)
                    } label: {
                        HomeCategoryBlock(collection: collection)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private var stylistCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.semibold))
                .foregroundStyle(BrandPalette.gold)
                .frame(width: 52, height: 52)
                .background(BrandPalette.goldDim, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Personal Stylist")
                    .font(BrandFont.serif(22, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Get outfit recommendations")
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(BrandPalette.gold)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(BrandPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
    }

    private var lookbookStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Lookbook",
                title: "Editorial chapters from BOUTIQUE.",
                copy: "Browse the story, then shop the pieces inside each edit."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if lookbookChapters.isEmpty {
                        EmptyStatePanel(
                            title: "No editorial chapters available",
                            copy: "Editorial chapters appear automatically when qualifying catalog content is published.",
                            buttonTitle: "Open Shop"
                        ) {
                            openShop()
                        }
                    } else {
                        ForEach(lookbookChapters.prefix(3)) { chapter in
                            Button {
                                openCategory(chapter.category)
                            } label: {
                                HomeLookbookCard(chapter: chapter)
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    private func openSearch() {
        BrandHaptics.selection()
        showSearchSheet = true
    }

    private func openShop() {
        store.selectedCategory = nil
        store.selectedPriceBand = nil
        store.selectedSort = .featured
        BrandHaptics.selection()
        selectedTab = .shop
    }

    private func openDiscover() {
        BrandHaptics.selection()
        selectedTab = .discover
    }

    private func openBag() {
        BrandHaptics.selection()
        selectedTab = .bag
    }

    private func openCategory(_ category: ProductCategory) {
        store.selectedCategory = category
        store.selectedPriceBand = nil
        store.selectedSort = .featured
        BrandHaptics.selection()
        selectedTab = .shop
    }

    private func openRoute(_ route: AppRoute) {
        BrandHaptics.selection()

        switch route {
        case .bag:
            selectedTab = .bag
        case .discover:
            selectedTab = .discover
        case .home:
            selectedTab = .home
        case .profile:
            selectedTab = .account
        case .wishlist, .notifications, .wallet, .support, .stylist, .legal, .settings, .about, .orders, .login, .admin:
            selectedTab = .account
            store.pushRoute(route)
        case .checkout:
            store.present(.checkout)
        }
    }

    private func refreshContent(showBlockingLoader: Bool = true) async {
        struct LoadTimeout: Error {}

        guard !isRefreshing else { return }
        isRefreshing = true
        if showBlockingLoader {
            isLoading = true
        } else {
            isLoading = false
        }
        defer {
            isRefreshing = false
            isLoading = false
        }

        do {
            _ = try await withThrowingTaskGroup(of: [Product].self) { group in
                group.addTask {
                    try await store.loadCatalog(forceRefresh: true)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(8))
                    throw LoadTimeout()
                }

                guard let value = try await group.next() else {
                    throw LoadTimeout()
                }
                group.cancelAll()
                return value
            }
            didLoadCatalog = true
            homeContent = try await APIService.shared.fetchHomeContent()
            homeCollections = try await APIService.shared.fetchCollections()
            loadError = nil
        } catch is LoadTimeout {
            let timeoutError = URLError(.timedOut)
            let (_, message, suggestion) = AppErrorHandler.categorize(timeoutError)
            loadError = visibleProducts.isEmpty
                ? [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
                : "Unable to refresh right now."
        } catch {
            let (_, message, suggestion) = AppErrorHandler.categorize(error)
            loadError = visibleProducts.isEmpty
                ? [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
                : "Unable to refresh right now."
        }
    }
}

private struct HomeHeroStory {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let detail: String
    let imageName: String
    let buttonTitle: String
    let action: () -> Void
}

private struct HomeMarketplaceSignal: Identifiable {
    let id: String
    let value: String
    let label: String
}

private struct HomeLoadingOverlay: View {
    var body: some View {
        ZStack {
            BrandPalette.background.opacity(0.64)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: BrandPalette.gold))
                    .scaleEffect(1.2)

                Text("Preparing your feed")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                VStack(spacing: 10) {
                    HomeSkeletonBlock(height: 44)
                    HomeSkeletonBlock(height: 180)
                    HomeSkeletonBlock(height: 220)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .brandPanel(cornerRadius: 18, tone: .shadow, material: true)
        }
    }
}

private struct HomeSkeletonBlock: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(BrandPalette.surfaceRaised)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .redacted(reason: .placeholder)
    }
}

private extension HomeView {
    var marketplacePulseStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SERVICE")
                        .font(BrandFont.mobileCaption())
                        .tracking(3)
                        .foregroundStyle(BrandPalette.gold)

                    Text("Operational signals presented with cleaner spacing and faster readability.")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                ForEach(marketplaceSignals) { signal in
                    HomeUtilitySignalCard(signal: signal)
                }
            }
        }
    }

    var heroCarousel: some View {
        VStack(spacing: 12) {
            if heroStories.indices.contains(activeHeroIndex) {
                HomeHeroCard(story: heroStories[activeHeroIndex])
            }

            VStack(spacing: 10) {
                ForEach(Array(heroStories.enumerated()), id: \.element.id) { index, story in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            activeHeroIndex = index
                        }
                    } label: {
                        HomeHeroSelectorRow(
                            title: story.title,
                            eyebrow: story.eyebrow,
                            isSelected: index == activeHeroIndex
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HomeInlineErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(BrandPalette.gold)
                Text("Connection Issue")
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)
            }

            Text(message)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Retry", action: retry)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .frame(minHeight: 44)
        }
        .padding(16)
        .brandPanel(cornerRadius: 16, tone: .chrome, material: true)
    }
}

private struct HomeHeroCard: View {
    let story: HomeHeroStory

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                MediaImage(name: story.imageName)
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()

                LinearGradient(
                    colors: [Color.clear, BrandPalette.textPrimary.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HStack(alignment: .top) {
                    HomeHeroTicket(
                        title: story.eyebrow.uppercased(),
                        subtitle: "Curated Feature"
                    )

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Live")
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)

                        Text("Home Story".uppercased())
                            .font(BrandFont.mobileCaption2())
                            .tracking(2)
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(BrandPalette.background.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                }
                .padding(18)
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: BrandRadius.sheet,
                    bottomLeadingRadius: 30,
                    bottomTrailingRadius: 30,
                    topTrailingRadius: BrandRadius.sheet
                )
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Rectangle()
                        .fill(BrandPalette.gold)
                        .frame(width: 3, height: 84)
                        .clipShape(Capsule(style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(story.title)
                            .font(BrandFont.serif(34, relativeTo: .largeTitle))
                            .foregroundStyle(BrandPalette.textPrimary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(story.subtitle)
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary.opacity(0.92))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(story.detail)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    HomeStoryChip(title: story.eyebrow)
                    HomeStoryChip(title: "Live Catalog")
                    HomeStoryChip(title: "Editorial")
                }

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ready to shop")
                            .font(BrandFont.mobileCaption2())
                            .tracking(1.8)
                            .foregroundStyle(BrandPalette.textMuted)

                        Text("Open the story destination with one action.")
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Button(action: story.action) {
                        HStack(spacing: 8) {
                            Text(story.buttonTitle)
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandPalette.accentForeground)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(BrandPalette.goldGradient, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BrandPalette.surfaceRaised,
                                BrandPalette.surface,
                                BrandPalette.overlay
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .padding(.horizontal, 14)
            .padding(.top, -26)
        }
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.sheet, style: .continuous)
                .fill(BrandPalette.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.sheet, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
        .frame(minHeight: 620)
    }
}

private struct HomeHeroTicket: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BrandFont.mobileCaption())
                .tracking(2.8)
                .foregroundStyle(BrandPalette.gold)

            Text(subtitle)
                .font(BrandFont.mobileCaption2())
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BrandPalette.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct HomeStoryChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(BrandFont.mobileCaption2())
            .foregroundStyle(BrandPalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
    }
}

private struct HomeHeroSelectorRow: View {
    let title: String
    let eyebrow: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(isSelected ? BrandPalette.gold : BrandPalette.hairlineStrong)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(BrandFont.mobileCaption2())
                    .tracking(2)
                    .foregroundStyle(isSelected ? BrandPalette.gold : BrandPalette.textMuted)

                Text(title)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(isSelected ? BrandPalette.textPrimary : BrandPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? BrandPalette.gold : BrandPalette.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? BrandPalette.surfaceRaised : BrandPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? BrandPalette.goldBorder : BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct HomeTopHeader: View {
    let topInset: CGFloat
    let openMenu: () -> Void
    let bagCount: Int
    let openBag: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: openMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                        .foregroundStyle(BrandPalette.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("BOUTIQUE")
                        .font(BrandFont.serif(20, relativeTo: .headline))
                        .fontWeight(.bold)
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("MENSWEAR")
                        .font(.caption2.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    NavigationLink(value: AppRoute.notifications) {
                        Image(systemName: "bell")
                            .font(.headline)
                            .foregroundStyle(BrandPalette.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Button(action: openBag) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bag")
                                .font(.headline)
                                .foregroundStyle(BrandPalette.textPrimary)
                                .frame(width: 44, height: 44)

                            if bagCount > 0 {
                                Text("\(min(bagCount, 99))")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BrandPalette.accentForeground)
                                    .padding(.horizontal, 5)
                                    .frame(height: 18)
                                    .background(BrandPalette.gold, in: Capsule(style: .continuous))
                                    .offset(x: 2, y: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 66)
            .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
        }
        .padding(.horizontal, 2)
        .padding(.top, topInset)
    }
}

private struct HomeQuickLinkChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.gold)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandPalette.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeUtilitySignalCard: View {
    let signal: HomeMarketplaceSignal

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(signal.label.uppercased())
                    .font(BrandFont.mobileCaption())
                    .tracking(1.6)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(signal.value)
                    .font(BrandFont.serif(24, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.textPrimary)
            }

            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(BrandPalette.gold)
                .frame(width: 40, height: 40)
                .background(BrandPalette.goldDim, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .brandPanel(cornerRadius: 20, tone: .chrome, material: true)
    }
}

private struct HomeSearchBar: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BrandPalette.gold)

                Text("Search BOUTIQUE...")
                    .font(.body)
                    .foregroundStyle(BrandPalette.muted)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(BrandPalette.surface, in: RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LocationBar: View {
    let city: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .foregroundStyle(BrandPalette.gold)

                Text("Deliver to \(city)")
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeCampaignCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let imageName: String
    let width: CGFloat
    let backgroundTone: GlassTone
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MediaImage(name: imageName)
                .scaledToFill()
                .frame(width: width, height: 280)
                .clipped()

            LinearGradient(
                colors: [Color.clear, BrandPalette.background.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(BrandPalette.gold)

                Text(title)
                    .font(BrandFont.serif(24, relativeTo: .title3))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(3)

                Button(buttonTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandPalette.gold)
                    .frame(minHeight: 44)
            }
            .padding(18)
        }
        .frame(width: width, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundTone == .chrome ? BrandPalette.surfaceRaised : BrandPalette.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
    }
}

private struct HomeCampaignSummaryCard: View {
    let collection: CollectionFeature

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MediaImage(name: collection.imageName)
                .scaledToFill()
                .frame(width: 260, height: 180)
                .clipped()

            LinearGradient(
                colors: [Color.clear, BrandPalette.background.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(collection.category.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(BrandPalette.gold)

                Text(collection.title)
                    .font(BrandFont.serif(24, relativeTo: .title3))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(collection.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(2)
            }
            .padding(18)
        }
        .frame(width: 260, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
    }
}

private struct HomeFeaturedProductSpotlight: View {
    let product: Product

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MediaImage(name: product.heroImageName)
                .scaledToFill()
                .frame(height: 360)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color.clear, BrandPalette.background.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(product.category.title.uppercased())
                    .font(BrandFont.mobileCaption())
                    .tracking(2.4)
                    .foregroundStyle(BrandPalette.gold)

                Text(product.name)
                    .font(BrandFont.serif(32, relativeTo: .largeTitle))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(product.summary)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary.opacity(0.9))
                    .lineLimit(3)

                HStack(spacing: 16) {
                    Text(BrandFormatter.price(product.price))
                        .font(BrandFont.serif(24, relativeTo: .title2))
                        .foregroundStyle(BrandPalette.gold)

                    if let rating = product.ratingDisplayValue {
                        Label(rating, systemImage: "star.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textPrimary)
                    }
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: BrandRadius.sheet, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.sheet, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
    }
}

private struct HomeCategoryBlock: View {
    let collection: CollectionFeature

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MediaImage(name: collection.imageName)
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()

            LinearGradient(
                colors: [Color.clear, BrandPalette.background.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(collection.title)
                    .font(BrandFont.serif(20, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(collection.subtitle)
                    .font(.caption)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(2)

                Rectangle()
                    .fill(BrandPalette.gold)
                    .frame(width: 32, height: 2)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HomeLookbookCard: View {
    let chapter: LookbookChapter

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MediaImage(name: chapter.imageName)
                .scaledToFill()
                .frame(width: 220, height: 300)
                .clipped()

            LinearGradient(
                colors: [Color.clear, BrandPalette.background.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.chapter)
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(BrandPalette.gold)

                Text(chapter.title)
                    .font(BrandFont.serif(24, relativeTo: .title3))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(chapter.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(2)
            }
            .padding(16)
        }
        .frame(width: 220, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct HomeMenuSheet: View {
    @Binding var selectedTab: AppTab
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button("Home") {
                    selectedTab = .home
                    dismiss()
                }
                .frame(minHeight: 44)

                Button("Discover") {
                    selectedTab = .discover
                    dismiss()
                }
                .frame(minHeight: 44)

                Button("Shop") {
                    selectedTab = .shop
                    dismiss()
                }
                .frame(minHeight: 44)

                Button("Bag") {
                    selectedTab = .bag
                    dismiss()
                }
                .frame(minHeight: 44)

                Button("Account") {
                    selectedTab = .account
                    dismiss()
                }
                .frame(minHeight: 44)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(BrandPalette.gold)
                }
            }
        }
    }
}

private struct AddressSelectionSheet: View {
    let addresses: [SavedAddress]
    @Binding var selectedAddressID: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if addresses.isEmpty {
                    Text("No saved addresses yet")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                } else {
                    ForEach(addresses) { address in
                        Button {
                            selectedAddressID = address.id
                            BrandHaptics.selection()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(address.label)
                                        .foregroundStyle(BrandPalette.textPrimary)

                                    Text(address.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(BrandPalette.textSecondary)
                                }

                                Spacer()

                                if selectedAddressID == address.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BrandPalette.gold)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Delivery Address")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HomeCategoryShortcut: Identifiable {
    let id = UUID()
    let title: String
    let category: ProductCategory
    let symbol: String
}

private struct HomeCategoryShortcutTile: View {
    let item: HomeCategoryShortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                    .fill(BrandPalette.surfaceRaised)

                Image(systemName: item.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandPalette.gold)
            }
            .frame(height: 74)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text("Explore")
                    .font(.caption2.weight(.medium))
                    .tracking(1.4)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(BrandPalette.surface, in: RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}
