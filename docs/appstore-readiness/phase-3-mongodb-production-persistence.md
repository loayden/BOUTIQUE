# Phase 3 MongoDB Production Persistence

Phase 3 focused on making Mongo persistence verifiable and safer in production.

## Implemented

- Added `npm run db:ensure-production`.
- Added `scripts/mongo-ensure-production.mjs`.
- The script:
  - connects to the configured MongoDB database
  - creates or updates validators for `app_state` and `uploaded_product_images`
  - creates required indexes idempotently
  - seeds the real starter catalog only when `app_state/main` is missing
  - verifies product IDs, basic product fields, deleted IDs, image references, and uploaded-image references
- Updated `mongo-health.mjs` and `mongo-seed.mjs` to support `AURELIEN_ENV_FILE`.
- Hardened the backend Mongo client:
  - bounded server selection timeout
  - bounded connect timeout
  - smaller pool size for serverless
  - failed connection promises are cleared so one timeout does not poison the runtime instance

## Local Verification

Local MongoDB at `127.0.0.1:27017`:

```text
npm run db:status
npm run db:ensure-production
```

Result:

- database: `aurelien`
- product count: `31`
- active product count: `31`
- deleted product count: `4`
- upload count: `4`
- app_state indexes: `_id_`, `updatedAt_desc`
- uploaded_product_images indexes: `_id_`, `createdAt_-1`, `contentType_1`, `size_1`
- validation failures: none

Backend verification:

- `npm run build`: passed
- `npm run typecheck`: passed
- Vercel production deploy: passed

## Production Verification

Deployed API:

- `https://boutique-api-one.vercel.app/api/products` returns `31` products.
- Product image URLs load from the production API/static origin.
- Public browse routes use Mongo-backed state with static catalog only as seed/fallback.

Mongo health:

```text
GET https://boutique-api-one.vercel.app/api/health
```

Result:

```json
{
  "ok": true,
  "service": "BOUTIQUE API",
  "storage": "mongodb",
  "database": {
    "storage": "mongodb",
    "databaseName": "aurelien",
    "reachable": true,
    "seeded": true
  }
}
```

Live validation:

- `npm run db:ensure-production`: passed against production Atlas.
- `npm run smoke:api`: passed against `https://boutique-api-one.vercel.app/api`.
- `npm run smoke:ecommerce`: passed against `https://boutique-api-one.vercel.app/api`.
- `npm run smoke:admin`: passed against `https://boutique-api-one.vercel.app/api`.
- Product-card image smoke checked all `31` active products with `0` image failures.
- Admin image upload returned a persisted image URL, and that URL still returned `image/jpeg` after product deletion.

## Added Production Guardrails

- Added `npm run prod:env:check` to validate the ignored production env file without printing secrets.
- Added `npm run prod:env:sync` to sync the linked Vercel production env only after explicit confirmation.
- The sync command refuses to run unless:
  - production values are present
  - `AURELIEN_IMAGE_STORAGE=mongodb`
  - `AURELIEN_ENABLE_EXPERIMENTAL_ENDPOINTS=false`
  - `AURELIEN_SECRETS_ROTATED=YES`
  - `AURELIEN_CONFIRM_PRODUCTION_ENV_UPDATE=YES`

Recommended sequence after rotating Atlas and app secrets:

```text
cd AurelienApp/AURE-LIEN-
AURELIEN_ENV_FILE=/absolute/path/to/rotated.env AURELIEN_SECRETS_ROTATED=YES npm run prod:env:check
AURELIEN_ENV_FILE=/absolute/path/to/rotated.env AURELIEN_SECRETS_ROTATED=YES AURELIEN_CONFIRM_PRODUCTION_ENV_UPDATE=YES npm run prod:env:sync
npm exec --yes vercel -- deploy --prod
curl -fsS https://boutique-api-one.vercel.app/api/health
AURELIEN_SMOKE_BASE_URL=https://boutique-api-one.vercel.app/api npm run smoke:ecommerce
```

## June 4, 2026 Production Recovery

Actions completed:

- Installed and authenticated the Atlas CLI with the Atlas project account.
- Confirmed the original Atlas project `69bf33ee6550c65f41f596c1` contains a stuck `Cluster0`.
- The original `Cluster0` remained in `UPDATING` state and timed out on TCP `27017`.
- Attempted old-cluster delete, but Atlas returned an API `500`.
- Attempted a Flex replacement in the old project, but Atlas required paid billing.
- Created a new Atlas production project for BOUTIQUE.
- Created a new free `M0` production cluster.
- Added a dedicated least-privilege database user for the API with `readWrite` on the `aurelien` database.
- Added an Atlas access-list entry for Vercel serverless production access.
- Generated a fresh ignored local production env file at `.env.production.local`.
- Synced rotated production env values to Vercel using `npm run prod:env:sync`.
- Redeployed `boutique-api` to production and re-aliased `https://boutique-api-one.vercel.app`.
- Patched public product/catalog routes to avoid stale CDN cache after admin mutations.

Current result:

- `GET https://boutique-api-one.vercel.app/api/products` still returns `31` products.
- `GET https://boutique-api-one.vercel.app/api/health` returns `200` with Mongo `reachable: true` and `seeded: true`.
- Production validation reports `31` active products, `2` deleted products excluded from customer UI, `2` persisted uploaded images, required indexes, and no failures.
- Live shopper and admin smoke tests pass.

Conclusion:

Production MongoDB persistence is now operational. The old stuck Atlas cluster remains in the old project as an Atlas support/cleanup item, but the production API no longer depends on it.
