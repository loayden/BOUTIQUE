import SwiftUI

struct SearchView: View {
    @Environment(AurelienStore.self) private var store

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var selectedCategory: ProductCategory?
    @State private var selectedPriceBand: PriceBand?
    @State private var selectedSize: String?
    @State private var selectedColor: String?

    private var availableSizes: [String] {
        Array(Set(store.products.flatMap(\.sizes))).sorted()
    }

    private var availableColors: [String] {
        Array(Set(store.products.flatMap(\.colors).map(\.name))).sorted()
    }

    private var results: [Product] {
        let trimmed = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return store.products.filter { product in
            !product.isExcluded && (
                product.name.localizedCaseInsensitiveContains(trimmed) ||
                product.summary.localizedCaseInsensitiveContains(trimmed) ||
                product.category.title.localizedCaseInsensitiveContains(trimmed)
            ) &&
            (selectedCategory == nil || product.category == selectedCategory) &&
            (selectedPriceBand == nil || selectedPriceBand?.contains(product.price) == true) &&
            (selectedSize.map { product.sizes.contains($0) } ?? true) &&
            (selectedColor == nil || product.colors.contains(where: { $0.name == selectedColor }))
        }
    }

    private var activeFilters: [SearchActiveFilter] {
        var filters: [SearchActiveFilter] = []

        if let selectedCategory {
            filters.append(.init(id: "category", title: selectedCategory.title, systemImage: "square.grid.2x2", kind: .category))
        }

        if let selectedPriceBand {
            filters.append(.init(id: "price", title: selectedPriceBand.title, systemImage: "banknote", kind: .price))
        }

        if let selectedSize {
            filters.append(.init(id: "size", title: "Size \(selectedSize)", systemImage: "ruler", kind: .size))
        }

        if let selectedColor {
            filters.append(.init(id: "color", title: selectedColor, systemImage: "paintpalette", kind: .color))
        }

        return filters
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.lg) {
                searchField
                filtersBar
                activeFiltersBar

                if debouncedQuery.isEmpty {
                    recentSearchesSection
                    trendingSearchesSection
                } else if results.isEmpty {
                    EmptyStatePanel(
                        title: "No matching products",
                        copy: "Try a broader material, category, or silhouette. Search stays live and filters as you type.",
                        buttonTitle: "Clear Search"
                    ) {
                        query = ""
                        debouncedQuery = ""
                    }
                } else {
                    BrandSectionHeader(
                        eyebrow: "Results",
                        title: "\(results.count) matching pieces",
                        copy: "Results stay direct and image-led so you can compare products quickly without extra chrome."
                    )

                    LazyVStack(spacing: 12) {
                        ForEach(results) { product in
                            ProductCardView(product: product, style: .list)
                        }
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, BrandSpacing.md)
            .padding(.bottom, viewport.bottomPadding + 24)
        }
        .background(AmbientBackdrop())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            debouncedQuery = trimmed
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandPalette.goldDeep)

            TextField("Search jackets, denim, loafers...", text: $query)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    store.rememberQuery(query)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    debouncedQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BrandPalette.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(BrandPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }

    private var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterMenu(
                    title: selectedCategory?.title ?? "Category",
                    systemImage: "square.grid.2x2"
                ) {
                    Button("All Categories") { selectedCategory = nil }
                    ForEach(ProductCategory.allCases) { category in
                        Button(category.title) { selectedCategory = category }
                    }
                }

                filterMenu(
                    title: selectedPriceBand?.title ?? "Price",
                    systemImage: "banknote"
                ) {
                    Button("All Prices") { selectedPriceBand = nil }
                    ForEach(PriceBand.allCases) { band in
                        Button(band.title) { selectedPriceBand = band }
                    }
                }

                filterMenu(
                    title: selectedSize ?? "Size",
                    systemImage: "ruler"
                ) {
                    Button("All Sizes") { selectedSize = nil }
                    ForEach(availableSizes, id: \.self) { size in
                        Button(size) { selectedSize = size }
                    }
                }

                filterMenu(
                    title: selectedColor ?? "Color",
                    systemImage: "paintpalette"
                ) {
                    Button("All Colors") { selectedColor = nil }
                    ForEach(availableColors, id: \.self) { color in
                        Button(color) { selectedColor = color }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activeFiltersBar: some View {
        if !activeFilters.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Active Filters")
                        .font(BrandFont.mobileCaption())
                        .tracking(1.6)
                        .foregroundStyle(BrandPalette.textSecondary)

                    Spacer(minLength: 0)

                    Button("Clear All", action: clearFilters)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.gold)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(activeFilters) { filter in
                            Button {
                                clearFilter(filter.kind)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: filter.systemImage)
                                    Text(filter.title)
                                        .lineLimit(1)
                                    Image(systemName: "xmark")
                                }
                                .font(.subheadline)
                                .foregroundStyle(BrandPalette.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                                .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
        }
    }

    private func filterMenu<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(BrandPalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
        }
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Recent",
                title: "Pick up from your last searches.",
                copy: store.recentQueries.isEmpty ? "Searches you use often will stay here as removable chips." : nil
            )

            if store.recentQueries.isEmpty {
                EmptyStatePanel(
                    title: "No recent searches yet",
                    copy: "Once you search, the last few phrases will stay ready for one-tap access.",
                    buttonTitle: "Open Shop"
                ) {
                    store.selectedTab = .shop
                }
            } else {
                FlexibleChipGrid(items: store.recentQueries) { term in
                    query = term
                    debouncedQuery = term
                    store.rememberQuery(term)
                } trailingAction: { term in
                    store.removeRecentQuery(term)
                }
            }
        }
    }

    private var trendingSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Trending",
                title: "Suggested searches from the live catalogue.",
                copy: "Use these to jump into the most active parts of the collection."
            )

            FlexibleChipGrid(items: store.trendingQueries) { term in
                query = term
                debouncedQuery = term
                store.rememberQuery(term)
            }
        }
    }

    private func clearFilters() {
        selectedCategory = nil
        selectedPriceBand = nil
        selectedSize = nil
        selectedColor = nil
    }

    private func clearFilter(_ kind: SearchActiveFilter.Kind) {
        switch kind {
        case .category:
            selectedCategory = nil
        case .price:
            selectedPriceBand = nil
        case .size:
            selectedSize = nil
        case .color:
            selectedColor = nil
        }
    }
}

private struct SearchActiveFilter: Identifiable {
    enum Kind {
        case category
        case price
        case size
        case color
    }

    let id: String
    let title: String
    let systemImage: String
    let kind: Kind
}

private struct FlexibleChipGrid: View {
    let items: [String]
    let action: (String) -> Void
    var trailingAction: ((String) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button {
                    action(item)
                } label: {
                    HStack(spacing: 8) {
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(BrandPalette.textPrimary)
                            .lineLimit(1)

                        if let trailingAction {
                            Spacer(minLength: 0)
                            Button {
                                trailingAction(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(BrandPalette.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
