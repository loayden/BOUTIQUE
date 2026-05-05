import SwiftUI

extension View {
    /// Ensures a minimum tappable area of 44x44 points for accessibility
    func minTouchArea() -> some View {
        self.contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44, alignment: .center)
    }
    /// Adds an accessibility label if provided
    func accessible(_ label: String?) -> some View {
        if let label = label {
            return AnyView(self.accessibilityLabel(Text(label)))
        } else {
            return AnyView(self)
        }
    }
}
