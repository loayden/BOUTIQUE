import SwiftUI
import UIKit

enum BrandPalette {
    // MARK: Backgrounds
    static let background = Color.boutCream
    static let backgroundWarm = Color.boutCreamTop
    static let surface = Color(hex: "#FFFFFF").opacity(0.72)
    static let surfaceRaised = Color(hex: "#F8F1E5").opacity(0.86)
    static let surfaceElevated = surfaceRaised
    static let overlay = Color(hex: "#FFFFFF").opacity(0.56)
    static let surfaceGlass = Color(hex: "#FFFFFF").opacity(0.72)

    // MARK: Accents
    static let gold = Color.boutGoldText
    static let goldWarm = Color.boutGold
    static let goldLight = Color(hex: "#B98A45")
    static let goldDeep = Color.boutGoldText
    static let goldGlow = Color.boutGold.opacity(0.22)
    static let goldDim = Color.boutGold.opacity(0.12)
    static let goldShimmer = Color.boutGold.opacity(0.76)
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
    static let sand = Color.boutInkSoft
    static let muted = Color.boutInk.opacity(0.72)
    static let ivoryMuted = sand

    static let textPrimary = Color.boutInk
    static let textSecondary = Color.boutInkSoft
    static let textMuted = Color.boutInk.opacity(0.72)
    static let error = Color.boutError
    static let success = Color.boutSuccess

    // MARK: Borders / Glass
    static let hairline = Color.boutBorder
    static let hairlineStrong = Color.boutBorderStrong
    static let goldBorder = Color.boutGold.opacity(0.30)
    static let hairlineGold = goldBorder

    static let glassLight = Color.boutGlassTop
    static let glassMedium = Color.boutGlassBottom
    static let glassDark = Color.boutCreamBottom.opacity(0.96)
    static let glassBorder = hairlineStrong
    static let glassBorderGold = goldBorder

    // MARK: Shadows / Ambient
    static let shadowSoft = Color.boutInk.opacity(0.08)
    static let shadowMedium = Color.boutInk.opacity(0.12)
    static let shadowStrong = Color.boutInk.opacity(0.18)
    static let shadowGlow = goldGlow.opacity(0.24)

    static let ambientGold = goldGlow
    static let ambientLight = Color.boutCreamTop.opacity(0.55)

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color.boutButtonStart, Color.boutButtonEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassGradient: LinearGradient {
        LinearGradient(
            colors: [Color.boutGlassTop, Color.boutGlassBottom, Color.boutCream.opacity(0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.boutCreamTop, Color.boutCream, Color.boutCreamBottom],
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
        let selectedColor = UIColor(hexString: "#7A581F")
        let normalColor = UIColor(hexString: "#6F6254")
        let backgroundColor = UIColor(hexString: "#FFF9EF", alpha: 0.88)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        tabAppearance.backgroundColor = backgroundColor
        tabAppearance.shadowColor = UIColor(hexString: "#7B6752", alpha: 0.18)

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
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        navAppearance.backgroundColor = UIColor(hexString: "#FFF9EF", alpha: 0.86)
        navAppearance.shadowColor = UIColor.clear

        // Serif fonts for nav bar titles
        let serifTitleFont = UIFont(name: "Georgia", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        let serifLargeFont = UIFont(name: "Georgia-Bold", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .bold)

        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(hexString: "#3D3025"),
            .font: serifTitleFont
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(hexString: "#3D3025"),
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
    static let boutInk = Color(hex: "3D3025")
    static let boutInkSoft = Color(hex: "6F6254")
    static let boutCream = Color(hex: "F5F1E8")
    static let boutCreamTop = Color(hex: "FFF9EF")
    static let boutCreamBottom = Color(hex: "EDE3D6")
    static let boutGold = Color(hex: "A87935")
    static let boutGoldText = Color(hex: "7A581F")
    static let boutButtonStart = Color(hex: "4C3A26")
    static let boutButtonEnd = Color(hex: "7D592B")
    static let boutError = Color(hex: "9A2222")
    static let boutSuccess = Color(hex: "256944")
    static let boutBorder = Color(hex: "7B6752").opacity(0.18)
    static let boutBorderStrong = Color(hex: "7B6752").opacity(0.26)
    static let boutGlassTop = Color(hex: "FFFFFF").opacity(0.72)
    static let boutGlassBottom = Color(hex: "F8F1E5").opacity(0.56)

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
