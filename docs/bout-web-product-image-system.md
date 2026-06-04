# BOUT Web Product Image System

## Frontend Rules

- Commerce listing cards use one fixed `4:5` portrait ratio.
- Commerce cards use `object-fit: cover`.
- Commerce cards keep identical heights across shelves, grids, search, wishlist, and related-product modules.
- Editorial hero, campaign, and lookbook media do not reuse the `4:5` product-card frame.
- PDP galleries should keep the full garment visible and use flexible ratios.

## Current Repo Implementation

- Shared commerce card media lives in:
  - `/Users/shereenmagdy/Desktop/ios/AurelienApp/AURE-LIEN-/app/globals.css`
  - `.product-card`
  - `.product-media-frame`
  - `.product-media-image`
- Editorial hero media is separated from listing cards:
  - `.editorial-hero-panel`
  - `.editorial-hero-frame`
  - `.editorial-hero-image`
- Homepage application:
  - `/Users/shereenmagdy/Desktop/ios/AurelienApp/AURE-LIEN-/app/page.tsx`

## Backend Content Contract

Each catalog product can optionally define:

```json
{
  "imageFocalPoint": {
    "x": 50,
    "y": 18
  }
}
```

- `x` and `y` are percentages from `0` to `100`.
- Default fallback is centered with a slightly upper-biased crop: `50% 18%`.
- Backend normalization lives in:
  - `/Users/shereenmagdy/Desktop/ios/AurelienApp/AURE-LIEN-/lib/backend.ts`

## Asset Pipeline Requirements

For production content:

1. Upload product photos in a consistent portrait composition.
2. Export normalized commerce crops at `4:5`.
3. Keep high-resolution originals for PDP and zoomable media.
4. Generate multiple renditions:
   - thumbnail
   - grid
   - PDP large
5. Preserve focal-point metadata through admin edits and publish flow.

## Surface Rules

- Home shelves: `4:5`
- Shop grid: `4:5`
- Category pages: `4:5`
- Search results: `4:5`
- Wishlist: `4:5`
- Related / you-may-also-like: `4:5`
- Hero / campaign: freeform or `16:9`
- Lookbook: art-directed
- PDP gallery: flexible / full image
- Swatches / icons / avatars: `1:1`

## QA Checklist

- Card heights remain identical across a mixed catalog.
- No white bars appear around listing images.
- Crops bias toward the garment instead of dead center when focal-point data exists.
- Hero media is not forced into the listing-card ratio.
- PDP media shows the full garment instead of card-cropping behavior.
