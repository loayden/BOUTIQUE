import SwiftUI

struct BagView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var recentlyRemovedLine: BagLine?
    @State private var undoDismissTask: Task<Void, Never>?

    private var bottomOverlayPadding: CGFloat {
        MobileChrome.bottomOverlayInset(for: UIScreen.main.bounds.width)
    }

    private var bagUnits: Int {
        store.bag.reduce(0) { $0 + $1.quantity }
    }

    private var recommendations: [Product] {
        Array(store.personalizedProducts.prefix(6))
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            VStack(alignment: .leading, spacing: BrandSpacing.md) {
                if store.bag.isEmpty {
                    BagEmptyStatePanel(
                        onBrowse: browseCollection
                    )
                } else {
                    BagHeaderPanel(
                        itemCount: bagUnits,
                        subtotal: store.subtotal,
                        shippingCost: store.shippingCost,
                        primaryAddress: store.primaryAddress
                    )

                    BagItemsSection(
                        lines: store.bag,
                        onRemove: remove
                    )

                    BagAssuranceSection(primaryAddress: store.primaryAddress)

                    BagSummaryCard(
                        subtotal: store.subtotal,
                        shippingCost: store.shippingCost,
                        total: store.total
                    )

                    checkoutActionCard

                    if recommendations.isEmpty == false {
                        BagRecommendationsSection(
                            products: recommendations,
                            onAdd: addRecommendationToBag
                        )
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, BrandSpacing.sm)
            .padding(.bottom, viewport.bottomPadding + 24)
        }
        .background(AmbientBackdrop())
        .navigationTitle("Bag")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let recentlyRemovedLine {
                UndoToast(
                    title: "\(recentlyRemovedLine.product.name) removed",
                    actionTitle: "Undo",
                    action: restoreRecentlyRemovedLine
                )
                .padding(.horizontal, BrandSpacing.md)
                .padding(.bottom, bottomOverlayPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onDisappear {
            undoDismissTask?.cancel()
        }
    }

    private var checkoutActionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let issue = store.firstBagAvailabilityIssue {
                Text(issue)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }

            Button(action: openCheckout) {
                HStack(spacing: BrandSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue to Shipping")
                            .font(BrandFont.mobileBody())

                        Text("Address, delivery, and payment continue in the next step.")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.accentForeground.opacity(0.78))
                            .lineLimit(2)
                    }

                    Spacer(minLength: BrandSpacing.sm)

                    Text(BrandFormatter.price(store.total))
                        .font(BrandFont.mobileTitle3())
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(BrandPalette.accentForeground)
                .padding(.horizontal, BrandSpacing.md)
                .padding(.vertical, BrandSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                        .fill(store.firstBagAvailabilityIssue == nil ? BrandPalette.gold : BrandPalette.surfaceRaised)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.firstBagAvailabilityIssue != nil)
        }
    }

    private func browseCollection() {
        BrandHaptics.selection()
        store.selectedTab = .shop
        dismiss()
    }

    private func addRecommendationToBag(_ product: Product) {
        BrandHaptics.selection()
        store.addToCart(product)
    }

    private func remove(_ line: BagLine) {
        undoDismissTask?.cancel()
        recentlyRemovedLine = line
        store.removeFromBag(line)

        undoDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                recentlyRemovedLine = nil
            }
        }
    }

    private func restoreRecentlyRemovedLine() {
        guard let recentlyRemovedLine else { return }
        undoDismissTask?.cancel()
        store.bag.insert(recentlyRemovedLine, at: 0)
        self.recentlyRemovedLine = nil
        BrandHaptics.notificationSuccess()
    }

    private func openCheckout() {
        store.present(.checkout)
    }
}

private struct BagHeaderPanel: View {
    let itemCount: Int
    let subtotal: Double
    let shippingCost: Double
    let primaryAddress: SavedAddress?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Bag",
                title: "\(itemCount) \(itemCount == 1 ? "piece is" : "pieces are") ready for checkout.",
                copy: headerCopy
            )

            HStack(spacing: 10) {
                BagMetricCard(
                    value: "\(itemCount)",
                    label: "Items",
                    note: "Live quantity"
                )
                BagMetricCard(
                    value: BrandFormatter.price(subtotal),
                    label: "Subtotal",
                    note: "Before delivery"
                )
                BagMetricCard(
                    value: shippingCost == 0 ? "Free" : BrandFormatter.price(shippingCost),
                    label: "Shipping",
                    note: "Confirmed next"
                )
            }
        }
        .padding(16)
        .brandPanel(cornerRadius: BrandRadius.sheet, tone: .shadow, material: true)
    }

    private var headerCopy: String {
        if let primaryAddress {
            return "Primary delivery is set to \(primaryAddress.city.rawValue). Review sizes and quantities before moving into shipping and payment."
        }
        return "Review sizes, quantities, and totals here. Delivery details are confirmed in the next checkout step."
    }
}

private struct BagMetricCard: View {
    let value: String
    let label: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(BrandFont.serif(20, relativeTo: .title3))
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(2)
                .foregroundStyle(BrandPalette.textSecondary)

            Text(note)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }
}

private struct BagItemsSection: View {
    let lines: [BagLine]
    let onRemove: (BagLine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandSectionHeader(
                eyebrow: "Selected Pieces",
                title: "Everything in your bag stays editable before payment.",
                copy: "Update quantities, review variants, or remove lines without leaving this screen."
            )

            VStack(spacing: 10) {
                ForEach(lines) { line in
                    BagLineRow(
                        line: line,
                        onRemove: { onRemove(line) }
                    )
                }
            }
        }
    }
}

private struct BagAssuranceSection: View {
    let primaryAddress: SavedAddress?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandSectionHeader(
                eyebrow: "Checkout Signals",
                title: "The bag stays transparent before the final payment step.",
                copy: "Shipping, confirmation, and support signals remain visible while the order is still editable."
            )

            VStack(spacing: 8) {
                BagAssuranceCard(
                    icon: "location",
                    title: primaryAddress == nil ? "Address selected in checkout" : "Delivering to \(primaryAddress?.city.rawValue ?? "")",
                    message: primaryAddress == nil ? "Choose a shipping address on the next screen before payment appears." : primaryAddress?.summary ?? ""
                )
                BagAssuranceCard(
                    icon: "lock.shield",
                    title: "Secure payment flow",
                    message: "Authentication, shipping, payment, and final review stay inside the same checkout path."
                )
                BagAssuranceCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Live cart sync",
                    message: "Quantity updates and removals are reflected immediately in the running total."
                )
            }
        }
    }
}

private struct BagAssuranceCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(BrandPalette.gold)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct BagLineRow: View {
    @Environment(AurelienStore.self) private var store

    let line: BagLine
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MediaImage(name: line.product.heroImageName)
                .scaledToFill()
                .frame(width: 84, height: 112)
                .background(BrandPalette.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(line.product.category.title.uppercased())
                            .font(BrandFont.mobileCaption2())
                            .tracking(2)
                            .foregroundStyle(BrandPalette.textSecondary)

                        Text(line.product.name)
                            .font(BrandFont.serif(18, relativeTo: .headline))
                            .foregroundStyle(BrandPalette.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(line.product.summary)
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(BrandPalette.surfaceRaised, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(line.product.name)")
                }

                HStack(spacing: 8) {
                    BagAttributeChip(title: "Size \(line.size)")
                    BagAttributeChip(title: line.color.name)
                    BagAttributeChip(title: line.product.stockLabel)
                }

                HStack(alignment: .bottom, spacing: 12) {
                    QuantityStepper(
                        quantity: line.quantity,
                        onDecrease: {
                            BrandHaptics.selection()
                            store.updateQuantity(for: line, delta: -1)
                        },
                        onIncrease: {
                            BrandHaptics.selection()
                            store.updateQuantity(for: line, delta: 1)
                        }
                    )

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Line Total")
                            .font(BrandFont.mobileCaption2())
                            .tracking(2)
                            .foregroundStyle(BrandPalette.textSecondary)

                        Text(BrandFormatter.price(line.subtotal))
                            .font(BrandFont.serif(18, relativeTo: .headline))
                            .foregroundStyle(BrandPalette.gold)
                    }
                }
            }
        }
        .padding(12)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct BagAttributeChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BrandPalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(BrandPalette.surfaceRaised)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
    }
}

private struct BagSummaryCard: View {
    let subtotal: Double
    let shippingCost: Double
    let total: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandSectionHeader(
                eyebrow: "Summary",
                title: "Order totals stay visible before shipping and payment.",
                copy: "You can continue to shipping from the fixed checkout bar at any time."
            )

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(title: "Subtotal", value: BrandFormatter.price(subtotal), emphasize: false)
                summaryRow(title: "Shipping Estimate", value: shippingCost == 0 ? "Free" : BrandFormatter.price(shippingCost), emphasize: false)
                DividerGlow()
                summaryRow(title: "Estimated Total", value: BrandFormatter.price(total), emphasize: true)
            }
            .padding(12)
            .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
        }
    }

    private func summaryRow(title: String, value: String, emphasize: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(emphasize ? BrandFont.mobileTitle3() : BrandFont.mobileBody())
                .foregroundStyle(emphasize ? BrandPalette.textPrimary : BrandPalette.textSecondary)

            Spacer()

            Text(value)
                .font(emphasize ? BrandFont.mobileTitle3() : BrandFont.mobileBody())
                .foregroundStyle(emphasize ? BrandPalette.gold : BrandPalette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct BagRecommendationsSection: View {
    let products: [Product]
    let onAdd: (Product) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandSectionHeader(
                eyebrow: "Recommended",
                title: "Real products matched to what is already in your bag.",
                copy: "These picks come from the same live catalog and exclude pieces already added."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(products) { product in
                        BagRecommendationCard(
                            product: product,
                            onAdd: { onAdd(product) }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct BagRecommendationCard: View {
    let product: Product
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: product) {
                VStack(alignment: .leading, spacing: 8) {
                    MediaImage(name: product.heroImageName)
                        .scaledToFill()
                        .frame(width: 176, height: 204)
                        .background(BrandPalette.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text(product.category.title.uppercased())
                        .font(BrandFont.mobileCaption2())
                        .tracking(2)
                        .foregroundStyle(BrandPalette.textSecondary)

                    Text(product.name)
                        .font(BrandFont.serif(17, relativeTo: .headline))
                        .foregroundStyle(BrandPalette.textPrimary)
                        .lineLimit(2)

                    Text(BrandFormatter.price(product.price))
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.gold)
                }
            }
            .buttonStyle(.plain)

            Button("Add to Bag", action: onAdd)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
        }
        .frame(width: 194, alignment: .topLeading)
        .padding(12)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct BagEmptyStatePanel: View {
    let onBrowse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandSectionHeader(
                eyebrow: "Bag",
                title: "Your bag is empty, but the checkout flow is ready.",
                copy: "Add pieces from the shop to review sizes, update quantities, and continue directly into shipping and payment."
            )

            VStack(spacing: 8) {
                BagAssuranceCard(
                    icon: "bag.badge.plus",
                    title: "Add from the live catalog",
                    message: "Every product added here stays connected to the same shop inventory and product detail screens."
                )
                BagAssuranceCard(
                    icon: "shippingbox",
                    title: "Fast checkout path",
                    message: "Shipping, payment, and order confirmation continue in one structured flow as soon as you add a piece."
                )
            }

            Button(action: onBrowse) {
                Text("Browse the Shop")
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
        }
        .padding(16)
        .brandPanel(cornerRadius: BrandRadius.sheet, tone: .shadow, material: true)
    }
}

private struct UndoToast: View {
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: BrandSpacing.sm) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(BrandPalette.gold)

            Text(title)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(actionTitle, action: action)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.gold)
        }
        .padding(.horizontal, BrandSpacing.md)
        .padding(.vertical, BrandSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(BrandPalette.overlay.opacity(0.96))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
        .shadow(color: BrandPalette.shadowStrong, radius: 18, x: 0, y: 8)
    }
}
