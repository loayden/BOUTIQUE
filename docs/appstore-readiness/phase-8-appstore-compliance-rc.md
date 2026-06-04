# Phase 8: App Store Compliance And TestFlight Release Candidate

Date: 2026-06-04

## Summary

Phase 8 is locally hardened but not fully complete. The app produces successful local builds with production URLs, bundled resources, and `PrivacyInfo.xcprivacy` included. Local compliance checks pass. XCTest and Release simulator builds pass.

The remaining blocker is external: this machine only has an Apple Development signing identity and no App Store Connect provider access, so Xcode cannot validate/export/upload the archive for TestFlight.

## Implemented

- Added `AurelienApp/Scripts/appstore_phase8_readiness.sh`.
- Added `AurelienApp/Release/AppStoreValidationOptions.plist`.
- Added `AurelienApp/Release/TestFlightUploadOptions.plist`.
- Removed `DEVELOPMENT_ASSET_PATHS = "AurelienApp/Resources"` from the app target and `project.yml`.
- Updated the release checklist with the live support URL, archive command, validation export command, and TestFlight upload command.

## Root Cause Fixed

The first successful device archive did not include `PrivacyInfo.xcprivacy`. The app target marked all of `AurelienApp/Resources` as development-only assets, so real app resources were stripped from the archive.

Fix: removed the development-assets setting from the app target. The fresh archive now includes:

- `PrivacyInfo.xcprivacy`
- production API/static/privacy/support URLs
- product media/font resources

## Verified

- `AurelienApp/Scripts/appstore_phase8_readiness.sh`: passed.
- `AurelienApp/Scripts/ensure_release_readiness.sh`: passed.
- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`: passed.
- Archive inspection confirmed `PrivacyInfo.xcprivacy` is present and declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
- Archive inspection confirmed:
  - `AURELIEN_API_BASE_URL=https://boutique-api-one.vercel.app/api`
  - `AURELIEN_STATIC_CONTENT_BASE_URL=https://boutique-api-one.vercel.app/v1`
  - `BOUTIQUE_PRIVACY_POLICY_URL=https://bout-clothes.vercel.app/privacy`
  - `BOUTIQUE_SUPPORT_URL=https://bout-clothes.vercel.app/returns`
- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`: passed with `27` tests and `0` failures.
- `npm run typecheck`: passed.
- `npm run build`: passed.
- `npm run db:ensure-production`: passed against production MongoDB.
- `npm run smoke:api`: passed against `https://boutique-api-one.vercel.app/api`.
- `npm run smoke:ecommerce`: passed against `https://boutique-api-one.vercel.app/api`.
- `npm run smoke:admin`: passed against `https://boutique-api-one.vercel.app/api`.

## App Store Connect Blocker

`xcodebuild -exportArchive` with `AppStoreValidationOptions.plist` failed with:

```text
No Accounts with App Store Connect Access
```

The local keychain currently has only an Apple Development signing identity. There is no Apple Distribution identity available to this shell, and Xcode cannot authenticate to an App Store Connect provider from the current account state.

Added `AurelienApp/Scripts/appstore_signing_readiness.sh` so this failure is now repeatable and explicit before attempting TestFlight export.

## Production Backend Status

Production MongoDB is reachable from the deployed Vercel backend. Live signup, login, wishlist, cart, checkout/order creation, order history, admin product CRUD, admin image upload, and account cleanup have been smoke-tested successfully.

## Next Required Actions

- Add an Apple Developer/App Store Connect account with provider access in Xcode or provide an App Store Connect API key for `xcodebuild`.
- Configure Apple Distribution/App Store signing for `com.shereenmagdy.aurelien`.
- Re-run:
  - `xcodebuild -exportArchive -archivePath build/Aurelien-AppStore.xcarchive -exportPath build/AppStoreValidationExport -exportOptionsPlist AurelienApp/Release/AppStoreValidationOptions.plist -allowProvisioningUpdates`
  - `xcodebuild -exportArchive -archivePath build/Aurelien-AppStore.xcarchive -exportPath build/TestFlightUpload -exportOptionsPlist AurelienApp/Release/TestFlightUploadOptions.plist -allowProvisioningUpdates`
- Rerun live auth/admin/ecommerce smokes immediately before TestFlight external testing.
- Keep rotated secrets out of git and rotate again if any value is exposed outside ignored env/Vercel/Atlas storage.
