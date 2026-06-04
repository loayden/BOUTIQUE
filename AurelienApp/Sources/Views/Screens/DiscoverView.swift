import SwiftUI
import UIKit

struct DiscoverView: View {
    @Environment(AurelienStore.self) private var store

    @SceneStorage("discover.surface") private var surfaceRaw = DiscoverSurface.feed.rawValue
    @SceneStorage("discover.feed.index") private var currentIndex = 0

    @AppStorage("discover.points") private var points = 0
    @AppStorage("discover.style_dna") private var styleDNA = "Minimal Tailored"

    @State private var outfits: [DiscoverOutfit] = []
    @State private var drops: [DiscoverDropData] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    @State private var likedOutfitIDs: Set<String> = []
    @State private var savedOutfitIDs: Set<String> = []

    @State private var discoverUserState = DiscoverUserState.empty

    @State private var activeSheet: DiscoverFeatureSheet?
    @State private var sharePayload: DiscoverSharePayload?
    @State private var lastInteractionAt = Date.distantPast

    private var surface: DiscoverSurface {
        get {
            guard let resolved = DiscoverSurface(rawValue: surfaceRaw) else {
                return .feed
            }
            return resolved
        }
        nonmutating set { surfaceRaw = newValue.rawValue }
    }

    private var discoverProducts: [Product] {
        var seen = Set<String>()
        var merged: [Product] = []

        for product in outfits.flatMap(\.products) + store.products {
            guard seen.insert(product.id).inserted else { continue }
            merged.append(product)
            if merged.count == 60 { break }
        }

        return merged
    }

    private var currentOutfit: DiscoverOutfit? {
        if outfits.indices.contains(currentIndex) {
            return outfits[currentIndex]
        }
        return outfits.first
    }

    private var activeDropCount: Int {
        drops.filter { ($0.unlocksAt ?? .distantPast) <= Date() }.count
    }

    private var discoverMomentumCopy: String {
        if let currentOutfit {
            return "Featuring \(currentOutfit.creatorName) with \(currentOutfit.products.count) shoppable pieces."
        }
        if drops.isEmpty == false {
            return "\(drops.count) live and upcoming drops are ready to shop."
        }
        return "Editorial outfits and launch highlights refresh from the live catalog."
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            let contentWidth = max(0, viewport.width - (viewport.horizontalPadding * 2))

            LazyVStack(alignment: .leading, spacing: BrandSpacing.lg) {
                header
                surfaceSelector

                if isLoading {
                    DiscoverLoadingState()
                } else if let errorMessage {
                    DiscoverErrorState(message: errorMessage) {
                        Task { await reloadDiscover(forceRefresh: true) }
                    }
                } else {
                    switch surface {
                    case .feed:
                        feedSurface(viewport: viewport, contentWidth: contentWidth)
                    case .drops:
                        dropsSurface(contentWidth: contentWidth)
                    }

                    overviewStrip
                }
            }
            .frame(width: contentWidth, alignment: .topLeading)
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, BrandSpacing.md)
            .padding(.bottom, viewport.bottomPadding + 24)
        }
        .background(AmbientBackdrop())
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Label("\(savedOutfitIDs.count)", systemImage: "bookmark.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandPalette.gold)

                    Text("\(activeDropCount) live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            featureSheet(for: sheet)
        }
        .sheet(item: $sharePayload) { payload in
            DiscoverActivityView(activityItems: payload.activityItems) { completed in
                if completed {
                    points += 1
                    BrandHaptics.selection()
                }
                sharePayload = nil
            }
        }
        .task {
            if outfits.isEmpty && drops.isEmpty {
                await reloadDiscover(forceRefresh: false)
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            guard outfits.indices.contains(newIndex) else { return }
            preloadNextOutfit(after: newIndex)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("DISCOVER")
                    .font(BrandFont.mobileCaption())
                    .tracking(2.2)
                    .foregroundStyle(BrandPalette.gold)

                Text("Shop outfits and drops.")
                    .font(BrandFont.serif(22, relativeTo: .title2))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(discoverMomentumCopy)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                DiscoverQuickTag(title: styleDNA, icon: "person.crop.circle")

                HStack(spacing: 8) {
                    DiscoverQuickTag(title: "\(likedOutfitIDs.count) liked", icon: "heart")
                    DiscoverQuickTag(title: "\(savedOutfitIDs.count) saved", icon: "bookmark")
                }
            }

            HStack(spacing: 10) {
                DiscoverHeroMetric(value: "\(outfits.count)", label: "Looks")
                DiscoverHeroMetric(value: "\(activeDropCount)", label: "Live Drops")
                DiscoverHeroMetric(value: "\(savedOutfitIDs.count)", label: "Saved")
            }
        }
        .padding(16)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }

    private var overviewStrip: some View {
        HStack(spacing: 12) {
            DiscoverOverviewCard(
                title: "Feed",
                value: "\(outfits.count)",
                subtitle: "Shoppable looks"
            )
            DiscoverOverviewCard(
                title: "Drops",
                value: "\(activeDropCount)",
                subtitle: "Live now"
            )
            DiscoverOverviewCard(
                title: "Saved",
                value: "\(max(savedOutfitIDs.count, store.wishlistedProducts.count))",
                subtitle: "Pieces kept"
            )
        }
    }

    private var currentOutfitProductsShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Shop The Look",
                title: currentOutfit?.title ?? "Shop the current outfit edit.",
                copy: "Tap any piece to open product details, save it, or add it to your bag.",
                actionTitle: "Open Shop"
            ) {
                store.selectedTab = .shop
            }

            if let currentOutfit, currentOutfit.products.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(currentOutfit.products.prefix(6)) { product in
                            NavigationLink(value: product) {
                                DiscoverProductMiniCard(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            } else {
                EmptyStatePanel(
                    title: "No products in this look",
                    copy: "This outfit does not currently include shoppable products.",
                    buttonTitle: "Browse Shop"
                ) {
                    store.selectedTab = .shop
                }
            }
        }
    }

    private var surfaceSelector: some View {
        HStack(spacing: 10) {
            ForEach(DiscoverSurface.allCases) { candidate in
                Button {
                    withInteractionLock {
                        BrandHaptics.selection()
                        surface = candidate
                    }
                } label: {
                    SelectionCapsule(
                        title: candidate.title,
                        isSelected: surface == candidate
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func feedSurface(viewport: PhoneViewport, contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.lg) {
            BrandSectionHeader(
                eyebrow: "Outfit Feed",
                title: "Swipe looks. Shop pieces.",
                copy: "Like, save, share, or move straight into the full shop from the current outfit card."
            )

            if outfits.isEmpty {
                EmptyStatePanel(
                    title: "No outfits available",
                    copy: "We could not build your outfit feed. Reload to fetch fresh recommendations.",
                    buttonTitle: "Reload"
                ) {
                    Task { await reloadDiscover(forceRefresh: true) }
                }
            } else {
                centeredFeedSection(contentWidth: contentWidth) {
                    outfitPager(viewport: viewport, contentWidth: contentWidth)
                }
            }

            centeredFeedSection(contentWidth: contentWidth) {
                currentOutfitProductsShelf
            }
            centeredFeedSection(contentWidth: contentWidth) {
                featureActionGrid
            }
            centeredFeedSection(contentWidth: contentWidth) {
                monetizationCards
            }
        }
    }

    private func outfitPager(viewport: PhoneViewport, contentWidth: CGFloat) -> some View {
        let cardWidth = min(contentWidth, 380)

        return VStack(spacing: 12) {
            if outfits.indices.contains(currentIndex) {
                let outfit = outfits[currentIndex]
                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    DiscoverOutfitCard(
                        outfit: outfit,
                        isLiked: likedOutfitIDs.contains(outfit.id),
                        isSaved: savedOutfitIDs.contains(outfit.id),
                        onLike: { toggleLike(outfit) },
                        onSave: { toggleSave(outfit) },
                        onShare: { share(outfit) },
                        onOpenShop: {
                            store.selectedTab = .shop
                        }
                    )
                    .frame(width: cardWidth)
                    .frame(height: min(max(cardWidth * 1.58, 560), 720))

                    Spacer(minLength: 0)
                }
                .frame(width: contentWidth)
            }

            VStack(spacing: 10) {
                ForEach(Array(outfits.enumerated()), id: \.element.id) { index, outfit in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            currentIndex = index
                        }
                    } label: {
                        DiscoverOutfitSelectorRow(
                            outfit: outfit,
                            isSelected: index == currentIndex
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var featureActionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Tools",
                title: "Tools that help you decide faster.",
                copy: "Keep Discover focused on editorial browsing, stylist help, and saved shopping continuity."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                featureButton(title: "Style Profile", subtitle: "Saved preferences", icon: "person.text.rectangle", sheet: .styleDNA)
                featureButton(title: "Stylist", subtitle: "Catalog advice", icon: "bubble.left.and.bubble.right", sheet: .aiStylist)
                featureActionButton(title: "Saved Pieces", subtitle: "Wishlist continuity", icon: "bookmark") {
                    store.selectedTab = .account
                    store.pushRoute(.wishlist)
                }
                featureActionButton(title: "Open Shop", subtitle: "Full catalog", icon: "bag") {
                    store.selectedTab = .shop
                }
            }
        }
    }

    private var monetizationCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Keep Shopping",
                title: "Move between launches, wishlist, and the full catalog.",
                copy: "Discover stays focused on lookbook edits and launch highlights without turning into a social feed."
            )

            Button {
                withInteractionLock {
                    surface = .drops
                    BrandHaptics.mediumImpact()
                }
                } label: {
                    DiscoverRevenueCard(
                        icon: "bolt.horizontal.circle.fill",
                        title: "Limited Drops",
                        subtitle: "Stock and timing",
                        detail: "See what is live now and what is arriving next without leaving the app shell.",
                        emphasis: "\(activeDropCount) live now"
                    )
                }
            .buttonStyle(.plain)

            Button {
                withInteractionLock {
                    store.selectedTab = .account
                    store.pushRoute(.wishlist)
                    BrandHaptics.selection()
                }
            } label: {
                DiscoverRevenueCard(
                    icon: "bookmark.circle.fill",
                    title: "Saved Pieces",
                    subtitle: "Wishlist",
                    detail: "Review saved products from Discover and continue shopping from your account.",
                    emphasis: "\(store.wishlistedProducts.count) saved"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func centeredFeedSection<Content: View>(
        contentWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Spacer(minLength: 0)
            content()
                .frame(width: min(contentWidth, 380), alignment: .topLeading)
            Spacer(minLength: 0)
        }
        .frame(width: contentWidth)
    }

    private func dropsSurface(contentWidth: CGFloat) -> some View {
        centeredFeedSection(contentWidth: contentWidth) {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    eyebrow: "Limited Drops",
                    title: "Launches with stock, timing, and product momentum.",
                    copy: "See what is live now, what is opening next, and when to jump back into the shop."
                )

                if drops.isEmpty {
                    EmptyStatePanel(
                        title: "No active drops",
                        copy: "Drop highlights are unavailable right now. Pull to refresh or try again shortly.",
                        buttonTitle: "Reload"
                    ) {
                        Task { await reloadDiscover(forceRefresh: true) }
                    }
                } else {
                    ForEach(drops) { drop in
                        DiscoverDropLaunchCard(
                            drop: drop,
                            countdownText: dropCountdownText(drop),
                            onExplore: {
                                store.selectedTab = .shop
                            }
                        )
                    }
                }
            }
        }
    }

    private func featureButton(title: String, subtitle: String, icon: String, sheet: DiscoverFeatureSheet) -> some View {
        Button {
            withInteractionLock {
                BrandHaptics.selection()
                activeSheet = sheet
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(BrandPalette.gold)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func featureActionButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withInteractionLock {
                BrandHaptics.selection()
                action()
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(BrandPalette.gold)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func featureSheet(for sheet: DiscoverFeatureSheet) -> some View {
        switch sheet {
        case .styleDNA:
            DiscoverStyleDNASheet(styleDNA: $styleDNA)
        case .aiStylist:
            DiscoverAIStylistSheet(products: discoverProducts)
        }
    }

    @MainActor
    private func reloadDiscover(forceRefresh: Bool) async {
        struct LoadTimeout: Error {}

        Logger.debug("DiscoverView reloadDiscover(forceRefresh: \(forceRefresh)) start")
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            isLoading = false
            Logger.debug("DiscoverView reloadDiscover end isLoading=\(isLoading) error=\(errorMessage ?? "nil")")
        }

        if forceRefresh {
            errorMessage = nil
        }

        do {
            let snapshot: DiscoverExperienceSnapshot = try await withThrowingTaskGroup(of: DiscoverExperienceSnapshot.self) { group in
                group.addTask {
                    try await APIService.shared.fetchDiscoverExperience()
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    throw LoadTimeout()
                }

                guard let value = try await group.next() else {
                    throw LoadTimeout()
                }
                group.cancelAll()
                return value
            }
            outfits = snapshot.feed.map {
                DiscoverOutfit(
                    id: $0.id,
                    creatorID: $0.creatorID,
                    creatorName: $0.creatorName,
                    title: $0.title,
                    caption: $0.caption,
                    score: $0.score,
                    products: $0.products
                )
            }
            drops = snapshot.drops
            let userState = (try? await APIService.shared.fetchDiscoverUserState()) ?? .empty
            discoverUserState = userState
            likedOutfitIDs = Set(userState.likedOutfitIDs)
            savedOutfitIDs = Set(userState.savedOutfitIDs)
            if let profile = userState.styleDNA ?? snapshot.styleProfile {
                styleDNA = profile.summary
            }
            currentIndex = min(currentIndex, max(outfits.count - 1, 0))
            errorMessage = nil
            Logger.debug("DiscoverView reloadDiscover success outfits=\(outfits.count) drops=\(drops.count)")
        } catch is LoadTimeout {
            Logger.error("DiscoverView reloadDiscover timed out")
            if outfits.isEmpty && drops.isEmpty {
                errorMessage = "Connection timed out. Please check your internet and retry."
            } else {
                errorMessage = "Unable to refresh discover right now."
            }
        } catch {
            Logger.error("DiscoverView reloadDiscover failed: \(error.localizedDescription)")
            if outfits.isEmpty && drops.isEmpty {
                errorMessage = "Discover content is unavailable right now."
            } else {
                errorMessage = "Unable to refresh discover right now."
            }
        }
    }

    private func preloadNextOutfit(after index: Int) {
        let nextIndex = index + 1
        guard outfits.indices.contains(nextIndex) else { return }
        let nextImages = outfits[nextIndex].products.flatMap(\.imageNames)
        for name in nextImages.prefix(4) {
            if name.lowercased().hasPrefix("http") {
                continue
            }
            _ = BrandMediaLibrary.image(named: name)
        }
    }

    private func toggleLike(_ outfit: DiscoverOutfit) {
        withInteractionLock {
            let isActive: Bool
            if likedOutfitIDs.contains(outfit.id) {
                likedOutfitIDs.remove(outfit.id)
                isActive = false
            } else {
                likedOutfitIDs.insert(outfit.id)
                isActive = true
                points += 2
                BrandHaptics.softImpact()
            }
            persistDiscoverInteraction(kind: .likedOutfit, targetID: outfit.id, isActive: isActive)
        }
    }

    private func toggleSave(_ outfit: DiscoverOutfit) {
        withInteractionLock {
            let isActive: Bool
            if savedOutfitIDs.contains(outfit.id) {
                savedOutfitIDs.remove(outfit.id)
                isActive = false
            } else {
                savedOutfitIDs.insert(outfit.id)
                isActive = true
                points += 3
                BrandHaptics.selection()
                if let product = outfit.products.first {
                    store.toggleWishlist(for: product)
                }
            }
            persistDiscoverInteraction(kind: .savedOutfit, targetID: outfit.id, isActive: isActive)
        }
    }

    private func persistDiscoverInteraction(kind: DiscoverInteractionKind, targetID: String, isActive: Bool) {
        Task {
            if let state = try? await APIService.shared.updateDiscoverInteraction(
                kind: kind,
                targetID: targetID,
                isActive: isActive
            ) {
                discoverUserState = state
                likedOutfitIDs = Set(state.likedOutfitIDs)
                savedOutfitIDs = Set(state.savedOutfitIDs)
            }
        }
    }

    private func share(_ outfit: DiscoverOutfit) {
        withInteractionLock {
            let productNames = outfit.products.prefix(4).map(\.name).joined(separator: ", ")
            let shareText = """
            BOUTIQUE Discover: \(outfit.title)
            \(outfit.caption)
            Pieces: \(productNames)
            """
            sharePayload = DiscoverSharePayload(activityItems: [shareText])
        }
    }

    private func dropCountdownText(_ drop: DiscoverDropData) -> String {
        guard let unlocksAt = drop.unlocksAt else {
            return "Live now"
        }

        let totalSeconds = max(0, Int(unlocksAt.timeIntervalSinceNow))
        if totalSeconds == 0 {
            return "Live now"
        }

        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        if days > 0 {
            return "Unlocks in \(days)d \(hours)h"
        }
        if hours > 0 {
            return "Unlocks in \(hours)h \(minutes)m"
        }
        return "Unlocks in \(minutes)m"
    }

    private func withInteractionLock(_ action: () -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastInteractionAt) > 0.16 else { return }
        lastInteractionAt = now
        action()
    }
}

enum DiscoverSurface: String, CaseIterable, Identifiable {
    case feed
    case drops

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: return "Feed"
        case .drops: return "Drops"
        }
    }
}

private enum DiscoverFeatureSheet: String, Identifiable {
    case styleDNA
    case aiStylist

    var id: String { rawValue }
}

private struct DiscoverSharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

private struct DiscoverActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct DiscoverQuickTag: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(BrandFont.mobileCaption2())
            .foregroundStyle(BrandPalette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

private struct DiscoverHeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(BrandFont.serif(19, relativeTo: .headline))
                .foregroundStyle(BrandPalette.textPrimary)

            Text(label.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(1.3)
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(9)
        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct DiscoverOverviewCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(1.1)
                .foregroundStyle(BrandPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)

            Text(value)
                .font(BrandFont.serif(18, relativeTo: .headline))
                .foregroundStyle(BrandPalette.textPrimary)

            Text(subtitle)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(10)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
    }
}

private struct DiscoverOutfit: Identifiable {
    let id: String
    let creatorID: String
    let creatorName: String
    let title: String
    let caption: String
    let score: Int
    let products: [Product]

    var heroImage: String {
        products.first?.heroImageName ?? "look1.jpg"
    }
}

private struct DiscoverOutfitCard: View {
    let outfit: DiscoverOutfit
    let isLiked: Bool
    let isSaved: Bool
    let onLike: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    let onOpenShop: () -> Void

    private var featuredCategories: [String] {
        Array(Set(outfit.products.prefix(4).map { $0.category.title }))
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width
            let innerWidth = max(0, cardWidth - 28)

            ZStack(alignment: .bottomLeading) {
                MediaImage(name: outfit.heroImage)
                    .scaledToFill()
                    .frame(width: cardWidth, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [Color.clear, BrandPalette.textPrimary.opacity(0.18), BrandPalette.textPrimary.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: cardWidth, height: proxy.size.height)

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        DiscoverCreatorPill(
                            creatorName: outfit.creatorName,
                            score: outfit.score
                        )

                        Spacer(minLength: 0)

                        Button("Shop Look") {
                            onOpenShop()
                        }
                        .buttonStyle(BrandCapsuleButtonStyle(tone: .gold, horizontalPadding: 14))
                        .frame(width: 116)
                        .frame(minHeight: 44)
                    }
                    .frame(width: innerWidth)
                    .padding(.top, 14)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(outfit.title)
                            .font(BrandFont.serif(24, relativeTo: .title2))
                            .foregroundStyle(BrandPalette.textPrimary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(outfit.caption)
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(featuredCategories, id: \.self) { category in
                                    Text(category)
                                        .font(BrandFont.mobileCaption2())
                                        .foregroundStyle(BrandPalette.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(BrandPalette.surfaceRaised.opacity(0.86), in: Capsule(style: .continuous))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                                        )
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            DiscoverActionStripButton(
                                systemImage: isLiked ? "heart.fill" : "heart",
                                title: "Like",
                                action: onLike
                            )
                            DiscoverActionStripButton(
                                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                                title: "Save",
                                action: onSave
                            )
                            DiscoverActionStripButton(
                                systemImage: "square.and.arrow.up",
                                title: "Share",
                                action: onShare
                            )
                            DiscoverActionStripButton(
                                systemImage: "bag",
                                title: "Shop",
                                action: onOpenShop
                            )
                        }
                    }
                    .padding(16)
                    .frame(width: innerWidth, alignment: .leading)
                            .background(
                        RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        BrandPalette.surfaceRaised.opacity(0.94),
                                        BrandPalette.surface.opacity(0.92),
                                        BrandPalette.overlay.opacity(0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                }
                .frame(width: cardWidth)
                .padding(.bottom, 14)
            }
            .frame(width: cardWidth, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.sheet, style: .continuous)
                .fill(BrandPalette.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.sheet, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct DiscoverCreatorPill: View {
    let creatorName: String
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(creatorName)
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(1)

            Text("Style score \(score)")
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BrandPalette.surfaceRaised.opacity(0.72), in: RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct DiscoverActionStripButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(BrandPalette.gold)
                    .background(BrandPalette.goldDim, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(BrandFont.mobileCaption2())
                    .foregroundStyle(BrandPalette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(BrandPalette.surfaceRaised.opacity(0.72), in: RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct DiscoverOutfitSelectorRow: View {
    let outfit: DiscoverOutfit
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(isSelected ? BrandPalette.gold : BrandPalette.hairlineStrong)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.creatorName.uppercased())
                    .font(BrandFont.mobileCaption2())
                    .tracking(2)
                    .foregroundStyle(isSelected ? BrandPalette.gold : BrandPalette.textMuted)

                Text(outfit.title)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(isSelected ? BrandPalette.textPrimary : BrandPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(outfit.products.count) pieces")
                .font(BrandFont.mobileCaption())
                .foregroundStyle(isSelected ? BrandPalette.textPrimary : BrandPalette.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(isSelected ? BrandPalette.surfaceRaised : BrandPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .stroke(isSelected ? BrandPalette.goldBorder : BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct DiscoverProductMiniCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MediaImage(name: product.heroImageName)
                .scaledToFill()
                .frame(width: 164, height: 188)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(product.category.title.uppercased())
                    .font(BrandFont.mobileCaption2())
                    .tracking(1.6)
                    .foregroundStyle(BrandPalette.textSecondary)

                Text(BrandFormatter.price(product.price))
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.gold)
            }
        }
        .padding(12)
        .frame(width: 188, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct DiscoverRevenueCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    let emphasis: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandPalette.goldDim)

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandPalette.gold)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.gold)

                Text(detail)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(emphasis)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct DiscoverDropLaunchCard: View {
    let drop: DiscoverDropData
    let countdownText: String
    let onExplore: () -> Void

    private var stockTone: Color {
        drop.stock < 10 ? Color.red.opacity(0.78) : BrandPalette.gold
    }

    private var progressValue: Double {
        min(max(Double(drop.stock), 0), 100) / 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(drop.name)
                        .font(BrandFont.serif(24, relativeTo: .title3))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(countdownText.uppercased())
                        .font(BrandFont.mobileCaption())
                        .tracking(1.8)
                        .foregroundStyle(BrandPalette.gold)
                }

                Spacer(minLength: 0)

                Text(drop.stock > 0 ? "\(drop.stock) left" : "Sold out")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(BrandPalette.surfaceRaised, in: Capsule(style: .continuous))
            }

            Text(drop.copy)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Inventory Pressure")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                    Spacer()
                    Text("\(drop.stock)%")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textPrimary)
                }

                ProgressView(value: progressValue)
                    .tint(stockTone)
            }

            Button("Open Shop") {
                onExplore()
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            .frame(minHeight: 44)
        }
        .padding(18)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }
}

private struct DiscoverChallengeSpotlight: View {
    let challenge: DiscoverChallengeData
    let hasVoted: Bool
    let isVoting: Bool
    let onVote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE CHALLENGE")
                .font(BrandFont.mobileCaption2())
                .tracking(2.2)
                .foregroundStyle(BrandPalette.gold)

            Text(challenge.title)
                .font(BrandFont.serif(28, relativeTo: .title2))
                .foregroundStyle(BrandPalette.textPrimary)

            Text(challenge.prompt)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                DiscoverOverviewCard(
                    title: "Reward",
                    value: "\(challenge.rewardPoints)",
                    subtitle: "Points"
                )

                Button(hasVoted ? "Vote Saved" : (isVoting ? "Saving..." : "Vote In Challenge")) {
                    onVote()
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: hasVoted ? .chrome : .gold))
                .disabled(isVoting || hasVoted)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(18)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct DiscoverLeaderboardRow: View {
    let entry: DiscoverLeaderboardData

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(entry.rank <= 3 ? BrandPalette.goldDim : BrandPalette.surfaceRaised)
                Text("#\(entry.rank)")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(entry.rank <= 3 ? BrandPalette.gold : BrandPalette.textSecondary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Weekly leaderboard")
                    .font(BrandFont.mobileCaption2())
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer()

            Text("\(entry.score) pts")
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textPrimary)
        }
        .frame(minHeight: 52)
    }
}

private struct DiscoverLoadingState: View {
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(BrandPalette.surfaceRaised)
                .frame(height: 460)
                .redacted(reason: .placeholder)

            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(BrandPalette.surfaceRaised)
                .frame(height: 120)
                .redacted(reason: .placeholder)

            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(BrandPalette.surfaceRaised)
                .frame(height: 120)
                .redacted(reason: .placeholder)
        }
    }
}

private struct DiscoverErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        EmptyStatePanel(
            title: "Discover unavailable",
            copy: message.isEmpty ? "Content isn't available right now. Please check your internet connection and try again." : message,
            buttonTitle: "Retry",
            action: retry
        )
    }
}

private struct DiscoverStyleDNASheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var styleDNA: String

    @State private var selectedStyle = "Minimal Tailored"
    @State private var selectedPalette = "Neutrals"
    @State private var selectedFit = "Relaxed"
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let styles = ["Minimal Tailored", "Street Luxe", "Classic Formal", "Athleisure Clean", "Avant Garde"]
    private let palettes = ["Neutrals", "Monochrome", "Earth Tones", "Contrast Pops"]
    private let fits = ["Slim", "Regular", "Relaxed", "Oversized"]

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Picker("Style Direction", selection: $selectedStyle) {
                        ForEach(styles, id: \.self) { Text($0) }
                    }

                    Picker("Palette", selection: $selectedPalette) {
                        ForEach(palettes, id: \.self) { Text($0) }
                    }

                    Picker("Fit Preference", selection: $selectedFit) {
                        ForEach(fits, id: \.self) { Text($0) }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Style DNA")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isLoading || isSaving)
                }
            }
            .task {
                await loadProfile()
            }
        }
    }

    private func loadProfile() async {
        guard isLoading else { return }
        errorMessage = nil
        do {
            let profile = try await APIService.shared.fetchDiscoverStyleDNA()
            selectedStyle = profile.style
            selectedPalette = profile.palette
            selectedFit = profile.fit
            styleDNA = profile.summary
            isLoading = false
        } catch {
            let parts = styleDNA.components(separatedBy: " • ")
            selectedStyle = parts.first ?? selectedStyle
            if parts.count > 1 {
                selectedPalette = parts[1]
            }
            errorMessage = "Unable to load saved style profile right now."
            isLoading = false
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let profile = DiscoverStyleDNAProfile(
                    style: selectedStyle,
                    palette: selectedPalette,
                    fit: selectedFit
                )
                let persisted = try await APIService.shared.saveDiscoverStyleDNA(profile)
                await MainActor.run {
                    styleDNA = persisted.summary
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to save style profile right now."
                    isSaving = false
                }
            }
        }
    }
}

private struct DiscoverClosetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let products: [Product]

    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if products.isEmpty {
                    Text("No live catalog products are available for closet tracking.")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                } else {
                    Section("\(selectedIDs.count) selected") {
                        ForEach(products) { product in
                            Button {
                                if selectedIDs.contains(product.id) {
                                    selectedIDs.remove(product.id)
                                } else {
                                    selectedIDs.insert(product.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    MediaImage(name: product.heroImageName)
                                        .scaledToFill()
                                        .frame(width: 52, height: 64)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name)
                                            .font(BrandFont.mobileBody())
                                            .foregroundStyle(BrandPalette.textPrimary)
                                        Text(product.category.title)
                                            .font(BrandFont.mobileCaption())
                                            .foregroundStyle(BrandPalette.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedIDs.contains(product.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(product.id) ? BrandPalette.gold : BrandPalette.textSecondary)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Closet Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveSelection()
                    }
                    .disabled(isLoading || isSaving)
                }
            }
            .task {
                await loadSelection()
            }
        }
    }

    private func loadSelection() async {
        guard isLoading else { return }
        errorMessage = nil
        do {
            selectedIDs = Set(try await APIService.shared.fetchDiscoverClosetProductIDs())
            isLoading = false
        } catch {
            selectedIDs = []
            errorMessage = "Unable to load closet selections right now."
            isLoading = false
        }
    }

    private func saveSelection() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await APIService.shared.saveDiscoverClosetSelection(productIDs: Array(selectedIDs))
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to save closet updates right now."
                    isSaving = false
                }
            }
        }
    }
}

private struct DiscoverAIStylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let products: [Product]

    @State private var query = ""
    @State private var messages: [StylistMessage] = [
        .init(id: "m-1", text: "Tell me the occasion and I will build from live catalog pieces.", isUser: false)
    ]
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isUser { Spacer() }
                                Text(message.text)
                                    .font(BrandFont.mobileBody())
                                    .foregroundStyle(message.isUser ? BrandPalette.accentForeground : BrandPalette.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        (message.isUser ? BrandPalette.gold : BrandPalette.surfaceRaised),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                if !message.isUser { Spacer() }
                            }
                        }
                    }
                    .padding(12)
                }

                HStack(spacing: 8) {
                    TextField("Ask stylist...", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Send") {
                        send()
                    }
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .gold, horizontalPadding: 16))
                    .frame(width: 88, height: 44)
                    .disabled(isSending || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
            }
            .navigationTitle("Catalog Stylist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(.init(id: UUID().uuidString, text: trimmed, isUser: true))
        query = ""
        isSending = true

        Task {
            do {
                let reply = try await APIService.shared.sendDiscoverStylistMessage(
                    trimmed,
                    contextProductIDs: Array(products.prefix(12).map(\.id))
                )
                await MainActor.run {
                    messages.append(.init(id: UUID().uuidString, text: reply, isUser: false))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    messages.append(
                        .init(
                            id: UUID().uuidString,
                            text: "I couldn’t reach the stylist service right now. Please try again.",
                            isUser: false
                        )
                    )
                    isSending = false
                }
            }
        }
    }
}

private struct DiscoverSnapMatchSheet: View {
    @Environment(AurelienStore.self) private var store
    @State private var selectedMood = "Minimal"
    @State private var matches: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let moods = ["Minimal", "Street", "Formal", "Travel", "Weekend"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Style Match")
                    .font(BrandFont.mobileTitle())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Choose a mood and match it against the live product catalog.")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                Picker("Mood", selection: $selectedMood) {
                    ForEach(moods, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    EmptyStatePanel(
                        title: "Style match unavailable",
                        copy: errorMessage,
                        buttonTitle: "Retry"
                    ) {
                        Task { await loadMatches() }
                    }
                } else if matches.isEmpty {
                    EmptyStatePanel(
                        title: "No matches found",
                        copy: "Try another mood to run a different catalog match.",
                        buttonTitle: "Try Again"
                    ) {
                        Task { await loadMatches() }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(matches.prefix(8)) { product in
                                NavigationLink(value: product) {
                                    HStack(spacing: 12) {
                                        MediaImage(name: product.heroImageName)
                                            .scaledToFill()
                                            .frame(width: 56, height: 70)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(product.name)
                                                .font(BrandFont.mobileBody())
                                                .foregroundStyle(BrandPalette.textPrimary)
                                            Text("\(selectedMood) match • \(BrandFormatter.price(product.price))")
                                                .font(BrandFont.mobileCaption())
                                                .foregroundStyle(BrandPalette.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrandPalette.textSecondary)
                                    }
                                    .padding(10)
                                    .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let first = matches.first {
                        Button(store.isWishlisted(first) ? "Saved Top Match" : "Save Top Match") {
                            store.toggleWishlist(for: first)
                        }
                        .buttonStyle(BrandCapsuleButtonStyle(tone: store.isWishlisted(first) ? .chrome : .gold))
                        .frame(minHeight: 44)
                    }
                }
            }
            .padding(16)
            .navigationTitle("Style Match")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .task {
                await loadMatches()
            }
            .onChange(of: selectedMood) { _, _ in
                Task { await loadMatches() }
            }
        }
    }

    private func loadMatches() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            matches = try await APIService.shared.fetchDiscoverSnapMatches(mood: selectedMood, limit: 8)
        } catch {
            matches = []
            errorMessage = "We couldn't fetch style matches at the moment."
        }
    }
}

private struct DiscoverTryBeforeBuySheet: View {
    let products: [Product]
    @State private var selected: Set<String> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var receipt: DiscoverReservationReceipt?

    var body: some View {
        NavigationStack {
            List {
                ForEach(products) { product in
                    Button {
                        if selected.contains(product.id) {
                            selected.remove(product.id)
                        } else {
                            selected.insert(product.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(BrandFont.mobileBody())
                                    .foregroundStyle(BrandPalette.textPrimary)
                                Text("\(BrandFormatter.price(product.price))")
                                    .font(BrandFont.mobileCaption())
                                    .foregroundStyle(BrandPalette.textSecondary)
                            }
                            Spacer()
                            if selected.contains(product.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BrandPalette.gold)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }

                if let receipt {
                    Text("Reservation \(receipt.id) saved with \(receipt.productIDs.count) item(s).")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(Color.green)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Try Before You Buy")
            .safeAreaInset(edge: .bottom) {
                Button(selected.isEmpty ? "Select Items" : (isSubmitting ? "Reserving..." : "Reserve \(selected.count) Item(s)")) {
                    submit()
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: selected.isEmpty ? .chrome : .gold))
                .disabled(selected.isEmpty || isSubmitting)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    private func submit() {
        guard !selected.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        receipt = nil
        errorMessage = nil

        Task {
            do {
                let reservation = try await APIService.shared.submitTryBeforeBuySelection(productIDs: Array(selected))
                await MainActor.run {
                    receipt = reservation
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to reserve these items right now."
                    isSubmitting = false
                }
            }
        }
    }
}

private struct DiscoverSubscriptionBoxSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("discover.subscription_plan_id") private var selectedPlanID = ""
    @State private var activeSubscription: DiscoverSubscriptionStatus?
    @State private var plans: [DiscoverSubscriptionPlan] = []
    @State private var isLoading = true
    @State private var isSubscribing = false
    @State private var errorMessage: String?

    private var selectedPlan: DiscoverSubscriptionPlan? {
        plans.first(where: { $0.id == selectedPlanID }) ?? plans.first
    }

    private var subscribed: Bool {
        activeSubscription?.subscribed == true
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Style Box Requests")
                    .font(BrandFont.mobileTitle())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Choose a curated outfit plan and save a request to your account for stylist follow-up.")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if let errorMessage {
                    EmptyStatePanel(
                        title: "Style box plans unavailable",
                        copy: errorMessage,
                        buttonTitle: "Retry"
                    ) {
                        Task { await loadPlans() }
                    }
                } else if plans.isEmpty {
                    EmptyStatePanel(
                        title: "No plans available",
                        copy: "Style box plans will appear once they are configured in admin.",
                        buttonTitle: "Reload"
                    ) {
                        Task { await loadPlans() }
                    }
                } else {
                    Picker("Plan", selection: Binding(
                        get: { selectedPlan?.id ?? selectedPlanID },
                        set: { selectedPlanID = $0 }
                    )) {
                        ForEach(plans) { plan in
                            Text("\(plan.interval) • \(BrandFormatter.price(plan.price))").tag(plan.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let selectedPlan {
                        Text("\(selectedPlan.title) · \(selectedPlan.details)")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }

                    if let activeSubscription {
                        Text("Requested plan: \(activeSubscription.planID ?? selectedPlanID)")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(Color.green)
                    }
                }

                Button(subscribed ? "Request Saved" : (isSubscribing ? "Saving..." : "Save Request")) {
                    subscribe()
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: subscribed ? .chrome : .gold))
                .disabled(subscribed || isSubscribing || selectedPlan == nil)
                .frame(minHeight: 44)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Style Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismissSheet() }
                }
            }
            .task {
                await loadPlans()
            }
        }
    }

    private func dismissSheet() {
        dismiss()
    }

    private func loadPlans() async {
        guard isLoading || plans.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let plansTask = APIService.shared.fetchDiscoverSubscriptionPlans()
            async let stateTask = APIService.shared.fetchDiscoverUserState()
            let fetchedPlans = try await plansTask
            let userState = try? await stateTask
            plans = fetchedPlans
            activeSubscription = userState?.activeSubscription
            if selectedPlanID.isEmpty {
                selectedPlanID = activeSubscription?.planID ?? plans.first?.id ?? ""
            }
            if let planID = activeSubscription?.planID {
                selectedPlanID = planID
            }
        } catch {
            errorMessage = "We couldn't fetch style box plans right now."
            plans = []
        }
    }

    private func subscribe() {
        guard let selectedPlan, !isSubscribing else { return }
        isSubscribing = true
        errorMessage = nil

        Task {
            do {
                let status = try await APIService.shared.subscribeToDiscoverPlan(planID: selectedPlan.id)
                await MainActor.run {
                    activeSubscription = status
                    isSubscribing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to save your style box request right now."
                    isSubscribing = false
                }
            }
        }
    }
}

private struct DiscoverSellerBoostSheet: View {
    @State private var budget: Double = 400
    @State private var durationDays = 3
    @State private var estimatedReach: Int?
    @State private var isEstimating = false
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var activation: DiscoverBoostActivation?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Campaign Request")
                    .font(BrandFont.mobileTitle())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Estimate discovery reach and save a campaign request for admin review.")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget: \(BrandFormatter.price(budget))")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textPrimary)
                    Slider(value: $budget, in: 100...3000, step: 50)
                }

                Stepper("Duration: \(durationDays) days", value: $durationDays, in: 1...14)

                if let estimatedReach {
                    Text("Estimated reach: \(estimatedReach) users")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                } else if isEstimating {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                }

                if let activation {
                    Text("Campaign request saved: \(activation.estimatedReach) estimated users.")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(Color.green)
                }

                Button(activation == nil ? "Save Campaign Request" : "Request Saved") {
                    activate()
                }
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                    .disabled(isActivating || activation != nil)
                    .frame(minHeight: 44)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Campaign Request")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await estimate()
            }
            .onChange(of: budget) { _, _ in
                Task { await estimate() }
            }
            .onChange(of: durationDays) { _, _ in
                Task { await estimate() }
            }
        }
    }

    private func estimate() async {
        guard !isEstimating else { return }
        isEstimating = true
        defer { isEstimating = false }
        errorMessage = nil

        do {
            estimatedReach = try await APIService.shared.estimateDiscoverBoostReach(
                budget: budget,
                days: durationDays
            )
        } catch {
            estimatedReach = nil
            errorMessage = "Unable to estimate reach right now."
        }
    }

    private func activate() {
        guard !isActivating else { return }
        isActivating = true
        errorMessage = nil

        Task {
            do {
                let result = try await APIService.shared.activateDiscoverSellerBoost(
                    budget: budget,
                    days: durationDays
                )
                await MainActor.run {
                    activation = result
                    isActivating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to save this campaign request right now."
                    isActivating = false
                }
            }
        }
    }
}

private struct StylistMessage: Identifiable {
    let id: String
    let text: String
    let isUser: Bool
}
