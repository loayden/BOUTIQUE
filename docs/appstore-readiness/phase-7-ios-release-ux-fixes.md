# Phase 7: iOS Release Build, Tests, And UX Blocking Fixes

Date: 2026-06-04

## Summary

Phase 7 is verified for the iOS simulator build/test surface. The XCTest bundle loads, the full suite passes, Debug and Release simulator builds pass, and the most visible conversion UI issues on product cards and product detail are fixed.

This phase does not claim TestFlight readiness. A signed archive, App Store signing, production MongoDB connectivity, and live ecommerce writes remain Phase 8 and production infrastructure blockers.

## Implemented

- Standardized commerce listing cards to a `4:5` image ratio in `ProductCardView`.
- Kept listing images in fill/cover behavior for visually consistent Home, Shop, Wishlist, Search, and related-product surfaces.
- Updated product-detail gallery images to fit the full garment instead of using the listing-card crop behavior.
- Hid the system navigation back button on product detail so the PDP has only one visible back affordance.
- Increased PDP sticky purchase-bar bottom clearance and scroll content bottom padding so Add to Bag / Buy Now is not covered by the floating tab bar.
- Added regression coverage for the commerce image ratio and PDP sticky CTA bottom clearance.

## Verified

- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`: passed with `27` tests and `0` failures.
- Targeted commerce UI regression tests: passed with `2` tests and `0` failures.
- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'generic/platform=iOS Simulator' build`: passed.
- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`: passed.
- `AurelienApp/Scripts/ensure_release_readiness.sh`: passed with HTTPS production API, static content, privacy, and support URLs.

## Notes

- A first Debug build attempt failed because Debug and Release builds were started concurrently and Xcode locked the shared build database. Re-running Debug after Release completed passed cleanly.
- Release simulator build was validated with code signing disabled. A real signed archive and TestFlight upload remain required in Phase 8.

## Remaining Blockers

- Production MongoDB is still unreachable from the deployed Vercel backend, so live signup, wishlist, cart, checkout, order-history, admin CRUD, and account deletion writes are not proven in production.
- Signed archive, provisioning, TestFlight upload, and installed TestFlight QA have not been completed.
- Secrets previously exposed during development must be rotated before public release.

## Next Phase Input

Phase 8 should focus on signed archive/TestFlight validation, App Store privacy metadata, reviewer-ready support/privacy/legal surfaces, and resolving the production MongoDB connectivity blocker before any public release claim.
