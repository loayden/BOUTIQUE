import SwiftUI

struct LimitedDropsView: View {
    @State private var drops: [DiscoverDropData] = []
    @State private var joinedDropIDs: Set<String> = []
    @State private var pendingDropIDs: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SkeletonView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage, retry: {
                        Task { await loadDrops() }
                    })
                } else if drops.isEmpty {
                    EmptyStateView(
                        icon: "flame",
                        message: "No limited drops are available.",
                        actionTitle: "Reload"
                    ) {
                        Task { await loadDrops() }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(drops) { drop in
                                LimitedDropCard(
                                    drop: drop,
                                    countdownText: countdownText(for: drop),
                                    isJoined: joinedDropIDs.contains(drop.id),
                                    isPending: pendingDropIDs.contains(drop.id)
                                ) {
                                    Task { await join(drop) }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Limited Drops")
            .task {
                await loadDrops()
            }
        }
    }

    private func loadDrops() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let dropsTask = APIService.shared.fetchDiscoverDrops()
            async let stateTask = APIService.shared.fetchDiscoverUserState()
            drops = try await dropsTask
            joinedDropIDs = Set((try? await stateTask)?.waitlistedDropIDs ?? [])
        } catch {
            drops = []
            errorMessage = error.localizedDescription
        }
    }

    private func join(_ drop: DiscoverDropData) async {
        guard joinedDropIDs.contains(drop.id) == false,
              pendingDropIDs.contains(drop.id) == false else {
            return
        }

        pendingDropIDs.insert(drop.id)
        defer { pendingDropIDs.remove(drop.id) }

        do {
            _ = try await APIService.shared.joinDiscoverDropWaitlist(dropID: drop.id)
            joinedDropIDs.insert(drop.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func countdownText(for drop: DiscoverDropData) -> String {
        guard let unlocksAt = drop.unlocksAt else { return "Live now" }
        let seconds = max(0, Int(unlocksAt.timeIntervalSinceNow))
        if seconds == 0 { return "Live now" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 { return "Unlocks in \(days)d \(hours)h" }
        return "Unlocks in \(max(1, seconds / 60))m"
    }
}

private struct LimitedDropCard: View {
    let drop: DiscoverDropData
    let countdownText: String
    let isJoined: Bool
    let isPending: Bool
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drop.name)
                        .font(BrandFont.mobileTitle3())
                        .foregroundStyle(BrandPalette.textPrimary)
                    Text(countdownText)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.gold)
                }

                Spacer()

                Text(drop.stock > 0 ? "\(drop.stock) left" : "Waitlist")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textPrimary)
            }

            Text(drop.copy)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)

            Button(isJoined ? "Joined Waitlist" : (isPending ? "Joining..." : "Join Waitlist")) {
                onJoin()
            }
            .buttonStyle(BrandCapsuleButtonStyle(tone: isJoined ? .chrome : .gold))
            .disabled(isJoined || isPending)
            .frame(minHeight: 44)
        }
        .padding(16)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}
