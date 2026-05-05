import SwiftUI

// MARK: - Tap Animation Modifier
struct TapAnimation: ViewModifier {
    @GestureState private var isPressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

extension View {
    func tapAnimated() -> some View {
        self.modifier(TapAnimation())
    }
}
