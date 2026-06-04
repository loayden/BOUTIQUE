# BOUTIQUE Backend/API App Store Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the BOUTIQUE iOS app and Next.js API ready for TestFlight and App Store review with production-safe backend behavior, verified data persistence, stable auth, working admin tools, and complete ecommerce flows.

**Architecture:** Keep the current SwiftUI app and Next.js catch-all API architecture, but add strict readiness gates around the API contract, Mongo persistence, auth/session behavior, admin CRUD, image delivery, checkout/order creation, and release configuration. The app must remain guest-browse first and use the backend as the production source of truth, with static content only as fallback/seed data.

**Tech Stack:** SwiftUI, XCTest, xcodebuild, Next.js App Router, TypeScript, MongoDB Atlas/local MongoDB, Node smoke scripts, Vercel-compatible environment variables.

---

## Phase 1: Baseline API Contract And Smoke Harness

**Purpose:** Create a repeatable truth source for which API routes the iOS app needs and whether local/live backend responses are healthy.

**Files:**
- Create: `AurelienApp/AURE-LIEN-/scripts/api-readiness.mjs`
- Modify: `AurelienApp/AURE-LIEN-/package.json`
- Modify: `AurelienApp/AURE-LIEN-/README.md`
- Create: `docs/appstore-readiness/phase-1-api-readiness.md`

- [x] Add a public API readiness script that checks `/api`, `/api/health`, `/api/products`, `/api/boutiques`, `/api/discover/feed`, `/api/support/channels`, `/api/support/faqs`, and `/api/legal/documents`.
- [x] Validate product payload shape and require every product to have at least one image URL.
- [x] Verify a sample of product image URLs returns HTTP 200.
- [x] Add an npm script for the readiness smoke.
- [x] Run the local API readiness smoke against a running local backend.
- [x] Run the same smoke against the deployed API and record failures as deployment blockers.

## Phase 2: Live API Completeness

**Purpose:** Make every route used by the iOS app available on the deployed backend.

**Acceptance Gates:**
- [x] `/api/products`, `/api/boutiques`, `/api/discover/feed`, `/api/support/channels`, `/api/support/faqs`, and `/api/legal/documents` return production-safe responses from `https://boutique-api-one.vercel.app/api`.
- [x] Missing deployed public routes from the stale `bout-clothes.vercel.app/api` deployment are available on the new `boutique-api-one` backend.
- [x] Public routes do not require auth.
- [ ] `/api/health` reports MongoDB `reachable: true` from Vercel. This is deferred to Phase 3 because Atlas rejects/times out Vercel runtime connections.

## Phase 3: MongoDB Production Persistence

**Purpose:** Verify Atlas-backed state is the production source of truth.

**Acceptance Gates:**
- [ ] `/api/health` reports `storage: "mongodb"`, `reachable: true`, and `seeded: true` in production. Blocked by Atlas network access from Vercel.
- [ ] Product, cart, wishlist, order, profile, notification, and uploaded image writes persist across backend restarts/redeploys. Blocked until deployed Mongo is reachable.
- [x] Index and schema validation scripts exist for the current production persistence collections.
- [x] Local Mongo validation passes with `31` products and no catalog/image validation failures.

## Phase 4: Authentication And Account Safety

**Purpose:** Stabilize login, signup, logout, refresh, role checks, and account deletion.

**Acceptance Gates:**
- [x] Guest users can browse Home, Discover, Shop, PDP, and Bag.
- [x] Login/signup/session persistence work without redirect loops locally.
- [x] Admin and non-admin tokens are enforced correctly locally.
- [x] Account deletion removes local app session and backend user-owned data locally.
- [x] Deployed unauthenticated protected routes return `401` before touching Mongo.
- [ ] Deployed signup/login/account deletion pass against production Mongo. Blocked until Atlas is reachable from Vercel.

## Phase 5: Admin Dashboard And Product Operations

**Purpose:** Make admin CRUD reliable enough to run the shop.

**Acceptance Gates:**
- [x] Admin can add/edit/delete products, upload images, update price, categories, stock, and availability locally.
- [x] Uploaded images remain accessible after product deletion locally.
- [x] Non-admin users cannot reach admin product endpoints locally.
- [x] Admin order management can read orders and update order status locally.
- [x] Deployed unauthenticated product/image mutations return `401` before touching Mongo.
- [ ] Deployed admin CRUD and uploads pass against production Mongo. Blocked until Atlas is reachable from Vercel.

## Phase 6: Ecommerce Flow Completion

**Purpose:** Prove the customer shopping lifecycle works end-to-end.

**Acceptance Gates:**
- [x] Browse products, open PDP, add to bag, update quantity, checkout, create order, view orders, wishlist save/remove, and logout/login persistence all pass locally.
- [x] All `31` local and deployed catalog products expose reachable product-card images.
- [x] Checkout shows only currently supported payment methods in the iOS checkout surface: Cash on Delivery and Vodafone Cash.
- [x] Deployed COD and promo validation routes return `200` without requiring MongoDB.
- [x] Deployed unauthenticated wishlist, cart, and order mutations return `401` before touching Mongo.
- [x] Account deletion returns stock for open pending/confirmed/preparing orders before removing user-owned order state.
- [ ] Deployed signup, cart, wishlist, checkout, and order-history writes pass against production Mongo. Blocked until Atlas is reachable from Vercel.

## Phase 7: iOS Release Build, Tests, And UX Blocking Fixes

**Purpose:** Remove iOS build/test blockers and known conversion UI failures.

**Acceptance Gates:**
- [x] XCTest bundle loads and the full suite passes.
- [x] Debug and Release simulator builds pass.
- [x] Product cards use consistent `4:5` commerce image ratio.
- [x] PDP has one custom back affordance and hides the system navigation back button.
- [x] Bottom tab bar does not cover Add to Bag / Buy Now; PDP reserves sticky CTA bottom clearance.
- [x] Release readiness guard rejects missing/non-HTTPS production URLs and the verified Release build used HTTPS production config.

## Phase 8: App Store Compliance And TestFlight Release Candidate

**Purpose:** Produce a signed, reviewable TestFlight build.

**Acceptance Gates:**
- [x] `PrivacyInfo.xcprivacy` is in the app target and present in a device archive.
- [x] Privacy/support URLs are live. Release support URL is `https://bout-clothes.vercel.app/returns`; `/support` returns `404`.
- [x] Account deletion is visible in-app for signed-in users and covered by tests.
- [x] Local Phase 8 readiness script exists and passes for privacy manifest, HTTPS URLs, support/privacy reachability, production product API, account deletion, orientation, and ATS checks.
- [x] Device archive succeeds with production URLs and bundled privacy/resources.
- [ ] App Store privacy answers, review notes, screenshots, age rating, version/build, signing, provisioning, and archive are complete in App Store Connect. Blocked until App Store Connect provider access is configured.
- [ ] Signed App Store Connect validation/export and TestFlight upload pass. Blocked because only Apple Development signing is installed and `xcodebuild -exportArchive` reports no App Store Connect provider access.
