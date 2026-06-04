import SwiftUI

/// Typed route enum for all app navigation.
public enum AppRoute: String, Hashable, Codable {
    case home
    case discover
    case bag
    case profile
    case login
    case orders
    case admin
    case checkout
    case wishlist
    case notifications
    case wallet
    case support
    case stylist
    case legal
    case settings
    case about
}

enum AppLaunchDestination: Equatable {
    case splash
    case onboarding
    case mainApp
    case auth

    static func resolve(
        showSplash: Bool,
        didCompleteOnboarding: Bool,
        isAuthenticated: Bool
    ) -> Self {
        if showSplash {
            return .splash
        }

        if !didCompleteOnboarding {
            return .onboarding
        }

        if isAuthenticated || AppExperiencePolicy.allowsGuestBrowsing {
            return .mainApp
        }

        return .auth
    }
}

enum ReleaseReadinessIssue: Hashable {
    case missingPrivacyManifest
    case invalidAPIBaseURL
    case invalidStaticContentBaseURL
    case invalidPrivacyPolicyURL
    case invalidSupportURL
}

enum ReleaseReadinessValidator {
    static func issues(
        apiBaseURL: String?,
        staticContentBaseURL: String?,
        privacyManifestPresent: Bool,
        privacyPolicyURL: String? = nil,
        supportURL: String? = nil
    ) -> Set<ReleaseReadinessIssue> {
        var issues = Set<ReleaseReadinessIssue>()

        if !privacyManifestPresent {
            issues.insert(.missingPrivacyManifest)
        }

        if !isValidProductionURL(apiBaseURL) {
            issues.insert(.invalidAPIBaseURL)
        }

        if !isValidProductionURL(staticContentBaseURL) {
            issues.insert(.invalidStaticContentBaseURL)
        }

        if !isValidProductionURL(privacyPolicyURL) {
            issues.insert(.invalidPrivacyPolicyURL)
        }

        if !isValidProductionURL(supportURL) {
            issues.insert(.invalidSupportURL)
        }

        return issues
    }

    private static func isValidProductionURL(_ rawValue: String?) -> Bool {
        guard let rawValue else { return false }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmed.isEmpty == false,
            trimmed.contains("$(") == false,
            let url = URL(string: trimmed),
            url.scheme?.lowercased() == "https",
            url.host?.isEmpty == false
        else {
            return false
        }

        return true
    }
}

enum AppExperiencePolicy {
    static let allowsGuestBrowsing = true
    static let exposesAdminSurfacesInPublicRelease = false

    private static let privacyPolicyURLKey = "BOUTIQUE_PRIVACY_POLICY_URL"
    private static let supportURLKey = "BOUTIQUE_SUPPORT_URL"

    static var adminSurfacesEnabled: Bool {
#if DEBUG
        true
#else
        exposesAdminSurfacesInPublicRelease
#endif
    }

    static func publicRoute(
        for route: AppRoute,
        isAdmin: Bool,
        isAuthenticated: Bool = true
    ) -> AppRoute {
        switch route {
        case .admin:
            return adminSurfacesEnabled && isAdmin ? .admin : .profile
        case .orders, .wallet, .notifications:
            return isAuthenticated ? route : .login
        default:
            return route
        }
    }

    static var privacyPolicyURL: URL? {
        configuredURL(for: privacyPolicyURLKey)
    }

    static var supportURL: URL? {
        configuredURL(for: supportURLKey)
    }

    static func validateLaunchConfiguration() {
#if !DEBUG
        let issues = ReleaseReadinessValidator.issues(
            apiBaseURL: Bundle.main.object(forInfoDictionaryKey: "AURELIEN_API_BASE_URL") as? String,
            staticContentBaseURL: Bundle.main.object(forInfoDictionaryKey: "AURELIEN_STATIC_CONTENT_BASE_URL") as? String,
            privacyManifestPresent: Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil,
            privacyPolicyURL: Bundle.main.object(forInfoDictionaryKey: privacyPolicyURLKey) as? String,
            supportURL: Bundle.main.object(forInfoDictionaryKey: supportURLKey) as? String
        )
        precondition(
            issues.isEmpty,
            "Release build is missing App Store readiness configuration: \(issues)"
        )
#endif
    }

    private static func configuredURL(for key: String) -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.contains("$(") == false else {
            return nil
        }

        return URL(string: trimmed)
    }
}
