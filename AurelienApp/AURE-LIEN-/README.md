# Aurelien Server

This Next.js app exposes the real API used by the iOS app at `/api`.

Required production environment:

- `AURELIEN_AUTH_SECRET`: long random signing secret for auth tokens.
- `AURELIEN_ADMIN_EMAIL`: first admin account email to seed.
- `AURELIEN_ADMIN_PASSWORD`: first admin account password to seed.
- `AURELIEN_MONGODB_URI`: MongoDB connection string for shared production data.
- `AURELIEN_MONGODB_DB`: database name, usually `aurelien`.
- `AURELIEN_IMAGE_STORAGE`: use `mongodb` for database-backed product photo uploads.
- `AURELIEN_UPLOAD_DIR`: writable persistent upload folder on the server when `AURELIEN_IMAGE_STORAGE=filesystem`.
- `AURELIEN_PUBLIC_UPLOAD_BASE_URL`: public URL that serves `AURELIEN_UPLOAD_DIR` when filesystem uploads are used.

Environment templates:

- `.env.example`: shared variable reference with placeholder values.
- `.env.development.example`: local MongoDB/dev-server template.
- `.env.production.example`: production deployment template for Vercel or another host.

Real `.env.local`, `.env.development`, `.env.production`, and Atlas credential files are intentionally ignored by git. Do not commit real secrets.

Local development can run without MongoDB; it will use `data/state.json`. Production must set `AURELIEN_MONGODB_URI`. The server now treats persisted app state as the source of truth for catalog, users, carts, and orders, and only uses the bundled catalog as a one-time seed when persisted state has no catalog yet.

When `AURELIEN_IMAGE_STORAGE=mongodb`, admin product photos are stored in MongoDB and served from `/api/uploads/product-image/:fileName`, so the server does not depend on temporary local disk.

Local MongoDB workflow on this machine:

```text
npm run db:init
```

That command:

- starts a local `mongod` on `127.0.0.1:27017`
- stores database files under `.mongodb/`
- seeds a clean empty app state and imports `public/v1/products.json` into `app_state._id=main.state.catalogProducts`
- prints a JSON health summary

Useful commands:

```text
npm run db:start
npm run db:seed
npm run db:status
npm run prod:env:check
npm run smoke:api:readiness
npm run smoke:api
npm run db:stop
```

`npm run prod:env:check` validates a local ignored production env file without printing secret values. By default it reads `.env.production.local`; set `AURELIEN_ENV_FILE=/absolute/path/to/file` to validate another file.

After rotating exposed secrets, `npm run prod:env:sync` can sync the validated production environment to the linked Vercel project. It intentionally refuses to run unless both guard variables are set:

```text
AURELIEN_SECRETS_ROTATED=YES AURELIEN_CONFIRM_PRODUCTION_ENV_UPDATE=YES npm run prod:env:sync
```

This is a production-impacting operation. Run it only after the MongoDB password/URI, auth secret, and admin password have been rotated.

`npm run smoke:api:readiness` runs the public App Store readiness smoke against the current API base, including products, boutiques, discover feed, support, legal, and sampled product image delivery.

`npm run smoke:api` runs the authenticated ecommerce smoke flow against the current API base, including admin image upload and product CRUD. Set `AURELIEN_SMOKE_BASE_URL` when the server is not running at the default local URL.

After deployment, set the iOS build setting `AURELIEN_API_BASE_URL` to:

```text
https://your-api-domain.com/api
```

The app also supports `AURELIEN_STATIC_CONTENT_BASE_URL` if static content is hosted separately.

For App Store release builds, also set these iOS build settings:

```text
BOUTIQUE_PRIVACY_POLICY_URL=https://bout-clothes.vercel.app/privacy
BOUTIQUE_SUPPORT_URL=https://bout-clothes.vercel.app/returns
```

Public App Store scope should keep the backend focused on:

- auth
- catalog
- wishlist
- cart
- checkout and order creation
- order history
- support and legal content
- stylist prompts and recommendations
- account deletion

The production archive should not depend on community, challenge, waitlist campaign, seller boost, or other internal-only endpoints.

Those internal-only surfaces are disabled by default through the API unless `AURELIEN_ENABLE_EXPERIMENTAL_ENDPOINTS=true` is explicitly set.
