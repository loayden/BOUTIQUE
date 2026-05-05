import SwiftUI

struct WishlistView: View {
    @Environment(AurelienStore.self) private var store
    @Binding var selectedTab: AppTab

    var body: some View {
        Group {
            if store.isAuthenticated {
                wishlistContent
            } else {
                unauthenticatedView
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
    }

    private var wishlistContent: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                if store.wishlist.isEmpty {
                    EmptyStatePanel(
                        title: "Your saved pieces are waiting",
                        copy: "Tap the heart on any product to keep it here. The layout stays dark, calm, and easy to edit on a phone.",
                        buttonTitle: "Explore Shop"
                    ) {
                        selectedTab = .shop
                    }
                } else {
                    BrandSectionHeader(
                        eyebrow: "Saved",
                        title: "Everything you’ve kept, arranged for quick return.",
                        copy: "Saved items now stay in a single mobile column so imagery and product details never feel cramped."
                    )

                    ForEach(store.wishlistedProducts) { product in
                        ProductCardView(product: product)
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
    }

    private var unauthenticatedView: some View {
        EmptyStatePanel(
            title: "Sign in to view saved pieces",
            copy: "Your wishlist is tied to your account so saved products can come back on every launch.",
            buttonTitle: "Sign In"
        ) {
            store.present(.auth)
        }
        .padding(20)
    }
}
