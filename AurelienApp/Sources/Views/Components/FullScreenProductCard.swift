import SwiftUI

public struct FullScreenProductCard: View {
    let product: Product
    var inlineMode: Bool = false

    public var body: some View {
        ProductCardView(product: product, style: .fullscreen, compact: false)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: inlineMode ? 28 : 0,
                    style: .continuous
                )
            )
    }
}
