# Fix ProductCardView crash ("productdetails not work")

## Previous Task (Completed):
# Fix FullScreenProductCarousel scope error in ShopView.swift
- [x] All steps completed

## Current Task Steps:
- [x] 1. Add `isValid` computed property to `Product` struct in CatalogModels.swift
- [x] 2. Filter invalid products in SampleData.swift `static let products`
- [x] 3. Update `filteredProducts()`, `personalizedProducts`, `relatedProducts(for:)` in AurelienStore.swift to use `isValid`
- [x] 4. Add defensive guards and logging in ProductCardView.swift body/formattedPrice
- [x] 5. Add minor guards for related products in ProductDetailView.swift
- [ ] 6. Clean Xcode build: Open Aurelien.xcodeproj, Cmd+Shift+K then Cmd+B
- [ ] 7. Test: Run app, navigate Shop -> tap ProductCard -> ProductDetail; check Console for logs
- [ ] 8. Verify previews in ProductCardView.swift

**Status:** Plan approved. Starting implementation.

