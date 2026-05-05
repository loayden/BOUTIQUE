import SwiftUI

struct SupportCenterView: View {
    @Environment(AurelienStore.self) private var store

    @State private var expandedFAQID: String?
    @State private var channels: [SupportChannel] = []
    @State private var faqs: [FAQItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Support",
                    title: "Customer care, FAQs, and policy guidance without leaving the app.",
                    copy: "Find support channels, answers, and store policies in one place."
                )

                if isLoading {
                    ProgressView()
                        .tint(BrandPalette.gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    if let errorMessage {
                        supportNotice(message: errorMessage)
                    }

                    if channels.isEmpty && faqs.isEmpty {
                        EmptyStatePanel(
                            title: "Support content unavailable",
                            copy: "The support center could not load its live content right now.",
                            buttonTitle: "Retry"
                        ) {
                            Task { await loadSupportData(forceReload: true) }
                        }
                    } else {
                        supportChannels
                        faqSection
                        policySection
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
        .task {
            await loadSupportData()
        }
    }

    private func supportNotice(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(BrandPalette.gold)

                Text("Support Sync Delayed")
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)
            }

            Text(message)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineSpacing(4)

            Button("Retry") {
                Task { await loadSupportData(forceReload: true) }
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            .frame(minHeight: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }

    private var supportChannels: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Client Care",
                title: "Service routes for support, styling, and operational follow-up.",
                copy: nil
            )

            ForEach(channels) { channel in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: channel.systemImage)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(BrandPalette.accent)
                        .frame(width: 40, height: 40)
                        .brandPanel(cornerRadius: 14, tone: .gold, material: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(channel.title)
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)

                        Text(channel.subtitle)
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)

                        Text(channel.detail)
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textMuted)
                            .lineSpacing(3)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
            }
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "FAQs",
                title: "Clear answers for delivery, returns, support, and account flow.",
                copy: "Every answer is formatted for phone reading with larger tap targets and cleaner spacing."
            )

            ForEach(faqs) { item in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedFAQID == item.id },
                        set: { expandedFAQID = $0 ? item.id : nil }
                    )
                ) {
                    Text(item.answer)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineSpacing(4)
                        .padding(.top, 8)
                } label: {
                    Text(item.question)
                        .font(BrandFont.mobileTitle3())
                        .foregroundStyle(BrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(BrandPalette.accent)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(
                    cornerRadius: BrandRadius.card,
                    tone: expandedFAQID == item.id ? .gold : .shadow,
                    material: expandedFAQID == item.id
                )
            }
        }
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Legal",
                title: "Terms, privacy, and client policy remain one tap away.",
                copy: "Policy language is carried over from the web system and reformatted for native reading."
            )

            NavigationLink(value: AppRoute.legal) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Open Legal Center")
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)

                        Text("Review privacy handling, store access, order rules, and account responsibilities.")
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)
                            .lineSpacing(4)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(BrandPalette.textMuted)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)

            if store.unreadNotificationCount > 0 {
                Text("There are \(store.unreadNotificationCount) unread client notifications still waiting in the notification center.")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.accent)
            }
        }
    }

    private func loadSupportData(forceReload: Bool = false) async {
        if !forceReload && !channels.isEmpty && !faqs.isEmpty {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let supportContent = try await APIService.shared.fetchSupportContent()
            let resolvedChannels = supportContent.channels
            let resolvedFAQs = supportContent.faqs

            channels = resolvedChannels
            faqs = resolvedFAQs
            errorMessage = (resolvedChannels.isEmpty && resolvedFAQs.isEmpty)
                ? "Live support content is currently unavailable."
                : nil
        } catch {
            errorMessage = channels.isEmpty && faqs.isEmpty
                ? "Unable to refresh live support content right now."
                : "Unable to refresh live support content right now."
        }

        isLoading = false
    }
}
