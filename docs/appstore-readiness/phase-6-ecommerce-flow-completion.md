# Phase 6: Ecommerce Flow Completion

Date: 2026-06-04

## Summary

Phase 6 is locally verified. The backend now has a dedicated customer ecommerce smoke test covering browse, product detail, related products, product-card image reachability, COD/promo validation, signup/login/session, wishlist add/remove, cart add/update/remove, checkout order creation, cart clearing, order history, order detail, logout, and account cleanup.

The deployed backend is improved for public checkout helpers and catalog image delivery, but live ecommerce writes still cannot pass because production MongoDB remains unreachable from Vercel.

## Implemented

- Added `npm run smoke:ecommerce` through `scripts/ecommerce-readiness.mjs`.
- The smoke test dynamically chooses a sellable product from the live catalog instead of assuming a fixed product, size, or color.
- The smoke test verifies all catalog products have a first listing image that returns image bytes.
- Made `/api/orders/validate-cod` and `/api/orders/validate-promo` stateless so they no longer load MongoDB before returning.
- Fixed account deletion cleanup so pending, confirmed, and preparing orders release reserved stock before user-owned order state is removed.
- Deployed the backend patch to the production alias `https://boutique-api-one.vercel.app`.

## Verified Locally

- `npm run smoke:ecommerce`: passed.
- `npm run smoke:auth`: passed.
- `npm run smoke:admin`: passed.
- `npm run build`: passed.
- `npm run typecheck`: passed.
- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'generic/platform=iOS Simulator' build`: passed.

Local ecommerce smoke covered:

- `GET /products` returned `31` products.
- Product-card image check verified `31` images with zero failures.
- `GET /products/:id` returned the selected PDP.
- `GET /products/:id/related` returned related products.
- `POST /orders/validate-cod` returned Cairo eligibility and COD fee.
- `POST /orders/validate-promo` accepted `WELCOME50`.
- Signup and login returned customer tokens.
- `/account` loaded the active session.
- Wishlist initial, add, and remove worked.
- Cart initial, add, quantity update, remove, and re-add worked.
- `POST /orders` created a COD order.
- Checkout cleared the cart.
- Order history and order detail returned the created order.
- Logout was reachable.
- Account deletion cleanup succeeded.

## Verified In Production

- Production deploy succeeded and aliased to `https://boutique-api-one.vercel.app`.
- `GET /api/products` returns `31` products with no missing product images.
- `POST /api/orders/validate-cod` returns `{"eligible":true,"codFee":20}` for Cairo without MongoDB.
- `POST /api/orders/validate-promo` returns the `WELCOME50` discount without MongoDB.
- Unauthenticated live writes return `401` before MongoDB:
  - `POST /api/orders`
  - `POST /api/cart/items`
  - `POST /api/saved/me`

Current production health:

```json
{
  "ok": false,
  "service": "BOUTIQUE API",
  "storage": "mongodb",
  "database": {
    "storage": "mongodb",
    "databaseName": "aurelien",
    "reachable": false,
    "seeded": false,
    "error": "Server selection timed out after 8000 ms"
  }
}
```

## Remaining Blocker

Live `npm run smoke:ecommerce` now reaches the auth write step and fails at `/auth/signup` with `500` because the deployed API still cannot reach MongoDB.

Until the Phase 3 Atlas/Vercel connectivity blocker is fixed, live customer writes cannot be proven for:

- Signup/login persistence.
- Wishlist add/remove.
- Cart add/update/remove.
- Checkout order creation.
- Order history and order detail.
- Account deletion cleanup.

## Next Phase Input

Phase 7 can proceed on iOS release-build, tests, and UX blocking fixes. It should not claim TestFlight/App Store readiness until production MongoDB health reports reachable and the live ecommerce smoke passes end-to-end.
