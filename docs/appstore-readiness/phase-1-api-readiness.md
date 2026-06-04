# Phase 1 API Readiness

Phase 1 establishes a repeatable API contract check for the routes the iOS app needs before App Store release.

## Public Routes Checked

- `GET /api`
- `GET /api/health`
- `GET /api/products`
- `GET /api/boutiques`
- `GET /api/discover/feed`
- `GET /api/support/channels`
- `GET /api/support/faqs`
- `GET /api/legal/documents`

## Product Image Checks

- Every product must expose at least one image URL through `images` or `imageNames`.
- Empty image strings are treated as failures.
- A sample of unique image URLs is fetched to confirm the server can actually deliver product media.

## Commands

Run against local API:

```bash
cd AurelienApp/AURE-LIEN-
npm run smoke:api:readiness
```

Run against deployed API:

```bash
cd AurelienApp/AURE-LIEN-
AURELIEN_SMOKE_BASE_URL=https://bout-clothes.vercel.app/api npm run smoke:api:readiness
```

The script exits non-zero when a required route, payload shape, or sampled product image is broken.

## Verification On May 31, 2026

Local API at `http://127.0.0.1:3104/api`:

- `npm run smoke:api:readiness` passed.
- `GET /api/products` returned `31` products.
- All required public routes returned `200`.
- The first `12` sampled product images returned image content.

Deployed API at `https://bout-clothes.vercel.app/api`:

- `npm run smoke:api:readiness` failed.
- `/api`, `/api/health`, `/api/boutiques`, `/api/discover/feed`, `/api/support/channels`, `/api/support/faqs`, and `/api/legal/documents` returned `404`.
- `/api/products` did not match the current production response contract expected by the iOS backend.

This means Phase 2 must focus on deploying the current backend route implementation and verifying the live API, not on changing the iOS app contract first.
