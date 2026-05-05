import SwiftUI

struct SubscriptionBoxView: View {
    @State private var plans: [DiscoverSubscriptionPlan] = []
    @State private var selectedPlanID = ""
    @State private var activeSubscription: DiscoverSubscriptionStatus?
    @State private var isLoading = true
    @State private var isSubscribing = false
    @State private var errorMessage: String?

    private var selectedPlan: DiscoverSubscriptionPlan? {
        plans.first(where: { $0.id == selectedPlanID }) ?? plans.first
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    SkeletonView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage, retry: {
                        Task { await load() }
                    })
                } else if plans.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        message: "No subscription plans are available.",
                        actionTitle: "Reload"
                    ) {
                        Task { await load() }
                    }
                } else {
                    Picker("Plan", selection: Binding(
                        get: { selectedPlan?.id ?? selectedPlanID },
                        set: { selectedPlanID = $0 }
                    )) {
                        ForEach(plans) { plan in
                            Text(plan.interval).tag(plan.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let selectedPlan {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedPlan.title)
                                .font(BrandFont.mobileTitle())
                                .foregroundStyle(BrandPalette.textPrimary)
                            Text(BrandFormatter.price(selectedPlan.price))
                                .font(BrandFont.mobileTitle3())
                                .foregroundStyle(BrandPalette.gold)
                            Text(selectedPlan.details)
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.textSecondary)
                        }
                        .padding(16)
                        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
                    }

                    if let activeSubscription {
                        Text("Requested plan: \(activeSubscription.planID ?? selectedPlanID)")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(Color.green)
                    }

                    Button(activeSubscription?.subscribed == true ? "Request Saved" : (isSubscribing ? "Saving..." : "Save Request")) {
                        subscribe()
                    }
                    .buttonStyle(BrandCapsuleButtonStyle(tone: activeSubscription?.subscribed == true ? .chrome : .gold))
                    .disabled(isSubscribing || activeSubscription?.subscribed == true || selectedPlan == nil)
                    .frame(minHeight: 44)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Style Box")
            .task {
                await load()
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let plansTask = APIService.shared.fetchDiscoverSubscriptionPlans()
            async let stateTask = APIService.shared.fetchDiscoverUserState()
            let fetchedPlans = try await plansTask
            let userState = try? await stateTask
            plans = fetchedPlans
            activeSubscription = userState?.activeSubscription
            selectedPlanID = activeSubscription?.planID ?? selectedPlanID
            if selectedPlanID.isEmpty {
                selectedPlanID = fetchedPlans.first?.id ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
            plans = []
        }
    }

    private func subscribe() {
        guard let selectedPlan, !isSubscribing else { return }
        isSubscribing = true
        errorMessage = nil

        Task {
            do {
                let status = try await APIService.shared.subscribeToDiscoverPlan(planID: selectedPlan.id)
                await MainActor.run {
                    activeSubscription = status
                    isSubscribing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubscribing = false
                }
            }
        }
    }
}
