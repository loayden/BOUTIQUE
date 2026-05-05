import SwiftUI

// MARK: - View Extension for Responsive Layout
extension View {
    /// Conditionally applies modifiers based on horizontal size class
    func responsive<T>(compact: T, regular: T) -> T {
        let sizeClass = UIScreen.main.traitCollection.horizontalSizeClass
        return sizeClass == .compact ? compact : regular
    }
}

// MARK: - Environment Key for Compact Mode
private struct IsCompactKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isCompact: Bool {
        get { self[IsCompactKey.self] }
        set { self[IsCompactKey.self] = newValue }
    }
}

// MARK: - Convenience Modifier
extension View {
    /// Applies different modifiers for compact vs regular size classes
    @ViewBuilder
    func ifCompact<T: View>(@ViewBuilder compact: () -> T, @ViewBuilder else regular: () -> T) -> some View {
        if UIScreen.main.traitCollection.horizontalSizeClass == .compact {
            compact()
        } else {
            regular()
        }
    }
}
