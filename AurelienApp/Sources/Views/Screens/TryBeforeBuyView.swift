import SwiftUI

struct TryBeforeBuyView: View {
    @State private var products: [Product] = []
    @State private var selectedIDs: Set<String> = []
    @State private var receipt: DiscoverReservationReceipt?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SkeletonView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage, retry: {
                        Task { await loadProducts() }
                    })
                } else if products.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox.fill",
                        message: "No in-stock catalog items are available.",
                        actionTitle: "Reload"
                    ) {
                        Task { await loadProducts() }
                    }
                } else {
                    List {
                        ForEach(products) { product in
                            Button {
                                if selectedIDs.contains(product.id) {
                                    selectedIDs.remove(product.id)
                                } else {
                                    selectedIDs.insert(product.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    MediaImage(name: product.heroImageName)
                                        .scaledToFill()
                                        .frame(width: 52, height: 64)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name)
                                            .font(BrandFont.mobileBody())
                                            .foregroundStyle(BrandPalette.textPrimary)
                                        Text(BrandFormatter.price(product.price))
                                            .font(BrandFont.mobileCaption())
                                            .foregroundStyle(BrandPalette.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedIDs.contains(product.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(product.id) ? BrandPalette.gold : BrandPalette.textSecondary)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }

                        if let receipt {
                            Text("Reservation \(receipt.id) saved with \(receipt.productIDs.count) item(s).")
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(Color.green)
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button(selectedIDs.isEmpty ? "Select Items" : (isSubmitting ? "Reserving..." : "Reserve \(selectedIDs.count) Item(s)")) {
                            submit()
                        }
                        .buttonStyle(BrandCapsuleButtonStyle(tone: selectedIDs.isEmpty ? .chrome : .gold))
                        .disabled(selectedIDs.isEmpty || isSubmitting)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("Try Before You Buy")
            .task {
                await loadProducts()
            }
        }
    }

    private func loadProducts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            products = try await APIService.shared.fetchProducts()
                .filter { $0.isInStock }
                .prefix(24)
                .map { $0 }
        } catch {
            products = []
            errorMessage = error.localizedDescription
        }
    }

    private func submit() {
        guard selectedIDs.isEmpty == false, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        receipt = nil

        Task {
            do {
                let reservation = try await APIService.shared.submitTryBeforeBuySelection(productIDs: Array(selectedIDs))
                await MainActor.run {
                    receipt = reservation
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}
