import SwiftUI

struct ProfileView: View {
    @Binding var selectedTab: AppTab

    init(selectedTab: Binding<AppTab> = .constant(.account)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        AccountView(selectedTab: $selectedTab)
    }
}
