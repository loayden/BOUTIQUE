import SwiftUI
import UIKit

struct ProductDetailView: View {
    static let commerceImageAspectRatio: CGFloat = 4.0 / 5.0
    static let stickyBarBottomPadding: CGFloat = 28
    static let stickyBarContentPadding: CGFloat = 168

    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chromeState: AppChromeState

    let product: Product

    @State private var selectedSize: String?
    @State private var selectedColor: Colorway?
    @State private var addedToCart = false
    @State private var cartLoading = false
    @State private var actionError: String?
    @State private var showSizeGuide = false
    @State private var galleryIndex = 0

    private var relatedProducts: [Product] {
        store.relatedProducts(for: product)
    }

    private var shareURL: URL {
        var components = URLComponents()
        components.scheme = "boutique"
        components.host = "product"
        components.path = "/\(product.id)"
        return components.url ?? URL(fileURLWithPath: "/product/\(product.id)")
    }

    private var detailRows: [ProductDetailFact] {
        [
            .init(label: "Material", value: product.composition),
            .init(label: "Care", value: product.care),
            .init(label: "Delivery", value: product.delivery),
            .init(label: "Returns", value: product.returns)
        ]
    }

    private var serviceItems: [ProductDetailServiceItem] {
        [
            .init(icon: "shippingbox", title: "Delivery", text: product.delivery.isEmpty ? "Delivery timing is confirmed at checkout." : product.delivery),
            .init(icon: "arrow.uturn.backward.circle", title: "Returns", text: product.returns),
            .init(icon: "checkmark.seal", title: "Availability", text: product.availabilityNote)
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            BrandPalette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    gallerySection

                    VStack(alignment: .leading, spacing: 28) {
                        productSummarySection

                        if !product.sizes.isEmpty || !product.colors.isEmpty {
                            variantSection
                        }

                        servicePanel
                        detailSection

                        if relatedProducts.isEmpty == false {
                            relatedProductsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, Self.stickyBarContentPadding)
                }
            }
            .scrollIndicators(.hidden)

            if let actionError {
                errorBanner(message: actionError)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyPurchaseBar
        }
        .sheet(isPresented: $showSizeGuide) {
            SizeGuideSheet(category: product.category)
        }
        .onAppear {
            chromeState.isTabBarHidden = true
            if selectedColor == nil {
                selectedColor = product.colors.first
            }
            if selectedSize == nil, product.sizes.count == 1 {
                selectedSize = product.sizes.first
            }
        }
        .onDisappear {
            chromeState.isTabBarHidden = false
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
                BrandHaptics.softImpact()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(BrandPalette.backgroundWarm.opacity(0.96), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            ShareLink(item: shareURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(BrandPalette.backgroundWarm.opacity(0.96), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(BrandPalette.background.opacity(0.96))
                .ignoresSafeArea(edges: .top)
        )
    }

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TabView(selection: $galleryIndex) {
                ForEach(Array(product.images.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topLeading) {
                        MediaImage(name: image)
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)

                        if let badge = product.badge {
                            Text(badge.rawValue.uppercased())
                                .font(BrandFont.mobileCaption2())
                                .tracking(1.8)
                                .foregroundStyle(BrandPalette.accentForeground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(BrandPalette.goldDeep, in: Capsule(style: .continuous))
                                .padding(16)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: min(UIScreen.main.bounds.width * 1.16, 520))
            .background(BrandPalette.productMediaBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 0,
                    style: .continuous
                )
            )

            HStack {
            HStack(spacing: 6) {
                ForEach(product.images.indices, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index == galleryIndex ? BrandPalette.goldDeep : BrandPalette.hairlineStrong)
                            .frame(width: index == galleryIndex ? 18 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: galleryIndex)
                    }
                }

                Spacer()

                Text("\(galleryIndex + 1) / \(max(product.images.count, 1))")
                    .font(BrandFont.mobileCaption2())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(BrandPalette.backgroundWarm, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 20)
        }
    }

    private var productSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(product.category.title.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.goldDeep)

            Text(product.name)
                .font(BrandFont.displayHero())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(BrandFormatter.price(product.price))
                    .font(BrandFont.serif(34, relativeTo: .title2))
                    .foregroundStyle(BrandPalette.goldDeep)

                Spacer(minLength: 12)

                availabilityPill
            }

            if product.ratingDisplayValue != nil || product.reviewVolumeText != nil {
                HStack(spacing: 8) {
                    if let rating = product.ratingDisplayValue {
                        Label(rating, systemImage: "star.fill")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.goldDeep)
                    }

                    if let reviewVolumeText = product.reviewVolumeText {
                        Text(reviewVolumeText)
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                }
            }

            Text(product.summary)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineSpacing(5)

            if product.story.isEmpty == false {
                Text(product.story)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineSpacing(4)
            }
        }
    }

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !product.sizes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("SIZE")
                            .font(BrandFont.mobileCaption2())
                            .tracking(2.4)
                            .foregroundStyle(BrandPalette.textSecondary)

                        Spacer()

                        Button("Size Guide") {
                            showSizeGuide = true
                        }
                        .buttonStyle(.plain)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.goldDeep)
                        .frame(minHeight: 44)
                    }

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
                                        .padding(.horizontal, 18)
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

            if !product.colors.isEmpty {
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
        }
    }

    private var servicePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SERVICE")
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.textSecondary)

            VStack(spacing: 14) {
                ForEach(serviceItems) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BrandPalette.goldDeep)
                            .frame(width: 18, height: 18)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(BrandPalette.textPrimary)

                            Text(item.text)
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(BrandPalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BrandPalette.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
            )
        }
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DETAILS")
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(detailRows.enumerated()), id: \.element.id) { index, row in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 18) {
                            Text(row.label.uppercased())
                                .font(BrandFont.mobileCaption2())
                                .tracking(2.4)
                                .foregroundStyle(BrandPalette.textSecondary)
                                .frame(width: 88, alignment: .leading)

                            Text(row.value)
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)

                        if index < detailRows.count - 1 {
                            Divider()
                                .overlay(BrandPalette.hairline)
                                .padding(.leading, 18)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BrandPalette.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
            )
        }
    }

    private var relatedProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RELATED")
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(relatedProducts) { relatedProduct in
                        NavigationLink(value: relatedProduct) {
                            ProductDetailRelatedCard(product: relatedProduct)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var availabilityPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(product.isInStock ? (product.isLowStock ? BrandPalette.rose : BrandPalette.sage) : BrandPalette.error)
                .frame(width: 8, height: 8)

            Text(product.stockLabel.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(1.8)
                .foregroundStyle(product.isInStock ? BrandPalette.textSecondary : BrandPalette.error)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BrandPalette.backgroundWarm, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }

    private var stickyPurchaseBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BrandFormatter.price(product.price))
                        .font(BrandFont.serif(28, relativeTo: .title3))
                        .foregroundStyle(BrandPalette.goldDeep)

                    Text(selectionSummary)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                availabilityPill
            }

            HStack(spacing: 10) {
                Button(action: handleBuyNow) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Buy Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome, horizontalPadding: 18))
                .disabled(cartLoading || !product.isInStock)

                Button(action: handleAddToCart) {
                    HStack(spacing: 8) {
                        Image(systemName: cartLoading ? "arrow.triangle.2.circlepath" : (addedToCart ? "checkmark" : "bag"))
                            .font(.system(size: 13, weight: .medium))
                        Text(!product.isInStock ? "Out of Stock" : (cartLoading ? "Adding..." : (addedToCart ? "Added" : "Add to Bag")))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold, horizontalPadding: 18))
                .disabled(cartLoading || !product.isInStock)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, Self.stickyBarBottomPadding)
        .background(
            Rectangle()
                .fill(BrandPalette.background.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(BrandPalette.hairline)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var selectionSummary: String {
        var parts: [String] = []

        if product.sizes.isEmpty == false {
            parts.append(selectedSize ?? "Select size")
        }

        if product.colors.isEmpty == false {
            parts.append(selectedColor?.name ?? "Select color")
        }

        return parts.isEmpty ? product.availabilityNote : parts.joined(separator: " • ")
    }

    private func errorBanner(message: String) -> some View {
        Text(message)
            .font(BrandFont.mobileCaption())
            .foregroundStyle(BrandPalette.error)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BrandPalette.backgroundWarm)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BrandPalette.error.opacity(0.22), lineWidth: 0.5)
                    )
            )
    }

    private func showError(_ message: String) {
        withAnimation {
            actionError = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation {
                    actionError = nil
                }
            }
        }
    }

    private func handleAddToCart() {
        guard validateSelections() else { return }
        cartLoading = true

        let size = selectedSize ?? (product.sizes.first ?? "Not specified")
        let color = selectedColor ?? (product.colors.first ?? Colorway(name: "Not specified", hex: 0xFFFFFF))

        Task {
            do {
                try await store.addCartLine(product: product, size: size, color: color)

                await MainActor.run {
                    cartLoading = false
                    withAnimation {
                        addedToCart = true
                    }
                }

                try? await Task.sleep(nanoseconds: 2_500_000_000)
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

    private func handleBuyNow() {
        guard validateSelections() else { return }
        cartLoading = true

        let size = selectedSize ?? (product.sizes.first ?? "Not specified")
        let color = selectedColor ?? (product.colors.first ?? Colorway(name: "Not specified", hex: 0xFFFFFF))

        Task {
            do {
                try await store.addCartLine(product: product, size: size, color: color)
                await MainActor.run {
                    cartLoading = false
                    store.selectedTab = .bag
                    dismiss()
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

    @discardableResult
    private func validateSelections() -> Bool {
        if !product.sizes.isEmpty, selectedSize == nil {
            showError("Please select a size first.")
            return false
        }

        if !product.isInStock {
            showError("\(product.name) is out of stock.")
            return false
        }

        if !product.colors.isEmpty, selectedColor == nil {
            showError("Please select a color first.")
            return false
        }

        return true
    }
}

private struct ProductDetailFact: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct ProductDetailServiceItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
}

private struct ProductDetailRelatedCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MediaImage(name: product.heroImageName)
                .scaledToFill()
                .frame(width: 180, height: 180 / ProductDetailView.commerceImageAspectRatio)
                .background(BrandPalette.productMediaBackground)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(product.category.title.uppercased())
                    .font(BrandFont.mobileCaption2())
                    .tracking(2.2)
                    .foregroundStyle(BrandPalette.textSecondary)

                Text(product.name)
                    .font(BrandFont.serif(18, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(BrandFormatter.price(product.price))
                    .font(BrandFont.serif(20, relativeTo: .headline))
                    .foregroundStyle(BrandPalette.goldDeep)
            }
        }
        .frame(width: 180, alignment: .leading)
    }
}

private struct ProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProductDetailView(product: previewProduct)
            .environment(AurelienStore())
            .environmentObject(AppChromeState())
    }
}

private let previewProduct = Product(
    id: "001",
    name: "Riviere Silk Blazer",
    category: .jackets,
    price: 12_500,
    summary: "A tailored silk blazer with a softer shoulder, quiet structure, and a cleaner evening line.",
    story: "Hand-finished seams and a controlled silhouette make it a dependable anchor for quieter editorial dressing.",
    imageNames: [
        "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800",
        "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=800",
        "https://images.unsplash.com/photo-1502163140606-888448ae8cfe?w=800"
    ],
    sizes: ["XS", "S", "M", "L", "XL"],
    colors: [
        Colorway(name: "Black", hex: 0x000000),
        Colorway(name: "Beige", hex: 0xE6DAC6),
        Colorway(name: "Navy", hex: 0x0F173B),
        Colorway(name: "Gold", hex: 0xC9A86A)
    ],
    composition: "100% Mulberry Silk",
    care: "Dry clean only.",
    delivery: "2-4 business days.",
    returns: "7-day returns.",
    badge: .newArrival,
    featured: true
)

private struct SizeGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: ProductCategory

    private var rows: [(String, String, String)] {
        switch category {
        case .pants, .denim, .jeans:
            return [("S", "28-30 in", "71-76 cm"), ("M", "31-33 in", "79-84 cm"), ("L", "34-36 in", "86-91 cm"), ("XL", "37-39 in", "94-99 cm")]
        case .footwear, .loafers, .sneakers, .boots:
            return [("40", "US 7", "25.4 cm"), ("41", "US 8", "26.0 cm"), ("42", "US 9", "26.7 cm"), ("43", "US 10", "27.3 cm"), ("44", "US 11", "27.9 cm")]
        default:
            return [("S", "35-37 in", "89-94 cm"), ("M", "38-40 in", "96-101 cm"), ("L", "41-43 in", "104-109 cm"), ("XL", "44-46 in", "112-117 cm")]
        }
    }

    private var measurementTitle: String {
        switch category {
        case .pants, .denim, .jeans:
            return "Waist"
        case .footwear, .loafers, .sneakers, .boots:
            return "Equivalent"
        default:
            return "Chest"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Size Guide")
                    .font(BrandFont.displayHero())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Use this as a fit starting point. Final measurements and variant availability still come from the live catalog.")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineSpacing(4)

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                    GridRow {
                        sizeGuideHeader("Size")
                        sizeGuideHeader(measurementTitle)
                        sizeGuideHeader("Metric")
                    }

                    ForEach(rows, id: \.0) { row in
                        GridRow {
                            sizeGuideValue(row.0)
                            sizeGuideValue(row.1)
                            sizeGuideValue(row.2)
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                        )
                )

                Spacer()
            }
            .padding(20)
            .background(BrandPalette.background.ignoresSafeArea())
            .navigationTitle("Fit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(BrandPalette.goldDeep)
                }
            }
        }
    }

    private func sizeGuideHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(BrandFont.mobileCaption2())
            .tracking(2.2)
            .foregroundStyle(BrandPalette.textSecondary)
    }

    private func sizeGuideValue(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.mobileBody())
            .foregroundStyle(BrandPalette.textPrimary)
            .frame(minHeight: 32, alignment: .leading)
    }
}
