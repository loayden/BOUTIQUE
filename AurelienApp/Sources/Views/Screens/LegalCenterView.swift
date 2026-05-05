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
                    copy: "These sections are adapted from the web storefront policies but reformatted to stay readable on a phone without dense tables or cramped copy blocks."
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
