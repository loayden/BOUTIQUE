import SwiftUI

struct SnapMatchView: View {
    @State private var selectedMood = "Minimal"
    @State private var matches: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let moods = ["Minimal", "Street", "Formal", "Travel", "Weekend"]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose a mood and match it against the live product catalog.")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                Picker("Mood", selection: $selectedMood) {
                    ForEach(moods, id: \.self) { mood in
                        Text(mood).tag(mood)
                    }
                }
                .pickerStyle(.segmented)

                if isLoading {
                    SkeletonView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage, retry: {
                        Task { await loadMatches() }
                    })
                } else if matches.isEmpty {
                    EmptyStateView(
                        icon: "sparkle.magnifyingglass",
                        message: "No catalog matches found for this mood.",
                        actionTitle: "Retry",
                        action: {
                            Task { await loadMatches() }
                        }
                    )
                } else {
                    List(matches) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            SnapMatchProductRow(product: product, mood: selectedMood)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Style Match")
            .task {
                await loadMatches()
            }
            .onChange(of: selectedMood) { _, _ in
                Task { await loadMatches() }
            }
        }
    }

    private func loadMatches() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            matches = try await APIService.shared.fetchDiscoverSnapMatches(mood: selectedMood, limit: 12)
        } catch {
            matches = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct SnapMatchProductRow: View {
    let product: Product
    let mood: String

    var body: some View {
        HStack(spacing: 12) {
            MediaImage(name: product.heroImageName)
                .scaledToFill()
                .frame(width: 56, height: 70)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text("\(mood) match - \(BrandFormatter.price(product.price))")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
            }
        }
        .frame(minHeight: 78)
    }
}
