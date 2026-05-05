import SwiftUI

public extension View {
    func bottomInsetBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) {
            content()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(
                    Rectangle()
                        .fill(BrandPalette.background.opacity(0.96))
                        .background(.ultraThinMaterial)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(BrandPalette.hairline)
                                .frame(height: 0.5)
                        }
                        .ignoresSafeArea(edges: .bottom)
                )
        }
    }
}
