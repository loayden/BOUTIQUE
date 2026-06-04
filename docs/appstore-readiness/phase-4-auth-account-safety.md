# Phase 4: Authentication And Account Safety

Date: 2026-06-03

## Summary

Phase 4 is code-complete locally. The backend now supports the iOS app's production auth/account contract, the iOS client uses the App Store compliance account-deletion route, and protected unauthenticated routes short-circuit to `401` before touching Mongo.

The deployed backend still cannot complete signup/login/account write flows because production MongoDB remains unreachable from Vercel.

## Implemented

- Added `npm run smoke:auth` through `scripts/auth-readiness.mjs`.
- Added `/api/auth/login` as a production alias for the existing sign-in flow.
- Added `/api/account` for authenticated current-user/profile reads.
- Added `/api/account/delete` for authenticated account deletion.
- Protected the final admin account from deletion.
- Centralized backend user-owned state cleanup for users, profiles, carts, orders, notifications, wallet data, wishlist state, closet state, and Discover state.
- Updated the Swift API client to call `/account/delete` for in-app account deletion.
- Updated the embedded Swift fallback backend to match the live API auth/account aliases.
- Added an unauthenticated protected-route precheck so deployed `/account` returns `401` even when Mongo is unavailable.

## Verified Locally

- `npm run smoke:auth`: passed.
- `npm run typecheck`: passed.
- `npm run build`: passed.
- `xcodebuild -project Aurelien.xcodeproj -scheme Aurelien -configuration Debug -destination 'generic/platform=iOS Simulator' build`: passed.

Local auth smoke covered:

- Guest `/products` browse.
- Guest `/discover/feed` browse.
- `/account` without auth returns `401`.
- Signup returns a token.
- `/auth/login` alias returns a token.
- Token refresh returns a token.
- `/account` returns the current user.
- Non-admin admin access returns `401`.
- Admin login preserves admin role.
- Admin analytics is reachable for admin users.
- `/account/delete` deletes the current account.
- Deleted account login is rejected.

## Verified In Production

- Production deploy succeeded and aliased to `https://boutique-api-one.vercel.app`.
- `GET /api/account` without auth now returns `401`.
- `GET /api/products` returns `31` products.
- `GET /api/health` still reports Mongo storage but unreachable.

Current production health:

```json
{
  "ok": false,
  "storage": "mongodb",
  "database": {
    "reachable": false,
    "seeded": false,
    "error": "Server selection timed out after 8000 ms"
  }
}
```

## Remaining Blocker

Production auth writes are blocked by Mongo connectivity:

- Live `npm run smoke:auth` now passes the protected `/account` precheck.
- It fails at `/auth/signup` with `500` because the deployed API cannot reach MongoDB.

This is not an iOS auth UI blocker anymore; it is the Phase 3 infrastructure blocker carrying forward.

## Next Phase Input

Phase 5 should focus on admin dashboard and product operations after Mongo connectivity is fixed, because admin product CRUD and uploaded image persistence depend on a writable production state store.
