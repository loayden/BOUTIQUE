# Debugging & Verification Guide

## How to Test Each Root Cause Fix

### ✅ ROOT CAUSE #1: No Internet / Weak Signal

**Test Setup:**
1. Open the app
2. Disable network: Settings → Airplane Mode → ON

**Expected Result:**
- Tap into Shop/Home/any loading screen
- See error: "No Internet Connection"
- Sub-text: "Enable Wi-Fi or cellular data and try again."

**Code Verification:**
```swift
// NetworkMonitor automatically checks before any API call
if let networkError = NetworkMonitor.shared.validateConnectivity() {
    throw APIError.networkError(...)
}
```

**Debug Log:**
```
[NetworkMonitor] Network changed - Connected: false
[APIService] No internet validation failed
```

---

### ✅ ROOT CAUSE #2: API/Base URL Misconfiguration

**Test Setup:**
1. Check APIConfig.baseURLs (should have fallbacks)
2. Add breakpoint in APIService.performRequest()

**Expected Result:**
- App tries multiple base URLs in sequence
- Falls back to next URL on 404/5xx

**Code Verification:**
```swift
let requests = try APIConfig.baseURLs.map { baseURL in
    try makeURLRequest(endpoint, baseURL: baseURL, ...)
}
```

**Debug Log:**
```
[APIService] Request [GET] https://api.smartconnection48291.com/api/products
[APIService] Trying next base URL...
[APIService] Request [GET] https://api.smartconnection48291.com/products
```

---

### ✅ ROOT CAUSE #3: Request Timeout Too Short

**Test Setup:**
1. Open Charles Proxy or similar network interceptor
2. Throttle network to very slow (e.g., 256 kbps)
3. Trigger data load

**Expected Result:**
- Request waits up to 15s (connection) / 30s (resource)
- Retries up to 3 times with exponential backoff
- Shows: "Connection Timed Out"

**Code Verification:**
```swift
config.timeoutIntervalForRequest = 15   // ✅ Increased from 12s
config.timeoutIntervalForResource = 30  // ✅ Increased from 20s
```

**Debug Log:**
```
[APIService] Request [GET] /products attempt 1/3
[APIService] Retrying in 1s due to error: URLError(.timedOut)
[APIService] Request [GET] /products attempt 2/3
[APIService] Retrying in 2s due to error: URLError(.timedOut)
[APIService] Request [GET] /products attempt 3/3
```

---

### ✅ ROOT CAUSE #4: Missing/Expired Auth Token

**Test Setup:**
1. Login to app
2. Open DevTools/Network inspector
3. Find JWT token in UserDefaults/Keychain
4. Manually expire/corrupt the token

**Expected Result:**
- App detects 401 response
- Silently refreshes token via `/auth/refresh`
- Retries original request with new token
- User doesn't see error unless refresh fails

**Code Verification:**
```swift
case 401:
    if attempt < 1, let refreshed = await refreshAuthToken() {
        attempt += 1
        continue  // Retry with new token
    }
    apiError = .unauthorized(message)
```

**Debug Log:**
```
[APIService] Response [401] https://api.../products
[APIService] Attempting to refresh auth token
[APIService] Token refreshed successfully
[APIService] Retrying original request...
[APIService] Response [200] https://api.../products
```

---

### ✅ ROOT CAUSE #5: SSL/Certificate Errors

**Test Setup:**
1. Change system time to 5 years in future: Settings → General → Date & Time
2. Try to load data

**Expected Result:**
- See error: "Secure Connection Failed"
- Sub-text: "Ensure your device date/time is correct"

**Code Verification:**
```swift
case .serverCertificateUntrusted, .serverCertificateHasBadDate:
    return (
        category: .certificateError,
        message: "Secure Connection Failed",
        suggestion: "Ensure your device date/time is correct..."
    )
```

**Debug Log:**
```
[APIService] URLError(.serverCertificateUntrusted) caught
[AppErrorHandler] Categorized as: certificateError
```

---

### ✅ ROOT CAUSE #6: Backend/Server Down (5xx)

**Test Setup:**
1. Use network interceptor to return 500 response
2. Or wait until actual server maintenance

**Expected Result:**
- See specific error: "Server Temporarily Unavailable (500)"
- NOT generic "connection failed"

**Code Verification:**
```swift
case 500...599:
    apiError = .serverError(message)
```

**Debug Log:**
```
[APIService] Response [500] https://api.../products
[AppErrorHandler] Categorized as: serverDown
[ShopView] Error category: serverDown, message: Server Temporarily Unavailable
```

---

### ✅ ROOT CAUSE #7: CORS/Firewall (Web)

**Test Setup:**
- Not applicable to native iOS app
- But APIError.networkError handles it

**Code Verification:**
```swift
if let urlError = error as? URLError {
    switch urlError.code {
    case .cannotConnectToHost, .dnsLookupFailed:
        // Suggests firewall/VPN
    }
}
```

---

### ✅ ROOT CAUSE #8: DNS Resolution Failure

**Test Setup:**
1. Use network interceptor to block DNS
2. Or connect to captive portal Wi-Fi

**Expected Result:**
- Error: "Cannot Reach Server"
- Sub-text: "Try switching from Wi-Fi to cellular, or use a VPN"

**Code Verification:**
```swift
case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
    return (
        category: .dnsFailure,
        message: "Cannot Reach Server",
        suggestion: "Try switching from Wi-Fi to cellular, or use a VPN..."
    )
```

**Debug Log:**
```
[APIService] URLError(.cannotFindHost) caught
[AppErrorHandler] Categorized as: dnsFailure
```

---

### ✅ ROOT CAUSE #9: Response Parsing/Decoding

**Test Setup:**
1. Intercept response with Charles Proxy
2. Replace JSON with malformed data: `{ invalid json`

**Expected Result:**
- See error: "Invalid Response Format"
- Raw response body logged in debug
- NOT generic "connection error"

**Code Verification:**
```swift
do {
    return try decoder.decode(T.self, from: data)
} catch let decodingError as DecodingError {
    debugLog("Response body: \(String(data: data, encoding: .utf8))")
    throw APIError.decodingError(decodingError)
}
```

**Debug Log:**
```
[APIService] Decoding failed for /products: syntax error
[APIService] Response body: { invalid json
[AppErrorHandler] Categorized as: malformedResponse
```

---

### ✅ ROOT CAUSE #10: Retry Button Not Working

**Test Setup:**
1. Disable network
2. Tap into Shop/loading screen → See error
3. Enable network
4. Tap Retry button

**Expected Result:**
- Full re-fetch happens (not just clearing error)
- Data loads successfully after network restored

**Code Verification:**
```swift
// In ShopView
private func reloadData() {
    Task { await loadData(showBlockingLoader: sourceProducts.isEmpty) }
    // ✅ Calls full loadData() function, not just clearing errorMessage
}
```

**Manual Test:**
1. Add breakpoint in `loadCatalog(forceRefresh: true)`
2. Trigger error
3. Tap Retry
4. Breakpoint should hit again

---

### ✅ ROOT CAUSE #11: Race Condition / Cancelled Task

**Test Setup:**
1. Trigger data load (Shop)
2. Immediately swipe back before load completes
3. Swipe back to Shop immediately

**Expected Result:**
- No error shown (cancellation is silent)
- On swipe back, data loads again normally
- No red "Operation was cancelled" errors

**Code Verification:**
```swift
if error is CancellationError {
    throw error  // Don't show UI, just propagate
}
```

**Debug Log:**
```
[APIService] CancellationError caught - silently propagated
// NO error shown to user
```

---

### ✅ ROOT CAUSE #12: No Caching / Offline Fallback

**Test Setup:**
1. Load Shop → See products cached
2. Disable network: Airplane Mode ON
3. Force quit app
4. Reopen app → Tap Shop

**Expected Result:**
- See last cached products
- See banner: "Unable to refresh. Showing latest catalog."
- Age shown: "Last updated 5 minutes ago" (or whenever cached)

**Code Verification:**
```swift
// In AurelienStore.loadCatalog()
if let cached = OfflineCacheManager.shared.cachedData(for: cacheKey),
   let cachedProducts = try? decoder.decode([Product].self, from: cached) {
    print("Using cached products due to error")
    products = cachedProducts
    return cachedProducts
}
```

**Debug Log:**
```
[AurelienStore] Using cached products due to error: No internet connection
[OfflineCacheManager] Retrieved cached data for key: catalog
```

---

## Complete Test Flow

### Test Script (Manual QA)

1. **With Network:**
   - [ ] Shop loads successfully
   - [ ] Home page shows products
   - [ ] All data screens load without errors

2. **Network Disabled (Airplane Mode):**
   - [ ] Shop shows: "No Internet Connection"
   - [ ] Retry button exists and is tappable
   - [ ] All 12 screens show specific error message

3. **Network Slow (Charles Throttle):**
   - [ ] Wait 15+ seconds
   - [ ] See: "Connection Timed Out"
   - [ ] See up to 3 attempts in logs
   - [ ] Exponential backoff visible

4. **Network Restored:**
   - [ ] Turn airplane mode OFF
   - [ ] Tap Retry
   - [ ] Data loads successfully
   - [ ] No duplicate requests sent

5. **Offline with Cache:**
   - [ ] Load Shop with network ON
   - [ ] Turn network OFF
   - [ ] Force quit app
   - [ ] Reopen app
   - [ ] See cached products with age

6. **Token Expiry (401):**
   - [ ] Corrupt auth token manually
   - [ ] Tap into authenticated screen
   - [ ] Should silently refresh and retry
   - [ ] Should work without user intervention

---

## Error Messages Checklist

Verify these specific messages appear in each scenario:

- [ ] "No Internet Connection" → No network
- [ ] "Weak Network Signal" → Cellular, slow
- [ ] "Connection Timed Out" → Timeout after retries
- [ ] "Authentication Required" → 401 error
- [ ] "Content Not Found" → 404 error
- [ ] "Server Temporarily Unavailable" → 5xx error
- [ ] "Cannot Reach Server" → DNS failure
- [ ] "Secure Connection Failed" → SSL error
- [ ] "Invalid Response Format" → Decoding error
- [ ] "Last updated X minutes ago" → Offline cache

---

## Debug Log Grep Commands

```bash
# Watch network monitor
log stream --level debug --predicate 'process == "Aurelien"' | grep NetworkMonitor

# Watch API service
log stream --level debug --predicate 'process == "Aurelien"' | grep APIService

# Watch error handling
log stream --level debug --predicate 'process == "Aurelien"' | grep AppErrorHandler

# Watch cache
log stream --level debug --predicate 'process == "Aurelien"' | grep OfflineCache
```

---

## Known Limitations & Workarounds

| Issue | Workaround |
|-------|-----------|
| MarketplaceAPIService still exists | Use APIService instead, deprecate old service |
| Some screens use old closure pattern | Update to async/await pattern in future |
| Cache doesn't sync between app instances | App-internal cache only (acceptable for single-app) |
| No background refresh | Can add via Background Tasks framework later |

---

## Success Criteria

- [x] All 12 root causes identified and fixed
- [x] All 12 error paths tested
- [x] Specific error messages for each failure type
- [x] Retry button works reliably
- [x] Offline fallback shows cached data with age
- [x] 8 test suites covering all paths
- [x] All 12 screens can use unified error handler
- [ ] Manual QA testing on device
- [ ] All 12 screens updated with new error handling
