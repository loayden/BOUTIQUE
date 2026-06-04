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
                        fallbackLocalImage(placeholder)
                    case .empty:
                        fallbackLocalImage(skeleton)
                    @unknown default:
                        fallbackLocalImage(placeholder)
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

    @ViewBuilder
    private func fallbackLocalImage<Content: View>(_ fallback: Content) -> some View {
        if let fallbackName = URL(string: name)?.lastPathComponent,
           let image = BrandMediaLibrary.image(named: fallbackName) {
            Image(uiImage: image)
                .resizable()
        } else {
            fallback
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
    var body: some View {
        BrandPalette.backgroundGradient
            .ignoresSafeArea()
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
                colors: [Color.boutCreamTop.opacity(0.96), BrandPalette.surfaceRaised, Color.white.opacity(0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .chrome:
            return LinearGradient(
                colors: [Color.white.opacity(0.70), Color.boutCreamTop.opacity(0.96), BrandPalette.surfaceRaised],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [Color.boutGold.opacity(0.10), Color.boutCreamTop.opacity(0.96), BrandPalette.surfaceRaised],
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
                        material ? AnyView(shape.fill(BrandPalette.backgroundWarm.opacity(0.34))) : AnyView(EmptyView())
                    )
            )
            .overlay(
                shape
                    .stroke(strokeColor, lineWidth: 0.5)
            )
            .clipShape(shape)
            .shadow(color: BrandPalette.shadowSoft, radius: 10, x: 0, y: 6)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased())
                    .font(BrandFont.labelCapsule())
                    .tracking(3.2)
                    .foregroundStyle(BrandPalette.goldDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 0)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.goldDeep)
                }
            }

            Text(title)
                .font(BrandFont.displayEditorial())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(3)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let copy {
                Text(copy)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineLimit(4)
                    .lineSpacing(4)
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
            .font(BrandFont.mobileCaption())
            .tracking(1.6)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 13)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(background(configuration: configuration))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
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
                .fill(configuration.isPressed ? Color.boutButtonEnd : Color.boutButtonStart)
        } else if tone == .shadow {
            Capsule(style: .continuous)
                .fill(configuration.isPressed ? BrandPalette.gold.opacity(0.18) : BrandPalette.goldDim)
        } else {
            Capsule(style: .continuous)
                .fill(configuration.isPressed ? BrandPalette.surfaceRaised : BrandPalette.surface)
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .gold:
            return Color.boutCreamTop
        case .shadow:
            return BrandPalette.goldDeep
        case .chrome:
            return BrandPalette.textPrimary
        }
    }

    private var borderColor: Color {
        switch tone {
        case .gold:
            return Color.boutButtonEnd.opacity(0.24)
        case .shadow:
            return BrandPalette.goldBorder
        case .chrome:
            return BrandPalette.hairlineStrong
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
                    .background(Color.boutButtonStart, in: Circle())

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
                    Circle()
                        .fill(tone == .gold ? BrandPalette.goldDim : BrandPalette.surfaceRaised)
                )
                .overlay(
                    Circle()
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
                .foregroundStyle(tone == .gold ? BrandPalette.goldDeep : BrandPalette.textPrimary)

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
            Circle()
                .fill(BrandPalette.goldDim)
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "bag")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(BrandPalette.goldDeep)
                )

            Text(title)
                .font(BrandFont.mobileTitle2())
                .foregroundStyle(BrandPalette.textPrimary)
                .multilineTextAlignment(.center)

            Text(copy)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button(buttonTitle, action: action)
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
        }
        .padding(28)
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
                    .font(BrandFont.labelCapsule())
                    .tracking(3)
                    .foregroundStyle(isFocused ? BrandPalette.goldDeep : BrandPalette.textMuted)
                if isRequired {
                    Text("*")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandPalette.goldDeep)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            TextField("", text: $text, prompt: Text(title).foregroundStyle(BrandPalette.textMuted))
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(minHeight: 56)
                .focused($isFocused)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isFocused
                                ? BrandPalette.goldDeep.opacity(0.42)
                                : (errorMessage != nil
                                    ? Color.red.opacity(0.5)
                                    : BrandPalette.hairlineStrong),
                            lineWidth: isFocused ? 1.0 : 0.5
                        )
                        .animation(.easeInOut(duration: 0.2), value: isFocused)
                )
                .shadow(
                    color: isFocused ? BrandPalette.gold.opacity(0.10) : .clear,
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
                    .background(BrandPalette.surface, in: Circle())
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
                    .background(Color.boutButtonStart, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(BrandPalette.surfaceRaised)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

struct DividerGlow: View {
    var body: some View {
        Rectangle()
            .fill(BrandPalette.hairline)
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
                                .font(BrandFont.mobileCaption())
                                .tracking(1.2)
                        }
                        .foregroundStyle(BrandPalette.goldDeep)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandPalette.backgroundWarm.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.boutBorderStrong, lineWidth: 0.5)
                }
                .shadow(
                    color: BrandPalette.shadowSoft,
                    radius: 12, x: 0, y: 6
                )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
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
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? BrandPalette.textPrimary
                                : BrandPalette.textSecondary.opacity(0.78)
                        )
                        .animation(.easeInOut(duration: 0.18), value: isSelected)

                    if tab == .bag && bagCount > 0 {
                        Text("\(min(bagCount, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.boutCreamTop)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(BrandPalette.goldDeep, in: Capsule())
                            .offset(x: 8, y: -6)
                            .animation(.spring(response: 0.3), value: bagCount)
                    }
                }
                .frame(height: 24)

                Text(tab.label)
                    .font(BrandFont.mobileCaption2())
                    .tracking(1.8)
                    .foregroundStyle(
                        isSelected
                            ? BrandPalette.textPrimary
                            : BrandPalette.textSecondary.opacity(0.78)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSelected)

                Capsule(style: .continuous)
                    .fill(isSelected ? BrandPalette.goldDeep : Color.clear)
                    .frame(width: 16, height: 3)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? BrandPalette.surfaceRaised : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
