import Foundation

final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home

    init(selectedTab: AppTab = .home) {
        self.selectedTab = selectedTab
    }
}
