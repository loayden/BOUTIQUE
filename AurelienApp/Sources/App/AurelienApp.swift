import Network
import SwiftUI

@main
struct BoutApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: AurelienStore
    @State private var networkMonitor: NetworkMonitor

    init() {
        APIConfig.validateLaunchConfiguration()
        AppExperiencePolicy.validateLaunchConfiguration()
        BrandAppearance.configure()
        _store = State(
            initialValue: AurelienStore(
                startBackgroundTasks: !APIConfig.isRunningAutomatedTests,
                restorePersistedSession: !APIConfig.isRunningAutomatedTests
            )
        )
        _networkMonitor = State(initialValue: APIConfig.isRunningAutomatedTests ? .testing : .shared)
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if APIConfig.isRunningAutomatedTests {
            TestHostBootstrapView()
        } else {
            AppShellView()
                .environment(store)
                .environment(networkMonitor)
                .tint(BrandPalette.gold)
                .mobileOnly()
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        store.handleAppDidEnterBackground()
                    case .active:
                        store.handleAppDidBecomeActive()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    static let testing = NetworkMonitor(startMonitoring: false)

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.shereenmagdy.aurelien.network-monitor")

    var isConnected = true
    var isExpensive = false
    var statusDescription = "Online"

    private init(startMonitoring: Bool = true) {
        guard startMonitoring else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func apply(path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive

        switch path.status {
        case .satisfied:
            statusDescription = path.isExpensive ? "Connected on cellular" : "Online"
        case .requiresConnection:
            statusDescription = "Connecting"
        case .unsatisfied:
            statusDescription = "Offline"
        @unknown default:
            statusDescription = "Network status unavailable"
        }
    }
}

private struct TestHostBootstrapView: View {
    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

enum AppTab: String, CaseIterable, Codable {
    case home
    case discover
    case shop
    case bag
    case account

    var icon: String {
        switch self {
        case .home: return "house"
        case .discover: return "sparkles"
        case .shop: return "rectangle.stack"
        case .bag: return "bag"
        case .account: return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .discover: return "sparkles"
        case .shop: return "rectangle.stack.fill"
        case .bag: return "bag.fill"
        case .account: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .discover: return "Discover"
        case .shop: return "Shop"
        case .bag: return "Bag"
        case .account: return "Account"
        }
    }
}
