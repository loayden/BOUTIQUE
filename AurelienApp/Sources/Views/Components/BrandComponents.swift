import SwiftUI
import UIKit

enum GlassTone {
    case shadow
    case chrome
    case gold
}

struct MediaImage: View {
    let name: String

    var body: some View {
        Group {
            if let remoteURL = URL(string: name), remoteURL.scheme?.hasPrefix("http") == true {
                AsyncImage(url: remoteURL, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                    case .failure:
                        placeholder
                    case .empty:
                        skeleton
                    @unknown default:
                        placeholder
                    }
                }
            } else if let image = BrandMediaLibrary.image(named: name) {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
            }
        }
    }

    private var skeleton: some View {
        RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
            .fill(BrandPalette.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .redacted(reason: .placeholder)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.boutGlassTop, Color.boutGlassBottom, BrandPalette.surfaceRaised],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Image(systemName: "photo.artframe")
                    .font(.title3.weight(.light))
                    .foregroundStyle(BrandPalette.textSecondary)

                Text("BOUTIQUE")
                    .font(BrandFont.mobileCaption())
                    .tracking(2.4)
                    .foregroundStyle(BrandPalette.textMuted)
            }
        }
    }
}

struct AmbientBackdrop: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            BrandPalette.backgroundGradient
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.boutGold.opacity(0.08 + phase * 0.02),
                    Color.clear
                ],
                center: UnitPoint(x: 0.82 + phase * 0.06, y: 0.12 - phase * 0.04),
                startRadius: 0,
                endRadius: 250
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.boutCreamTop.opacity(0.42 + phase * 0.04),
                    Color.clear
                ],
                center: UnitPoint(x: 0.50, y: 0.88 + phase * 0.04),
                startRadius: 0,
                endRadius: 210
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 10)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1.0
            }
        }
    }
}

private struct BrandPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tone: GlassTone
    let material: Bool

    private var fill: LinearGradient {
        switch tone {
        case .shadow:
            return LinearGradient(
                colors: [Color.boutGlassTop, Color.boutGlassBottom, BrandPalette.surfaceRaised],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .chrome:
            return LinearGradient(
                colors: [Color.boutGlassTop, Color.boutGlassBottom, Color.boutCream.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [Color.boutGold.opacity(0.12), Color.boutGlassTop, Color.boutGlassBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var strokeColor: Color {
        switch tone {
        case .gold:
            return BrandPalette.goldBorder
        case .chrome:
            return BrandPalette.hairlineStrong
        case .shadow:
            return BrandPalette.hairline
        }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(
                shape
                    .fill(fill)
                    .background(
                        material ? AnyView(shape.fill(.thinMaterial).opacity(0.38)) : AnyView(EmptyView())
                    )
            )
            .overlay(
                shape
                    .stroke(strokeColor, lineWidth: 0.5)
            )
            .clipShape(shape)
            .shadow(color: BrandPalette.shadowSoft, radius: 7, x: 0, y: 4)
    }
}

extension View {
    func brandPanel(
        cornerRadius: CGFloat = BrandRadius.card,
        tone: GlassTone = .shadow,
        material: Bool = true
    ) -> some View {
        modifier(BrandPanelModifier(cornerRadius: cornerRadius, tone: tone, material: material))
    }
}

struct BrandSectionHeader: View {
    let eyebrow: String
    let title: String
    let copy: String?
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 0)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrandPalette.gold)
                }
            }

            Text(title)
                .font(BrandFont.serif(22, relativeTo: .title2))
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let copy {
                Text(copy)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(3)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BrandCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let tone: GlassTone
    var horizontalPadding: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tone == .gold ? Color.boutCreamTop : BrandPalette.textPrimary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .background(background(configuration: configuration))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tone == .gold ? Color.boutButtonEnd.opacity(0.32) : BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .clipShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.58)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }

    @ViewBuilder
    private func background(configuration: Configuration) -> some View {
        if tone == .gold {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: configuration.isPressed
                            ? [Color.boutButtonEnd, Color.boutButtonStart]
                            : [Color.boutButtonStart, Color.boutButtonEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            Capsule(style: .continuous)
                .fill(Color.boutGlassBottom)
                .background(.thinMaterial, in: Capsule(style: .continuous))
        }
    }
}

struct SelectionCapsule: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isSelected ? Color.boutGoldText : BrandPalette.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.boutGold.opacity(0.14) : BrandPalette.surfaceRaised)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? BrandPalette.goldBorder : BrandPalette.hairlineStrong, lineWidth: 0.5)
            )
            .frame(minHeight: 44)
            .contentShape(Capsule(style: .continuous))
    }
}

struct BagFloatingButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bag.fill")
                    .font(.headline)
                    .foregroundStyle(Color.boutCreamTop)
                    .frame(width: 56, height: 56)
                    .background(BrandPalette.goldGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if count > 0 {
                        Text("\(min(count, 99))")
                            .font(.caption2.bold())
                            .foregroundStyle(BrandPalette.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(BrandPalette.ivory, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct BrandGlassIconButton: View {
    let systemName: String
    var tone: GlassTone = .chrome
    var accent: Color = BrandPalette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                        .fill(tone == .gold ? BrandPalette.goldDim : BrandPalette.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                        .stroke(tone == .gold ? BrandPalette.goldBorder : BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct BrandStatCard: View {
    let stat: BrandStat
    var tone: GlassTone = .chrome

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stat.value)
                .font(BrandFont.serif(24, relativeTo: .title2))
                .foregroundStyle(tone == .gold ? BrandPalette.gold : BrandPalette.textPrimary)

            Text(stat.label.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(BrandPalette.textSecondary)

            if let note = stat.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: tone, material: true)
    }
}

struct EmptyStatePanel: View {
    let title: String
    let copy: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: BrandSpacing.md) {
            Image(systemName: "bag.fill")
                .font(.largeTitle)
                .foregroundStyle(BrandPalette.textSecondary)

            Text(title)
                .font(BrandFont.serif(22, relativeTo: .title3))
                .foregroundStyle(BrandPalette.textPrimary)
                .multilineTextAlignment(.center)

            Text(copy)
                .font(.subheadline)
                .foregroundStyle(BrandPalette.textSecondary)
                .multilineTextAlignment(.center)

            Button(buttonTitle, action: action)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

struct BrandField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var autocapitalization: TextInputAutocapitalization = .words
    var autocorrectionDisabled: Bool = true
    var isRequired: Bool = false
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(isFocused ? BrandPalette.gold : BrandPalette.textMuted)
                if isRequired {
                    Text("*")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.gold)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            TextField("", text: $text, prompt: Text(title).foregroundStyle(BrandPalette.textMuted))
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .font(.body)
                .foregroundStyle(BrandPalette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .focused($isFocused)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BrandPalette.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isFocused
                                ? BrandPalette.gold.opacity(0.55)
                                : (errorMessage != nil
                                    ? Color.red.opacity(0.5)
                                    : BrandPalette.hairlineStrong),
                            lineWidth: isFocused ? 1.0 : 0.5
                        )
                        .animation(.easeInOut(duration: 0.2), value: isFocused)
                )
                .shadow(
                    color: isFocused ? BrandPalette.gold.opacity(0.12) : .clear,
                    radius: 8, x: 0, y: 2
                )

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: errorMessage)
    }
}

struct QuantityStepper: View {
    let quantity: Int
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDecrease) {
                Image(systemName: "minus")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandPalette.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(BrandPalette.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)

            Text("\(quantity)")
                .font(.body.weight(.semibold))
                .foregroundStyle(BrandPalette.textPrimary)
                .frame(minWidth: 32)

            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.boutCreamTop)
                    .frame(width: 44, height: 44)
                    .background(BrandPalette.goldGradient, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.boutGlassBottom)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

struct DividerGlow: View {
    var body: some View {
        LinearGradient(
            colors: [Color.clear, BrandPalette.goldBorder, Color.clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

// MARK: - Master Glass Modifier with Depth Control

enum GlassDepth {
    case whisper    // barely-there surface suggestion
    case soft       // cards in lists
    case medium     // elevated cards, prominent panels
    case deep       // sheets, form panels
    case floating   // toasts, FABs, tab bar
}

struct BoutGlassModifier: ViewModifier {
    let depth: GlassDepth
    let tone: GlassTone
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background { glassBackground }
            .overlay { glassBorder }
            .shadow(
                color: BrandPalette.shadowMedium.opacity(shadowOpacity / 0.12),
                radius: shadowRadius, x: 0, y: shadowY
            )
            .shadow(
                color: tone == .gold
                    ? BrandPalette.gold.opacity(0.10)
                    : .clear,
                radius: 14, x: 0, y: 4
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    private var glassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            // Material blur layer
            shape
                .fill(.ultraThinMaterial)
                .opacity(materialOpacity)
            // Warm tint layer
            shape
                .fill(tintColor)
            // Top edge inner highlight (makes it feel like real glass)
            LinearGradient(
                colors: [
                    Color.white.opacity(topHighlightOpacity),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.35)
            )
            .clipShape(shape)
        }
    }
    
    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: 0.5)
    }
    
    // Per-depth tuning
    private var materialOpacity: Double {
        switch depth {
        case .whisper:  return 0.25
        case .soft:     return 0.42
        case .medium:   return 0.55
        case .deep:     return 0.68
        case .floating: return 0.82
        }
    }
    
    private var tintColor: Color {
        switch tone {
        case .gold:
            switch depth {
            case .whisper:  return BrandPalette.gold.opacity(0.04)
            case .soft:     return BrandPalette.gold.opacity(0.06)
            case .medium:   return BrandPalette.gold.opacity(0.09)
            case .deep:     return BrandPalette.gold.opacity(0.11)
            case .floating: return BrandPalette.gold.opacity(0.13)
            }
        case .chrome, .shadow:
            let base: Double
            switch depth {
            case .whisper:  base = 0.03
            case .soft:     base = 0.05
            case .medium:   base = 0.07
            case .deep:     base = 0.10
            case .floating: base = 0.14
            }
            return Color.boutGlassTop.opacity(base + 0.48)
        }
    }
    
    private var topHighlightOpacity: Double {
        switch depth {
        case .whisper:  return 0.04
        case .soft:     return 0.07
        case .medium:   return 0.09
        case .deep:     return 0.11
        case .floating: return 0.14
        }
    }
    
    private var borderColor: Color {
        switch tone {
        case .gold:
            return BrandPalette.gold.opacity(depth == .whisper ? 0.18 : 0.30)
        case .chrome:
            return Color.boutBorderStrong
        case .shadow:
            return Color.boutBorder
        }
    }
    
    private var shadowOpacity: Double {
        switch depth {
        case .whisper:  return 0.10
        case .soft:     return 0.18
        case .medium:   return 0.26
        case .deep:     return 0.34
        case .floating: return 0.44
        }
    }
    
    private var shadowRadius: CGFloat {
        switch depth {
        case .whisper:  return 6
        case .soft:     return 9
        case .medium:   return 14
        case .deep:     return 20
        case .floating: return 24
        }
    }
    
    private var shadowY: CGFloat {
        switch depth {
        case .whisper:  return 2
        case .soft:     return 4
        case .medium:   return 6
        case .deep:     return 9
        case .floating: return 10
        }
    }
}

extension View {
    func boutGlass(
        _ depth: GlassDepth = .soft,
        tone: GlassTone = .chrome,
        cornerRadius: CGFloat = BrandRadius.card
    ) -> some View {
        modifier(BoutGlassModifier(
            depth: depth,
            tone: tone,
            cornerRadius: cornerRadius
        ))
    }
    
    // Backwards compat aliases:
    func luxuryGlass(
        _ level: String = "raised",
        tone: GlassTone = .chrome,
        cornerRadius: CGFloat = BrandRadius.card
    ) -> some View {
        boutGlass(.medium, tone: tone, cornerRadius: cornerRadius)
    }
}

// MARK: - Back Button Modifier

struct BoutBackButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let label: String
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        BrandHaptics.softImpact()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .medium))
                            Text(label)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(BrandPalette.gold)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
    }
}

extension View {
    func boutBackButton(_ label: String = "Back") -> some View {
        modifier(BoutBackButton(label: label))
    }
}

// MARK: - Floating Glass Island Tab Bar

struct BoutTabBar: View {
    @Binding var selectedTab: AppTab
    let bagCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(Color.boutGlassTop)
                .background(.thinMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.boutGlassBottom)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.boutBorderStrong, lineWidth: 0.5)
                }
                .shadow(
                    color: BrandPalette.shadowMedium,
                    radius: 18, x: 0, y: 6
                )
                .shadow(
                    color: BrandPalette.gold.opacity(0.05),
                    radius: 22, x: 0, y: 3
                )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            if selectedTab == tab {
                BrandHaptics.softImpact()
            } else {
                selectedTab = tab
                BrandHaptics.selection()
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? BrandPalette.gold
                                : BrandPalette.textSecondary.opacity(0.72)
                        )
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)

                    if tab == .bag && bagCount > 0 {
                        Text("\(min(bagCount, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.boutCreamTop)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(BrandPalette.gold, in: Capsule())
                            .offset(x: 8, y: -6)
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3), value: bagCount)
                    }
                }
                .frame(height: 24)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? BrandPalette.gold
                            : BrandPalette.textSecondary.opacity(0.72)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? BrandPalette.goldDim : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
