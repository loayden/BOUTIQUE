# Quick Fix Script - Remaining 8 Screens

Each remaining screen needs this pattern update. Replace:
```swift
self.errorMessage = error.localizedDescription
```

With:
```swift
// ROOT CAUSE: Use AppErrorHandler to categorize error
let (_, message, suggestion) = AppErrorHandler.categorize(error)
self.errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
```

## Screen 1: TryBeforeBuyView.swift

**Method: `checkEligibility()`**
**Location**: Line ~68

```swift
// BEFORE
} catch {
    await MainActor.run {
        self.errorMessage = error.localizedDescription
    }
}

// AFTER
} catch {
    await MainActor.run {
        let (_, message, suggestion) = AppErrorHandler.categorize(error)
        self.errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
```

---

## Screen 2: SubscriptionBoxView.swift

**Method: `subscribe()`**
**Location**: Line ~65

Same pattern as above.

---

## Screen 3: SnapMatchView.swift

**Method: `searchMatches()`**
**Location**: Line ~?

Search for:
```swift
self.errorMessage = error.localizedDescription
```

Replace with AppErrorHandler pattern.

---

## Screen 4: ProductBoostView.swift

**Method: `boostProduct()`**
**Location**: Line ~?

Search for:
```swift
self.errorMessage = error.localizedDescription
```

Replace with AppErrorHandler pattern.

---

## Screen 5: StyleProfileView.swift

**Method: `loadProfile()`**
**Location**: Line ~?

Search for:
```swift
self.errorMessage = error.localizedDescription
```

Replace with AppErrorHandler pattern.

---

## Screen 6: SocialHubView.swift

**Method: `loadUsers()`**
**Location**: Line ~?

Search for:
```swift
errorMessage = error.localizedDescription
```

Replace with AppErrorHandler pattern (note: no `self.` prefix based on file structure).

---

## Screen 7: OutfitFeedView.swift

**Methods: `loadFeed()` AND ViewModel**
**Challenge**: This file uses both closure callbacks and async/await

**In loadFeed():**
```swift
case .failure(let error):
    self.errorMessage = error.localizedDescription
```

Replace with:
```swift
case .failure(let error):
    let (_, message, suggestion) = AppErrorHandler.categorize(error)
    self.errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
```

**In ViewModel.fetchOutfits():**
```swift
catch {
    await MainActor.run {
        errorMessage = error.localizedDescription
    }
}
```

Replace with:
```swift
catch {
    await MainActor.run {
        let (_, message, suggestion) = AppErrorHandler.categorize(error)
        errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
```

---

## Screen 8: OrdersView.swift

**Methods**: `loadOrders()` or `loadOrderHistory()`
**Location**: Line ~?

Search for all instances of:
```swift
errorMessage = error.localizedDescription
```

Replace each with AppErrorHandler pattern.

---

## Bulk Replace Command (Terminal)

If you prefer to use sed or another tool:

```bash
# Find all occurrences across screens
grep -rn "errorMessage = error.localizedDescription" /Users/shereenmagdy/Desktop/ios/AurelienApp/Sources/Views/Screens/

# Then manually replace each with the AppErrorHandler pattern
# OR use this sed command (careful - test first):
sed -i '' 's/errorMessage = error\.localizedDescription/let (_, message, suggestion) = AppErrorHandler.categorize(error); errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\\n\\n")/g' /path/to/file.swift
```

---

## Verification Checklist

After updating all 8 remaining screens, verify:

- [ ] All `errorMessage = error.localizedDescription` replaced
- [ ] AppErrorHandler imported (if not already)
- [ ] No compilation errors
- [ ] Try loading each screen with network disabled to test error display
- [ ] Verify Retry button works on each screen
- [ ] Check that error messages are now specific (no generic "Error: request failed")

---

## Testing Each Screen

1. **Disable Network**: Settings → Airplane Mode ON
2. **Trigger Error**: Tap into screen or pull to refresh
3. **Verify**: See specific error message (e.g., "No Internet Connection")
4. **Retry**: Tap Retry button
5. **Re-Enable Network**: Settings → Airplane Mode OFF
6. **Retry Again**: Should load successfully

---

## If Errors Occur During Implementation

**Issue**: "Cannot find 'AppErrorHandler' in scope"
**Solution**: Add import at top of file:
```swift
import Foundation  // Already there
// AppErrorHandler should be available automatically if in same target
```

**Issue**: Syntax error in error message formatting
**Solution**: Ensure spacing:
```swift
[message, suggestion]  // space after [
.filter { !$0.isEmpty }  // space after }
.joined(separator: "\n\n")  // newlines in quotes
```

**Issue**: Compiler warning about @MainActor
**Solution**: Already handled in async/await pattern, no changes needed.

---

## Files That Should NOT Be Modified

- ❌ LoginView.swift (handles auth errors differently)
- ❌ OnboardingView.swift (setup flow, not data loading)
- ❌ StylistStudioView.swift (different error UI)

Only update the 8 screens listed above.
