import SwiftUI
import Combine

/// Centralized app state and event store (unidirectional data flow)
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var selectedTab: AppTab = .home
    @Published var lastVisitedRoute: AppRoute = .home
    @Published var searchTerms: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var userProfile: UserProfile? = nil
    // Add more global state as needed

    @AppStorage("selectedTab") private var selectedTabRaw: String = AppTab.home.rawValue
    @AppStorage("lastVisitedRoute") private var lastVisitedRouteRaw: String = AppRoute.home.rawValue
    @AppStorage("searchTerms") private var searchTermsRaw: String = ""

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Restore persisted state
        selectedTab = AppTab(rawValue: selectedTabRaw) ?? .home
        lastVisitedRoute = AppRoute(rawValue: lastVisitedRouteRaw) ?? .home
        searchTerms = searchTermsRaw

        // Persist state on change
        $selectedTab
            .sink { [weak self] tab in self?.selectedTabRaw = tab.rawValue }
            .store(in: &cancellables)
        $lastVisitedRoute
            .sink { [weak self] route in self?.lastVisitedRouteRaw = route.rawValue }
            .store(in: &cancellables)
        $searchTerms
            .sink { [weak self] terms in self?.searchTermsRaw = terms }
            .store(in: &cancellables)
    }
}

struct UserProfile: Codable, Hashable {
    let id: String
    let name: String
    let avatarURL: String?
    // Add more user fields as needed
}
