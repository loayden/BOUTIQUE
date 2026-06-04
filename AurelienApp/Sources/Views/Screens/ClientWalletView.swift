import SwiftUI

struct ClientWalletView: View {
    @Environment(AurelienStore.self) private var store
    @State private var showAddressSheet = false

    var body: some View {
        Group {
            if store.isAuthenticated {
                walletContent
            } else {
                unauthenticatedView
            }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
    }

    private var walletContent: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Wallet",
                    title: "Saved delivery preferences, shaped for faster mobile checkout.",
                    copy: "The app keeps address and client profile details close to the hand so returning customers move through checkout without friction."
                )

                profileSnapshot
                addressSection
                paymentSection
                preferenceSection
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .sheet(isPresented: $showAddressSheet) {
            CheckoutAddressSheet(
                currentUser: store.currentUser,
                defaultRecipient: store.currentUser?.name ?? store.profile.name
            ) { draft in
                store.addAddress(
                    label: draft.label,
                    recipient: draft.recipient,
                    line1: draft.line1,
                    apartment: draft.apartment,
                    city: draft.city.rawValue,
                    phone: draft.phone,
                    isPrimary: draft.isPrimary
                )
            }
        }
    }

    private var unauthenticatedView: some View {
        EmptyStatePanel(
            title: "Sign in to manage wallet details",
            copy: "Delivery addresses and payment preferences are protected account data.",
            buttonTitle: "Sign In"
        ) {
            store.present(.auth)
        }
        .padding(20)
    }

    private var profileSnapshot: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Client Profile".uppercased())
                .font(BrandFont.mobileCaption())
                .tracking(3.2)
                .foregroundStyle(BrandPalette.textMuted)

            Text(store.currentUser?.name ?? store.profile.name)
                .font(BrandFont.mobileTitle())
                .foregroundStyle(BrandPalette.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                walletInfoRow(label: "Email", value: store.currentUser?.email ?? store.profile.email)
                walletInfoRow(label: "Tier", value: store.profile.tier)
                walletInfoRow(label: "City", value: store.primaryAddress?.city.rawValue ?? store.profile.city)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Saved Addresses",
                title: "Delivery details stay structured and easy to reuse.",
                copy: "Primary addresses can prefill checkout so mobile entry stays minimal.",
                actionTitle: "Add Address",
                action: { showAddressSheet = true }
            )

            ForEach(store.savedAddresses) { address in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(address.label)
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)

                        Spacer()

                        if address.isPrimary {
                            Text("Primary")
                                .font(BrandFont.mobileCaption2())
                                .tracking(2.4)
                                .foregroundStyle(BrandPalette.accent)
                        }
                    }

                    Text(address.recipient)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(address.summary)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)

                    Text(address.phone)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textMuted)

                    HStack(spacing: BrandSpacing.sm) {
                        if !address.isPrimary {
                            Button("Make Primary") {
                                store.setPrimaryAddress(id: address.id)
                            }
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.gold)
                        }

                        Spacer()

                        Button("Delete", role: .destructive) {
                            store.deleteAddress(id: address.id)
                        }
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: address.isPrimary ? .gold : .shadow, material: address.isPrimary)
            }
        }
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Payment",
                title: "Only active payment methods are shown.",
                copy: "Only payment methods that can complete a real order should appear here. Checkout currently supports Cash on Delivery and Vodafone Cash."
            )

            PreferenceCard(
                title: "Cash on Delivery",
                subtitle: "Active",
                detail: "Eligibility is checked by governorate before an order can be placed."
            )

            PreferenceCard(
                title: "Vodafone Cash",
                subtitle: "Order Request",
                detail: "Checkout collects a valid wallet number and keeps the order pending for manual payment confirmation."
            )
        }
    }

    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Preferences",
                title: "Mobile checkout now remembers the details that matter.",
                copy: nil
            )

            PreferenceCard(
                title: "In-App Alerts",
                subtitle: "Active",
                detail: "Operational updates remain visible inside the app with unread tracking."
            )

            PreferenceCard(
                title: "Offline-Ready Account State",
                subtitle: "Enabled",
                detail: "Core account, wishlist, bag, and order data are preserved on-device for smoother recovery during intermittent connectivity."
            )
        }
    }

    private func walletInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(2.8)
                .foregroundStyle(BrandPalette.textMuted)

            Text(value)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
        }
    }
}

private struct PreferenceCard: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Spacer()

                Text(subtitle.uppercased())
                    .font(BrandFont.mobileCaption2())
                    .tracking(2.8)
                    .foregroundStyle(BrandPalette.accent)
            }

            Text(detail)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)
    }
}
