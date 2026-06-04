import SwiftUI

final class AppChromeState: ObservableObject {
    @Published var isTabBarHidden = false
}

struct AppShellView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(NetworkMonitor.self) private var networkMonitor
    @AppStorage("aurelien.didCompleteOnboarding.v2") private var didCompleteOnboarding = false
    @StateObject private var chromeState = AppChromeState()
    @State private var showSplash = true
    @State private var mountedTabs: Set<AppTab> = [.home]

    var body: some View {
        AppRootView(
            showSplash: showSplash,
            didCompleteOnboarding: didCompleteOnboarding,
            isAuthenticated: store.isAuthenticated,
            splashView: {
                LaunchSplashView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
            },
            onboardingView: {
                FirstLaunchOnboardingView {
                    didCompleteOnboarding = true
                }
            },
            authView: {
                LoginView(allowsClose: false)
            },
            mainAppView: {
                authenticatedShell
                    .environmentObject(chromeState)
            }
        )
    }

    private var authenticatedShell: some View {
        ZStack(alignment: .bottom) {
            tabContainer
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if chromeState.isTabBarHidden == false {
                        BoutTabBar(selectedTab: tabSelection, bagCount: store.bagCount)
                    }
                }
                .onOpenURL(perform: handleDeepLink)
                .sheet(item: activeSheetBinding) { sheet in
                    sheetDestination(for: sheet)
                }

            if networkMonitor.isConnected == false && APIConfig.usesEmbeddedStaticBackend == false {
                NetworkStatusBanner(message: networkMonitor.statusDescription)
                    .padding(.horizontal, 16)
                    .padding(.bottom, chromeState.isTabBarHidden ? 16 : MobileChrome.bottomOverlayInset(for: UIScreen.main.bounds.width))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.2), value: chromeState.isTabBarHidden)
        .onAppear {
            if let preferredTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "settings.defaultLandingTab") ?? ""),
               store.path(for: store.selectedTab).isEmpty,
               store.selectedTab == .home,
               preferredTab != .home {
                Task { @MainActor in
                    await Task.yield()
                    guard store.selectedTab == .home, store.path(for: .home).isEmpty else {
                        return
                    }
                    store.selectedTab = preferredTab
                }
            }
        }
    }

    private var tabContainer: some View {
        ZStack {
            ForEach(AppTab.allCases.filter { mountedTabs.contains($0) }, id: \.self) { tab in
                tabNavigationRoot(for: tab)
                    .opacity(store.selectedTab == tab ? 1 : 0)
                    .allowsHitTesting(store.selectedTab == tab)
                    .accessibilityHidden(store.selectedTab != tab)
            }
        }
        .onAppear {
            mountedTabs.insert(store.selectedTab)
        }
        .onChange(of: store.selectedTab) { _, tab in
            mountedTabs.insert(tab)
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { store.selectedTab },
            set: { store.selectedTab = $0 }
        )
    }

    private var activeSheetBinding: Binding<AurelienStore.AppSheet?> {
        Binding(
            get: { store.activeSheet },
            set: { store.activeSheet = $0 }
        )
    }

    private func pathBinding(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { store.path(for: tab) },
            set: { store.setPath($0, for: tab) }
        )
    }

    private func tabNavigationRoot(for tab: AppTab) -> some View {
        NavigationStack(path: pathBinding(for: tab)) {
            tabRootView(for: tab)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Product.self) { product in
                    ProductDetailView(product: product)
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .tag(tab)
    }

    @ViewBuilder
    private func tabRootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView(selectedTab: tabSelection)
        case .discover:
            DiscoverView()
        case .shop:
            ShopView()
        case .bag:
            BagView()
        case .account:
            AccountView(selectedTab: tabSelection)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch AppExperiencePolicy.publicRoute(
            for: route,
            isAdmin: store.isAdmin,
            isAuthenticated: store.isAuthenticated
        ) {
        case .home:
            HomeView(selectedTab: tabSelection)
        case .discover:
            DiscoverView()
        case .profile:
            AccountView(selectedTab: tabSelection)
        case .login:
            LoginView()
        case .bag:
            BagView()
        case .orders:
            OrdersView()
        case .admin:
            AdminDashboardView()
        case .checkout:
            CheckoutView()
        case .wishlist:
            WishlistView(selectedTab: tabSelection)
        case .notifications:
            NotificationsView()
        case .wallet:
            ClientWalletView()
        case .support:
            SupportCenterView()
        case .stylist:
            StylistStudioView()
        case .legal:
            LegalCenterView()
        case .settings:
            SettingsView()
        case .about:
            AboutAppView()
        }
    }

    @ViewBuilder
    private func sheetDestination(for sheet: AurelienStore.AppSheet) -> some View {
        switch sheet {
        case .auth:
            LoginView()
        case .checkout:
            NavigationStack {
                CheckoutView()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        if let productID = deepLinkedID(in: url, singular: "product", plural: "products") {
            openDeepLinkedProduct(productID)
            return
        }

        if deepLinkedID(in: url, singular: "order", plural: "orders") != nil {
            store.selectedTab = .account
            store.handleDeepLink(.orders)
            return
        }

        let segment = (url.host ?? url.pathComponents.dropFirst().first ?? "").lowercased()

        switch segment {
        case "home":
            store.selectedTab = .home
        case "discover":
            store.selectedTab = .discover
        case "shop":
            store.selectedTab = .shop
        case "bag":
            store.selectedTab = .bag
        case "account", "profile":
            store.selectedTab = .account
        case "orders":
            store.selectedTab = .account
            store.handleDeepLink(.orders)
        case "wishlist":
            store.selectedTab = .account
            store.handleDeepLink(.wishlist)
        case "notifications":
            store.selectedTab = .account
            store.handleDeepLink(.notifications)
        case "wallet":
            store.selectedTab = .account
            store.handleDeepLink(.wallet)
        case "admin":
            store.selectedTab = .account
            store.handleDeepLink(
                AppExperiencePolicy.publicRoute(
                    for: .admin,
                    isAdmin: store.isAdmin,
                    isAuthenticated: store.isAuthenticated
                )
            )
        case "support":
            store.selectedTab = .account
            store.handleDeepLink(.support)
        case "stylist":
            store.selectedTab = .account
            store.handleDeepLink(.stylist)
        case "legal":
            store.selectedTab = .account
            store.handleDeepLink(.legal)
        case "settings":
            store.selectedTab = .account
            store.handleDeepLink(.settings)
        case "about":
            store.selectedTab = .account
            store.handleDeepLink(.about)
        case "checkout":
            store.present(.checkout)
        default:
            break
        }
    }

    private func deepLinkedID(in url: URL, singular: String, plural: String) -> String? {
        let host = url.host?.lowercased()
        let parts = url.pathComponents
            .filter { $0 != "/" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if host == singular || host == plural {
            return parts.first
        }

        guard let first = parts.first?.lowercased(),
              first == singular || first == plural,
              parts.count > 1 else {
            return nil
        }
        return parts[1]
    }

    private func openDeepLinkedProduct(_ productID: String) {
        Task { @MainActor in
            if store.products.isEmpty {
                _ = try? await store.loadCatalog(forceRefresh: false)
            }

            guard let product = store.products.first(where: { $0.id == productID }) else {
                store.selectedTab = .shop
                return
            }

            store.selectedTab = .shop
            var path = store.path(for: .shop)
            path.append(product)
            store.setPath(path, for: .shop)
        }
    }
}

private struct AppRootView<Splash: View, Onboarding: View, Auth: View, MainApp: View>: View {
    let showSplash: Bool
    let didCompleteOnboarding: Bool
    let isAuthenticated: Bool
    @ViewBuilder let splashView: () -> Splash
    @ViewBuilder let onboardingView: () -> Onboarding
    @ViewBuilder let authView: () -> Auth
    @ViewBuilder let mainAppView: () -> MainApp

    var body: some View {
        Group {
            switch AppLaunchDestination.resolve(
                showSplash: showSplash,
                didCompleteOnboarding: didCompleteOnboarding,
                isAuthenticated: isAuthenticated
            ) {
            case .splash:
                splashView()
            case .onboarding:
                onboardingView()
            case .mainApp:
                mainAppView()
            case .auth:
                authView()
            }
        }
    }
}

private struct FirstLaunchOnboardingView: View {
    let completion: () -> Void

    @State private var page = 0

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            eyebrow: "BOUTIQUE",
            title: "Luxury menswear, ready to shop.",
            copy: "Browse real products, save favorites, and checkout without losing your place.",
            systemImage: "bag.badge.plus"
        ),
        OnboardingSlide(
            eyebrow: "Live Stock",
            title: "Know what is available before you buy.",
            copy: "Sizes, stock, delivery fees, and order status stay clear from shop to delivery.",
            systemImage: "shippingbox"
        ),
        OnboardingSlide(
            eyebrow: "Your Account",
            title: "Your bag, wishlist, and orders stay with you.",
            copy: "Saved details and order history come back when you reopen the app.",
            systemImage: "sparkles"
        )
    ]

    var body: some View {
        ZStack {
            AmbientBackdrop()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Button("Skip") {
                        completion()
                    }
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                Spacer(minLength: 12)

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        onboardingSlide(slide)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index == page ? BrandPalette.gold : BrandPalette.hairlineStrong)
                            .frame(width: index == page ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: page)
                    }
                }
                .padding(.top, 20)

                Button(page == slides.indices.last ? "Start Shopping" : "Next") {
                    if page < slides.count - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            page += 1
                        }
                    } else {
                        completion()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 42)
            }
        }
    }

    private func onboardingSlide(_ slide: OnboardingSlide) -> some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.height < 760

            ScrollView(showsIndicators: false) {
                VStack(spacing: compactLayout ? 18 : 24) {
                    Spacer(minLength: compactLayout ? 18 : 28)

                    ZStack {
                        RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                            .fill(BrandPalette.goldDim)
                            .frame(width: compactLayout ? 86 : 100, height: compactLayout ? 86 : 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                                    .stroke(BrandPalette.goldBorder, lineWidth: 0.6)
                            )

                        Image(systemName: slide.systemImage)
                            .font(.system(size: compactLayout ? 30 : 34, weight: .light))
                            .foregroundStyle(BrandPalette.gold)
                    }

                    VStack(spacing: compactLayout ? 10 : 12) {
                        Text(slide.eyebrow.uppercased())
                            .font(BrandFont.mobileCaption2())
                            .tracking(3)
                            .foregroundStyle(BrandPalette.gold)

                        Text(slide.title)
                            .font(BrandFont.serif(compactLayout ? 26 : 30, relativeTo: .largeTitle))
                            .foregroundStyle(BrandPalette.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(compactLayout ? 4 : 6)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(slide.copy)
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, compactLayout ? 24 : 28)

                    VStack(alignment: .leading, spacing: compactLayout ? 8 : 12) {
                        onboardingBenefit("Real catalog and product photos", compact: compactLayout)
                        onboardingBenefit("Saved wishlist, bag, address, and orders", compact: compactLayout)
                        onboardingBenefit("Order tracking and support in one account", compact: compactLayout)
                    }
                    .padding(compactLayout ? 14 : 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandPanel(cornerRadius: BrandRadius.sheet, tone: .chrome, material: true)
                    .padding(.horizontal, 20)

                    Spacer(minLength: compactLayout ? 18 : 24)
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    private func onboardingBenefit(_ text: String, compact: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BrandPalette.gold)

            Text(text)
                .font(compact ? BrandFont.mobileCaption() : BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingSlide {
    let eyebrow: String
    let title: String
    let copy: String
    let systemImage: String
}

private struct NetworkStatusBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(BrandPalette.goldDeep)

            Text(message)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textPrimary)

            Spacer(minLength: 0)

            Text("Reconnect to refresh live content")
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .brandPanel(cornerRadius: 16, tone: .chrome, material: true)
    }
}

private struct MainContentView: View {
    let selectedTab: Binding<AppTab>

    var body: some View {
        switch selectedTab.wrappedValue {
        case .home:
            HomeView(selectedTab: selectedTab)
        case .discover:
            DiscoverView()
        case .shop:
            ShopView()
        case .bag:
            BagView()
        case .account:
            AccountView(selectedTab: selectedTab)
        }
    }
}

private struct LaunchSplashView: View {
    let completion: () -> Void
    @State private var contentVisible = false
    @State private var logoScaled = false

    var body: some View {
        ZStack {
            BrandPalette.backgroundGradient
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 18) {
                    LaunchLogoView(imageName: "BoutiqueLogo")
                        .frame(width: 108, height: 108)
                        .scaleEffect(logoScaled ? 1.0 : 0.95)
                        .opacity(contentVisible ? 1 : 0)

                    Text("BOUTIQUE")
                        .font(BrandFont.displayHero())
                        .foregroundStyle(BrandPalette.textPrimary)
                        .tracking(1.4)
                        .multilineTextAlignment(.center)
                        .scaleEffect(logoScaled ? 1.0 : 0.95)
                        .opacity(contentVisible ? 1 : 0)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if contentVisible {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [BrandPalette.gold.opacity(0.18), BrandPalette.gold.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 1.5)
                    .cornerRadius(1)
                    .padding(.horizontal, 88)
                    .offset(y: 150)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: contentVisible)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                contentVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    logoScaled = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion()
            }
        }
    }
}

private struct LaunchLogoView: View {
    let imageName: String

    var body: some View {
        if let logo = UIImage(named: imageName) {
            Image(uiImage: logo)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))
                .shadow(color: BrandPalette.shadowStrong.opacity(0.16), radius: 18, x: 0, y: 8)
        } else {
            Image(systemName: "bag.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(BrandPalette.gold)
                .padding(20)
                .background(BrandPalette.surface)
                .clipShape(Circle())
                .shadow(color: BrandPalette.shadowSoft.opacity(0.25), radius: 20, x: 0, y: 12)
        }
    }
}
