import SwiftUI

struct SkeletonView: View {
    var cornerRadius: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    BrandPalette.surfaceRaised.opacity(0.92),
                    BrandPalette.surface.opacity(0.72),
                    BrandPalette.surfaceRaised.opacity(0.92)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .shimmering()
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(BrandPalette.textMuted)
            Text(message)
                .font(.title3)
                .foregroundStyle(BrandPalette.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(BrandPalette.error)
            Text(message)
                .font(.title3)
                .foregroundStyle(BrandPalette.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Shimmer effect modifier
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.boutCreamTop.opacity(0.52), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: phase * geo.size.width * 2 - geo.size.width)
                        .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
                }
                .clipped()
            )
            .onAppear { phase = 1 }
    }
}
