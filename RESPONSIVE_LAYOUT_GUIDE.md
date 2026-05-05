# Responsive Layout Reference Guide

## Search Patterns to Find & Replace

### 1. Fixed Frame Heights (Hero Images, Cards)
**Search for:**
```
.frame(height: 300)
.frame(height: 320)
.frame(height: 480)
.frame(height: 560)
```

**Replace with pattern:**
```swift
.frame(height: isCompact ? 240 : 480)
```

**Files already fixed:**
- `HomeView.swift`: Hero 320→240
- `ProductDetailView.swift`: Hero 300→240  
- `ShopView.swift`: Hero 180→100
- `HomeView.swift`: Collection cards 280→220, 340→280

---

### 2. Fixed Font Sizes (Large Titles)
**Search for:**
```
.font(BrandFont.serif(32
.font(BrandFont.serif(34
.font(BrandFont.serif(36
.font(BrandFont.serif(40
```

**Replace with pattern:**
```swift
.font(BrandFont.serif(isCompact ? 26 : 36, relativeTo: .largeTitle))
```

**Common reductions:**
- 34 → 26
- 32 → 24  
- 28 → 22
- 24 → 20

---

### 3. Fixed Spacing (BrandSpacing)
**Search for:**
```
spacing: BrandSpacing.xl
spacing: BrandSpacing.lg
.padding(BrandSpacing.xl)
.padding(BrandSpacing.lg)
```

**Replace with pattern:**
```swift
// For VStack/LazyVStack spacing
spacing: isCompact ? 24 : BrandSpacing.xl

// For padding
.padding(isCompact ? 16 : BrandSpacing.lg)
```

---

### 4. Fixed Padding Values
**Search for:**
```
.padding(24)
.padding(20)
.padding(18)
```

**Replace with pattern:**
```swift
.padding(isCompact ? 16 : 24)
```

---

### 5. Grid Item Minimum Widths
**Search for:**
```
GridItem(.adaptive(minimum: 280)
GridItem(.adaptive(minimum: 260)
GridItem(.adaptive(minimum: 160)
```

**Replace with pattern:**
```swift
let isCompact = horizontalSizeClass == .compact
[GridItem(.adaptive(minimum: isCompact ? 140 : 280), spacing: isCompact ? 10 : 18)]
```

---

### 6. Component Button Sizes
**Search for (in BrandComponents.swift):**
```
.padding(.horizontal, 22)
.padding(.vertical, 14)
.font(BrandFont.sans(12
```

**Current responsive implementation:**
```swift
struct BrandCapsuleButtonStyle: ButtonStyle {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func makeBody(configuration: Configuration) -> some View {
        let isCompact = horizontalSizeClass == .compact
        configuration.label
            .font(BrandFont.sans(isCompact ? 10 : 12, relativeTo: .callout))
            .padding(.horizontal, isCompact ? 14 : 22)
            .padding(.vertical, isCompact ? 10 : 14)
    }
}
```

---

## Required Property Setup

Every view that uses `isCompact` needs these two lines:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
private var isCompact: Bool { horizontalSizeClass == .compact }
```

**Check for missing setup in:**
- Any nested structs inside view files
- Sheet/modal views
- Reusable components

---

## Navigation Title Display Modes

**For mobile, use inline mode:**
```swift
.navigationBarTitleDisplayMode(isCompact ? .inline : .large)
```

**Already applied in:**
- `AccountView.swift`
- `SearchView.swift`
- `WishlistView.swift`
- `ShopView.swift`

---

## Scroll View Best Practices

**Ensure content fits screen width:**
```swift
ScrollView(.vertical, showsIndicators: false) {
    VStack {
        // content
    }
    .padding(.horizontal, isCompact ? 16 : 24)
}
```

**No horizontal scroll indicators:**
```swift
ScrollView(.horizontal, showsIndicators: false)
```

---

## Safe Area Handling

**Use safeAreaInset for floating controls:**
```swift
.safeAreaInset(edge: .top) {
    // floating controls
}
.safeAreaInset(edge: .bottom) {
    // bottom bars
}
```

**Don't use ignoresSafeArea() unless absolutely necessary.**

---

## Files Already Fully Responsive

1. ✅ `ShopView.swift` - Hero 100pt, grid 140pt min, 8pt category pills
2. ✅ `HomeView.swift` - Hero 240pt, fonts reduced ~30%
3. ✅ `ProductDetailView.swift` - Hero 240pt, spacing 16pt
4. ✅ `AccountView.swift` - Inline nav mode, spacing 24pt
5. ✅ `SearchView.swift` - Inline nav mode, fonts reduced
6. ✅ `BagView.swift` - Spacing 24pt
7. ✅ `CheckoutView.swift` - Spacing 24pt
8. ✅ `OrdersView.swift` - Card sizes reduced
9. ✅ `WishlistView.swift` - Grid adaptive, spacing 24pt
10. ✅ `AdminDashboardView.swift` - Stats cards, chart height 160pt
11. ✅ `BrandComponents.swift` - SelectionCapsule, BrandCapsuleButtonStyle

---

## Project Configuration

**Info.plist additions made:**
- `UIRequiresFullScreen` = true
- `UISupportedInterfaceOrientations` for iPhone
- `UISupportedInterfaceOrientations~ipad` for iPad

**project.pbxproj:**
- `TARGETED_DEVICE_FAMILY = 1` (iPhone only)
- `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`
- `IPHONEOS_DEPLOYMENT_TARGET = 17.0`

---

## Testing Checklist

- [ ] Hero images don't overflow screen
- [ ] Text doesn't get clipped
- [ ] Category pills fit in horizontal scroll
- [ ] Product grid shows 2 columns on iPhone
- [ ] No horizontal scrolling
- [ ] Navigation titles use inline mode
- [ ] Safe area respected (notch, home indicator)
- [ ] Fonts readable but not oversized
- [ ] Spacing feels comfortable on iPhone SE/15/16

---

## Build Commands

```bash
# Clean build folder
cmd + shift + k

# Build
cmd + b

# Or via xcodebuild:
xcodebuild -project Aurelien.xcodeproj -scheme Aurelien clean build
```
