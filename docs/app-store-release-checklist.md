# BOUTIQUE App Store Release Checklist

## Product scope

- Ship the public shopper app only: `Home`, `Discover`, `Shop`, `Bag`, `Account`, PDP, auth, checkout, orders, support, legal, settings, stylist.
- Keep community, challenge voting, leaderboard, waitlist campaigns, product boost, subscription-plan sales, and internal/admin surfaces out of the App Store release flow.

## iOS build configuration

- Set `AURELIEN_API_BASE_URL` to the production HTTPS API, for example:
  - `https://boutique-api-one.vercel.app/api`
- Set `AURELIEN_STATIC_CONTENT_BASE_URL` to the production HTTPS static host, for example:
  - `https://boutique-api-one.vercel.app/v1`
- Confirm `BOUTIQUE_PRIVACY_POLICY_URL` resolves to `https://bout-clothes.vercel.app/privacy` or the current production privacy page.
- Confirm `BOUTIQUE_SUPPORT_URL` resolves to `https://bout-clothes.vercel.app/returns` or the current production support/returns page. Do not use `https://bout-clothes.vercel.app/support`; it currently returns `404`.
- Confirm Release builds do not ship ATS exceptions for `localhost` or `127.0.0.1`.
- Confirm the app bundle includes `PrivacyInfo.xcprivacy`.
- Confirm iPhone orientation support is portrait-only unless landscape has been explicitly QA’d.
- Run the local App Store compliance gate:
  - `AURELIEN_API_BASE_URL=https://boutique-api-one.vercel.app/api AURELIEN_STATIC_CONTENT_BASE_URL=https://boutique-api-one.vercel.app/v1 BOUTIQUE_PRIVACY_POLICY_URL=https://bout-clothes.vercel.app/privacy BOUTIQUE_SUPPORT_URL=https://bout-clothes.vercel.app/returns AurelienApp/Scripts/appstore_phase8_readiness.sh`

## Backend readiness

- Deploy `AurelienApp/AURE-LIEN-` with:
  - production `AURELIEN_AUTH_SECRET`
  - production `AURELIEN_ADMIN_EMAIL`
  - production `AURELIEN_ADMIN_PASSWORD`
  - production `AURELIEN_MONGODB_URI`
  - production `AURELIEN_MONGODB_DB`
  - stable image hosting through MongoDB-backed storage or a persistent upload host
- Validate ignored production env locally before syncing:
  - `cd AurelienApp/AURE-LIEN-`
  - `AURELIEN_ENV_FILE=/absolute/path/to/rotated.env AURELIEN_SECRETS_ROTATED=YES npm run prod:env:check`
- Sync Vercel production env only after secret rotation and explicit approval:
  - `AURELIEN_ENV_FILE=/absolute/path/to/rotated.env AURELIEN_SECRETS_ROTATED=YES AURELIEN_CONFIRM_PRODUCTION_ENV_UPDATE=YES npm run prod:env:sync`
- Redeploy the API after env sync:
  - `npm exec --yes vercel -- deploy --prod`
- Verify live persistence before TestFlight:
  - `curl -fsS https://boutique-api-one.vercel.app/api/health`
  - `AURELIEN_ENV_FILE=.env.production.local npm run db:ensure-production`
  - `AURELIEN_ENV_FILE=.env.production.local AURELIEN_SMOKE_BASE_URL=https://boutique-api-one.vercel.app/api AURELIEN_SMOKE_TIMEOUT_MS=30000 npm run smoke:api`
  - `AURELIEN_SMOKE_BASE_URL=https://boutique-api-one.vercel.app/api AURELIEN_SMOKE_TIMEOUT_MS=30000 npm run smoke:ecommerce`
  - `AURELIEN_ENV_FILE=.env.production.local AURELIEN_SMOKE_BASE_URL=https://boutique-api-one.vercel.app/api AURELIEN_SMOKE_TIMEOUT_MS=30000 npm run smoke:admin`
- Verify the production API supports:
  - auth
  - catalog
  - wishlist
  - bag/cart
  - checkout/order creation
  - order history
  - support/legal content
  - stylist prompts/recommendations
  - account deletion
- Do not rely on the embedded static backend for the archive you upload to App Store Connect.

## Privacy and policy

- Confirm guest browse works for `Home`, `Discover`, `Shop`, PDP, and `Bag`.
- Confirm final order submission requires sign-in.
- Confirm account deletion is reachable in-app from `Account`.
- Confirm privacy policy and support links open valid public URLs.
- Confirm App Privacy answers in App Store Connect match actual collection and tracking behavior.

## Verification

- Debug build:
  - `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Debug tests:
  - `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- Release build:
  - `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Release archive:
  - `AURELIEN_API_BASE_URL=https://boutique-api-one.vercel.app/api AURELIEN_STATIC_CONTENT_BASE_URL=https://boutique-api-one.vercel.app/v1 BOUTIQUE_PRIVACY_POLICY_URL=https://bout-clothes.vercel.app/privacy BOUTIQUE_SUPPORT_URL=https://bout-clothes.vercel.app/returns xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Release -destination 'generic/platform=iOS' archive -archivePath build/Aurelien-AppStore.xcarchive`
- App Store validation export:
  - `xcodebuild -exportArchive -archivePath build/Aurelien-AppStore.xcarchive -exportPath build/AppStoreValidationExport -exportOptionsPlist AurelienApp/Release/AppStoreValidationOptions.plist -allowProvisioningUpdates`
- TestFlight upload export:
  - `xcodebuild -exportArchive -archivePath build/Aurelien-AppStore.xcarchive -exportPath build/TestFlightUpload -exportOptionsPlist AurelienApp/Release/TestFlightUploadOptions.plist -allowProvisioningUpdates`
  - Requires App Store Connect provider access and an Apple Distribution/App Store signing path.
- Signing preflight:
  - `AurelienApp/Scripts/appstore_signing_readiness.sh`

## Manual QA

- Guest browse across home, discover, shop, PDP, and bag
- Sign in and sign out without being forced back into auth
- Checkout validation and payment-method honesty
- Order history visibility only after sign-in
- Account deletion success path and failure messaging
- Support/legal links
- Offline/error states
- Large-touch-target checks on account, bag, checkout, and PDP

## App Store Connect

- Update screenshots after the final UI pass
- Set age rating based on the shipped public shopper scope
- Add support URL
- Add privacy policy URL
- Add App Review notes explaining:
  - guest browse is supported
  - final order placement requires sign-in
  - admin tooling is not part of the public release flow
  - account deletion is available in Account after sign-in
  - payment methods are limited to the methods currently supported by the live store
