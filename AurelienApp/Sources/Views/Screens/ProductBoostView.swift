import SwiftUI

struct ProductBoostView: View {
    @State private var budget: Double = 400
    @State private var days = 3
    @State private var estimatedReach: Int?
    @State private var activation: DiscoverBoostActivation?
    @State private var isEstimating = false
    @State private var isActivating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget: \(BrandFormatter.price(budget))")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textPrimary)
                    Slider(value: $budget, in: 100...3000, step: 50)
                }

                Stepper("Duration: \(days) days", value: $days, in: 1...14)

                if let estimatedReach {
                    Text("Estimated reach: \(estimatedReach) users")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                } else if isEstimating {
                    ProgressView()
                }

                if let activation {
                    Text("Campaign request \(activation.campaignID ?? "saved") has \(activation.estimatedReach) estimated users.")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(Color.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(.red)
                }

                Button(activation == nil ? (isActivating ? "Saving..." : "Save Campaign Request") : "Request Saved") {
                    activate()
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: activation == nil ? .gold : .chrome))
                .disabled(isActivating || activation != nil)
                .frame(minHeight: 44)

                Spacer()
            }
            .padding()
            .navigationTitle("Campaign Request")
            .task {
                await estimate()
            }
            .onChange(of: budget) { _, _ in
                Task { await estimate() }
            }
            .onChange(of: days) { _, _ in
                Task { await estimate() }
            }
        }
    }

    private func estimate() async {
        guard !isEstimating else { return }
        isEstimating = true
        errorMessage = nil
        defer { isEstimating = false }

        do {
            estimatedReach = try await APIService.shared.estimateDiscoverBoostReach(
                budget: budget,
                days: days
            )
        } catch {
            estimatedReach = nil
            errorMessage = error.localizedDescription
        }
    }

    private func activate() {
        guard !isActivating else { return }
        isActivating = true
        errorMessage = nil

        Task {
            do {
                let result = try await APIService.shared.activateDiscoverSellerBoost(
                    budget: budget,
                    days: days
                )
                await MainActor.run {
                    activation = result
                    isActivating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isActivating = false
                }
            }
        }
    }
}
