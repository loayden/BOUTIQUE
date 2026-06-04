import SwiftUI

struct ProductDetailsView: View {
    let product: Product

    var body: some View {
        ProductDetailView(product: product)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }
}
