import AppIntents

@available(iOS 17.0, *)
struct OpenShopIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Shop"
    static let description = IntentDescription("Open the BOUTIQUE shop tab.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppStore.shared.selectedTab = .shop
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct BoutiqueAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenShopIntent(),
            phrases: [
                "Open shop in \(.applicationName)",
                "Browse \(.applicationName)"
            ],
            shortTitle: "Open Shop",
            systemImageName: "bag"
        )
    }
}
