import MapKit
import SwiftUI

private enum ColorSystem {
    static let hexMap: [String: UInt] = [
        "black": 0x0A0908,
        "white": 0xFAFAFA,
        "cream": 0xFFF8E7,
        "ivory": 0xFFFFF0,
        "beige": 0xF5F5DC,
        "tan": 0xD2B48C,
        "camel": 0xC19A6B,
        "brown": 0x8B4513,
        "mocha": 0x6F4E37,
        "chocolate": 0x3E2723,
        "navy": 0x1A237E,
        "midnight": 0x263238,
        "blue": 0x2F6DB5,
        "indigo": 0x4B0082,
        "sky": 0x87CEEB,
        "gray": 0x808080,
        "grey": 0x808080,
        "charcoal": 0x36454F,
        "stone": 0x78909C,
        "green": 0x2E7D32,
        "olive": 0x556B2F,
        "sage": 0x9CAF88,
        "sand": 0xC2B280,
        "khaki": 0xBDB76B,
        "gold": 0xC9A86A,
        "silver": 0x9E9E9E,
        "tortoise": 0x5D4037
    ]

    static func color(for name: String) -> Color {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return Color(hex: hexMap[key] ?? 0x0A0908)
    }
}

struct ShopView: View {
    @Environment(AurelienStore.self) private var store

    @AppStorage("shopLayoutMode") private var layoutModeRaw = ShopLayoutMode.grid.rawValue
    @SceneStorage("shop.didLoadCatalog") private var didLoadCatalog = false

    @State private var draftSearch = ""
    @State private var searchText = ""
    @State private var showInlineSearch = false
    @State private var showFilterSheet = false
    @State private var selectedSizes: Set<String> = []
    @State private var selectedColors: Set<String> = []
    @State private var selectedFullScreenIndex = 0
    @State private var showFullScreenCarousel = false
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var didLoadOnce = false
    @State private var boutiques: [ShopBoutique] = []

    private enum ShopLayoutMode: String {
        case grid
        case fullscreen

        var icon: String {
            switch self {
            case .grid:
                return "square.grid.2x2"
            case .fullscreen:
                return "rectangle.portrait"
            }
        }
    }

    private var layoutMode: ShopLayoutMode {
        ShopLayoutMode(rawValue: layoutModeRaw) ?? .grid
    }

    private var sourceProducts: [Product] {
        store.products.filter { $0.isValid && !ProductCardView.excluded.contains($0.name) }
    }

    private var categories: [ProductCategory] {
        sourceProducts.map(\.category).uniqued()
    }

    private var sizes: [String] {
        sourceProducts.flatMap(\.sizes).uniqued().sorted()
    }

    private var colors: [String] {
        sourceProducts.flatMap(\.colors).map(\.name).uniqued().sorted()
    }

    private var displayProducts: [Product] {
        var products = sourceProducts
            .filter { !ProductCardView.excluded.contains($0.name) }
            .filter { store.selectedCategory == nil || $0.category == store.selectedCategory }
            .filter { store.selectedPriceBand == nil || store.selectedPriceBand?.contains($0.price) == true }
            .filter {
                searchText.isEmpty
                || $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
            }
            .filter { selectedSizes.isEmpty || !selectedSizes.isDisjoint(with: Set($0.sizes)) }
            .filter { selectedColors.isEmpty || $0.colors.contains(where: { selectedColors.contains($0.name) }) }

        switch store.selectedSort {
        case .featured:
            products.sort { lhs, rhs in
                if lhs.featured == rhs.featured {
                    return lhs.price > rhs.price
                }
                return lhs.featured && !rhs.featured
            }
        case .newest:
            products.reverse()
        case .priceLowToHigh:
            products.sort { $0.price < $1.price }
        case .priceHighToLow:
            products.sort { $0.price > $1.price }
        }

        return products
    }

    private var shopSignals: [ShopSignal] {
        [
            .init(id: "signal-boutiques", value: "\(boutiques.count)", label: "Boutiques"),
            .init(id: "signal-delivery", value: "Same Day", label: "Cairo & Giza"),
            .init(id: "signal-service", value: "Tracked", label: "Doorstep updates")
        ]
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            ZStack(alignment: .top) {
                shopContent(viewport: viewport)

                if isLoading && sourceProducts.isEmpty {
                    shopLoadingOverlay
                        .padding(.top, 32)
                        .zIndex(1)
                }
            }
        }
        .background(AmbientBackdrop())
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showFilterSheet) {
            ShopFilterSheet(
                categories: categories,
                sizes: sizes,
                colors: colors,
                selectedCategory: Binding(
                    get: { store.selectedCategory },
                    set: { store.selectedCategory = $0 }
                ),
                selectedPriceBand: Binding(
                    get: { store.selectedPriceBand },
                    set: { store.selectedPriceBand = $0 }
                ),
                selectedSort: Binding(
                    get: { store.selectedSort },
                    set: { store.selectedSort = $0 }
                ),
                selectedSizes: $selectedSizes,
                selectedColors: $selectedColors,
                clearAll: clearAllFilters
            )
        }
        .task(id: draftSearch) {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            searchText = draftSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .task {
            guard didLoadOnce == false else { return }
            didLoadOnce = true
            if sourceProducts.isEmpty == false {
                didLoadCatalog = true
                isLoading = false
            } else {
                await loadData(showBlockingLoader: sourceProducts.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $showFullScreenCarousel) {
            FullScreenProductCarousel(
                products: displayProducts,
                selectedIndex: $selectedFullScreenIndex,
                isPresented: $showFullScreenCarousel
            )
        }
    }

    // MARK: - Data Loading & Error Handling
    @MainActor
    private func loadData(showBlockingLoader: Bool = true) async {
        struct LoadTimeout: Error {}

        if showBlockingLoader {
            isLoading = true
        } else {
            isLoading = false
        }
        errorMessage = nil

        do {
            let result = try await withThrowingTaskGroup(of: ShopLoadResult.self) { group in
                group.addTask {
                    async let products = store.loadCatalog(forceRefresh: true)
                    async let remoteBoutiques: [ShopBoutique] = APIService.shared.request("/boutiques")
                    return try await ShopLoadResult(
                        products: products,
                        boutiques: remoteBoutiques
                    )
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

            boutiques = result.boutiques
            didLoadCatalog = true
        } catch is LoadTimeout {
            errorMessage = sourceProducts.isEmpty
                ? "Connection timed out. Check your internet and retry."
                : "Unable to refresh right now."
        } catch {
            let (category, message, suggestion) = AppErrorHandler.categorize(error)
            if sourceProducts.isEmpty {
                errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
            } else {
                errorMessage = "Unable to refresh right now."
            }
            _ = category
        }

        isLoading = false
    }

    private func reloadData() {
        Task { await loadData(showBlockingLoader: sourceProducts.isEmpty) }
    }

    @ViewBuilder
    private func shopContent(viewport: PhoneViewport) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            if let errorMessage, sourceProducts.isEmpty {
                shopErrorState(message: errorMessage)
            } else {
                shopHeroCard

                if showInlineSearch {
                    ShopInlineSearchBar(text: $draftSearch) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            draftSearch = ""
                            searchText = ""
                            showInlineSearch = false
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let errorMessage {
                    InlineShopErrorBanner(message: errorMessage, retry: reloadData)
                }

                categoryStrip
                filterSummary
                shopSignalsStrip
                boutiquesSection

                if sourceProducts.isEmpty && isLoading == false {
                    EmptyStatePanel(
                        title: "No products available",
                        copy: "Inventory sync finished without returning products. Try again in a moment.",
                        buttonTitle: "Retry",
                        action: reloadData
                    )
                } else if displayProducts.isEmpty {
                    EmptyStatePanel(
                        title: "No matching pieces",
                        copy: "Clear one or more filters to widen the collection again.",
                        buttonTitle: "Reset Filters",
                        action: clearAllFilters
                    )
                } else {
                    productSection(viewport: viewport)
                }
            }
        }
        .padding(.horizontal, viewport.horizontalPadding)
        .padding(.top, BrandSpacing.md)
        .padding(.bottom, viewport.bottomPadding + 32)
    }

    private var shopLoadingOverlay: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: BrandPalette.gold))
                .scaleEffect(1.4)
                .accessibilityLabel("Loading shop")
            Text("Loading shop...")
                .font(.headline)
                .foregroundStyle(BrandPalette.sand)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(BrandPalette.background.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func shopErrorState(message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(BrandPalette.gold)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(BrandPalette.textPrimary)
            Button(action: reloadData) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 120)
                    .background(BrandPalette.goldGradient)
                    .foregroundColor(Color.boutCreamTop)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Retry loading shop")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Empty State View
    private struct EmptyStateView: View {
        let icon: String
        let message: String
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(BrandPalette.sand)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(BrandPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .accessibilityElement(children: .combine)
        }
    }

    private struct InlineShopErrorBanner: View {
        let message: String
        let retry: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(BrandPalette.gold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Issue")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(message)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                Spacer(minLength: 0)

                Button("Retry", action: retry)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.gold)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showInlineSearch.toggle()
                }

                if !showInlineSearch {
                    draftSearch = ""
                    searchText = ""
                }

                BrandHaptics.selection()
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BrandPalette.gold)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    layoutModeRaw = layoutMode == .grid ? ShopLayoutMode.fullscreen.rawValue : ShopLayoutMode.grid.rawValue
                }
                BrandHaptics.selection()
            } label: {
                Image(systemName: layoutMode.icon)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(BrandPalette.gold)
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                store.selectedTab = .bag
                BrandHaptics.selection()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: store.bagCount > 0 ? "bag.fill" : "bag")
                        .foregroundStyle(BrandPalette.gold)
                        .frame(width: 44, height: 44)

                    if store.bagCount > 0 {
                        Text("\(min(store.bagCount, 99))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.boutCreamTop)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(BrandPalette.gold, in: Capsule(style: .continuous))
                            .offset(x: 7, y: -2)
                    }
                }
            }

            Button {
                showFilterSheet = true
                BrandHaptics.selection()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(BrandPalette.gold)
            }
        }
    }

    private var shopHeroCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Marketplace Edit".uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(2.4)
                    .foregroundStyle(BrandPalette.textSecondary)

                Text(store.selectedCategory?.title ?? "Shop Boutiques")
                    .font(BrandFont.serif(28, relativeTo: .title2))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("\(displayProducts.count) products · \(boutiques.count) boutique locations")
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(BrandPalette.gold)
                .frame(width: 52, height: 52)
                .background(
                    BrandPalette.goldDim,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .padding(18)
        .brandPanel(cornerRadius: BrandRadius.sheet, tone: .gold, material: true)
    }

    private var shopSignalsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shopSignals) { signal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(signal.value)
                            .font(BrandFont.serif(18, relativeTo: .headline))
                            .foregroundStyle(BrandPalette.textPrimary)

                        Text(signal.label.uppercased())
                            .font(BrandFont.mobileCaption())
                            .tracking(1.4)
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryPill("All", category: nil)

                ForEach(categories, id: \.self) { category in
                    categoryPill(category.title, category: category)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryPill(_ title: String, category: ProductCategory?) -> some View {
        Button {
            store.selectedCategory = category
            BrandHaptics.selection()
        } label: {
            SelectionCapsule(title: title, isSelected: store.selectedCategory == category)
        }
        .buttonStyle(.plain)
    }

    private var filterSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandSectionHeader(
                eyebrow: "Filters",
                title: "Refined browsing.",
                copy: filterCopy,
                actionTitle: hasActiveFilters ? "Clear All" : nil,
                action: hasActiveFilters ? clearAllFilters : nil
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    summaryPill(store.selectedSort.title)

                    if let band = store.selectedPriceBand {
                        summaryPill(band.title)
                    }

                    if !selectedSizes.isEmpty {
                        summaryPill("\(selectedSizes.count) sizes")
                    }

                    if !selectedColors.isEmpty {
                        summaryPill("\(selectedColors.count) colors")
                    }
                }
            }
        }
    }

    private var boutiquesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Boutiques",
                title: "Storefronts with map-ready cards.",
                copy: "Browse boutique locations with map-ready delivery coverage while inventory sync stays connected to the live catalog."
            )

            if boutiques.isEmpty {
                EmptyStatePanel(
                    title: "No boutique locations available",
                    copy: "Boutique coverage will appear here as soon as the network source publishes location data.",
                    buttonTitle: "Retry",
                    action: reloadData
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(boutiques) { boutique in
                            BoutiqueMapCard(boutique: boutique)
                                .frame(width: 286)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var filterCopy: String {
        if let category = store.selectedCategory {
            return "Browsing \(category.title.lowercased()) - \(displayProducts.count) results."
        }

        if hasActiveFilters {
            return "\(displayProducts.count) products match your filters."
        }

        return layoutMode == .fullscreen
            ? "Full-screen feed active. Tap any card to open the immersive carousel."
            : "Use the layout button in the toolbar to switch to full-screen feed mode."
    }

    private var hasActiveFilters: Bool {
        store.selectedCategory != nil
            || store.selectedPriceBand != nil
            || !selectedSizes.isEmpty
            || !selectedColors.isEmpty
            || !searchText.isEmpty
            || store.selectedSort != .featured
    }

    private func summaryPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandPalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private func productSection(viewport: PhoneViewport) -> some View {
        if displayProducts.isEmpty {
            EmptyStatePanel(
                title: "No matching pieces",
                copy: "Clear one or more filters to widen the collection again.",
                buttonTitle: "Reset Filters",
                action: clearAllFilters
            )
        } else if layoutMode == .fullscreen {
            fullScreenFeed(viewport: viewport)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(displayProducts) { product in
                    ProductCardView(
                        product: product,
                        style: .grid,
                        compact: false
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func fullScreenFeed(viewport: PhoneViewport) -> some View {
        LazyVStack(spacing: 20) {
            ForEach(Array(displayProducts.enumerated()), id: \.element.id) { index, product in
                Button {
                    selectedFullScreenIndex = index
                    showFullScreenCarousel = true
                    BrandHaptics.selection()
                } label: {
                    ProductCardView(product: product, style: .fullscreen)
                        .frame(width: viewport.width, height: max(540, viewport.width * 1.25))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func clearAllFilters() {
        store.selectedCategory = nil
        store.selectedPriceBand = nil
        store.selectedSort = .featured
        selectedSizes.removeAll()
        selectedColors.removeAll()
        draftSearch = ""
        searchText = ""
        BrandHaptics.selection()
    }
}

private struct ShopSignal: Identifiable {
    let id: String
    let value: String
    let label: String
}

private struct ShopBoutique: Identifiable {
    let id: String
    let name: String
    let area: String
    let governorate: String
    let dispatchNote: String
    let coordinate: CLLocationCoordinate2D
}

extension ShopBoutique: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, area, governorate, dispatchNote, coordinate
    }

    private enum CoordinateKeys: String, CodingKey {
        case latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        area = try container.decode(String.self, forKey: .area)
        governorate = try container.decode(String.self, forKey: .governorate)
        dispatchNote = try container.decode(String.self, forKey: .dispatchNote)

        let coordinateContainer = try container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(
            latitude: try coordinateContainer.decode(CLLocationDegrees.self, forKey: .latitude),
            longitude: try coordinateContainer.decode(CLLocationDegrees.self, forKey: .longitude)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(area, forKey: .area)
        try container.encode(governorate, forKey: .governorate)
        try container.encode(dispatchNote, forKey: .dispatchNote)

        var coordinateContainer = container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
        try coordinateContainer.encode(coordinate.latitude, forKey: .latitude)
        try coordinateContainer.encode(coordinate.longitude, forKey: .longitude)
    }
}

private struct ShopLoadResult {
    let products: [Product]
    let boutiques: [ShopBoutique]
}

private struct ShopInlineSearchBar: View {
    @Binding var text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandPalette.gold)

            TextField("Search the collection...", text: $text)
                .font(.body)
                .foregroundStyle(BrandPalette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BrandPalette.textMuted)
                }
                .buttonStyle(.plain)
            }

            Button(action: dismiss) {
                Text("Cancel")
                    .font(.callout)
                    .foregroundStyle(BrandPalette.gold)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            BrandPalette.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct BoutiqueMapCard: View {
    let boutique: ShopBoutique

    @State private var position: MapCameraPosition

    init(boutique: ShopBoutique) {
        self.boutique = boutique
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: boutique.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Map(position: $position, interactionModes: []) {
                Marker(boutique.name, coordinate: boutique.coordinate)
                    .tint(BrandPalette.gold)
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(boutique.name)
                    .font(BrandFont.serif(22, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("\(boutique.area), \(boutique.governorate)")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                Text(boutique.dispatchNote)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.gold)

                Text("Map-verified boutique delivery hub.")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct ShopFilterSheet: View {
    let categories: [ProductCategory]
    let sizes: [String]
    let colors: [String]

    @Binding var selectedCategory: ProductCategory?
    @Binding var selectedPriceBand: PriceBand?
    @Binding var selectedSort: SortOption
    @Binding var selectedSizes: Set<String>
    @Binding var selectedColors: Set<String>

    let clearAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                filterSection("Category") {
                    filterRow("All", selected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(categories, id: \.self) { category in
                        filterRow(category.title, selected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }

                filterSection("Price Range") {
                    filterRow("Any", selected: selectedPriceBand == nil) {
                        selectedPriceBand = nil
                    }

                    ForEach(PriceBand.allCases) { band in
                        filterRow(band.title, selected: selectedPriceBand == band) {
                            selectedPriceBand = band
                        }
                    }
                }

                filterSection("Size") {
                    ForEach(sizes, id: \.self) { size in
                        multiRow(size, selected: selectedSizes.contains(size)) {
                            selectedSizes.toggle(size)
                        }
                    }
                }

                filterSection("Color") {
                    ForEach(colors, id: \.self) { color in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(ColorSystem.color(for: color))
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                                )

                            multiRow(color.capitalized, selected: selectedColors.contains(color)) {
                                selectedColors.toggle(color)
                            }
                        }
                    }
                }

                filterSection("Sort") {
                    ForEach(SortOption.allCases) { option in
                        filterRow(option.title, selected: selectedSort == option) {
                            selectedSort = option
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(BrandPalette.overlay.ignoresSafeArea())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        clearAll()
                    }
                    .foregroundStyle(BrandPalette.gold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(BrandPalette.gold)
                }
            }
        }
        .tint(BrandPalette.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    @ViewBuilder
    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Section(title) {
            content()
        }
    }

    private func filterRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(BrandPalette.textPrimary)

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandPalette.gold)
                }
            }
        }
    }

    private func multiRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(BrandPalette.textPrimary)

                Spacer()

                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? BrandPalette.gold : BrandPalette.textMuted)
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}
