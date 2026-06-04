import SwiftUI

struct StylistStudioView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var prompts: [StylistPrompt] = []
    @State private var selectedPrompt: StylistPrompt?
    @State private var recommendations: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Stylist Studio",
                    title: "Smart, editorial recommendations shaped for the customer in hand.",
                    copy: "Choose a direction, generate a refined set of pieces, and move into shop without losing the editorial tone."
                )

                if isLoading {
                    ProgressView()
                        .tint(BrandPalette.gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage {
                    EmptyStatePanel(
                        title: "Stylist temporarily unavailable",
                        copy: errorMessage,
                        buttonTitle: "Retry"
                    ) {
                        Task { await loadStylistData(forceReload: true) }
                    }
                } else {
                    promptRail
                    stylistResponse
                    recommendationSection
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Stylist")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
        .task {
            await loadStylistData()
        }
    }

    private var promptRail: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            Text("Select A Prompt".uppercased())
                .font(BrandFont.mobileCaption())
                .tracking(3.2)
                .foregroundStyle(BrandPalette.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts) { prompt in
                        Button {
                            selectedPrompt = prompt
                            generateRecommendations()
                        } label: {
                            SelectionCapsule(title: prompt.title, isSelected: selectedPrompt == prompt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var stylistResponse: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedPrompt?.title ?? "Personal Edit")
                .font(BrandFont.mobileTitle())
                .foregroundStyle(BrandPalette.textPrimary)

            Text(selectedPrompt?.prompt ?? "Start with a prompt to generate an editorial recommendation.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineSpacing(4)

            Text(stylistNarrative)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineSpacing(5)

            if let category = selectedPrompt?.category {
                Button("Open \(category.title)") {
                    store.openCategory(category)
                    store.selectedTab = .shop
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .frame(minHeight: 44)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Recommended Pieces",
                title: "Products selected from profile signals and prompt context.",
                copy: nil
            )

            if recommendations.isEmpty {
                EmptyStatePanel(
                    title: "No recommendations yet",
                    copy: "Choose a stylist prompt to generate a curated set of pieces.",
                    buttonTitle: "Browse Shop"
                ) {
                    store.selectedTab = .shop
                    dismiss()
                }
            } else {
                ForEach(recommendations) { product in
                    ProductCardView(product: product, compact: true)
                }
            }
        }
    }

    private var stylistNarrative: String {
        guard let prompt = selectedPrompt else {
            return "The stylist studio can translate saved tastes into a tighter product path when a client needs guidance."
        }

        switch prompt.category {
        case .suits:
            return "Start with a cleaner tailored foundation, keep the palette warm and dark, and let footwear or sunglasses provide the final authority instead of louder layering."
        case .jackets:
            return "The strongest travel edit begins with one outer layer that holds structure, one knit or shirt that softens it, and one dependable shoe that does not interrupt the silhouette."
        case .shirts:
            return "For daily dressing, the balance should stay calm: a sharper shirt, cleaner denim or soft tailoring, and one accessory that supports the wardrobe rather than leads it."
        case .sneakers:
            return "Finishing pieces should sharpen the whole composition without competing for attention. Choose one footwear anchor and one quieter accessory, then keep the rest disciplined."
        case nil:
            return "The app can keep the browse personal by narrowing choices to a smaller, more coherent edit before the customer reaches checkout."
        default:
            return "Use the prompt to narrow the catalogue into a smaller, more purposeful edit that feels easier to browse on the phone."
        }
    }

    private func loadStylistData(forceReload: Bool = false) async {
        if !forceReload && !prompts.isEmpty {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            prompts = try await APIService.shared.request("/stylist/prompts")
            selectedPrompt = prompts.first
            generateRecommendations()
            isLoading = false
        } catch {
            errorMessage = prompts.isEmpty
                ? "Stylist prompts could not be loaded right now."
                : "Unable to refresh stylist prompts right now."
            isLoading = false
        }
    }

    private func generateRecommendations() {
        let source = store.products

        guard let category = selectedPrompt?.category else {
            recommendations = Array(source.filter { !$0.isExcluded }.prefix(6))
            return
        }

        let matching = source.filter { $0.category == category && !$0.isExcluded }
        if matching.isEmpty {
            recommendations = Array(source.filter { !$0.isExcluded }.prefix(6))
        } else {
            recommendations = Array(matching.prefix(6))
        }
    }
}
