import SwiftUI
import UIKit

enum BrandPalette {
    // MARK: Backgrounds
    static let background = Color.boutBackground
    static let backgroundWarm = Color.boutCreamTop
    static let productMediaBackground = Color.boutWarmSurface.opacity(0.98)
    static let surface = Color.boutCreamTop.opacity(0.90)
    static let surfaceRaised = Color.boutWarmSurface.opacity(0.98)
    static let surfaceElevated = Color.white.opacity(0.74)
    static let overlay = Color.boutCreamTop.opacity(0.72)
    static let surfaceGlass = Color.white.opacity(0.62)

    // MARK: Accents
    static let gold = Color.boutGold
    static let goldWarm = Color.boutGold
    static let goldLight = Color(hex: "#C8A66A")
    static let goldDeep = Color.boutGoldText
    static let goldGlow = Color.boutGold.opacity(0.18)
    static let goldDim = Color.boutGold.opacity(0.10)
    static let goldShimmer = Color.boutGold.opacity(0.72)
    static let sage = Color.boutSuccess
    static let steel = Color.boutInkSoft
    static let rose = Color.boutError

    static let accent = gold
    static let accentLight = goldLight
    static let accentDeep = goldWarm
    static let accentDim = goldDim
    static let accentForeground = Color.boutCreamTop

    // MARK: Typography
    static let ivory = Color.boutCreamTop
    static let sand = Color.boutMuted
    static let muted = Color.boutInk.opacity(0.70)
    static let ivoryMuted = sand

    static let textPrimary = Color.boutInk
    static let textSecondary = Color.boutMuted
    static let textMuted = Color.boutInk.opacity(0.70)
    static let error = Color.boutError
    static let success = Color.boutSuccess

    // MARK: Borders / Glass
    static let hairline = Color.boutBorder
    static let hairlineStrong = Color.boutBorderStrong
    static let goldBorder = Color.boutGold.opacity(0.24)
    static let hairlineGold = goldBorder

    static let glassLight = Color.white.opacity(0.78)
    static let glassMedium = Color.boutWarmSurface.opacity(0.82)
    static let glassDark = Color.boutWarmSurface.opacity(0.96)
    static let glassBorder = hairlineStrong
    static let glassBorderGold = goldBorder

    // MARK: Shadows / Ambient
    static let shadowSoft = Color.boutInk.opacity(0.06)
    static let shadowMedium = Color.boutInk.opacity(0.10)
    static let shadowStrong = Color.boutInk.opacity(0.16)
    static let shadowGlow = goldGlow.opacity(0.24)

    static let ambientGold = goldGlow
    static let ambientLight = Color.boutCreamTop.opacity(0.45)

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color.boutButtonStart, Color.boutButtonEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.72), Color.boutWarmSurface.opacity(0.94), Color.boutCreamTop.opacity(0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.boutCreamTop, Color.boutBackground, Color.boutWarmSurface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum BrandSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
    static let xxxl: CGFloat = 48
}

enum BrandRadius {
    static let soft: CGFloat = 10
    static let card: CGFloat = 12
    static let sheet: CGFloat = 18
    static let pill: CGFloat = 999
    static let luxury: CGFloat = 14
    static let image: CGFloat = 14
}

enum BrandShadow {
    static let card = Color.boutInk.opacity(0.10)
    static let deep = Color.boutInk.opacity(0.16)
}

enum BrandHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func softImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func notificationSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func notificationWarning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func notificationError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

enum BrandAppearance {
    static func configure() {
        let selectedColor = UIColor(hexString: "#73561F")
        let normalColor = UIColor(hexString: "#4E4A45")
        let backgroundColor = UIColor(hexString: "#FFFDF8", alpha: 0.94)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialLight)
        tabAppearance.backgroundColor = backgroundColor
        tabAppearance.shadowColor = UIColor(hexString: "#49443C", alpha: 0.14)

        let captionFont = UIFont.preferredFont(forTextStyle: .caption2)
        [tabAppearance.stackedLayoutAppearance,
         tabAppearance.inlineLayoutAppearance,
         tabAppearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: normalColor,
                .font: captionFont
            ]
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
                .font: captionFont
            ]
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = selectedColor

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialLight)
        navAppearance.backgroundColor = UIColor(hexString: "#FFFDF8", alpha: 0.90)
        navAppearance.shadowColor = UIColor.clear

        let serifTitleFont = UIFont(name: "Georgia", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .medium)
        let serifLargeFont = UIFont(name: "Georgia", size: 31) ?? UIFont.systemFont(ofSize: 31, weight: .regular)

        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(hexString: "#171513"),
            .font: serifTitleFont
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(hexString: "#171513"),
            .font: serifLargeFont
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = selectedColor
    }
}

enum BrandFormatter {
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let absoluteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func price(_ value: Double) -> String {
        let rounded = NSNumber(value: value.rounded())
        let formatted = priceFormatter.string(from: rounded) ?? "\(Int(value.rounded()))"
        return "EGP \(formatted)"
    }

    static func discount(_ value: Double) -> String {
        "- \(price(abs(value)))"
    }

    static func orderDate(_ date: Date) -> String {
        if abs(date.timeIntervalSinceNow) < 60 * 60 * 24 * 2 {
            return relativeFormatter.localizedString(for: date, relativeTo: .now)
        }

        return absoluteDateFormatter.string(from: date)
    }
}

extension Color {
    static let boutInk = Color(hex: "171513")
    static let boutInkSoft = Color(hex: "4E4A45")
    static let boutMuted = Color(hex: "4E4A45")
    static let boutBackground = Color(hex: "F7F7F4")
    static let boutCream = Color(hex: "F7F7F4")
    static let boutCreamTop = Color(hex: "FFFDF8")
    static let boutWarmSurface = Color(hex: "F2EFE8")
    static let boutCreamBottom = Color(hex: "F2EFE8")
    static let boutGold = Color(hex: "9B7532")
    static let boutGoldText = Color(hex: "73561F")
    static let boutButtonStart = Color(hex: "171513")
    static let boutButtonEnd = Color(hex: "231F1C")
    static let boutError = Color(hex: "9A2222")
    static let boutSuccess = Color(hex: "256944")
    static let boutBorder = Color(hex: "49443C").opacity(0.14)
    static let boutBorderStrong = Color(hex: "49443C").opacity(0.22)
    static let boutGlassTop = Color(hex: "FFFDF8").opacity(0.74)
    static let boutGlassBottom = Color(hex: "F2EFE8").opacity(0.82)

    init(hex: String, opacity: Double = 1) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init(hexString: String, alpha: CGFloat = 1) {
        let sanitized = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}
