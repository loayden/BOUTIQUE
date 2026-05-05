import SwiftUI

struct StyleProfileView: View {
    @State private var selectedStyle = "Minimal Tailored"
    @State private var selectedPalette = "Neutrals"
    @State private var selectedFit = "Regular"
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedMessage: String?
    @State private var errorMessage: String?

    private let styles = ["Minimal Tailored", "Street Luxe", "Classic Formal", "Athleisure Clean", "Avant Garde"]
    private let palettes = ["Neutrals", "Monochrome", "Earth Tones", "Contrast Pops"]
    private let fits = ["Slim", "Regular", "Relaxed", "Oversized"]

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Section("Style") {
                        Picker("Direction", selection: $selectedStyle) {
                            ForEach(styles, id: \.self) { Text($0) }
                        }
                        Picker("Palette", selection: $selectedPalette) {
                            ForEach(palettes, id: \.self) { Text($0) }
                        }
                        Picker("Fit", selection: $selectedFit) {
                            ForEach(fits, id: \.self) { Text($0) }
                        }
                    }
                }

                if let savedMessage {
                    Text(savedMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(Color.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Style Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveProfile()
                    }
                    .disabled(isLoading || isSaving)
                }
            }
            .task {
                await loadProfile()
            }
        }
    }

    private func loadProfile() async {
        guard isLoading else { return }
        errorMessage = nil
        do {
            let profile = try await APIService.shared.fetchDiscoverStyleDNA()
            selectedStyle = profile.style
            selectedPalette = profile.palette
            selectedFit = profile.fit
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func saveProfile() {
        guard !isSaving else { return }
        isSaving = true
        savedMessage = nil
        errorMessage = nil

        let profile = DiscoverStyleDNAProfile(
            style: selectedStyle,
            palette: selectedPalette,
            fit: selectedFit
        )

        Task {
            do {
                let saved = try await APIService.shared.saveDiscoverStyleDNA(profile)
                await MainActor.run {
                    selectedStyle = saved.style
                    selectedPalette = saved.palette
                    selectedFit = saved.fit
                    savedMessage = "Saved \(saved.summary)."
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
