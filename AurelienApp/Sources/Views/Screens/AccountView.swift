import SwiftUI

struct AccountView: View {
    @Environment(AurelienStore.self) private var store
    @Binding var selectedTab: AppTab
    @State private var showLogin = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountErrorMessage: String?
    @State private var appeared = false

    var body: some View {
        PhoneScrollScreen { viewport in
            VStack(alignment: .leading, spacing: BrandSpacing.xxl) {
                profileSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: appeared)
                
                clientServicesSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: appeared)
                
                houseSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.15), value: appeared)
                
                orderSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: appeared)

                preferencesSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.23), value: appeared)
                
                sessionSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.27), value: appeared)
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await signOut() }
            }
        } message: {
            Text("This will end the current session on this device and return you to sign in.")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This removes your account from BOUTIQUE, clears saved data on this device, and signs you out.")
        }
        .onAppear {
            appeared = true
        }
    }

    private var profileSection: some View {
        Group {
            if let user = store.currentUser {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Private Client".uppercased())
                            .font(BrandFont.labelCapsule())
                            .tracking(4)
                            .foregroundStyle(BrandPalette.gold)
                        
                        Spacer()
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(BrandPalette.gold)
                    }

                    Text(user.name)
                        .font(BrandFont.mobileTitle())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(store.profile.note)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineSpacing(5)

                    DividerGlow()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(label: "Email", value: user.email)

                        if let phone = user.phone, !phone.isEmpty {
                            infoRow(label: "Phone", value: phone)
                        }

                        infoRow(label: "Access", value: user.isAdmin ? "Administrator" : store.profile.tier)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Welcome".uppercased())
                                .font(BrandFont.labelCapsule())
                                .tracking(4)
                                .foregroundStyle(BrandPalette.gold)

                            Text("Sign in for faster checkout, saved pieces, and order tracking.")
                                .font(BrandFont.serif(28, relativeTo: .title2))
                                .foregroundStyle(BrandPalette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(BrandPalette.gold)
                            .frame(width: 52, height: 52)
                            .background(BrandPalette.goldDim, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Text("Keep order history, delivery details, and saved pieces together in one calm account surface.")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineSpacing(5)

                    HStack(spacing: 12) {
                        AccountStatusChip(icon: "bag", title: "Bag Sync")
                        AccountStatusChip(icon: "heart", title: "Saved Pieces")
                        AccountStatusChip(icon: "shippingbox", title: "Checkout")
                    }

                    VStack(spacing: 12) {
                        Button("Sign In") {
                            showLogin = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))

                        actionRow(title: "Open Shop", subtitle: "Continue browsing the live catalog", accent: BrandPalette.textPrimary) {
                            selectedTab = .shop
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .gold, material: true)
    }

    private var clientServicesSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Client Services",
                title: "Support, wallet, stylist guidance, and notifications stay native to the account.",
                copy: "Client care, payment preferences, and stylist guidance stay close without crowding the main shopping flow."
            )

            if store.isAuthenticated {
                NavigationLink(value: AppRoute.notifications) {
                    actionRowLabel(
                        title: "Alerts",
                        subtitle: store.unreadNotificationCount == 0 ? "All updates reviewed" : "\(store.unreadNotificationCount) unread updates",
                        accent: store.unreadNotificationCount == 0 ? BrandPalette.textPrimary : BrandPalette.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: AppRoute.wallet) {
                    actionRowLabel(
                        title: "Wallet & Preferences",
                        subtitle: "\(store.savedAddresses.count) addresses • \(store.paymentMethods.count) payment methods",
                        accent: BrandPalette.textPrimary
                    )
                }
                .buttonStyle(.plain)
            } else {
                actionRow(title: "Sign In For Wallet Access", subtitle: "Saved addresses, alerts, and payment preferences require an account", accent: BrandPalette.textPrimary) {
                    showLogin = true
                }
            }

            NavigationLink(value: AppRoute.stylist) {
                actionRowLabel(
                    title: "Stylist Studio",
                    subtitle: "Prompt-led recommendations and curated edits",
                    accent: BrandPalette.accent
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.support) {
                actionRowLabel(
                    title: "Customer Support",
                    subtitle: "FAQs, contact guidance, and service channels",
                    accent: BrandPalette.textPrimary
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.legal) {
                actionRowLabel(
                    title: "Legal & Privacy",
                    subtitle: "Terms, privacy, and account policy",
                    accent: BrandPalette.textPrimary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var houseSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "House Access",
                title: "Saved pieces and brand story stay close at hand.",
                copy: "Move back into saved products or the editorial house feed without losing your account context."
            )

            NavigationLink(value: AppRoute.wishlist) {
                actionRowLabel(
                    title: "Saved Pieces",
                    subtitle: "\(store.wishlistedProducts.count) items in your wishlist",
                    accent: BrandPalette.accent
                )
            }
            .buttonStyle(.plain)

            actionRow(title: "Open Discover", subtitle: "Manifesto, lookbook, and house standards", accent: BrandPalette.textPrimary) {
                selectedTab = .discover
            }
        }
    }

    private var orderSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Orders",
                title: "Keep recent activity close at hand.",
                copy: store.isAuthenticated
                    ? (store.orders.isEmpty ? "Orders will appear here after checkout." : "Your latest order preview stays light, with the full timeline one tap away.")
                    : "Order history is available after sign-in so purchases and delivery updates stay attached to your account."
            )

            if !store.isAuthenticated {
                EmptyStatePanel(
                    title: "Sign in to view orders",
                    copy: "Order history, delivery tracking, and support follow-up are protected account data.",
                    buttonTitle: "Sign In"
                ) {
                    showLogin = true
                }
            } else if let latestOrder = store.orders.first {
                NavigationLink {
                    OrderDetailView(order: latestOrder)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Latest Order")
                                .font(BrandFont.mobileTitle3())
                                .foregroundStyle(BrandPalette.textPrimary)

                            Spacer()

                            Text(latestOrder.status.title)
                                .font(BrandFont.mobileCaption())
                                .tracking(2)
                                .foregroundStyle(BrandPalette.accent)
                        }

                        Text("\(latestOrder.lines.count) pieces • \(latestOrder.shippingCity)")
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textSecondary)

                        Text(BrandFormatter.price(latestOrder.total))
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.accent)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
                }
                .buttonStyle(.plain)
            } else {
                EmptyStatePanel(
                    title: "No orders yet",
                    copy: "Once you place an order, delivery progress and payment details will appear here.",
                    buttonTitle: "Explore Shop"
                ) {
                    selectedTab = .shop
                }
            }
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: "Preferences",
                title: "Keep personal settings and app information one tap away.",
                copy: "Device preferences, launch behavior, and house details stay available without leaving the account flow."
            )

            NavigationLink(value: AppRoute.settings) {
                actionRowLabel(
                    title: "Settings",
                    subtitle: "Notifications, launch preferences, and app behavior",
                    accent: BrandPalette.textPrimary
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.about) {
                actionRowLabel(
                    title: "About BOUTIQUE",
                    subtitle: "Brand story, contact details, and app version",
                    accent: BrandPalette.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(
                eyebrow: "Session",
                title: "History, administration, and sign-in state stay easy to manage.",
                copy: "Authentication, order access, and session controls stay grouped in one controlled section."
            )

            sessionOverviewCard

            if store.isAuthenticated {
                NavigationLink(value: AppRoute.orders) {
                    actionRowLabel(
                        title: "Order History",
                        subtitle: "View all orders",
                        accent: BrandPalette.textPrimary
                    )
                }
                .buttonStyle(.plain)
            }

            if store.isAdmin && AppExperiencePolicy.adminSurfacesEnabled {
                NavigationLink(value: AppRoute.admin) {
                    actionRowLabel(
                        title: "Admin Dashboard",
                        subtitle: "Review users, orders, and product data",
                        accent: BrandPalette.accent
                    )
                }
                .buttonStyle(.plain)
            }

            if store.isAuthenticated {
                signOutActionCard
                deleteAccountActionCard
            } else {
                signInActionCard
            }
        }
    }

    private var sessionOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Overview".uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.gold)

            Text(store.isAuthenticated ? "Your account is active on this device." : "You are currently signed out.")
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)

            Text(store.isAuthenticated
                 ? "Orders, saved pieces, checkout addresses, and payment context remain linked until you sign out."
                 : "Sign in to restore orders, wishlist activity, delivery addresses, and a faster checkout path.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                AccountStatusChip(icon: store.isAuthenticated ? "checkmark.shield" : "lock", title: store.isAuthenticated ? "Secure Session" : "Guest Mode")
                AccountStatusChip(icon: "shippingbox", title: "\(store.orders.count) Orders")
                AccountStatusChip(icon: "mappin.and.ellipse", title: "\(store.savedAddresses.count) Addresses")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
    }

    private var signOutActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Control")
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)

            Text("Use sign out when you want to remove account access from this device while keeping browsing available.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showSignOutConfirmation = true
            } label: {
                HStack {
                    Text(isSigningOut ? "Signing Out..." : "Sign Out")
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .font(BrandFont.mobileBody())
                .foregroundStyle(Color.red.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.red.opacity(0.24), lineWidth: 0.7)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSigningOut)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
    }

    private var deleteAccountActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account Deletion")
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)

            Text("Delete the account if you want BOUTIQUE to remove your profile, orders, saved pieces, addresses, and device session data.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Text(isDeletingAccount ? "Deleting Account..." : "Delete Account")
                    Spacer()
                    Image(systemName: "trash")
                }
                .font(BrandFont.mobileBody())
                .foregroundStyle(Color.red.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.red.opacity(0.24), lineWidth: 0.7)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)

            if let deleteAccountErrorMessage {
                Text(deleteAccountErrorMessage)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
    }

    private var signInActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Restore Your Account")
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)

            Text("Sign in to continue with saved addresses, wishlist activity, and a faster path into checkout.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Sign In") {
                showLogin = true
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
    }

    private func actionRow(title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionRowLabel(title: title, subtitle: subtitle, accent: accent)
        }
        .buttonStyle(.plain)
    }

    private func actionRowLabel(title: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(accent)

                Text(subtitle)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(accent == BrandPalette.gold ? BrandPalette.gold.opacity(0.7) : BrandPalette.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: accent == BrandPalette.gold ? .gold : .shadow, material: accent == BrandPalette.gold)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(BrandFont.mobileCaption2())
                .tracking(3)
                .foregroundStyle(BrandPalette.textMuted)

            Text(value)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
        }
    }

    private func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        try? await APIService.shared.logout()
        store.logout()
        showLogin = false
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        deleteAccountErrorMessage = nil

        do {
            try await store.deleteCurrentAccount()
            showLogin = false
        } catch {
            deleteAccountErrorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct AccountStatusChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandPalette.gold)

            Text(title)
                .font(BrandFont.mobileCaption2())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 12)
        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

struct SettingsView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(NetworkMonitor.self) private var networkMonitor

    @AppStorage("settings.pushOrderUpdates") private var pushOrderUpdates = true
    @AppStorage("settings.pushEditorialAlerts") private var pushEditorialAlerts = true
    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("settings.defaultLandingTab") private var defaultLandingTab = AppTab.home.rawValue

    private var resolvedLandingTab: AppTab {
        AppTab(rawValue: defaultLandingTab) ?? .home
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Settings",
                    title: "App behavior, launch preferences, and delivery signals.",
                    copy: "These controls stay local to the device so the client experience remains stable even when the network is under load."
                )

                settingsSection(
                    title: "In-App Alerts",
                    subtitle: "Choose which alerts stay visible on this device."
                ) {
                    settingsToggle(
                        title: "Order Alerts",
                        subtitle: "Shipping status, delivery progress, and post-order actions shown inside the app.",
                        isOn: $pushOrderUpdates
                    )
                    settingsToggle(
                        title: "Editorial Alerts",
                        subtitle: "New drops, collection edits, and personalized recommendations shown in-app.",
                        isOn: $pushEditorialAlerts
                    )
                }

                settingsSection(
                    title: "Experience",
                    subtitle: "Keep interaction behavior predictable across launches."
                ) {
                    settingsToggle(
                        title: "Haptics",
                        subtitle: "Subtle tactile feedback on wishlist, bag, and checkout actions.",
                        isOn: $hapticsEnabled
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Default Landing Tab")
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)

                        Picker("Default Landing Tab", selection: $defaultLandingTab) {
                            ForEach(AppTab.allCases, id: \.self) { tab in
                                Text(tab.label).tag(tab.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("The app will open on \(resolvedLandingTab.label) after sign-in when that context is available.")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
                }

                settingsSection(
                    title: "Data & Device",
                    subtitle: "Quick status and local cleanup actions."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        statusRow("Connection", value: networkMonitor.statusDescription)
                        statusRow("Saved Pieces", value: "\(store.wishlistedProducts.count)")
                        statusRow("Unread Notifications", value: "\(store.unreadNotificationCount)")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)

                    Button("Clear Recent Searches") {
                        store.clearRecentQueries()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome))
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
    }

    private func settingsSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            BrandSectionHeader(
                eyebrow: title,
                title: title,
                copy: subtitle
            )

            content()
        }
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineSpacing(4)
            }
        }
        .toggleStyle(.switch)
        .tint(BrandPalette.gold)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
    }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)

            Spacer()

            Text(value)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
        }
    }
}

struct AboutAppView: View {
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "About",
                    title: "BOUTIQUE brings menswear into a faster delivery model.",
                    copy: "The app combines curated catalog browsing, premium checkout, and client-service follow-up in one native commerce experience."
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text("House Story")
                        .font(BrandFont.serif(24, relativeTo: .title2))
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("BOUTIQUE is designed as a luxury fashion marketplace for clients who want the pace of modern delivery with the polish of a private boutique. The app keeps shopping, checkout, and client care calm, image-led, and direct.")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .lineSpacing(5)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)

                VStack(alignment: .leading, spacing: 12) {
                    statusRow("App", value: "BOUTIQUE")
                    statusRow("Build", value: appVersion)
                    statusRow("Support", value: "Support Center")
                    statusRow("Coverage", value: "Egypt")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)

                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink(value: AppRoute.support) {
                        aboutActionRow(
                            title: "Open Support Center",
                            subtitle: "FAQs, service channels, and order help."
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AppRoute.legal) {
                        aboutActionRow(
                            title: "Open Legal Center",
                            subtitle: "Terms, privacy, and account policies."
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("About BOUTIQUE")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Account")
    }

    private func aboutActionRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(BrandPalette.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
    }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)

            Spacer()

            Text(value)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
        }
    }
}
