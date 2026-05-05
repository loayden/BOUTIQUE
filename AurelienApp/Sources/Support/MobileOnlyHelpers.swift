import SwiftUI

// MARK: - Mobile-Only Helpers
// This extension forces all views to use compact/mobile sizing regardless of device

extension View {
    /// Forces mobile compact layout regardless of device size class
    @ViewBuilder
    func mobileOnly() -> some View {
        self
            .environment(\.horizontalSizeClass, .compact)
    }
}

// MARK: - Mobile Sizing Constants

enum MobileSize {
    static let heroHeight: CGFloat = 220
    static let cardHeight: CGFloat = 200
    static let serviceStoryHeight: CGFloat = 220

    static let largeTitle: CGFloat = 32
    static let title: CGFloat = 26
    static let title2: CGFloat = 22
    static let title3: CGFloat = 18
    static let body: CGFloat = 14
    static let caption: CGFloat = 11
    static let caption2: CGFloat = 10

    static let sectionSpacing: CGFloat = 20
    static let cardSpacing: CGFloat = 14
    static let elementSpacing: CGFloat = 10

    static let horizontalPadding: CGFloat = 18
    static let cardPadding: CGFloat = 16

    static let gridMinWidth: CGFloat = 148
    static let productCardWidth: CGFloat = 208
}

enum MobileChrome {
    static func bottomContentInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<350:
            return 120
        case 430...:
            return 140
        default:
            return 132
        }
    }

    static func bottomOverlayInset(for width: CGFloat) -> CGFloat {
        bottomContentInset(for: width) + 18
    }
}

struct PhoneViewport {
    let width: CGFloat

    var horizontalPadding: CGFloat {
        switch width {
        case ..<350: return 14
        case 430...: return 20
        default: return 18
        }
    }

    var bottomPadding: CGFloat {
        MobileChrome.bottomContentInset(for: width)
    }

    var overlayBottomPadding: CGFloat {
        MobileChrome.bottomOverlayInset(for: width)
    }

    var compactHeroAspect: CGFloat {
        switch width {
        case ..<350: return 0.70
        case 400...: return 0.60
        default: return 0.65
        }
    }

    var collectionAspect: CGFloat {
        switch width {
        case ..<350: return 0.75
        case 400...: return 0.65
        default: return 0.70
        }
    }

    var editorialAspect: CGFloat {
        switch width {
        case ..<350: return 0.85
        case 400...: return 0.75
        default: return 0.80
        }
    }

    var productCardAspect: CGFloat {
        switch width {
        case ..<350: return 0.72
        case 400...: return 0.62
        default: return 0.68
        }
    }

    var compactProductCardAspect: CGFloat {
        width < 350 ? 0.75 : 0.72
    }

    var productGalleryHeight: CGFloat {
        min(max(width * 1.08, 360), 440)
    }

    var stackInlineControls: Bool {
        width < 360
    }
}

struct PhoneScrollScreen<Content: View>: View {
    var showsIndicators = false
    @ViewBuilder let content: (PhoneViewport) -> Content

    @State private var showScrollToTop = false

    private let scrollSpaceName = "phone-scroll-screen"
    private let topAnchorID = "phone-scroll-top-anchor"

    var body: some View {
        GeometryReader { proxy in
            let viewport = PhoneViewport(width: proxy.size.width)

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: showsIndicators) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorID)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: PhoneScrollOffsetPreferenceKey.self,
                                    value: geometry.frame(in: .named(scrollSpaceName)).minY
                                )
                            }
                        )

                    content(viewport)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, 16)
                }
                .coordinateSpace(name: scrollSpaceName)
                .onPreferenceChange(PhoneScrollOffsetPreferenceKey.self) { offset in
                    let shouldShow = offset < -520
                    if shouldShow != showScrollToTop {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showScrollToTop = shouldShow
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showScrollToTop {
                        Button {
                            BrandHaptics.selection()
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                scrollProxy.scrollTo(topAnchorID, anchor: .top)
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(BrandPalette.textPrimary)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(BrandPalette.surfaceRaised.opacity(0.96))
                                        .background(.ultraThinMaterial, in: Circle())
                                )
                                .overlay(
                                    Circle()
                                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                                )
                                .shadow(color: BrandPalette.shadowSoft, radius: 14, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, viewport.horizontalPadding)
                        .padding(.bottom, viewport.overlayBottomPadding)
                        .accessibilityLabel("Scroll to top")
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct PhoneScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
