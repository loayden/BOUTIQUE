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
            return BrandPalette.steel.opacity(0.90)
        case .bestseller:
            return BrandPalette.gold.opacity(0.94)
        case .trending:
            return BrandPalette.rose.opacity(0.90)
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
                case .failure:
                    fallbackImage ?? placeholder
                default:
                    fallbackImage ?? placeholder
                }
            }
        } else {
            MediaImage(name: name)
        }
    }

    private var fallbackImage: AnyView? {
        guard let fallbackName = URL(string: name)?.lastPathComponent,
              let image = BrandMediaLibrary.image(named: fallbackName) else {
            return nil
        }

        return AnyView(
            Image(uiImage: image)
                .resizable()
        )
    }

    private var placeholder: AnyView {
        AnyView(
            Rectangle()
                .fill(BrandPalette.productMediaBackground)
        )
    }
}

private struct ProductCardMedia: View {
    let images: [String]
    let badgeStyle: ProductBadgeStyle?
    let inWishlist: Bool
    let onWishlist: () -> Void

    @Binding var currentIndex: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottom) {
                if images.count > 1 {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            mediaFrame(for: image)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    mediaFrame(for: images.first ?? "")
                }

                LinearGradient(
                    colors: [.clear, .clear, BrandPalette.background.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                if images.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(images.indices, id: \.self) { index in
                            Capsule(style: .continuous)
                                .fill(index == currentIndex ? BrandPalette.goldDeep : Color.white.opacity(0.60))
                                .frame(width: index == currentIndex ? 18 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
                }
            }
            .background(BrandPalette.productMediaBackground)

            VStack(alignment: .trailing, spacing: 10) {
                if let badgeStyle {
                    Text(badgeStyle.label.uppercased())
                        .font(BrandFont.mobileCaption2())
                        .tracking(1.8)
                        .foregroundStyle(badgeStyle.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(badgeStyle.background, in: Capsule(style: .continuous))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onWishlist) {
                    Image(systemName: inWishlist ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(inWishlist ? BrandPalette.goldDeep : BrandPalette.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(BrandPalette.backgroundWarm.opacity(0.94))
                        )
                        .overlay(
                            Circle()
                                .stroke(inWishlist ? BrandPalette.goldBorder : BrandPalette.hairlineStrong, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
        }
    }

    private func mediaFrame(for image: String) -> some View {
        ProductCardGalleryImage(name: image)
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandPalette.productMediaBackground)
            .clipped()
    }
}

private struct ProductCardDetailsPanel: View {
    let product: Product
    let style: ProductCardView.CardStyle
    let compact: Bool
    let primaryActionTitle: String

    @Binding var selectedSize: String?
    @Binding var selectedColor: Colorway?
    @Binding var addedToCart: Bool
    @Binding var cartLoading: Bool
    @Binding var feedbackError: String?

    let onPrimaryAction: () -> Void
    let onViewDetails: () -> Void

    private var isFullscreen: Bool {
        style == .fullscreen
    }

    private var titleFont: Font {
        if isFullscreen {
            return BrandFont.serif(26, relativeTo: .title2)
        }
        return BrandFont.serif(compact ? 17 : 20, relativeTo: .headline)
    }

    private var summaryLineLimit: Int {
        if isFullscreen {
            return 4
        }
        return compact ? 2 : 3
    }

    private var supportingText: String {
        if let reviewVolumeText = product.reviewVolumeText {
            return reviewVolumeText
        }
        return product.delivery.isEmpty ? product.availabilityNote : product.delivery
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isFullscreen ? 16 : 12) {
            if let feedbackError {
                Text(feedbackError)
                    .font(BrandFont.mobileCaption2())
                    .foregroundStyle(BrandPalette.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(BrandPalette.error.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(BrandPalette.error.opacity(0.18), lineWidth: 0.5)
                            )
                    )
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.category.title.uppercased())
                        .font(BrandFont.mobileCaption2())
                        .tracking(2.4)
                        .foregroundStyle(BrandPalette.textSecondary)

                    Text(product.name)
                        .font(titleFont)
                        .foregroundStyle(BrandPalette.textPrimary)
                        .lineLimit(isFullscreen ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                availabilityPill
            }

            Text(product.summary)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineSpacing(3)
                .lineLimit(summaryLineLimit)

            HStack(alignment: .firstTextBaseline) {
                Text(BrandFormatter.price(product.price))
                    .font(BrandFont.serif(isFullscreen ? 30 : 24, relativeTo: .title3))
                    .foregroundStyle(BrandPalette.goldDeep)

                Spacer(minLength: 12)

                if let rating = product.ratingDisplayValue {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(rating)
                            .font(BrandFont.mobileCaption2())
                    }
                    .foregroundStyle(BrandPalette.goldDeep)
                }
            }

            if isFullscreen {
                if !product.sizes.isEmpty {
                    sizeSelector
                }

                if !product.colors.isEmpty {
                    colorSelector
                }

                trustStrip
                fullScreenActionRow
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(supportingText)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineLimit(2)

                    Button(action: onPrimaryAction) {
                        HStack(spacing: 8) {
                            Image(systemName: compactActionIcon)
                                .font(.system(size: 13, weight: .medium))
                            Text(primaryActionTitle)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        BrandCapsuleButtonStyle(
                            tone: product.isInStock ? .gold : .chrome,
                            horizontalPadding: 18
                        )
                    )
                    .disabled(cartLoading || (!product.isInStock && primaryActionTitle == "Out of Stock"))
                }
            }
        }
        .padding(isFullscreen ? 18 : 16)
        .background(
            RoundedRectangle(cornerRadius: isFullscreen ? 22 : BrandRadius.card, style: .continuous)
                .fill(isFullscreen ? BrandPalette.backgroundWarm.opacity(0.96) : BrandPalette.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: isFullscreen ? 22 : BrandRadius.card, style: .continuous)
                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
        )
    }

    private var availabilityPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(product.isInStock ? (product.isLowStock ? BrandPalette.rose : BrandPalette.sage) : BrandPalette.error)
                .frame(width: 7, height: 7)

            Text(product.stockLabel.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(1.6)
                .foregroundStyle(product.isInStock ? BrandPalette.textSecondary : BrandPalette.error)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(BrandPalette.backgroundWarm)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
        )
    }

    private var trustStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            trustRow(icon: "shippingbox", text: product.delivery.isEmpty ? "Delivery timing confirmed at checkout." : product.delivery)
            trustRow(icon: "arrow.uturn.backward.circle", text: product.returns)
            trustRow(icon: "checkmark.seal", text: product.availabilityNote)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BrandPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BrandPalette.hairline, lineWidth: 0.5)
                )
        )
    }

    private func trustRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BrandPalette.goldDeep)

            Text(text)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sizeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SIZE")
                .font(BrandFont.mobileCaption2())
                .tracking(2.4)
                .foregroundStyle(BrandPalette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(product.sizes, id: \.self) { size in
                        let isSelected = selectedSize == size

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedSize = size
                            }
                            BrandHaptics.selection()
                        } label: {
                            Text(size)
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(isSelected ? BrandPalette.backgroundWarm : BrandPalette.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? BrandPalette.textPrimary : BrandPalette.backgroundWarm)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(isSelected ? BrandPalette.textPrimary : BrandPalette.hairlineStrong, lineWidth: 0.5)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("COLOR")
                    .font(BrandFont.mobileCaption2())
                    .tracking(2.4)
                    .foregroundStyle(BrandPalette.textSecondary)

                if let selectedColor {
                    Text(selectedColor.name)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(product.colors, id: \.self) { colorway in
                        let isSelected = selectedColor == colorway

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedColor = colorway
                            }
                            BrandHaptics.selection()
                        } label: {
                            Circle()
                                .fill(Color(hex: colorway.hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? BrandPalette.goldDeep : BrandPalette.hairlineStrong, lineWidth: isSelected ? 2 : 1)
                                )
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(BrandPalette.backgroundWarm)
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
        }
    }

    private var fullScreenActionRow: some View {
        VStack(spacing: 10) {
            Button(action: onPrimaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: primaryActionIcon)
                        .font(.system(size: 14, weight: .medium))
                    Text(primaryActionTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold, horizontalPadding: 18))
            .disabled(cartLoading || !product.isInStock)

            Button(action: onViewDetails) {
                HStack(spacing: 8) {
                    Text("View Product")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome, horizontalPadding: 18))
        }
    }

    private var compactActionIcon: String {
        if primaryActionTitle == "Select Options" {
            return "slider.horizontal.3"
        }
        return primaryActionIcon
    }

    private var primaryActionIcon: String {
        if cartLoading {
            return "arrow.triangle.2.circlepath"
        }
        if addedToCart {
            return "checkmark"
        }
        if product.isInStock == false {
            return "xmark"
        }
        return "bag"
    }
}

public struct ProductCardView: View {
    public enum CardStyle: String, CaseIterable, Hashable {
        case list
        case grid
        case fullscreen
    }

    static let imageAspectRatio: CGFloat = 4.0 / 5.0
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
        style == .fullscreen ? 24 : 16
    }

    private var cleanImages: [String] {
        let images = product.images.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return images.isEmpty ? [product.heroImageName] : images
    }

    private var badgeStyle: ProductBadgeStyle? {
        ProductBadgeStyle(product.badge)
    }

    private var requiresVariantSelection: Bool {
        product.sizes.count > 1 || product.colors.count > 1
    }

    private var cardPrimaryActionTitle: String {
        if !product.isInStock {
            return "Out of Stock"
        }
        if cartLoading {
            return "Adding..."
        }
        if addedToCart {
            return "Added"
        }
        return requiresVariantSelection ? "Select Options" : "Add to Bag"
    }

    private var fullScreenPrimaryActionTitle: String {
        if !product.isInStock {
            return "Out of Stock"
        }
        if cartLoading {
            return "Adding..."
        }
        if addedToCart {
            return "Added"
        }
        return "Add to Bag"
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
        case .grid:
            gridCard
        case .fullscreen:
            fullScreenCard
        }
    }

    private var listCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ProductCardMedia(
                images: [cleanImages.first ?? product.heroImageName],
                badgeStyle: badgeStyle,
                inWishlist: inWishlist,
                onWishlist: handleWishlist,
                currentIndex: $currentImage
            )
            .frame(width: 126, height: 126 / Self.imageAspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: BrandRadius.image, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(product.category.title.uppercased())
                    .font(BrandFont.mobileCaption2())
                    .tracking(2.4)
                    .foregroundStyle(BrandPalette.textSecondary)

                Text(product.name)
                    .font(BrandFont.serif(19, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(product.summary)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(2)

                HStack(alignment: .firstTextBaseline) {
                    Text(BrandFormatter.price(product.price))
                        .font(BrandFont.serif(22, relativeTo: .headline))
                        .foregroundStyle(BrandPalette.goldDeep)

                    Spacer(minLength: 12)

                    statusLine
                }

                Button(action: handlePrimaryCardAction) {
                    HStack(spacing: 8) {
                        Image(systemName: compactPrimaryActionIcon)
                            .font(.system(size: 13, weight: .medium))
                        Text(cardPrimaryActionTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    BrandCapsuleButtonStyle(
                        tone: product.isInStock ? .gold : .chrome,
                        horizontalPadding: 18
                    )
                )
                .disabled(cartLoading || (!product.isInStock && cardPrimaryActionTitle == "Out of Stock"))
            }
        }
        .padding(16)
        .background(cardSurface(cornerRadius: BrandRadius.card))
    }

    private var gridCard: some View {
        VStack(spacing: 0) {
            ProductCardMedia(
                images: cleanImages,
                badgeStyle: badgeStyle,
                inWishlist: inWishlist,
                onWishlist: handleWishlist,
                currentIndex: $currentImage
            )
            .aspectRatio(Self.imageAspectRatio, contentMode: .fit)

            ProductCardDetailsPanel(
                product: product,
                style: .grid,
                compact: compact,
                primaryActionTitle: cardPrimaryActionTitle,
                selectedSize: $selectedSize,
                selectedColor: $selectedColor,
                addedToCart: $addedToCart,
                cartLoading: $cartLoading,
                feedbackError: $feedbackError,
                onPrimaryAction: handlePrimaryCardAction,
                onViewDetails: { showDetails = true }
            )
        }
        .background(cardSurface(cornerRadius: radius))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var fullScreenCard: some View {
        VStack(spacing: 0) {
            ProductCardMedia(
                images: cleanImages,
                badgeStyle: badgeStyle,
                inWishlist: inWishlist,
                onWishlist: handleWishlist,
                currentIndex: $currentImage
            )
            .aspectRatio(Self.imageAspectRatio, contentMode: .fit)

            ProductCardDetailsPanel(
                product: product,
                style: .fullscreen,
                compact: false,
                primaryActionTitle: fullScreenPrimaryActionTitle,
                selectedSize: $selectedSize,
                selectedColor: $selectedColor,
                addedToCart: $addedToCart,
                cartLoading: $cartLoading,
                feedbackError: $feedbackError,
                onPrimaryAction: handleConfiguredAddToCart,
                onViewDetails: { showDetails = true }
            )
        }
        .background(BrandPalette.backgroundWarm)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: BrandPalette.shadowMedium, radius: 16, x: 0, y: 8)
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(product.isInStock ? (product.isLowStock ? BrandPalette.rose : BrandPalette.sage) : BrandPalette.error)
                .frame(width: 7, height: 7)

            Text(product.stockLabel)
                .font(BrandFont.mobileCaption2())
                .foregroundStyle(product.isInStock ? BrandPalette.textSecondary : BrandPalette.error)
                .lineLimit(1)
        }
    }

    private var compactPrimaryActionIcon: String {
        if cardPrimaryActionTitle == "Select Options" {
            return "slider.horizontal.3"
        }
        if cartLoading {
            return "arrow.triangle.2.circlepath"
        }
        if addedToCart {
            return "checkmark"
        }
        if product.isInStock == false {
            return "xmark"
        }
        return "bag"
    }

    private func cardSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(BrandPalette.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .shadow(color: BrandPalette.shadowSoft, radius: 10, x: 0, y: 6)
    }

    private func handleWishlist() {
        guard product.isValid else { return }
        store.toggleWishlist(for: product)
    }

    private func handlePrimaryCardAction() {
        if requiresVariantSelection {
            showDetails = true
            BrandHaptics.selection()
            return
        }

        handleQuickAddToCart()
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
                    if let apiError = error as? APIError, case .unauthorized = apiError {
                        store.present(.auth)
                    } else {
                        showError((error as? APIError)?.errorDescription ?? error.localizedDescription)
                    }
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
                    if let apiError = error as? APIError, case .unauthorized = apiError {
                        store.present(.auth)
                    } else {
                        showError((error as? APIError)?.errorDescription ?? error.localizedDescription)
                    }
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
