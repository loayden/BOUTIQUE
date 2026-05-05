import SwiftUI

public struct FullScreenProductCarousel: View {
    let products: [Product]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    public var body: some View {
        ZStack(alignment: .top) {
            BrandPalette.background
                .ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                    GeometryReader { geometry in
                        ProductCardView(product: product, style: .fullscreen)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Button {
                    isPresented = false
                    BrandHaptics.selection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Text(counterText)
                    .font(.system(size: 11, weight: .light))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
        }
    }

    private var counterText: String {
        guard !products.isEmpty else { return "0 / 0" }
        let clampedIndex = max(0, min(selectedIndex, products.count - 1))
        return "\(clampedIndex + 1) / \(products.count)"
    }
}
