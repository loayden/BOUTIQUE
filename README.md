# BOUTIQUE iOS

Native SwiftUI iPhone translation of the existing BOUTIQUE website.

## Design direction

- Quiet-luxury palette built from obsidian black, espresso surfaces, champagne gold, and warm ivory text.
- Editorial typography using bundled Cormorant Garamond and Jost variable fonts.
- Glass depth reserved for primary chrome surfaces, sheets, controls, and tab/navigation bars.
- Static layered gradients on most cards to preserve smooth scrolling on lower-memory devices.
- Native iPhone interaction patterns: `TabView`, `NavigationStack`, safe-area aware sticky actions, and sheet-based variant pickers.

## Screen map

- `Home`: immersive editorial hero, collection rail, featured products, brand promises.
- `Shop`: category-aware browse view with pinned controls and a filter sheet.
- `Search`: full-screen search destination with recent and trending queries.
- `Saved`: wishlist-first view with premium empty state treatment.
- `Bag`: floating global entry point with sticky checkout action.
- `Account`: calm profile overview plus orders history.
- `Checkout`: dark-glass form flow with lightweight validation and confirmation.

## Tokens

- Background: `#0A0908`
- Secondary surface: `#14110F`
- Accent gold: `#C9A86A`
- Support gold: `#8B6A3E`
- Primary text: `rgba(255,248,236,0.88)`
- Secondary text: `rgba(255,248,236,0.56)`
- Borders: `rgba(255,248,236,0.10)`

## Project setup

This workspace was empty, so the app is scaffolded from scratch.

1. Install full Xcode and select it with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
2. Generate the project with `xcodegen generate`.
3. Open `Aurelien.xcodeproj` in Xcode and run on an iPhone simulator.

`xcodebuild` and simulator verification were not possible on this machine because only Command Line Tools were configured when this work was done.
