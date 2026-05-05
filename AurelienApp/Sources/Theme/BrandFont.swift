import SwiftUI
import UIKit

// MARK: - Luxury Typography System
// Serif for titles (luxury feel), Sans-serif for body
// Light weight ONLY, wide letter spacing (tracking), airy spacing

enum BrandFont {
    // MARK: - Base Fonts
    
    /// Serif font for display, titles, product names, prices
    static func serif(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title
    ) -> Font {
        // Prefer Georgia (available on all iOS devices, true serif)
        // Falls back to system serif if unavailable
        .custom("Georgia", size: size).weight(.regular)
    }
    
    /// Bold serif font for prominent titles
    static func serifBold(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title
    ) -> Font {
        .custom("Georgia-Bold", size: size).weight(.bold)
    }
    
    /// Sans-serif for body, captions, UI labels
    static func sans(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body,
        weight: Font.Weight = .regular
    ) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    
    // MARK: - Semantic Shortcuts
    
    /// Hero display (onboarding, home hero)
    static func mobileLargeTitle() -> Font {
        serifBold(34, relativeTo: .largeTitle)
    }
    
    /// Page title (serif, prominent)
    static func mobileTitle() -> Font {
        serifBold(26, relativeTo: .title)
    }
    
    /// Section title
    static func mobileTitle2() -> Font {
        serifBold(22, relativeTo: .title2)
    }
    
    /// Card title, prominent labels
    static func mobileTitle3() -> Font {
        serif(18, relativeTo: .headline)
    }
    
    /// Body text
    static func mobileBody() -> Font {
        sans(15, relativeTo: .body)
    }
    
    /// Secondary labels
    static func mobileCaption() -> Font {
        sans(13, relativeTo: .subheadline)
    }
    
    /// Tertiary/metadata
    static func mobileCaption2() -> Font {
        sans(11, relativeTo: .caption, weight: .medium)
    }
    
    /// ALL CAPS labels (category, section eyebrow)
    static func labelCapsule() -> Font {
        sans(10, relativeTo: .caption2, weight: .semibold)
    }
    
    /// Price display — always serif, gold
    static func price(_ size: CGFloat = 17) -> Font {
        serif(size, relativeTo: .headline)
    }
    
    /// Order ID — monospace
    static func orderId() -> Font {
        .system(.subheadline, design: .monospaced).weight(.medium)
    }
    
    // MARK: - Display Fonts
    
    static func displayHero() -> Font {
        serifBold(40, relativeTo: .largeTitle)
    }

    static func displayEditorial() -> Font {
        serif(28, relativeTo: .title)
    }
}

// MARK: - Text Extension for Luxury Tracking
extension Text {
    func luxuryTracking(_ points: CGFloat = 3) -> some View {
        self.tracking(points)
    }
}
