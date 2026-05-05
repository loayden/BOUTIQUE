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

Local development can run without MongoDB; it will use `data/state.json`. Production should set `AURELIEN_MONGODB_URI` so products, users, carts, and orders are shared across devices.

When `AURELIEN_IMAGE_STORAGE=mongodb`, admin product photos are stored in MongoDB and served from `/api/uploads/product-image/:fileName`, so the server does not depend on temporary local disk.

After deployment, set the iOS build setting `AURELIEN_API_BASE_URL` to:

```text
https://your-api-domain.com/api
```

The app also supports `AURELIEN_STATIC_CONTENT_BASE_URL` if static content is hosted separately.
