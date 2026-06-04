# Phase 2 Live API Completeness

Phase 2 deployed the current backend route implementation to Vercel and moved the iOS default API host away from the stale `bout-clothes.vercel.app/api` deployment.

## Production API

- API base URL: `https://boutique-api-one.vercel.app/api`
- Static content base URL: `https://boutique-api-one.vercel.app/v1`
- Vercel project: `lols-projects-f47f6ee8/boutique-api`
- Production alias: `https://boutique-api-one.vercel.app`

## Routes Verified

These routes now return `200` from the new deployed API:

- `GET /api`
- `GET /api/products`
- `GET /api/boutiques`
- `GET /api/discover/feed`
- `GET /api/support/channels`
- `GET /api/support/faqs`
- `GET /api/legal/documents`

The deployed product route returns `31` products, and sampled product image URLs return valid image content.

## Changes Made

- Added a Vercel project link for `AurelienApp/AURE-LIEN-`.
- Set required production environment variables on the Vercel project without committing secrets.
- Removed the custom Next.js `distDir` so Vercel can build the app with the standard `.next` output.
- Strengthened `.vercelignore` to keep videos and generated build output out of deployment uploads.
- Added public catalog fallback so `GET /api/products` can serve the bundled real starter catalog if MongoDB is temporarily unreachable.
- Updated the iOS default API/static URLs to the new working backend.

## Remaining Blocker For Phase 3

`GET /api/health` currently returns `503` from Vercel because Vercel serverless functions cannot reach the configured MongoDB Atlas cluster:

```text
connect ETIMEDOUT <atlas-host-ip>:27017
```

The same Atlas database is reachable from this Mac and contains `31` products, so this is most likely MongoDB Atlas Network Access allowlisting. Phase 3 must fix Atlas production access, usually by allowing Vercel runtime egress or using a MongoDB/Vercel integration with supported network access.

Do not mark the backend fully production-ready until `/api/health` reports MongoDB `reachable: true` and `seeded: true` from the deployed API.
