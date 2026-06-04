import SwiftUI

struct LegalCenterView: View {
    @State private var documents: [LegalDocument] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Legal",
                    title: "Terms, privacy, and account responsibilities presented in a native reading flow.",
                    copy: "Policy content is kept readable, warm, and deliberate, with enough spacing for comfortable review on a phone."
                )

                if isLoading {
                    ProgressView()
                        .tint(BrandPalette.gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    EmptyStatePanel(
                        title: "Unable to load legal documents",
                        copy: errorMessage,
                        buttonTitle: "Retry"
                    ) {
                        Task { await loadDocuments(forceReload: true) }
                    }
                } else {
                    ForEach(documents) { document in
                        VStack(alignment: .leading, spacing: BrandSpacing.lg) {
                            Text(document.title)
                                .font(BrandFont.mobileTitle())
                                .foregroundStyle(BrandPalette.textPrimary)

                            Text(document.intro)
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.textSecondary)
                                .lineSpacing(4)

                            ForEach(document.sections) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.heading.uppercased())
                                        .font(BrandFont.mobileCaption())
                                        .tracking(3)
                                        .foregroundStyle(BrandPalette.textMuted)

                                    ForEach(section.body, id: \.self) { paragraph in
                                        Text(paragraph)
                                            .font(BrandFont.mobileBody())
                                            .foregroundStyle(BrandPalette.textSecondary)
                                            .lineSpacing(4)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
                    }

                    if let privacyPolicyURL = AppExperiencePolicy.privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Open External Privacy Policy")
                                        .font(BrandFont.mobileTitle3())
                                        .foregroundStyle(BrandPalette.textPrimary)

                                    Text(privacyPolicyURL.absoluteString)
                                        .font(BrandFont.mobileCaption())
                                        .foregroundStyle(BrandPalette.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundStyle(BrandPalette.textMuted)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Support")
        .task {
            await loadDocuments()
        }
    }

    private func loadDocuments(forceReload: Bool = false) async {
        if !forceReload && !documents.isEmpty {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            documents = try await APIService.shared.fetchLegalDocuments()
            if documents.isEmpty {
                errorMessage = "No legal documents are currently published."
            }
            isLoading = false
        } catch {
            errorMessage = documents.isEmpty
                ? "Documents could not be loaded right now."
                : "Unable to refresh legal documents right now."
            isLoading = false
        }
    }
}
