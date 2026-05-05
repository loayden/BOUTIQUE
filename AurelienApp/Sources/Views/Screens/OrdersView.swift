import SwiftUI

struct OrdersView: View {
    @Environment(AurelienStore.self) private var store

    @State private var orders: [Order] = []
    @State private var isLoading = true
    @State private var selectedFilter: OrderStatus?
    @State private var loadError: String?
    @State private var isRefreshing = false

    private var filteredOrders: [Order] {
        guard let selectedFilter else { return orders }
        return orders.filter { $0.status == selectedFilter }
    }

    var body: some View {
        Group {
            if !store.isAuthenticated {
                unauthenticatedView
            } else {
                ordersContent
            }
        }
        .navigationTitle("My Orders")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
        .task {
            if isLoading {
                await loadOrders()
            }
        }
    }

    private var ordersContent: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                filterHeader

                if let loadError {
                    InlineOrderError(message: loadError) {
                        Task { await loadOrders(forceRefresh: true) }
                    }
                }

                if isLoading {
                    OrderListSkeleton()
                } else if filteredOrders.isEmpty {
                    emptyView
                } else {
                    ForEach(filteredOrders) { order in
                        NavigationLink {
                            OrderDetailView(order: order)
                        } label: {
                            OrderCard(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
    }

    private var unauthenticatedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BrandPalette.gold.opacity(0.6))

            Text("Sign in to view your orders")
                .font(BrandFont.mobileTitle2())
                .foregroundStyle(BrandPalette.textPrimary)

            Text("Access your order history, track shipments, and manage your account.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            NavigationLink("Sign In") {
                LoginView()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            .padding(.horizontal, 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
        .padding(.horizontal, 20)
    }

    private var emptyView: some View {
        EmptyStatePanel(
            title: selectedFilter == nil ? "No orders yet" : "No \(selectedFilter?.title.lowercased() ?? "") orders",
            copy: "As soon as you place an order, the timeline, totals, and delivery details will appear here in a mobile-first list.",
            buttonTitle: "Browse Shop"
        ) {
            BrandHaptics.selection()
            store.selectedTab = .shop
        }
    }

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status Filter".uppercased())
                        .font(BrandFont.mobileCaption2())
                        .tracking(3)
                        .foregroundStyle(BrandPalette.textMuted)

                    Text(selectedFilter?.title ?? "All Orders")
                        .font(BrandFont.mobileTitle3())
                        .foregroundStyle(BrandPalette.textPrimary)
                }

                Spacer()

                Menu {
                    Button("All Orders") {
                        BrandHaptics.selection()
                        selectedFilter = nil
                    }

                    ForEach(OrderStatus.allCases) { status in
                        Button(status.title) {
                            BrandHaptics.selection()
                            selectedFilter = status
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundStyle(BrandPalette.gold)
                        .frame(width: 44, height: 44)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", status: nil)
                    ForEach(OrderStatus.allCases) { status in
                        filterChip(title: status.title, status: status)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
    }

    private func filterChip(title: String, status: OrderStatus?) -> some View {
        Button {
            BrandHaptics.selection()
            selectedFilter = status
        } label: {
            SelectionCapsule(title: title, isSelected: selectedFilter == status)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func loadOrders(forceRefresh: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            isLoading = false
        }

        if forceRefresh {
            loadError = nil
        }

        do {
            if let userID = store.currentUser?.id {
                let remoteOrders = try await APIService.shared.fetchUserOrders(userId: userID)
                orders = remoteOrders
            } else {
                orders = []
            }
            loadError = nil
        } catch {
            loadError = "Live order data is unavailable right now."
        }
    }
}

private struct OrderListSkeleton: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                    .fill(BrandPalette.surfaceRaised)
                    .frame(height: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                    .redacted(reason: .placeholder)
            }
        }
    }
}

private struct InlineOrderError: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection issue")
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)

            Text(message)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)

            Button("Retry", action: retry)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .frame(minHeight: 44)
        }
        .padding(16)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
    }
}

private struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Order \(order.id)")
                        .font(BrandFont.mobileTitle3())
                        .foregroundStyle(BrandPalette.textPrimary)

                    if let date = order.createdAt {
                        Text(BrandFormatter.orderDate(date))
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                }

                Spacer()

                StatusBadge(status: order.status)
            }

            DividerGlow()

            VStack(spacing: 10) {
                ForEach(order.items.prefix(2)) { item in
                    HStack(spacing: 12) {
                        MediaImage(name: item.product?.heroImageName ?? item.imageName)
                            .scaledToFit()
                            .frame(width: 64, height: 76)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.textPrimary)
                                .lineLimit(2)

                            Text("\(item.quantity)x • \(item.size ?? "One Size") • \(item.color ?? "Default")")
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(BrandPalette.textSecondary)
                        }

                        Spacer()
                    }
                }
            }

            HStack {
                Text("\(order.items.count) items")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                Spacer()

                Text(BrandFormatter.price(order.total))
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)
    }
}

private struct StatusBadge: View {
    let status: OrderStatus

    var color: Color {
        switch status {
        case .pending: return BrandPalette.gold
        case .confirmed: return BrandPalette.goldLight
        case .preparing: return Color(red: 0.75, green: 0.78, blue: 0.95)
        case .shipped: return BrandPalette.success
        case .delivered: return Color(red: 0.6, green: 0.8, blue: 0.6)
        case .cancelled: return Color(red: 0.9, green: 0.5, blue: 0.5)
        }
    }

    var body: some View {
        Text(status.title.uppercased())
            .font(BrandFont.mobileCaption2())
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct OrderDetailView: View {
    let order: Order

    var body: some View {
        PhoneScrollScreen { viewport in
            VStack(alignment: .leading, spacing: BrandSpacing.xl) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(order.id)
                        .font(BrandFont.mobileTitle())
                        .foregroundStyle(BrandPalette.textPrimary)

                    if let date = order.createdAt {
                        Text(BrandFormatter.orderDate(date))
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }

                    StatusBadge(status: order.status)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tracking")
                        .font(BrandFont.mobileTitle2())
                        .foregroundStyle(BrandPalette.textPrimary)

                    OrderTrackingTimeline(status: order.status)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(BrandFont.mobileTitle2())
                        .foregroundStyle(BrandPalette.textPrimary)

                    ForEach(order.items) { item in
                        HStack(spacing: 12) {
                            MediaImage(name: item.product?.heroImageName ?? item.imageName)
                                .scaledToFit()
                                .frame(width: 74, height: 90)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(BrandFont.mobileBody())
                                    .foregroundStyle(BrandPalette.textPrimary)

                                Text("\(item.quantity)x • \(item.size ?? "One Size") • \(item.color ?? "Default")")
                                    .font(BrandFont.mobileCaption())
                                    .foregroundStyle(BrandPalette.textSecondary)

                                Text(BrandFormatter.price(item.price))
                                    .font(BrandFont.mobileCaption())
                                    .foregroundStyle(BrandPalette.accent)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SummaryLine(title: "Subtotal", value: order.subtotal)
                    SummaryLine(title: "Shipping", value: order.shippingCost)
                    SummaryLine(title: "Discount", value: -order.discount)
                    DividerGlow()
                    SummaryLine(title: "Total", value: order.total, emphasize: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)
            }
            .padding(viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Orders")
    }
}

struct OrderTrackingTimeline: View {
    let status: OrderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status == .cancelled {
                timelineRow(title: "Cancelled", icon: "xmark.circle.fill", isComplete: true, isCurrent: true)
                Text("This order is no longer moving through delivery.")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
            } else {
                ForEach(OrderStatus.trackingFlow) { step in
                    timelineRow(
                        title: step.title,
                        icon: icon(for: step),
                        isComplete: isComplete(step),
                        isCurrent: step == status
                    )
                }
            }
        }
    }

    private func timelineRow(title: String, icon: String, isComplete: Bool, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isComplete ? BrandPalette.gold : BrandPalette.textMuted)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isComplete ? BrandPalette.gold.opacity(0.16) : BrandPalette.surfaceRaised)
                )

            Text(title)
                .font(BrandFont.mobileBody())
                .foregroundStyle(isCurrent ? BrandPalette.textPrimary : BrandPalette.textSecondary)

            Spacer(minLength: 0)

            if isCurrent {
                Text("Current")
                    .font(BrandFont.mobileCaption2())
                    .tracking(1.8)
                    .foregroundStyle(BrandPalette.gold)
            }
        }
    }

    private func icon(for step: OrderStatus) -> String {
        switch step {
        case .pending: return "clock"
        case .confirmed: return "checkmark.seal"
        case .preparing: return "shippingbox"
        case .shipped: return "truck.box"
        case .delivered: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    private func isComplete(_ step: OrderStatus) -> Bool {
        guard let current = status.trackingIndex,
              let candidate = step.trackingIndex else {
            return false
        }
        return candidate <= current
    }
}

private struct SummaryLine: View {
    let title: String
    let value: Double
    var emphasize = false

    var body: some View {
        HStack {
            Text(title)
                .font(emphasize ? BrandFont.mobileTitle3() : BrandFont.mobileBody())
                .foregroundStyle(emphasize ? BrandPalette.textPrimary : BrandPalette.textSecondary)

            Spacer()

            Text(BrandFormatter.price(value))
                .font(emphasize ? BrandFont.mobileTitle3() : BrandFont.mobileBody())
                .foregroundStyle(emphasize ? BrandPalette.accent : BrandPalette.textPrimary)
        }
    }
}
