import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ─────────────────────────────────────────────
// MARK: - Design Tokens
// ─────────────────────────────────────────────

extension Color {
    static let darkBG    = Color.boutCream
    static let gold      = Color.boutGoldText
    static let cream10   = Color.boutBorder
    static let cream25   = Color.boutInk.opacity(0.55)
    static let cream45   = Color.boutInk.opacity(0.72)
    static let cream60   = Color.boutInkSoft
}

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.boutBorder, lineWidth: 1)
                    )
            )
    }
}

struct GoldGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.gold.opacity(0.22), Color.gold.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.gold.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassBackground()) }
    func goldGlassCard() -> some View { modifier(GoldGlassBackground()) }
}

// ─────────────────────────────────────────────
// MARK: - Product Detail View
// ─────────────────────────────────────────────

struct ProductDetailView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let product: Product

    @State private var selectedSize: String?
    @State private var selectedColor: Colorway?
    @State private var addedToCart = false
    @State private var cartLoading = false
    @State private var actionError: String? = nil
    @State private var activeTab: Tab = .specs
    @State private var heroAppeared = false
    @State private var showSizeGuide = false

    enum Tab { case specs, details }

    private var relatedProducts: [Product] {
        store.relatedProducts(for: product)
    }

    var body: some View {
        ZStack {
            BrandPalette.backgroundGradient.ignoresSafeArea()
            ambientGlows

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    breadcrumb
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    HorizontalScrollGallery(images: product.images, productName: product.name)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 40)
                        .opacity(heroAppeared ? 1 : 0)
                        .offset(y: heroAppeared ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: heroAppeared)

                    productInfo
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)

                    detailsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)

                    if relatedProducts.isEmpty == false {
                        relatedProductsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }

                    Color.clear.frame(height: 40)
                }
            }
            .scrollIndicators(.never)

            if let error = actionError {
                VStack {
                    errorToast(message: error)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyPurchaseBar
        }
        .sheet(isPresented: $showSizeGuide) {
            SizeGuideSheet(category: product.category)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { heroAppeared = true }
            if selectedColor == nil {
                selectedColor = product.colors.first
            }
            if selectedSize == nil && product.sizes.count == 1 {
                selectedSize = product.sizes.first
            }
        }
    }

    private var ambientGlows: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [Color.boutGold.opacity(0.08), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.9
                )
                RadialGradient(
                    colors: [Color.boutCreamTop.opacity(0.40), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.7
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Text("Shop")
            Image(systemName: "chevron.right").font(.system(size: 8))
            Text(product.category.title)
            Image(systemName: "chevron.right").font(.system(size: 8))
            Text(product.name).foregroundStyle(Color.cream45)
        }
        .font(.system(size: 9, weight: .light))
        .tracking(4)
        .foregroundStyle(Color.cream25)
    }

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(product.category.title.uppercased())
                .font(.system(size: 8, weight: .light))
                .tracking(6)
                .foregroundStyle(Color.gold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.gold.opacity(0.08))
                        .overlay(Capsule().stroke(Color.gold.opacity(0.2), lineWidth: 1))
                )
                .padding(.bottom, 20)

            Text(product.name)
                .font(.custom("Cormorant Garamond", size: 48))
                .fontWeight(.light)
                .foregroundStyle(BrandPalette.textPrimary)
                .lineSpacing(4)
                .padding(.bottom, 20)

            starRating
                .padding(.bottom, 28)

            priceBlock
                .padding(.bottom, 24)

            stockSignal
                .padding(.bottom, 24)

            Rectangle()
                .fill(LinearGradient(colors: [Color.gold.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 40, height: 1)
                .padding(.bottom, 24)

            Text(product.summary)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Color.cream45)
                .lineSpacing(6)
                .padding(.bottom, 32)

            if !product.sizes.isEmpty {
                sizeSelector.padding(.bottom, 28)
            }

            if !product.colors.isEmpty {
                colorSelector.padding(.bottom, 36)
            }

            Divider().overlay(Color.boutBorder)
            ShareButtons(product: product).padding(.top, 20)
        }
    }

    private var starRating: some View {
        HStack(spacing: 8) {
            Image(systemName: product.ratingDisplayValue == nil ? "star.slash" : "star.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.yellow)

            Text(product.ratingDisplayValue.map { "\($0) / 5" } ?? "Rating pending")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundStyle(Color.cream45)

            if let reviewVolumeText = product.reviewVolumeText {
                Text(reviewVolumeText)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color.cream25)
            }
        }
    }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRICE")
                .font(.system(size: 10, weight: .light))
                .tracking(6)
                .foregroundStyle(Color.cream45)

            Text("EGP \(Int(product.price).formatted())")
                .font(.custom("Cormorant Garamond", size: 36))
                .fontWeight(.light)
                .foregroundStyle(Color.gold)
        }
    }

    private var stockSignal: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(product.isInStock ? (product.isLowStock ? Color.orange : Color.gold) : Color.red)
                .frame(width: 8, height: 8)

            Text(product.stockLabel.uppercased())
                .font(.system(size: 10, weight: .light))
                .tracking(4)
                .foregroundStyle(product.isInStock ? Color.cream45 : Color.red.opacity(0.9))
        }
    }

    private var sizeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SIZE")
                    .font(.system(size: 9, weight: .light))
                    .tracking(6)
                    .foregroundStyle(Color.cream25)

                Spacer()

                Button("Size Guide") {
                    showSizeGuide = true
                }
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Color.gold)
                .frame(minHeight: 44)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(product.sizes, id: \.self) { size in
                        let chosen = selectedSize == size
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedSize = size }
                        } label: {
                            Text(size)
                                .font(.system(size: 13, weight: .light))
                                .tracking(2)
                                .foregroundStyle(chosen ? Color.gold : Color.cream60)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(chosen ? Color.boutGold.opacity(0.14) : Color.boutGlassBottom)
                                        .overlay(
                                            Capsule().stroke(
                                                chosen ? Color.boutGold.opacity(0.5) : Color.boutBorder,
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("COLOR")
                    .font(.system(size: 9, weight: .light))
                    .tracking(6)
                    .foregroundStyle(Color.cream25)

                if let c = selectedColor {
                    Text("— \(c.name)")
                        .font(.custom("Cormorant Garamond", size: 14))
                        .italic()
                        .foregroundStyle(Color.cream45)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(product.colors, id: \.self) { colorName in
                        let chosen = selectedColor == colorName
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedColor = colorName }
                        } label: {
                            Circle()
                                .fill(Color(hex: colorName.hex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().stroke(
                                        chosen ? Color.boutGold.opacity(0.9) : Color.boutBorderStrong,
                                        lineWidth: chosen ? 2 : 1
                                    )
                                )
                                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                                .shadow(color: chosen ? Color.gold.opacity(0.25) : .clear, radius: 10, x: 0, y: 0)
                                .scaleEffect(chosen ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3), value: chosen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button(action: handleAddToCart) {
                HStack(spacing: 12) {
                    Image(systemName: cartLoading ? "arrow.triangle.2.circlepath" : (addedToCart ? "checkmark" : "bag"))
                        .font(.system(size: 18, weight: .light))
                    Text(cartLoading ? "Adding..." : addedToCart ? "Added" : "Add to Bag")
                        .font(.system(size: 11, weight: .light))
                        .tracking(4)
                }
                .foregroundStyle(addedToCart ? Color.boutGoldText : Color.boutCreamTop)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background {
                    if addedToCart {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.gold.opacity(0.22), Color.gold.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.gold.opacity(0.28), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.boutBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 56)
            .disabled(cartLoading || !product.isInStock)

            Button(action: handleBuyNow) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .light))
                    Text("Buy Now")
                        .font(.system(size: 11, weight: .light))
                        .tracking(4)
                }
                .foregroundStyle(Color.boutGoldText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .goldGlassCard()
            }
            .buttonStyle(.plain)
            .frame(minHeight: 56)
            .disabled(cartLoading || !product.isInStock)
        }
    }

    private var stickyPurchaseBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BrandFormatter.price(product.price))
                        .font(.custom("Cormorant Garamond", size: 28))
                        .fontWeight(.light)
                        .foregroundStyle(Color.gold)

                    Text(selectionSummary)
                        .font(.system(size: 11, weight: .light))
                        .tracking(1.6)
                        .foregroundStyle(Color.cream45)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Button(action: handleBuyNow) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .light))
                        Text("Buy Now")
                            .font(.system(size: 11, weight: .light))
                            .tracking(3)
                    }
                    .foregroundStyle(Color.boutGoldText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: 48)
                    .goldGlassCard()
                }
                .buttonStyle(.plain)
                .disabled(cartLoading || !product.isInStock)
            }

            Button(action: handleAddToCart) {
                HStack(spacing: 12) {
                    Image(systemName: cartLoading ? "arrow.triangle.2.circlepath" : (addedToCart ? "checkmark" : "bag"))
                        .font(.system(size: 18, weight: .light))
                    Text(!product.isInStock ? "Out of Stock" : (cartLoading ? "Adding..." : addedToCart ? "Added to Bag" : "Add to Bag"))
                        .font(.system(size: 12, weight: .light))
                        .tracking(3.4)
                }
                .foregroundStyle(Color.boutCreamTop)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            .disabled(cartLoading || !product.isInStock)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(Color.boutGlassTop)
                .background(.thinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.boutBorder)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var selectionSummary: String {
        let sizeLabel = selectedSize ?? (product.sizes.isEmpty ? "No size selection" : "Select size")
        let colorLabel = selectedColor?.name ?? (product.colors.isEmpty ? "No color selection" : "Select color")
        return "\(sizeLabel) • \(colorLabel)"
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CRAFTSMANSHIP")
                    .font(.system(size: 9, weight: .light))
                    .tracking(6)
                    .foregroundStyle(Color.cream25)

                Text("Product Details")
                    .font(.custom("Cormorant Garamond", size: 32))
                    .fontWeight(.light)
                    .foregroundStyle(Color.gold)
            }

            HStack(spacing: 0) {
                tabButton(label: "Specifications", icon: "square.3.layers.3d", tab: .specs)
                tabButton(label: "Highlights", icon: "star.circle", tab: .details)
            }
            .overlay(
                Divider().frame(maxWidth: .infinity, maxHeight: 1).offset(y: 20),
                alignment: .bottom
            )

            Group {
                if activeTab == .specs {
                    SpecificationsTab(specs: product.detailSpecs)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    HighlightsTab(highlights: product.detailHighlights)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: activeTab)
        }
    }

    @ViewBuilder
    private func tabButton(label: String, icon: String, tab: Tab) -> some View {
        let active = activeTab == tab
        Button {
            withAnimation { activeTab = tab }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 13, weight: .light))
                    Text(label.uppercased()).font(.system(size: 11, weight: .light)).tracking(3)
                }
                .foregroundStyle(active ? Color.boutGoldText : Color.cream45)
                Rectangle()
                    .fill(active ? Color.yellow : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func errorToast(message: String) -> some View {
        HStack {
            Text(message.uppercased())
                .font(.system(size: 10, weight: .light))
                .tracking(3)
                .foregroundStyle(Color(red: 1, green: 0.47, blue: 0.47))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
    }

    private func showError(_ msg: String) {
        withAnimation { actionError = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { actionError = nil }
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
                    withAnimation { addedToCart = true }
                }

                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    withAnimation { addedToCart = false }
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
        if !product.sizes.isEmpty && selectedSize == nil {
            showError("Please select a size first.")
            return false
        }
        if !product.isInStock {
            showError("\(product.name) is out of stock.")
            return false
        }
        if !product.colors.isEmpty && selectedColor == nil {
            showError("Please select a color first.")
            return false
        }
        return true
    }
}

private extension ProductDetailView {
    var relatedProductsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RELATED PRODUCTS")
                    .font(.system(size: 9, weight: .light))
                    .tracking(8)
                    .foregroundStyle(Color.cream25)

                Text("Continue the edit")
                    .font(.custom("Cormorant Garamond", size: 28))
                    .fontWeight(.light)
                    .foregroundStyle(BrandPalette.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(relatedProducts) { relatedProduct in
                        NavigationLink(value: relatedProduct) {
                            RelatedProductCard(product: relatedProduct)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ProductSpec: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct ProductHighlight: Identifiable {
    let id = UUID()
    let title: String
    let desc: String
    let icon: String
}

private extension Product {
    var detailSpecs: [ProductSpec] {
        [
            ProductSpec(label: "Material", value: composition),
            ProductSpec(label: "Care", value: care),
            ProductSpec(label: "Delivery", value: delivery),
            ProductSpec(label: "Returns", value: returns)
        ]
    }

    var detailHighlights: [ProductHighlight] {
        var items: [ProductHighlight] = [
            ProductHighlight(title: "Ready for Dispatch", desc: availabilityNote, icon: "bolt.fill"),
            ProductHighlight(title: "Trusted Quality", desc: "Client services assist with shipping, returns, and premium care.", icon: "checkmark.seal.fill")
        ]

        if let badge = badge {
            items.insert(
                ProductHighlight(title: badge.rawValue, desc: "A curated selection from our boutique collection.", icon: "tag.fill"),
                at: 0
            )
        }

        return items
    }
}

private struct ProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProductDetailView(product: previewProduct)
    }
}

private let previewProduct = Product(
    id: "001",
    name: "Rivière Silk Blazer",
    category: .jackets,
    price: 12_500,
    summary: "A masterpiece of Parisian tailoring, the Rivière Silk Blazer drapes effortlessly.",
    story: "Hand-finished seams and a structured silhouette make it the cornerstone of any curated wardrobe.",
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

struct HorizontalScrollGallery: View {
    let images: [String]
    let productName: String

    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GALLERY")
                    .font(.system(size: 9, weight: .light))
                    .tracking(8)
                    .foregroundStyle(Color.cream25)

                Text("Explore Every Angle")
                    .font(.custom("Cormorant Garamond", size: 28))
                    .fontWeight(.light)
                    .foregroundStyle(BrandPalette.textPrimary)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(images.enumerated()), id: \.offset) { i, image in
                            GalleryCard(
                                imageName: image,
                                productName: productName,
                                index: i,
                                total: images.count,
                                isSelected: selectedIndex == i
                            )
                            .id(i)
                            .onTapGesture { withAnimation(.spring(response: 0.4)) { selectedIndex = i } }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .onChange(of: selectedIndex) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<images.count, id: \.self) { i in
                    Capsule()
                        .fill(selectedIndex == i ? Color.gold : Color.cream25)
                        .frame(width: selectedIndex == i ? 32 : 8, height: 4)
                        .animation(.spring(response: 0.3), value: selectedIndex)
                        .onTapGesture { withAnimation { selectedIndex = i } }
                }
            }
        }
    }
}

private struct RelatedProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.boutGlassBottom)

                MediaImage(name: product.heroImageName)
                    .scaledToFill()
                    .frame(width: 220, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .frame(width: 220, height: 260)

            VStack(alignment: .leading, spacing: 6) {
                Text(product.category.title.uppercased())
                    .font(.system(size: 8, weight: .light))
                    .tracking(4)
                    .foregroundStyle(Color.cream25)

                Text(product.name)
                    .font(.custom("Cormorant Garamond", size: 24))
                    .fontWeight(.light)
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(BrandFormatter.price(product.price))
                    .font(.custom("Cormorant Garamond", size: 22))
                    .fontWeight(.light)
                    .foregroundStyle(Color.gold)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 228, alignment: .leading)
    }
}

private struct GalleryCard: View {
    let imageName: String
    let productName: String
    let index: Int
    let total: Int
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GalleryImage(name: imageName)
                .frame(width: 320, height: 400)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            Text("\(index + 1) / \(total)")
                .font(.system(size: 10, weight: .light))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15).background(.ultraThinMaterial))
                .clipShape(Capsule())
                .padding(16)

            if isSelected {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gold.opacity(0.5), lineWidth: 2)
            }
        }
        .frame(width: 320, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.boutBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 16)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.25), value: isHovered)
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
    }
}

private struct GalleryImage: View {
    let name: String

    var body: some View {
        if let url = URL(string: name), let scheme = url.scheme, scheme.hasPrefix("http") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Rectangle().fill(Color.boutGlassBottom)
                }
            }
        } else {
            MediaImage(name: name)
                .scaledToFill()
        }
    }
}

struct ShareButtons: View {
    let product: Product
    @State private var copied = false

    var shareURL: URL {
        var components = URLComponents()
        components.scheme = "boutique"
        components.host = "product"
        components.path = "/\(product.id)"
        return components.url ?? URL(fileURLWithPath: "/product/\(product.id)")
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("SHARE")
                .font(.system(size: 10, weight: .light))
                .tracking(4)
                .foregroundStyle(Color.cream45)

            shareButton(icon: "hand.thumbsup") {
                openURL("https://facebook.com/sharer/sharer.php?u=\(shareURL.absoluteString)")
            }
            shareButton(icon: "bird") {
                openURL("https://twitter.com/intent/tweet?text=Check+out+\(product.name)")
            }
            shareButton(icon: "network") {
                openURL("https://www.linkedin.com/sharing/share-offsite/?url=\(shareURL.absoluteString)")
            }

            Button {
                #if os(iOS)
                UIPasteboard.general.url = shareURL
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(shareURL.absoluteString, forType: .string)
                #endif
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(copied ? Color.green : Color.cream60)
                    .frame(width: 36, height: 36)
                    .background(Color.boutGlassBottom)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func shareButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.cream60)
                .frame(width: 36, height: 36)
                .background(Color.boutGlassBottom)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

private struct SpecificationsTab: View {
    let specs: [ProductSpec]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(specs) { spec in
                VStack(alignment: .leading, spacing: 8) {
                    Text(spec.label.uppercased())
                        .font(.system(size: 10, weight: .light))
                        .tracking(5)
                        .foregroundStyle(Color.cream45)

                    Text(spec.value)
                        .font(.custom("Cormorant Garamond", size: 17))
                        .fontWeight(.light)
                        .foregroundStyle(BrandPalette.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassCard()
            }
        }
    }
}

private struct HighlightsTab: View {
    let highlights: [ProductHighlight]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(highlights) { item in
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gold.opacity(0.16), Color.gold.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Circle().stroke(Color.gold.opacity(0.24), lineWidth: 1))
                            .frame(width: 48, height: 48)

                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Color.gold)
                    }

                    Text(item.title)
                        .font(.custom("Cormorant Garamond", size: 18))
                        .fontWeight(.light)
                        .foregroundStyle(BrandPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(item.desc)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.cream45)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard()
            }
        }
    }
}

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
        case .pants, .denim, .jeans: return "Waist"
        case .footwear, .loafers, .sneakers, .boots: return "Equivalent"
        default: return "Chest"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Size Guide")
                    .font(.custom("Cormorant Garamond", size: 34))
                    .foregroundStyle(BrandPalette.textPrimary)

                Text("Use this as a fit starting point. Product measurements and available variants still come from the live catalog.")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.cream45)
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
                .glassCard()

                Spacer()
            }
            .padding(20)
            .background(BrandPalette.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Fit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.gold)
                }
            }
        }
    }

    private func sizeGuideHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .light))
            .tracking(3)
            .foregroundStyle(Color.cream25)
    }

    private func sizeGuideValue(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .light))
            .foregroundStyle(Color.cream60)
            .frame(minHeight: 32, alignment: .leading)
    }
}
