import SwiftUI

private struct PressableScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private enum ProductBadgeStyle {
    case new
    case bestseller
    case trending

    init?(_ badge: ProductBadge?) {
        switch badge {
        case .newArrival:
            self = .new
        case .bestselling:
            self = .bestseller
        case .editorialPick:
            self = .trending
        case nil:
            return nil
        }
    }

    var label: String {
        switch self {
        case .new:
            return "New"
        case .bestseller:
            return "Best Seller"
        case .trending:
            return "Trending"
        }
    }

    var background: Color {
        switch self {
        case .new:
            return BrandPalette.steel.opacity(0.88)
        case .bestseller:
            return BrandPalette.gold.opacity(0.9)
        case .trending:
            return BrandPalette.rose.opacity(0.88)
        }
    }

    var foreground: Color {
        switch self {
        case .bestseller:
            return BrandPalette.accentForeground
        case .new, .trending:
            return .white
        }
    }
}

private struct ProductCardGalleryImage: View {
    let name: String

    var body: some View {
        if let url = URL(string: name), url.scheme?.hasPrefix("http") == true {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                default:
                    Rectangle().fill(Color.white.opacity(0.04))
                }
            }
        } else {
            MediaImage(name: name)
        }
    }
}

private struct ProductCardCarousel: View {
    let images: [String]
    let badgeStyle: ProductBadgeStyle?
    let inWishlist: Bool
    let onWishlist: () -> Void

    @Binding var currentIndex: Int
    @State private var autoplayTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if images.isEmpty {
                Rectangle().fill(Color.white.opacity(0.04))
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ProductCardGalleryImage(name: image)
                            .scaledToFill()
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            LinearGradient(
                colors: [.black.opacity(0.72), .black.opacity(0.16), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .allowsHitTesting(false)

            if images.count > 1 {
                VStack {
                    Spacer()

                    HStack(spacing: 3) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index < currentIndex
                                    ? Color.white.opacity(0.45)
                                    : index == currentIndex
                                        ? BrandPalette.gold.opacity(0.9)
                                        : Color.white.opacity(0.18)
                                )
                                .frame(height: 2)
                                .animation(.easeInOut(duration: 0.25), value: currentIndex)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    if let badgeStyle {
                        Text(badgeStyle.label.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.6)
                            .foregroundStyle(badgeStyle.foreground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                badgeStyle.background,
                                in: Capsule(style: .continuous)
                            )
                    }

                    Spacer()
                }
                .padding(12)

                Spacer()
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    Button(action: onWishlist) {
                        ZStack {
                            Circle()
                                .fill(
                                    inWishlist
                                    ? Color.red.opacity(0.34)
                                    : Color.white.opacity(0.08)
                                )
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            inWishlist ? Color.red.opacity(0.34) : Color.white.opacity(0.12),
                                            lineWidth: 1
                                        )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: inWishlist ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(inWishlist ? .red : Color.white.opacity(0.72))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
        }
        .onAppear {
            startAutoplay()
        }
        .onDisappear {
            stopAutoplay()
        }
    }

    private func startAutoplay() {
        guard images.count > 1 else { return }

        autoplayTask?.cancel()
        autoplayTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        currentIndex = (currentIndex + 1) % images.count
                    }
                }
            }
        }
    }

    private func stopAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
    }
}

private struct ProductCardDetailsPanel: View {
    let product: Product
    let style: ProductCardView.CardStyle
    let compact: Bool

    @Binding var selectedSize: String?
    @Binding var selectedColor: Colorway?
    @Binding var addedToCart: Bool
    @Binding var cartLoading: Bool
    @Binding var feedbackError: String?
    @Binding var detailsExpanded: Bool

    let onAddToCart: () -> Void
    let onViewDetails: () -> Void

    private var titleSize: CGFloat {
        switch style {
        case .fullscreen:
            return 24
        case .grid:
            return compact ? 17 : 20
        case .list:
            return 18
        }
    }

    private var bodyCopySize: CGFloat {
        compact ? 11 : 12
    }

    private var trustLabel: String {
        if let rating = product.ratingDisplayValue {
            return rating
        }
        return "New"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.boutBorderStrong, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                if let feedbackError {
                    Text(feedbackError.uppercased())
                        .font(.system(size: 9, weight: .light))
                        .tracking(3)
                        .foregroundStyle(BrandPalette.error)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(BrandPalette.error.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(BrandPalette.error.opacity(0.18), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(product.category.title.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.8)
                        .foregroundStyle(BrandPalette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.boutGold.opacity(0.08))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.boutBorder, lineWidth: 0.5)
                                )
                        )

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Image(systemName: product.ratingDisplayValue == nil ? "sparkles" : "star.fill")
                            .font(.system(size: 10, weight: .medium))
                        Text(trustLabel)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(product.ratingDisplayValue == nil ? BrandPalette.textPrimary : Color.boutCreamTop)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(product.ratingDisplayValue == nil ? Color.boutGlassBottom : Color.boutButtonEnd)
                    )
                }

                Text(product.name)
                    .font(BrandFont.serif(titleSize, relativeTo: .title2))
                    .fontWeight(.light)
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(style == .fullscreen ? 3 : 2)
                    .lineSpacing(2)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Price".uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.6)
                            .foregroundStyle(BrandPalette.textMuted)

                        Text(BrandFormatter.price(product.price))
                            .font(BrandFont.serif(style == .fullscreen ? 28 : 22, relativeTo: .title3))
                            .fontWeight(.light)
                            .foregroundStyle(BrandPalette.gold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(product.isInStock ? (product.isLowStock ? BrandPalette.rose : BrandPalette.sage) : Color.red.opacity(0.82))
                                .frame(width: 7, height: 7)

                            Text(product.stockLabel)
                                .font(.system(size: 9, weight: .light))
                                .tracking(1.4)
                                .foregroundStyle(BrandPalette.textSecondary)
                        }

                        if let reviewVolumeText = product.reviewVolumeText {
                            Text(reviewVolumeText)
                                .font(.system(size: 9, weight: .light))
                                .foregroundStyle(BrandPalette.textMuted)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        detailChip(
                            icon: "shippingbox",
                            title: product.delivery.isEmpty ? "Fast delivery" : product.delivery
                        )

                        if let primaryColor = product.colors.first {
                            detailChip(
                                icon: "circle.fill",
                                title: product.colors.count > 1 ? "\(primaryColor.name) +\(product.colors.count - 1)" : primaryColor.name,
                                tint: Color(hex: primaryColor.hex)
                            )
                        }

                        if product.sizes.isEmpty == false {
                            detailChip(
                                icon: "ruler",
                                title: product.sizes.count == 1 ? product.sizes[0] : "\(product.sizes.first ?? "")-\(product.sizes.last ?? "")"
                            )
                        }
                    }
                }

                if style == .grid {
                    expandButton
                }

                if detailsExpanded || style == .fullscreen {
                    expandedSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.boutGlassTop, Color.boutGlassBottom, Color.boutCream.opacity(0.70)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .background(.thinMaterial)
            )
        }
    }

    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !product.summary.isEmpty {
                Text(product.summary)
                    .font(.system(size: bodyCopySize, weight: .light))
                    .tracking(0.3)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(style == .fullscreen ? 4 : 3)
            }

            HStack(spacing: 8) {
                miniStat(
                    "Sizing",
                    value: selectedSize
                        ?? (product.sizes.isEmpty ? "Open" : "\(product.sizes.first ?? "") - \(product.sizes.last ?? "")")
                )
                miniStat("Palette", value: selectedColor?.name ?? (product.colors.first?.name ?? "Mono"))
                miniStat("Status", value: product.availabilityNote)
            }

            if !product.sizes.isEmpty {
                sizeSelector
            }

            if !product.colors.isEmpty {
                colorSelector
            }

            HStack(spacing: 6) {
                Image(systemName: product.ratingDisplayValue == nil ? "star.slash" : "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(BrandPalette.gold)

                Text(product.ratingDisplayValue ?? "Rating pending")
                    .font(.system(size: 11, weight: .light))
                    .tracking(2)
                    .foregroundStyle(BrandPalette.textSecondary)

                if let reviewVolumeText = product.reviewVolumeText {
                    Text(reviewVolumeText)
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(BrandPalette.textMuted)
                }
            }

            ctaRow
        }
    }

    private func miniStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 7, weight: .light))
                .tracking(4)
                .foregroundStyle(BrandPalette.textMuted)

            Text(value)
                .font(.system(size: 10, weight: .light))
                .tracking(1.5)
                .foregroundStyle(BrandPalette.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.boutGlassBottom)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.boutBorder, lineWidth: 0.5)
                )
        )
    }

    private var sizeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIZE")
                .font(.system(size: 8, weight: .light))
                .tracking(5)
                .foregroundStyle(BrandPalette.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(product.sizes, id: \.self) { size in
                        let isSelected = selectedSize == size

                        Button {
                            withAnimation(.spring(response: 0.28)) {
                                selectedSize = isSelected ? nil : size
                            }
                            BrandHaptics.selection()
                        } label: {
                            Text(size)
                                .font(.system(size: 11, weight: .light))
                                .tracking(2)
                                .foregroundStyle(isSelected ? BrandPalette.gold : BrandPalette.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? Color.boutGold.opacity(0.14) : Color.boutGlassBottom)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(
                                                    isSelected ? Color.boutGold.opacity(0.5) : Color.boutBorder,
                                                    lineWidth: 1
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var colorSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("COLOR")
                    .font(.system(size: 8, weight: .light))
                    .tracking(5)
                    .foregroundStyle(BrandPalette.textMuted)

                if let selectedColor {
                    Text("- \(selectedColor.name)")
                        .font(BrandFont.serif(12, relativeTo: .caption))
                        .italic()
                        .foregroundStyle(BrandPalette.textSecondary)
                }
            }

            HStack(spacing: 10) {
                ForEach(product.colors, id: \.self) { colorway in
                    let isSelected = selectedColor == colorway

                    Button {
                        withAnimation(.spring(response: 0.28)) {
                            selectedColor = isSelected ? nil : colorway
                        }
                        BrandHaptics.selection()
                    } label: {
                        Circle()
                            .fill(Color(hex: colorway.hex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected ? Color.boutGold.opacity(0.9) : Color.boutBorderStrong,
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .scaleEffect(isSelected ? 1.12 : 1.0)
                            .animation(.spring(response: 0.28), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ctaRow: some View {
        HStack(spacing: 10) {
            Button(action: onViewDetails) {
                HStack(spacing: 6) {
                    Text("View")
                        .font(.system(size: 10, weight: .light))
                        .tracking(3)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .light))
                }
                .foregroundStyle(BrandPalette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.boutGlassBottom)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.boutBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button(action: onAddToCart) {
                HStack(spacing: 6) {
                    Image(systemName: cartLoading ? "arrow.triangle.2.circlepath" : (addedToCart ? "checkmark" : "bag"))
                        .font(.system(size: 14, weight: .light))

                    Text(!product.isInStock ? "Out of Stock" : (cartLoading ? "Adding..." : (addedToCart ? "Added" : "Add to Bag")))
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                }
                .foregroundStyle(Color.boutCreamTop)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    Capsule(style: .continuous)
                        .fill(addedToCart ? Color.boutButtonStart.opacity(0.86) : Color.boutButtonEnd)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    Color.boutButtonStart.opacity(addedToCart ? 0.45 : 0.65),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: BrandPalette.gold.opacity(0.18), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(.plain)
            .disabled(cartLoading || !product.isInStock)
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                detailsExpanded.toggle()
            }
            BrandHaptics.selection()
        } label: {
            HStack(spacing: 8) {
                Text(detailsExpanded ? "Show Less" : "Show More")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.8)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .rotationEffect(.degrees(detailsExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: 0.22), value: detailsExpanded)
            }
            .foregroundStyle(BrandPalette.textPrimary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.boutGlassBottom)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.boutBorder, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func detailChip(icon: String, title: String, tint: Color = BrandPalette.gold) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(BrandPalette.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.boutGlassBottom)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.boutBorder, lineWidth: 0.5)
                )
        )
    }
}

public struct ProductCardView: View {
    public enum CardStyle: String, CaseIterable, Hashable {
        case list
        case grid
        case fullscreen
    }

    static let excluded: Set<String> = Product.excludedNames

    @Environment(AurelienStore.self) private var store

    let product: Product
    var style: CardStyle = .list
    var compact: Bool = false

    @State private var currentImage = 0
    @State private var addedToCart = false
    @State private var cartLoading = false
    @State private var detailsExpanded = false
    @State private var selectedSize: String?
    @State private var selectedColor: Colorway?
    @State private var feedbackError: String?
    @State private var showDetails = false

    private var inWishlist: Bool {
        store.isWishlisted(product)
    }

    private var radius: CGFloat {
        style == .fullscreen ? 22 : 18
    }

    private var cleanImages: [String] {
        let images = product.images.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return images.isEmpty ? [product.heroImageName] : images
    }

    private var badgeStyle: ProductBadgeStyle? {
        ProductBadgeStyle(product.badge)
    }

    public var body: some View {
        if !product.isValid || Self.excluded.contains(product.name) || product.isExcluded {
            EmptyView()
        } else {
            cardBody
                .contentShape(Rectangle())
                .onTapGesture {
                    guard style != .fullscreen else { return }
                    showDetails = true
                    BrandHaptics.selection()
                }
                .navigationDestination(isPresented: $showDetails) {
                    ProductDetailView(product: product)
                }
                .onAppear {
                    if style == .fullscreen {
                        detailsExpanded = true
                    }
                    if product.sizes.count == 1 {
                        selectedSize = product.sizes.first
                    }
                    if product.colors.count == 1 {
                        selectedColor = product.colors.first
                    }
                }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        switch style {
        case .list:
            listCard
        case .grid, .fullscreen:
            glassCard
        }
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ProductCardGalleryImage(name: cleanImages.first ?? product.heroImageName)
                    .scaledToFill()
                    .frame(width: 126, height: 176)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: BrandRadius.image, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .clear, BrandPalette.background.opacity(0.24)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BrandRadius.image, style: .continuous))
                    )
                    .overlay(listBadgeOverlay, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.category.title.uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(2.4)
                                .foregroundStyle(BrandPalette.textSecondary)

                            Text(product.name)
                                .font(BrandFont.serif(18, relativeTo: .headline))
                                .fontWeight(.semibold)
                                .foregroundStyle(BrandPalette.textPrimary)
                                .lineLimit(2)

                            Text(product.summary)
                                .font(.caption)
                                .foregroundStyle(BrandPalette.textSecondary.opacity(0.85))
                                .lineSpacing(3)
                                .lineLimit(3)
                        }

                        Spacer(minLength: 0)

                        listWishlistButton
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            listInfoChip(
                                icon: product.ratingDisplayValue == nil ? "sparkles" : "star.fill",
                                title: product.ratingDisplayValue ?? "New arrival",
                                tint: product.ratingDisplayValue == nil ? BrandPalette.textPrimary : BrandPalette.gold
                            )

                            listInfoChip(
                                icon: "shippingbox",
                                title: product.delivery.isEmpty ? product.availabilityNote : product.delivery
                            )

                            if let primaryColor = product.colors.first {
                                listInfoChip(
                                    icon: "circle.fill",
                                    title: product.colors.count > 1 ? "\(primaryColor.name) +\(product.colors.count - 1)" : primaryColor.name,
                                    tint: Color(hex: primaryColor.hex)
                                )
                            }

                            if !product.sizes.isEmpty {
                                listInfoChip(
                                    icon: "ruler",
                                    title: product.sizes.count == 1 ? product.sizes[0] : "\(product.sizes.count) sizes"
                                )
                            }
                        }
                    }

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Price".uppercased())
                                .font(.system(size: 9, weight: .medium))
                                .tracking(1.6)
                                .foregroundStyle(BrandPalette.textSecondary.opacity(0.7))

                            Text(BrandFormatter.price(product.price))
                                .font(BrandFont.serif(22, relativeTo: .headline))
                                .foregroundStyle(BrandPalette.gold)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(product.isInStock ? (product.isLowStock ? BrandPalette.rose : BrandPalette.sage) : Color.red.opacity(0.82))
                                .frame(width: 7, height: 7)

                            Text(product.stockLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(BrandPalette.textSecondary)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: { showDetails = true }) {
                    HStack(spacing: 6) {
                        Text("View Details")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                            .fill(BrandPalette.surfaceRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(action: handleQuickAddToCart) {
                    HStack(spacing: 6) {
                        Image(systemName: cartLoading ? "arrow.triangle.2.circlepath" : (addedToCart ? "checkmark" : "bag.badge.plus"))
                        Text(!product.isInStock ? "Out of Stock" : (cartLoading ? "Adding..." : (addedToCart ? "Added" : "Add to Bag")))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.accentForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                            .fill(BrandPalette.goldGradient)
                    )
                }
                .buttonStyle(.plain)
                .disabled(cartLoading || !product.isInStock)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.boutGlassTop, Color.boutGlassBottom, BrandPalette.surfaceRaised],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
        .shadow(color: BrandPalette.shadowSoft, radius: 10, x: 0, y: 6)
    }

    private var glassCard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.boutGlassTop, Color.boutGlassBottom, Color.boutCream.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.boutBorderStrong, lineWidth: 1)
                )

            ZStack {
                RadialGradient(
                    colors: [Color.boutCreamTop.opacity(0.46), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 100
                )
                RadialGradient(
                    colors: [BrandPalette.gold.opacity(0.10), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 90
                )
            }
            .allowsHitTesting(false)

            if style == .fullscreen {
                fullScreenLayout
            } else {
                gridLayout
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, BrandPalette.gold.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(
            color: BrandPalette.shadowMedium,
            radius: style == .fullscreen ? 24 : 14,
            x: 0,
            y: style == .fullscreen ? 16 : 8
        )
    }

    private var gridLayout: some View {
        VStack(spacing: 0) {
            ProductCardCarousel(
                images: cleanImages,
                badgeStyle: badgeStyle,
                inWishlist: inWishlist,
                onWishlist: handleWishlist,
                currentIndex: $currentImage
            )
            .aspectRatio(4 / 5, contentMode: .fit)

            ProductCardDetailsPanel(
                product: product,
                style: .grid,
                compact: compact,
                selectedSize: $selectedSize,
                selectedColor: $selectedColor,
                addedToCart: $addedToCart,
                cartLoading: $cartLoading,
                feedbackError: $feedbackError,
                detailsExpanded: $detailsExpanded,
                onAddToCart: handleConfiguredAddToCart,
                onViewDetails: { showDetails = true }
            )
        }
    }

    private var fullScreenLayout: some View {
        ZStack(alignment: .bottom) {
            ProductCardCarousel(
                images: cleanImages,
                badgeStyle: badgeStyle,
                inWishlist: inWishlist,
                onWishlist: handleWishlist,
                currentIndex: $currentImage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ProductCardDetailsPanel(
                product: product,
                style: .fullscreen,
                compact: false,
                selectedSize: $selectedSize,
                selectedColor: $selectedColor,
                addedToCart: $addedToCart,
                cartLoading: $cartLoading,
                feedbackError: $feedbackError,
                detailsExpanded: $detailsExpanded,
                onAddToCart: handleConfiguredAddToCart,
                onViewDetails: { showDetails = true }
            )
        }
    }

    private var listWishlistButton: some View {
        Button(action: handleWishlist) {
            Image(systemName: inWishlist ? "heart.fill" : "heart")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(inWishlist ? BrandPalette.gold : BrandPalette.textSecondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(BrandPalette.overlay.opacity(0.72))
                        .background(.ultraThinMaterial, in: Circle())
                )
                .overlay(
                    Circle()
                        .stroke(inWishlist ? BrandPalette.goldBorder : BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func listInfoChip(icon: String, title: String, tint: Color = BrandPalette.gold) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.caption2)
                .foregroundStyle(BrandPalette.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(BrandPalette.surfaceRaised)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private var listBadgeOverlay: some View {
        if let badgeStyle {
            Text(badgeStyle.label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(badgeStyle.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeStyle.background, in: Capsule(style: .continuous))
                .padding(10)
        }
    }

    private func handleWishlist() {
        guard product.isValid else { return }
        store.toggleWishlist(for: product)
    }

    private func handleQuickAddToCart() {
        guard !cartLoading else { return }
        guard product.isInStock else {
            showError("\(product.name) is out of stock.")
            return
        }

        cartLoading = true
        BrandHaptics.selection()

        Task {
            do {
                let size = product.sizes.first ?? "Not specified"
                let color = product.colors.first ?? Colorway(name: "Not specified", hex: 0xFFFFFF)
                try await store.addCartLine(product: product, size: size, color: color)

                await MainActor.run {
                    cartLoading = false
                    withAnimation(.spring(response: 0.3)) {
                        addedToCart = true
                    }
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation {
                        addedToCart = false
                    }
                }
            } catch {
                await MainActor.run {
                    cartLoading = false
                    showError((error as? APIError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
    }

    private func handleConfiguredAddToCart() {
        guard cartLoading == false else { return }
        guard product.isInStock else {
            showError("\(product.name) is out of stock.")
            return
        }

        if product.sizes.count > 1 && selectedSize == nil {
            showError("Please select a size.")
            return
        }

        if product.colors.count > 1 && selectedColor == nil {
            showError("Please select a color.")
            return
        }

        cartLoading = true
        BrandHaptics.selection()

        Task {
            do {
                let size = selectedSize ?? product.sizes.first ?? "Not specified"
                let color = selectedColor ?? product.colors.first ?? Colorway(name: "Not specified", hex: 0xFFFFFF)

                try await store.addCartLine(product: product, size: size, color: color)

                await MainActor.run {
                    cartLoading = false

                    withAnimation(.spring(response: 0.3)) {
                        addedToCart = true
                    }
                }

                try? await Task.sleep(nanoseconds: 2_200_000_000)
                await MainActor.run {
                    withAnimation {
                        addedToCart = false
                    }
                }
            } catch {
                await MainActor.run {
                    cartLoading = false
                    showError((error as? APIError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ message: String) {
        withAnimation {
            feedbackError = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation {
                    feedbackError = nil
                }
            }
        }
    }
}

extension Product {
    static var preview: Product {
        Product(
            id: "1",
            name: "Black Minimal Leather Jacket",
            category: .jackets,
            price: 1199,
            summary: "A quiet leather essential with clean shoulders and a darker finish.",
            story: "Built as a foundational outer layer for evenings and colder city movement.",
            imageNames: ["lether.jpg"],
            sizes: ["S", "M", "L", "XL"],
            colors: [Colorway(name: "Black", hex: 0x131313)],
            composition: "100% leather",
            care: "Specialist clean only",
            delivery: "2-4 business days",
            returns: "7-day returns",
            badge: .newArrival,
            featured: true
        )
    }

    static var previewCompact: Product {
        Product(
            id: "2",
            name: "Vintage Knit Cardigan",
            category: .knitwear,
            price: 1249,
            summary: "A layered cardigan-jacket hybrid with a controlled winter texture.",
            story: "A softer knit layer shaped to keep volume refined and easy on the body.",
            imageNames: ["Knitwear.jpg"],
            sizes: ["S", "M", "L"],
            colors: [Colorway(name: "Ivory", hex: 0xF2EBD9)],
            composition: "Wool blend",
            care: "Dry clean only",
            delivery: "2-4 business days",
            returns: "7-day returns",
            badge: .editorialPick,
            featured: false
        )
    }
}

#Preview("List") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ProductCardView(product: .preview, style: .list)
                ProductCardView(product: .previewCompact, style: .list)
            }
            .padding(16)
        }
        .background(BrandPalette.background)
        .environment(AurelienStore())
    }
}

#Preview("Grid") {
    NavigationStack {
        ProductCardView(product: .preview, style: .grid)
            .frame(width: 200)
            .padding()
            .background(BrandPalette.background)
            .environment(AurelienStore())
    }
}

#Preview("Full-screen") {
    NavigationStack {
        ProductCardView(product: .preview, style: .fullscreen)
            .frame(width: 390, height: 720)
            .background(BrandPalette.background)
            .environment(AurelienStore())
    }
}
