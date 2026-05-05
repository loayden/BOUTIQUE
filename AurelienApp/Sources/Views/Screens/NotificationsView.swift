import SwiftUI

struct NotificationsView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: ClientNotificationKind?

    private var filteredNotifications: [ClientNotification] {
        guard let selectedKind else { return store.notifications }
        return store.notifications.filter { $0.kind == selectedKind }
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Notifications",
                    title: "Order signals, promotions, and client guidance in one place.",
                    copy: "The app keeps operational updates and personalized discovery visible without interrupting the browse."
                )

                notificationSummary
                notificationFilters

                if filteredNotifications.isEmpty {
                    EmptyStatePanel(
                        title: "No notifications in this view",
                        copy: "Order updates, promotions, and smart recommendations will appear here as soon as activity changes.",
                        buttonTitle: "Mark All Read"
                    ) {
                        store.markAllNotificationsRead()
                    }
                } else {
                    ForEach(filteredNotifications) { notification in
                        NotificationCard(notification: notification, deleteAction: {
                            store.removeNotification(notification)
                        }) {
                            destinationAction(for: notification)
                        }
                        .onTapGesture {
                            store.markNotificationRead(notification)
                        }
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
    }

    private var notificationSummary: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            HStack(spacing: 12) {
                NotificationMetricCard(
                    title: "Unread",
                    value: "\(store.unreadNotificationCount)",
                    subtitle: "Need attention"
                )

                NotificationMetricCard(
                    title: "Order Alerts",
                    value: "\(store.notifications.filter { $0.kind == .orderUpdate }.count)",
                    subtitle: "Operational"
                )
            }

            Button("Mark All As Read") {
                store.markAllNotificationsRead()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome))
        }
    }

    private var notificationFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    selectedKind = nil
                } label: {
                    SelectionCapsule(title: "All", isSelected: selectedKind == nil)
                }
                .buttonStyle(.plain)

                ForEach(ClientNotificationKind.allCases, id: \.self) { kind in
                    Button {
                        selectedKind = kind
                    } label: {
                        SelectionCapsule(title: kind.title, isSelected: selectedKind == kind)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationAction(for notification: ClientNotification) -> some View {
        if let actionTitle = notification.actionTitle, let destination = notification.destination {
            switch destination {
            case .shop:
                Button(actionTitle) {
                    store.markNotificationRead(notification)
                    store.selectedTab = .shop
                    dismiss()
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            case .discover:
                Button(actionTitle) {
                    store.markNotificationRead(notification)
                    store.selectedTab = .discover
                    dismiss()
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            case .orders:
                NavigationLink(value: AppRoute.orders) {
                    notificationActionLabel(actionTitle)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .simultaneousGesture(TapGesture().onEnded {
                    store.markNotificationRead(notification)
                })
            case .wishlist:
                NavigationLink(value: AppRoute.wishlist) {
                    notificationActionLabel(actionTitle)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .simultaneousGesture(TapGesture().onEnded {
                    store.markNotificationRead(notification)
                })
            case .support:
                NavigationLink(value: AppRoute.support) {
                    notificationActionLabel(actionTitle)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .simultaneousGesture(TapGesture().onEnded {
                    store.markNotificationRead(notification)
                })
            case .stylist:
                NavigationLink(value: AppRoute.stylist) {
                    notificationActionLabel(actionTitle)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .simultaneousGesture(TapGesture().onEnded {
                    store.markNotificationRead(notification)
                })
            case .wallet:
                NavigationLink(value: AppRoute.wallet) {
                    notificationActionLabel(actionTitle)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .simultaneousGesture(TapGesture().onEnded {
                    store.markNotificationRead(notification)
                })
            }
        }
    }

    private func notificationActionLabel(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity)
    }
}

private struct NotificationMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.textMuted)

            Text(value)
                .font(BrandFont.mobileTitle())
                .foregroundStyle(BrandPalette.accent)

            Text(subtitle)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }
}

private struct NotificationCard<ActionContent: View>: View {
    let notification: ClientNotification
    let deleteAction: () -> Void
    @ViewBuilder let actionContent: () -> ActionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.kind.systemImage)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(notification.isRead ? BrandPalette.textMuted : BrandPalette.accent)
                    .frame(width: 34, height: 34)
                    .brandPanel(cornerRadius: 12, tone: notification.isRead ? .shadow : .gold, material: !notification.isRead)

                VStack(alignment: .leading, spacing: 6) {
                    Text(notification.kind.title.uppercased())
                        .font(BrandFont.mobileCaption2())
                        .tracking(3)
                        .foregroundStyle(BrandPalette.textMuted)

                    Text(notification.title)
                        .font(BrandFont.mobileTitle3())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(notification.message)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineSpacing(4)
                }

                Spacer(minLength: 0)
            }

            if let emphasis = notification.emphasis {
                Text(emphasis)
                    .font(BrandFont.mobileCaption())
                    .tracking(1.6)
                    .foregroundStyle(BrandPalette.accent)
            }

            Text(notification.timestamp)
                .font(BrandFont.mobileCaption2())
                .tracking(2)
                .foregroundStyle(BrandPalette.textMuted)

            actionContent()

            Button("Delete", role: .destructive, action: deleteAction)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(.red)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: notification.isRead ? .shadow : .chrome, material: true)
    }
}
