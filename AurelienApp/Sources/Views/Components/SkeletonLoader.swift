import SwiftUI

struct SkeletonLoader: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(BrandPalette.surfaceRaised.opacity(0.88))
            .shimmering()
            .frame(height: 24)
    }
}
