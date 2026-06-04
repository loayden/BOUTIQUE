import SwiftUI
import UIKit

// MARK: - Luxury Typography System
// Serif for titles (luxury feel), Sans-serif for body
// Light weight ONLY, wide letter spacing (tracking), airy spacing

enum BrandFont {
    // MARK: - Base Fonts

    static func serif(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title
    ) -> Font {
        .system(size: size, weight: .light, design: .serif)
    }

    static func serifBold(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title
    ) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func sans(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body,
        weight: Font.Weight = .regular
    ) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Semantic Shortcuts

    static func mobileLargeTitle() -> Font {
        serifBold(36, relativeTo: .largeTitle)
    }

    static func mobileTitle() -> Font {
        serifBold(28, relativeTo: .title)
    }

    static func mobileTitle2() -> Font {
        serifBold(24, relativeTo: .title2)
    }

    static func mobileTitle3() -> Font {
        serifBold(19, relativeTo: .headline)
    }

    static func mobileBody() -> Font {
        sans(16, relativeTo: .body)
    }

    static func mobileCaption() -> Font {
        sans(13, relativeTo: .subheadline)
    }

    static func mobileCaption2() -> Font {
        sans(11, relativeTo: .caption, weight: .medium)
    }

    static func labelCapsule() -> Font {
        sans(11, relativeTo: .caption2, weight: .semibold)
    }

    static func price(_ size: CGFloat = 17) -> Font {
        serifBold(size, relativeTo: .headline)
    }

    static func orderId() -> Font {
        .system(.subheadline, design: .monospaced).weight(.medium)
    }

    // MARK: - Display Fonts

    static func displayHero() -> Font {
        serifBold(42, relativeTo: .largeTitle)
    }

    static func displayEditorial() -> Font {
        serifBold(30, relativeTo: .title)
    }
}

// MARK: - Text Extension for Luxury Tracking
extension Text {
    func luxuryTracking(_ points: CGFloat = 3) -> some View {
        self.tracking(points)
    }
}
