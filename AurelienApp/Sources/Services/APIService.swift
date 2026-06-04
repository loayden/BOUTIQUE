import Foundation
import Security
import SwiftUI

// MARK: - API Configuration
enum APIConfig {
    private static let defaultAPIBaseURL = "https://boutique-api-one.vercel.app/api"
    private static let defaultContentBaseURL = "https://boutique-api-one.vercel.app/v1"
    private static let embeddedBackendOptInKey = "AURELIEN_ENABLE_EMBEDDED_BACKEND"
    private static let debugFallbackAPIBaseURLs = [
        "http://127.0.0.1:3000/api",
        "http://127.0.0.1:3104/api",
        defaultAPIBaseURL,
    ]
    private static var runtimeAPIOriginOverride: URL?

    static var usesEmbeddedStaticBackend: Bool {
        #if DEBUG
        if isRunningAutomatedTests {
            return true
        }

        return configuredBoolean(for: embeddedBackendOptInKey)
        #else
        false
        #endif
    }

    static var isRunningAutomatedTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var apiBaseURL: String {
        resolvedBaseURL(for: "AURELIEN_API_BASE_URL", fallback: defaultAPIBaseURL)
    }

    static var requestBaseURLs: [String] {
        #if DEBUG
        var candidates = debugFallbackAPIBaseURLs
        if let configured = configuredValidBaseURL(for: "AURELIEN_API_BASE_URL") {
            candidates.append(configured)
        }
        return deduplicatedValidatedBaseURLs(candidates)
        #else
        if let configured = configuredValidBaseURL(for: "AURELIEN_API_BASE_URL") {
            return [configured]
        }
        return deduplicatedValidatedBaseURLs([defaultAPIBaseURL])
        #endif
    }

    static var contentBaseURL: String {
        resolvedBaseURL(for: "AURELIEN_STATIC_CONTENT_BASE_URL", fallback: defaultContentBaseURL)
    }

    static var staticProductsURL: URL? {
        URL(string: "\(contentBaseURL)/products.json")
    }

    static var contentOriginURL: URL? {
        guard let baseURL = URL(string: contentBaseURL),
              let scheme = baseURL.scheme,
              let host = baseURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = baseURL.port
        return components.url
    }

    static var apiOriginURL: URL? {
        #if DEBUG
        if let runtimeAPIOriginOverride {
            return runtimeAPIOriginOverride
        }
        #endif

        guard let baseURL = URL(string: apiBaseURL),
              let scheme = baseURL.scheme,
              let host = baseURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = baseURL.port
        return components.url
    }

    static func resolvedRemoteAssetURLString(for rawValue: String) -> String {
        resolvedRemoteAssetURLString(
            for: rawValue,
            usesEmbeddedStaticBackend: usesEmbeddedStaticBackend,
            apiOriginURL: apiOriginURL,
            contentOriginURL: contentOriginURL
        )
    }

    static func resolvedRemoteAssetURLString(
        for rawValue: String,
        usesEmbeddedStaticBackend: Bool,
        apiOriginURL: URL?,
        contentOriginURL: URL?
    ) -> String {
        let normalizedAPIOriginURL = normalizedAssetOriginURL(from: apiOriginURL)
        let normalizedContentOriginURL = normalizedAssetOriginURL(from: contentOriginURL)
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return rawValue }

        if usesEmbeddedStaticBackend {
            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url.path.isEmpty ? url.absoluteString : url.path
            }
            return trimmed
        }

        if let url = URL(string: trimmed),
           url.scheme?.hasPrefix("http") == true {
            if let rebased = rebasedRuntimeAssetURL(from: url, apiOriginURL: normalizedAPIOriginURL) {
                return rebased
            }
            return url.absoluteString
        }

        if trimmed.hasPrefix("/"), let origin = normalizedAPIOriginURL ?? normalizedContentOriginURL {
            return origin.appendingPathComponent(String(trimmed.dropFirst())).absoluteString
        }

        guard let origin = normalizedAPIOriginURL ?? normalizedContentOriginURL else {
            return trimmed
        }

        return origin
            .appendingPathComponent("uploads", isDirectory: true)
            .appendingPathComponent(trimmed)
            .absoluteString
    }

    private static func normalizedAssetOriginURL(from sourceURL: URL?) -> URL? {
        guard let sourceURL,
              let scheme = sourceURL.scheme,
              let host = sourceURL.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = sourceURL.port
        return components.url
    }

    private static func rebasedRuntimeAssetURL(from sourceURL: URL, apiOriginURL: URL?) -> String? {
        guard let apiOriginURL,
              let host = sourceURL.host?.lowercased(),
              (host == "localhost" || host == "127.0.0.1"),
              sourceURL.path.hasPrefix("/") else {
            return nil
        }

        return apiOriginURL
            .appendingPathComponent(String(sourceURL.path.dropFirst()))
            .absoluteString
    }

    static func noteSuccessfulAPIRequestURL(_ url: URL?) {
        #if DEBUG
        guard let url,
              let scheme = url.scheme,
              let host = url.host else {
            return
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port
        runtimeAPIOriginOverride = components.url
        #endif
    }

    static var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    static func validateLaunchConfiguration() {
        #if !DEBUG
        precondition(
            configuredValidBaseURL(for: "AURELIEN_API_BASE_URL") != nil,
            "AURELIEN_API_BASE_URL must be configured with a valid HTTPS URL for production builds."
        )
        precondition(
            configuredValidBaseURL(for: "AURELIEN_STATIC_CONTENT_BASE_URL") != nil,
            "AURELIEN_STATIC_CONTENT_BASE_URL must be configured with a valid HTTPS URL for production builds."
        )
        #endif
    }

    private static func configuredValidBaseURL(for key: String) -> String? {
        guard let rawValue = configuredValue(for: key) else { return nil }
        return validatedBaseURL(normalizedBaseURL(rawValue))
    }

    private static func normalizedBaseURL(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private static func configuredValue(for key: String) -> String? {
        let envValue = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let envValue, envValue.isEmpty == false {
            return envValue
        }

        let plistValue = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistValue,
           plistValue.isEmpty == false,
           plistValue.hasPrefix("$(") == false {
            return plistValue
        }

        return nil
    }

    private static func configuredBoolean(for key: String) -> Bool {
        let value = configuredValue(for: key)?.lowercased()
        switch value {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private static func resolvedBaseURL(for key: String, fallback: String) -> String {
        let fallbackCandidate = normalizedBaseURL(fallback)

        if let configured = configuredValue(for: key),
           let validated = validatedBaseURL(normalizedBaseURL(configured)) {
            return validated
        }

        if let validatedFallback = validatedBaseURL(fallbackCandidate) {
            return validatedFallback
        }

        assertionFailure("Base URL for \(key) must be HTTPS, or local HTTP in Debug.")
        return fallbackCandidate
    }

    private static func validatedBaseURL(_ candidate: String) -> String? {
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              isAllowedScheme(scheme, forHost: url.host),
              url.host?.isEmpty == false else {
            return nil
        }

        return candidate
    }

    private static func deduplicatedValidatedBaseURLs(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        var resolved: [String] = []

        for candidate in candidates.compactMap({ validatedBaseURL(normalizedBaseURL($0)) }) {
            if seen.insert(candidate).inserted {
                resolved.append(candidate)
            }
        }

        return resolved
    }

    private static func isAllowedScheme(_ scheme: String, forHost host: String?) -> Bool {
        if scheme == "https" {
            return true
        }

        #if DEBUG
        guard scheme == "http",
              let host = host?.lowercased() else {
            return false
        }

        return host == "127.0.0.1" || host == "localhost"
        #else
        return false
        #endif
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized(String?)
    case notFound(String?)
    case serverError(String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .httpError(let code, let message): return message ?? "HTTP Error: \(code)"
        case .decodingError: return "Failed to decode data"
        case .networkError(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "Internet connection appears to be offline."
                case .timedOut:
                    return "The request timed out. Please try again."
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    return "The server is unavailable right now. Please try again shortly."
                default:
                    return urlError.localizedDescription
                }
            }
            return "Network error"
        case .unauthorized(let message): return message ?? "Unauthorized"
        case .notFound(let message): return message ?? "This content isn't available right now."
        case .serverError(let message): return message ?? "Server error"
        }
    }
}

extension Notification.Name {
    static let aurelienAuthSessionInvalidated = Notification.Name("aurelien.auth.sessionInvalidated")
}

enum AuthSessionInvalidationUserInfo {
    static let token = "aurelien.auth.invalidatedToken"
}

// MARK: - API Service
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var isLoading = false
    @Published var error: APIError?
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private struct InFlightRequest {
        let token: UUID
        let task: Task<(Data, HTTPURLResponse, URLRequest), Error>
    }

    private var ongoingRequests: [String: InFlightRequest] = [:]
    private var activeRequestCount = 0

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 14
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        config.shouldUseExtendedBackgroundIdleMode = false
        config.urlCache = nil
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = fractional.date(from: value) {
                return date
            }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]

            if let date = plain.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date string: \(value)"
            )
        }
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Advanced Networking
    private func exponentialBackoff(attempt: Int) -> UInt64 {
        let clampedAttempt = min(max(attempt, 0), 6)
        return UInt64(1 << clampedAttempt)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        Logger.debug("APIService: \(message)")
        #endif
    }

    private func normalizedPath(for endpoint: String) -> String {
        let path = endpoint.split(separator: "?", maxSplits: 1).first.map(String.init) ?? endpoint
        return path.hasPrefix("/") ? path : "/\(path)"
    }

    private func allowsSessionInvalidation(for endpoint: String) -> Bool {
        switch normalizedPath(for: endpoint) {
        case "/auth/signin", "/auth/signup", "/auth/logout":
            return false
        default:
            return true
        }
    }

    private func invalidateAuthSessionIfCurrent(requestToken: String?, endpoint: String? = nil) {
        guard let requestToken, !requestToken.isEmpty else {
            debugLog("Ignoring anonymous auth invalidation for \(endpoint ?? "unknown endpoint")")
            return
        }

        if let endpoint, allowsSessionInvalidation(for: endpoint) == false {
            debugLog("Ignoring auth invalidation for non-session endpoint \(endpoint)")
            return
        }

        guard AuthTokenStore.value(for: AuthTokenStore.serviceKey) == requestToken else {
            debugLog("Ignoring stale auth invalidation for \(endpoint ?? "unknown endpoint")")
            return
        }

        AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)
        NotificationCenter.default.post(
            name: .aurelienAuthSessionInvalidated,
            object: nil,
            userInfo: [AuthSessionInvalidationUserInfo.token: requestToken]
        )
    }

    private func beginRequestLifecycle() {
        activeRequestCount += 1
        isLoading = activeRequestCount > 0
    }

    private func endRequestLifecycle() {
        activeRequestCount = max(activeRequestCount - 1, 0)
        isLoading = activeRequestCount > 0
    }

    private func clearInFlightRequest(for endpoint: String, token: UUID) {
        guard let current = ongoingRequests[endpoint], current.token == token else {
            return
        }
        ongoingRequests.removeValue(forKey: endpoint)
    }

    private func requestKey(for endpoint: String, baseURL: String) -> String {
        "\(baseURL)|\(normalizedPath(for: endpoint))"
    }

    private func isLocalDebugRequest(_ request: URLRequest) -> Bool {
        guard let host = request.url?.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost"
    }

    private func shouldFallbackToCachedResponse(for error: APIError) -> Bool {
        switch error {
        case .networkError, .serverError:
            return true
        case let .httpError(statusCode, _):
            return statusCode >= 500
        default:
            return false
        }
    }

    private func shouldTryNextBaseURL(after error: APIError) -> Bool {
        switch error {
        case .networkError, .notFound, .serverError:
            return true
        case let .httpError(code, _):
            return code == 404 || code >= 500
        default:
            return false
        }
    }

    // MARK: - Request Deduplication & Cancellation
    func cancelRequest(for endpoint: String) {
        let normalizedEndpoint = normalizedPath(for: endpoint)
        let keys = ongoingRequests.keys.filter { $0.hasSuffix("|\(normalizedEndpoint)") }
        for key in keys {
            ongoingRequests[key]?.task.cancel()
            ongoingRequests.removeValue(forKey: key)
        }
    }

    func cancelAllRequests() {
        ongoingRequests.values.forEach { $0.task.cancel() }
        ongoingRequests.removeAll()
    }

    // MARK: - Retry Logic
    func performRequestWithRetry(_ endpoint: String, method: String = "GET", body: Data? = nil, maxAttempts: Int = 3) async throws -> Data {
        var attempt = 0
        var lastError: Error?
        while attempt < maxAttempts {
            do {
                debugLog("Request [\(method)] \(endpoint), attempt \(attempt+1)")
                let data = try await performRequest(endpoint, method: method, body: body)
                return data
            } catch {
                if error is CancellationError {
                    throw error
                }
                if let apiError = error as? APIError {
                    switch apiError {
                    case .unauthorized, .notFound:
                        throw apiError
                    case let .httpError(code, _) where (400...499).contains(code):
                        throw apiError
                    default:
                        break
                    }
                }
                lastError = error
                let delay = exponentialBackoff(attempt: attempt)
                debugLog("Retrying in \(delay)s due to error: \(error)")
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                attempt += 1
            }
        }
        throw lastError ?? APIError.networkError(NSError(domain: "Unknown", code: -1))
    }
    
    // ROOT CAUSE #3: Check if error should trigger a retry
    private func shouldRetryRequest(_ error: APIError, attempt: Int, maxAttempts: Int) -> Bool {
        if attempt >= maxAttempts - 1 { return false }
        
        switch error {
        case .networkError:
            return true
        case let .httpError(code, _):
            // Retry on 5xx and some client errors
            return code >= 500 || code == 408 || code == 429
        case .serverError, .unauthorized:
            return true
        default:
            return false
        }
    }
    
    private func shouldRetryNetworkError(_ error: Error, attempt: Int, maxAttempts: Int) -> Bool {
        if attempt >= maxAttempts - 1 { return false }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            case .cancelled:
                return false
            default:
                return false
            }
        }
        
        return false
    }
    
    // ROOT CAUSE #4: Silent token refresh on 401
    @MainActor
    private func refreshAuthToken(for requestToken: String?) async -> Bool {
        guard let requestToken, !requestToken.isEmpty else {
            return false
        }

        guard AuthTokenStore.value(for: AuthTokenStore.serviceKey) == requestToken else {
            debugLog("Skipping refresh for stale auth token")
            return false
        }

        do {
            debugLog("Attempting to refresh auth token")
            // Try to refresh using refresh endpoint if available
            let refreshData = try await performRequest("/auth/refresh", method: "POST", allowAuthRefresh: false)
            if let response = try? decoder.decode(AuthRefreshResponse.self, from: refreshData) {
                AuthTokenStore.save(response.token, for: AuthTokenStore.serviceKey)
                debugLog("Token refreshed successfully")
                return true
            }
        } catch {
            debugLog("Token refresh failed: \(error)")
        }
        invalidateAuthSessionIfCurrent(requestToken: requestToken)
        return false
    }

    private func makeURLRequest(
        _ endpoint: String,
        baseURL: String = APIConfig.apiBaseURL,
        method: String = "GET",
        body: Data? = nil,
        authorizationToken: String? = AuthTokenStore.value(for: AuthTokenStore.serviceKey)
    ) throws -> URLRequest {
        let normalizedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"

        guard let url = URL(string: baseURL + normalizedEndpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method
        request.timeoutInterval = method.uppercased() == "GET" ? 10 : 15
        var headers = APIConfig.headers
        if let token = authorizationToken, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        return request
    }

    private func performRequest(_ endpoint: String, method: String = "GET", body: Data? = nil, allowAuthRefresh: Bool = true) async throws -> Data {
        if APIConfig.usesEmbeddedStaticBackend {
            beginRequestLifecycle()
            defer { endRequestLifecycle() }

            let requestAuthToken = AuthTokenStore.value(for: AuthTokenStore.serviceKey)
            do {
                let data = try await EmbeddedStaticBackend.shared.performRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    token: requestAuthToken
                )
                self.error = nil
                return data
            } catch let error as APIError {
                if allowAuthRefresh,
                   allowsSessionInvalidation(for: endpoint),
                   case .unauthorized = error,
                   await refreshAuthToken(for: requestAuthToken) {
                    return try await performRequest(endpoint, method: method, body: body, allowAuthRefresh: false)
                }
                if case .unauthorized = error {
                    invalidateAuthSessionIfCurrent(
                        requestToken: requestAuthToken,
                        endpoint: endpoint
                    )
                }
                self.error = error
                throw error
            } catch {
                let apiError = APIError.networkError(error)
                self.error = apiError
                throw apiError
            }
        }

        var lastError: APIError?
        let requestAuthToken = AuthTokenStore.value(for: AuthTokenStore.serviceKey)
        for baseURL in APIConfig.requestBaseURLs {
            let request = try makeURLRequest(
                endpoint,
                baseURL: baseURL,
                method: method,
                body: body,
                authorizationToken: requestAuthToken
            )

            do {
                return try await executeRemoteRequest(
                    request,
                    endpoint: endpoint,
                    requestAuthToken: requestAuthToken,
                    allowAuthRefresh: allowAuthRefresh
                )
            } catch let error as APIError {
                lastError = error
                let shouldTryFallback = APIConfig.requestBaseURLs.count > 1 && shouldTryNextBaseURL(after: error) && baseURL != APIConfig.requestBaseURLs.last
                if shouldTryFallback {
                    debugLog("Retrying \(endpoint) against fallback API base after \(error)")
                    continue
                }
                self.error = error
                throw error
            }
        }

        let fallbackError = lastError ?? APIError.invalidResponse
        self.error = fallbackError
        throw fallbackError
    }

    private func executeRemoteRequest(
        _ request: URLRequest,
        endpoint: String,
        requestAuthToken: String?,
        allowAuthRefresh: Bool
    ) async throws -> Data {
        let normalizedMethod = request.httpMethod?.uppercased() ?? "GET"
        let isGetRequest = normalizedMethod == "GET"
        let maxAttempts = isGetRequest ? 3 : 1
        let requestKey = requestKey(for: endpoint, baseURL: request.url?.deletingLastPathComponent().absoluteString ?? APIConfig.apiBaseURL)

        if NetworkMonitor.shared.isConnected == false && isLocalDebugRequest(request) == false {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }

        if isGetRequest, let inFlight = ongoingRequests[requestKey] {
            debugLog("Deduping GET for request \(requestKey)")
            return try await inFlight.task.value.0
        }

        if !isGetRequest, let inFlight = ongoingRequests[requestKey] {
            inFlight.task.cancel()
            ongoingRequests.removeValue(forKey: requestKey)
        }

        beginRequestLifecycle()
        let requestToken = UUID()
        let task = Task { [session, decoder] in
            var lastError: Error?
            var attempt = 0

            while attempt < maxAttempts {
                do {
                    debugLog("Request [\(normalizedMethod)] \(request.url?.absoluteString ?? endpoint) attempt \(attempt+1)/\(maxAttempts)")
                    let timeoutNanoseconds = UInt64((max(request.timeoutInterval + 2, 10) * 1_000_000_000).rounded())
                    let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group -> (Data, URLResponse) in
                        group.addTask { try await session.data(for: request) }
                        group.addTask {
                            try await Task.sleep(nanoseconds: timeoutNanoseconds)
                            throw APIError.networkError(URLError(.timedOut))
                        }
                        guard let result = try await group.next() else {
                            throw APIError.networkError(NSError(domain: "Unknown", code: -1))
                        }
                        group.cancelAll()
                        return result
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }

                    debugLog("Response [\(httpResponse.statusCode)] \(request.url?.absoluteString ?? endpoint)")

                    if (200...299).contains(httpResponse.statusCode) {
                        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
                           contentType.contains("application/json") == false,
                           let bodyPreview = String(data: data.prefix(500), encoding: .utf8),
                           bodyPreview.contains("<html") || bodyPreview.contains("<!doctype") {
                            debugLog("Non-JSON response for \(endpoint): contentType=\(contentType), preview=\(bodyPreview.prefix(200))")
                            throw APIError.decodingError(
                                DecodingError.dataCorrupted(
                                    .init(codingPath: [], debugDescription: "Expected JSON but got HTML.")
                                )
                            )
                        }
                        return (data, httpResponse, request)
                    }

                    let payload = try? decoder.decode(APIErrorPayload.self, from: data)
                    let message = payload?.resolvedMessage

                    let apiError: APIError
                    switch httpResponse.statusCode {
                    case 401:
                        apiError = .unauthorized(message)
                    case 404:
                        apiError = .notFound(message)
                    case 500...599:
                        apiError = .serverError(message)
                    default:
                        apiError = .httpError(httpResponse.statusCode, message)
                    }

                    lastError = apiError
                    throw apiError
                } catch let error as APIError {
                    lastError = error
                    if case let .networkError(underlying) = error, underlying is CancellationError {
                        throw underlying
                    }
                    let shouldRetry = isGetRequest && attempt < maxAttempts - 1 && {
                        switch error {
                        case .networkError, .serverError:
                            return true
                        case let .httpError(code, _):
                            return code >= 500 || code == 408 || code == 429
                        default:
                            return false
                        }
                    }()
                    if shouldRetry {
                        let delay = exponentialBackoff(attempt: attempt)
                        debugLog("Retrying in \(delay)s due to error: \(error)")
                        try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                        attempt += 1
                        continue
                    }
                    throw error
                } catch {
                    if error is CancellationError {
                        throw error
                    }

                    let apiError = APIError.networkError(error)
                    lastError = apiError
                    let shouldRetry = isGetRequest && attempt < maxAttempts - 1 && {
                        guard let urlError = error as? URLError else { return false }
                        switch urlError.code {
                        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
                            return true
                        default:
                            return false
                        }
                    }()
                    if shouldRetry {
                        let delay = exponentialBackoff(attempt: attempt)
                        debugLog("Retrying network error in \(delay)s: \(error)")
                        try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                        attempt += 1
                        continue
                    }
                    throw apiError
                }
            }

            throw lastError ?? APIError.networkError(NSError(domain: "Unknown", code: -1))
        }
        ongoingRequests[requestKey] = InFlightRequest(token: requestToken, task: task)

        defer {
            endRequestLifecycle()
            clearInFlightRequest(for: requestKey, token: requestToken)
        }

        do {
            let (data, httpResponse, completedRequest) = try await task.value

            if (200...299).contains(httpResponse.statusCode) {
                APIConfig.noteSuccessfulAPIRequestURL(completedRequest.url)
                self.error = nil
                return data
            }

            throw APIError.invalidResponse
        } catch let error as APIError {
            if allowAuthRefresh,
               allowsSessionInvalidation(for: endpoint),
               case .unauthorized = error,
               await refreshAuthToken(for: requestAuthToken) {
                clearInFlightRequest(for: requestKey, token: requestToken)
                return try await executeRemoteRequest(
                    request,
                    endpoint: endpoint,
                    requestAuthToken: AuthTokenStore.value(for: AuthTokenStore.serviceKey),
                    allowAuthRefresh: false
                )
            }
            if case .unauthorized = error {
                invalidateAuthSessionIfCurrent(requestToken: requestAuthToken, endpoint: endpoint)
            }
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Generic Request
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        do {
            let data = try await performRequest(endpoint, method: method, body: body)
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                // ROOT CAUSE #9: Separate decoding errors from network errors
                debugLog("Decoding failed for \(endpoint): \(decodingError)")
                if let dataString = String(data: data, encoding: .utf8) {
                    debugLog("Response body: \(dataString.prefix(500))")
                }
                let apiError = APIError.decodingError(decodingError)
                self.error = apiError
                throw apiError
            }
        } catch let error as APIError {
            self.error = error
            throw error
        } catch {
            let apiError = APIError.networkError(error)
            self.error = apiError
            throw apiError
        }
    }

    private func performRequest(withFallbackEndpoints endpoints: [String], method: String = "GET", body: Data? = nil) async throws -> Data {
        var lastError: Error?

        for endpoint in endpoints {
            do {
                return try await performRequest(endpoint, method: method, body: body)
            } catch let error as APIError {
                lastError = error

                switch error {
                case .notFound:
                    continue
                case let .httpError(code, _):
                    if code == 404 {
                        continue
                    }
                    if code >= 500 {
                        continue
                    }
                    throw error
                case .networkError, .serverError:
                    continue
                default:
                    throw error
                }
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? APIError.notFound("This request could not be completed.")
    }

    private func request<T: Decodable>(withFallbackEndpoints endpoints: [String], method: String = "GET", body: Data? = nil) async throws -> T {
        let data = try await performRequest(withFallbackEndpoints: endpoints, method: method, body: body)
        return try decoder.decode(T.self, from: data)
    }

    private func decodeFailure(_ description: String) -> APIError {
        APIError.decodingError(
            DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: description)
            )
        )
    }

    private func nestedJSONData(from value: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(value) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: value)
    }

    private func decodeArray<T: Decodable>(_ type: T.Type, from data: Data, keys: [String]) throws -> [T] {
        if let direct = try? decoder.decode([T].self, from: data) {
            return direct
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw decodeFailure("Expected array payload for \(T.self).")
        }

        for key in keys {
            guard let value = dictionary[key], let nested = nestedJSONData(from: value) else { continue }
            if let decoded = try? decoder.decode([T].self, from: nested) {
                return decoded
            }
        }

        throw decodeFailure("Unable to decode array payload for \(T.self).")
    }

    private func decodeObject<T: Decodable>(_ type: T.Type, from data: Data, keys: [String]) throws -> T {
        if let direct = try? decoder.decode(T.self, from: data) {
            return direct
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw decodeFailure("Expected object payload for \(T.self).")
        }

        for key in keys {
            guard let value = dictionary[key], let nested = nestedJSONData(from: value) else { continue }
            if let decoded = try? decoder.decode(T.self, from: nested) {
                return decoded
            }
        }

        throw decodeFailure("Unable to decode object payload for \(T.self).")
    }

    private func fetchCachedOrRemoteData(
        cacheKey: String,
        endpoints: [String],
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        _ = cacheKey
        return try await performRequest(withFallbackEndpoints: endpoints, method: method, body: body)
    }

    // MARK: - Discover
    func fetchDiscoverExperience() async throws -> DiscoverExperienceSnapshot {
        async let feedTask = fetchDiscoverFeed()
        async let dropsTask = fetchDiscoverDrops()
        async let styleTask = fetchDiscoverStyleDNA()

        let feed = (try? await feedTask) ?? []
        let drops = (try? await dropsTask) ?? []
        let styleProfile = try? await styleTask

        if feed.isEmpty && drops.isEmpty {
            throw APIError.notFound("No discover content is available right now.")
        }

        return DiscoverExperienceSnapshot(
            feed: feed,
            drops: drops,
            challenges: [],
            leaderboard: [],
            styleProfile: styleProfile
        )
    }

    func fetchDiscoverUserState() async throws -> DiscoverUserState {
        do {
            let data = try await fetchCachedOrRemoteData(
                cacheKey: "discover.user-state",
                endpoints: ["/discover/me", "/discover/state"]
            )

            if let state = try? decoder.decode(DiscoverUserState.self, from: data) {
                return state
            }

            return try decodeObject(DiscoverUserState.self, from: data, keys: ["state", "data"])
        } catch {
            return .empty
        }
    }

    func fetchDiscoverFeed() async throws -> [DiscoverFeedItemData] {
        let data: Data
        do {
            data = try await fetchCachedOrRemoteData(
                cacheKey: "discover.feed",
                endpoints: ["/discover/feed", "/outfits/feed", "/outfits", "/feed"]
            )
        } catch {
            data = try await fetchStaticContentFile("discover.json")
        }

        let rawOutfits = try decodeArray(BackendDiscoverOutfit.self, from: data, keys: ["items", "outfits", "feed", "data"])
        let catalog = (try? await fetchProducts()) ?? []
        let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

        return rawOutfits.compactMap { outfit in
            let inlineProducts = outfit.productReferences.compactMap(\.product).map(\.nativeProduct)
            let referencedProducts = outfit.productReferences
                .compactMap(\.productID)
                .compactMap { catalogByID[$0] }
            let explicitIDProducts = outfit.resolvedProductIDs.compactMap { catalogByID[$0] }
            let products = (inlineProducts + referencedProducts + explicitIDProducts).uniqued(by: \.id)

            guard products.isEmpty == false else {
                return nil
            }

            let fallbackTitle = products.first?.name ?? "Look"
            let fallbackCaption = products.map(\.name).joined(separator: " • ")

            return DiscoverFeedItemData(
                id: outfit.id ?? "discover-feed-\(UUID().uuidString.lowercased())",
                creatorID: outfit.creatorID ?? outfit.creatorName?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "boutique-editorial",
                creatorName: outfit.creatorName ?? "BOUTIQUE Editorial",
                title: outfit.title ?? fallbackTitle,
                caption: outfit.caption ?? outfit.summary ?? fallbackCaption,
                score: max(0, min(100, outfit.score ?? outfit.styleScore ?? 80)),
                products: products
            )
        }
    }

    func fetchDiscoverDrops() async throws -> [DiscoverDropData] {
        let data: Data
        do {
            data = try await fetchCachedOrRemoteData(
                cacheKey: "discover.drops",
                endpoints: ["/discover/drops", "/drops"]
            )
        } catch {
            data = try await fetchStaticContentFile("discover.json")
        }

        let rawDrops = try decodeArray(BackendDiscoverDrop.self, from: data, keys: ["drops", "items", "data"])
        return rawDrops.compactMap { drop in
            let name = drop.name ?? drop.title
            let copy = drop.copy ?? drop.details ?? drop.summary
            guard let name, let copy else { return nil }
            return DiscoverDropData(
                id: drop.id ?? drop.mongoID ?? UUID().uuidString.lowercased(),
                name: name,
                copy: copy,
                stock: max(0, drop.stock ?? drop.inventory ?? 0),
                unlocksAt: drop.unlocksAt ?? drop.startAt ?? drop.endsAt
            )
        }
    }

    func fetchDiscoverCommunity() async throws -> DiscoverCommunityData {
        async let challengesTask = fetchDiscoverChallenges()
        async let leaderboardTask = fetchDiscoverLeaderboard()

        let challenges = (try? await challengesTask) ?? []
        let leaderboard = (try? await leaderboardTask) ?? []
        return DiscoverCommunityData(challenges: challenges, leaderboard: leaderboard)
    }

    private func fetchDiscoverChallenges() async throws -> [DiscoverChallengeData] {
        let data = try await fetchCachedOrRemoteData(
            cacheKey: "discover.challenges",
            endpoints: ["/discover/challenges", "/gamification/challenges"]
        )

        let rawChallenges = try decodeArray(BackendDiscoverChallenge.self, from: data, keys: ["challenges", "items", "data"])
        return rawChallenges.compactMap { challenge in
            guard let title = challenge.title, let prompt = challenge.prompt ?? challenge.description else {
                return nil
            }
            return DiscoverChallengeData(
                id: challenge.id ?? challenge.rawID ?? UUID().uuidString.lowercased(),
                title: title,
                prompt: prompt,
                rewardPoints: max(0, challenge.rewardPoints ?? challenge.points ?? 0)
            )
        }
    }

    private func fetchDiscoverLeaderboard() async throws -> [DiscoverLeaderboardData] {
        let data = try await fetchCachedOrRemoteData(
            cacheKey: "discover.leaderboard",
            endpoints: ["/discover/leaderboard", "/gamification/leaderboard"]
        )

        let rawEntries = try decodeArray(BackendDiscoverLeaderboardEntry.self, from: data, keys: ["leaderboard", "entries", "items", "data"])
        return rawEntries.compactMap { entry in
            let rank = entry.rank ?? entry.position
            let score = entry.score ?? entry.points
            guard let rank, let score else { return nil }
            let name = entry.name ?? entry.username ?? "Member"
            return DiscoverLeaderboardData(
                id: entry.id ?? UUID().uuidString.lowercased(),
                rank: max(1, rank),
                name: name,
                score: max(0, score)
            )
        }
    }

    func fetchDiscoverStyleDNA() async throws -> DiscoverStyleDNAProfile {
        let data: Data
        do {
            data = try await fetchCachedOrRemoteData(
                cacheKey: "discover.styledna",
                endpoints: ["/discover/style-dna", "/profile/style"]
            )
        } catch {
            data = try await fetchStaticContentFile("discover.json")
        }

        let raw = try decodeObject(BackendDiscoverStyleDNA.self, from: data, keys: ["profile", "styleDNA", "defaultStyleDNA", "data"])
        return raw.nativeProfile
    }

    func saveDiscoverStyleDNA(_ profile: DiscoverStyleDNAProfile) async throws -> DiscoverStyleDNAProfile {
        let payload = BackendDiscoverStyleDNARequest(
            style: profile.style,
            palette: profile.palette,
            fit: profile.fit
        )
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/style-dna", "/profile/style"],
            method: "PUT",
            body: body
        )
        let resolved = (try? decodeObject(BackendDiscoverStyleDNA.self, from: data, keys: ["profile", "styleDNA", "data"]).nativeProfile) ?? profile
        return resolved
    }

    func saveDiscoverClosetSelection(productIDs: [String]) async throws {
        let payload = BackendDiscoverClosetSelectionRequest(productIDs: productIDs)
        let data = try encoder.encode(payload)
        _ = try await performRequest(
            withFallbackEndpoints: ["/discover/closet", "/closet"],
            method: "POST",
            body: data
        )
    }

    func fetchDiscoverClosetProductIDs() async throws -> [String] {
        let state = try await fetchDiscoverUserState()
        return state.closetProductIDs
    }

    func updateDiscoverInteraction(kind: DiscoverInteractionKind, targetID: String, isActive: Bool) async throws -> DiscoverUserState {
        let payload = BackendDiscoverInteractionRequest(
            kind: kind.rawValue,
            targetID: targetID,
            isActive: isActive
        )
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/interactions"],
            method: "POST",
            body: body
        )

        if let state = try? decoder.decode(DiscoverUserState.self, from: data) {
            return state
        }

        return try decodeObject(DiscoverUserState.self, from: data, keys: ["state", "data"])
    }

    func sendDiscoverStylistMessage(_ message: String, contextProductIDs: [String]) async throws -> String {
        let request = BackendDiscoverStylistRequest(message: message, productIDs: contextProductIDs)
        let body = try encoder.encode(request)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/ai-stylist", "/ai/stylist"],
            method: "POST",
            body: body
        )
        if let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
           raw.isEmpty == false,
           raw.first != "{" && raw.first != "[" {
            return raw
        }
        let response = try decodeObject(BackendDiscoverStylistResponse.self, from: data, keys: ["data", "result"])
        return response.reply ?? response.message ?? "No stylist response was returned."
    }

    func fetchDiscoverSnapMatches(mood: String, limit: Int = 6) async throws -> [Product] {
        let request = BackendDiscoverSnapMatchRequest(mood: mood, limit: max(1, min(limit, 20)))
        let body = try encoder.encode(request)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/snap-match", "/discover/match"],
            method: "POST",
            body: body
        )

        let catalog = (try? await fetchProducts()) ?? []
        let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

        if let backendProducts = try? decodeArray(BackendProduct.self, from: data, keys: ["products", "matches", "items", "data"]) {
            let mapped = backendProducts.map(\.nativeProduct)
            if mapped.isEmpty == false {
                return mapped
            }
        }

        if let ids = try? decodeArray(String.self, from: data, keys: ["productIDs", "productIds", "ids"]) {
            let resolved = ids.compactMap { catalogByID[$0] }
            if resolved.isEmpty == false {
                return resolved
            }
        }

        let matches = try decodeArray(BackendDiscoverProductMatch.self, from: data, keys: ["matches", "items", "data"])
        let inlineProducts = matches.compactMap(\.product).map(\.nativeProduct)
        let referencedProducts = matches.compactMap(\.resolvedProductID).compactMap { catalogByID[$0] }
        return (inlineProducts + referencedProducts).uniqued(by: \.id)
    }

    func submitTryBeforeBuySelection(productIDs: [String]) async throws -> DiscoverReservationReceipt {
        let request = BackendTryBeforeBuyRequest(productIDs: productIDs)
        let body = try encoder.encode(request)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/try-before-buy/reserve", "/trybeforebuy/request"],
            method: "POST",
            body: body
        )

        if let receipt = try? decoder.decode(DiscoverReservationReceipt.self, from: data) {
            return receipt
        }

        return try decodeObject(DiscoverReservationReceipt.self, from: data, keys: ["reservation", "request", "data"])
    }

    func fetchDiscoverSubscriptionPlans() async throws -> [DiscoverSubscriptionPlan] {
        let data: Data
        do {
            data = try await fetchCachedOrRemoteData(
                cacheKey: "discover.subscription.plans",
                endpoints: ["/discover/subscription/plans", "/subscription/box/plans", "/subscription/plans"]
            )
        } catch {
            data = try await fetchStaticContentFile("discover.json")
        }
        let rawPlans = try decodeArray(BackendDiscoverSubscriptionPlan.self, from: data, keys: ["plans", "items", "data"])
        return rawPlans.map(\.nativePlan)
    }

    func subscribeToDiscoverPlan(planID: String) async throws -> DiscoverSubscriptionStatus {
        let payload = BackendDiscoverSubscribeRequest(planID: planID)
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/subscription/subscribe", "/subscription/box"],
            method: "POST",
            body: body
        )

        if let status = try? decoder.decode(DiscoverSubscriptionStatus.self, from: data) {
            return status
        }

        return try decodeObject(DiscoverSubscriptionStatus.self, from: data, keys: ["subscription", "status", "data"])
    }

    func estimateDiscoverBoostReach(budget: Double, days: Int) async throws -> Int {
        let payload = BackendDiscoverBoostEstimateRequest(budget: budget, days: days)
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/seller-boost/estimate", "/product/boost/estimate"],
            method: "POST",
            body: body
        )
        let estimate = try decodeObject(BackendDiscoverBoostEstimateResponse.self, from: data, keys: ["data", "estimate", "result"])
        return max(0, estimate.estimatedReach ?? estimate.reach ?? 0)
    }

    func activateDiscoverSellerBoost(budget: Double, days: Int) async throws -> DiscoverBoostActivation {
        let payload = BackendDiscoverBoostEstimateRequest(budget: budget, days: days)
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/seller-boost/activate", "/product/boost"],
            method: "POST",
            body: body
        )

        if let activation = try? decoder.decode(DiscoverBoostActivation.self, from: data) {
            return activation
        }

        return try decodeObject(DiscoverBoostActivation.self, from: data, keys: ["boost", "campaign", "data"])
    }

    func joinDiscoverDropWaitlist(dropID: String) async throws -> DiscoverDropWaitlistReceipt {
        let safeDropID = dropID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? dropID
        let payload = BackendDiscoverDropWaitlistRequest(dropID: dropID)
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/drops/\(safeDropID)/waitlist", "/drops/\(safeDropID)/waitlist"],
            method: "POST",
            body: body
        )

        if let receipt = try? decoder.decode(DiscoverDropWaitlistReceipt.self, from: data) {
            return receipt
        }

        return DiscoverDropWaitlistReceipt(success: true, dropID: dropID, waitlistCount: 1)
    }

    func submitDiscoverChallengeVote(challengeID: String) async throws -> DiscoverVoteOutcome {
        let payload = BackendDiscoverVoteRequest(challengeID: challengeID)
        let body = try encoder.encode(payload)
        let data = try await performRequest(
            withFallbackEndpoints: ["/discover/challenges/vote", "/gamification/vote"],
            method: "POST",
            body: body
        )
        let response = try? decodeObject(BackendDiscoverVoteResponse.self, from: data, keys: ["data", "result"])
        return DiscoverVoteOutcome(
            pointsAwarded: max(0, response?.pointsAwarded ?? response?.points ?? 0),
            totalPoints: response?.totalPoints
        )
    }
    
    // MARK: - Profile
    func fetchClientProfile(userId: String? = nil) async throws -> ClientProfile {
        _ = userId
        let data = try await performRequest("/profile")

        if let payload = try? decodeObject(BackendClientProfile.self, from: data, keys: ["profile", "user", "account", "data"]) {
            return payload.nativeProfile
        }

        if let user = try? decoder.decode(User.self, from: data) {
            return ClientProfile(
                name: user.name,
                email: user.email,
                tier: user.isAdmin ? "Administrator" : "Member",
                city: "Cairo",
                note: "Manage your account preferences and order activity."
            )
        }

        throw decodeFailure("Unable to decode client profile payload.")
    }

    func updateClientProfile(_ profile: ClientProfile) async throws -> ClientProfile {
        let payload = BackendClientProfileRequest(
            name: profile.name,
            email: profile.email,
            tier: profile.tier,
            city: profile.city,
            note: profile.note
        )
        let body = try encoder.encode(payload)
        let data = try await performRequest("/profile", method: "PATCH", body: body)
        if let resolved = try? decodeObject(BackendClientProfile.self, from: data, keys: ["profile", "user", "account", "data"]).nativeProfile {
            return resolved
        }
        return profile
    }

    func fetchWalletSnapshot() async throws -> WalletSnapshot {
        let data = try await performRequest("/wallet")
        if let snapshot = try? decoder.decode(WalletSnapshot.self, from: data) {
            return snapshot
        }
        return try decodeObject(WalletSnapshot.self, from: data, keys: ["wallet", "data"])
    }

    func createSavedAddress(_ address: SavedAddress) async throws -> [SavedAddress] {
        let body = try encoder.encode(address)
        let data = try await performRequest("/wallet/addresses", method: "POST", body: body)
        return try decodeArray(SavedAddress.self, from: data, keys: ["savedAddresses", "data"])
    }

    func setPrimarySavedAddress(id: String) async throws -> [SavedAddress] {
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try await performRequest("/wallet/addresses/\(safeID)/primary", method: "PATCH", body: nil)
        return try decodeArray(SavedAddress.self, from: data, keys: ["savedAddresses", "data"])
    }

    func deleteSavedAddress(id: String) async throws -> [SavedAddress] {
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try await performRequest("/wallet/addresses/\(safeID)", method: "DELETE", body: nil)
        return try decodeArray(SavedAddress.self, from: data, keys: ["savedAddresses", "data"])
    }

    func fetchNotifications() async throws -> [ClientNotification] {
        let data = try await performRequest("/notifications")
        if let notifications = try? decoder.decode([ClientNotification].self, from: data) {
            return notifications
        }
        return try decodeArray(ClientNotification.self, from: data, keys: ["notifications", "items", "data"])
    }

    func markNotificationRead(id: String) async throws {
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await performRequest("/notifications/\(safeID)/read", method: "PATCH", body: nil)
    }

    func markAllNotificationsRead() async throws {
        _ = try await performRequest("/notifications/read-all", method: "POST", body: nil)
    }

    func deleteNotification(id: String) async throws {
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await performRequest("/notifications/\(safeID)", method: "DELETE", body: nil)
    }

    func fetchSavedProducts(userId: String? = nil) async throws -> [Product] {
        _ = userId
        let data = try await performRequest("/saved/me")
        return try decodeProductsPayload(from: data)
    }

    func saveProduct(productId: String, userId: String? = nil) async throws -> [Product] {
        _ = userId
        let payload = SavedProductRequest(productId: productId)
        let body = try encoder.encode(payload)
        let data = try await performRequest("/saved/me", method: "POST", body: body)
        return try decodeProductsPayload(from: data)
    }

    func removeSavedProduct(productId: String, userId: String? = nil) async throws -> [Product] {
        _ = userId
        let payload = SavedProductRequest(productId: productId)
        let body = try encoder.encode(payload)
        let data = try await performRequest("/saved/me", method: "DELETE", body: body)
        return try decodeProductsPayload(from: data)
    }

    // MARK: - Products
    func fetchProducts() async throws -> [Product] {
        do {
            let data = try await performRequest("/products")
            let products = try decodeProductsPayload(from: data)
            if products.isEmpty == false {
                return products
            }
        } catch {
            debugLog("Falling back to static products after /products failed: \(error)")
        }

        let staticData = try await fetchStaticContentFile("products.json")
        let products = try decodeProductsPayload(from: staticData)
        guard products.isEmpty == false else {
            throw APIError.notFound("No products are available right now.")
        }
        return products
    }
    
    func fetchProduct(id: String) async throws -> Product {
        let data = try await performRequest("/products/\(id)")
        if let product = try? decoder.decode(Product.self, from: data) {
            return product
        }
        if let product = try? decoder.decode(BackendProduct.self, from: data) {
            return product.nativeProduct
        }

        if let product = try? decodeObject(Product.self, from: data, keys: ["product", "data"]) {
            return product
        }

        let product = try decodeObject(BackendProduct.self, from: data, keys: ["product", "data"])
        return product.nativeProduct
    }
    
    func createProduct(_ product: Product) async throws -> Product {
        let body = try encoder.encode(product)
        let data = try await performRequest("/products", method: "POST", body: body)

        if let created = try? decoder.decode(Product.self, from: data) {
            return created
        }

        if let created = try? decodeObject(Product.self, from: data, keys: ["product", "data"]) {
            return created
        }

        if let backendProduct = try? decoder.decode(BackendProduct.self, from: data) {
            return backendProduct.nativeProduct
        }

        return try decodeObject(BackendProduct.self, from: data, keys: ["product", "data"]).nativeProduct
    }

    func uploadProductImage(data: Data, fileName: String) async throws -> String {
        if APIConfig.usesEmbeddedStaticBackend {
            throw APIError.httpError(400, "Remote image upload is only available when AURELIEN_API_BASE_URL is configured.")
        }

        beginRequestLifecycle()
        defer { endRequestLifecycle() }

        let boundary = "AurelienBoundary-\(UUID().uuidString)"
        var request = try makeURLRequest("/uploads/product-image", method: "POST")
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartImageBody(data: data, fileName: fileName, boundary: boundary)

        do {
            let (responseData, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let payload = try? decoder.decode(APIErrorPayload.self, from: responseData)
                let message = payload?.resolvedMessage
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.unauthorized(message)
                case 404:
                    throw APIError.notFound(message)
                case 500...599:
                    throw APIError.serverError(message)
                default:
                    throw APIError.httpError(httpResponse.statusCode, message)
                }
            }

            let upload = try decoder.decode(ProductImageUploadResponse.self, from: responseData)
            self.error = nil
            return upload.url
        } catch let error as APIError {
            self.error = error
            throw error
        } catch {
            let apiError = APIError.networkError(error)
            self.error = apiError
            throw apiError
        }
    }

    private func multipartImageBody(data: Data, fileName: String, boundary: String) -> Data {
        var body = Data()
        let safeFileName = fileName.replacingOccurrences(of: "\"", with: "")
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n")
        body.appendUTF8("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        return body
    }
    
    func updateProduct(_ product: Product) async throws -> Product {
        let body = try encoder.encode(product)
        let data = try await performRequest("/products/\(product.id)", method: "PUT", body: body)

        if let updated = try? decoder.decode(Product.self, from: data) {
            return updated
        }

        if let updated = try? decodeObject(Product.self, from: data, keys: ["product", "data"]) {
            return updated
        }

        if let backendProduct = try? decoder.decode(BackendProduct.self, from: data) {
            return backendProduct.nativeProduct
        }

        return try decodeObject(BackendProduct.self, from: data, keys: ["product", "data"]).nativeProduct
    }
    
    func deleteProduct(id: String) async throws {
        _ = try await performRequest("/products/\(id)", method: "DELETE")
    }
    
    // MARK: - Users
    func fetchUsers() async throws -> [User] {
        let data = try await performRequest("/admin/users")
        if let users = try? decoder.decode([BackendAdminUser].self, from: data) {
            return users.map(\.nativeUser)
        }
        let users = try decodeArray(BackendAdminUser.self, from: data, keys: ["users", "customers", "items", "data"])
        return users.map(\.nativeUser)
    }
    
    func fetchUser(id: String) async throws -> User {
        return try await request("/users/\(id)")
    }
    
    func createUser(_ user: User) async throws -> User {
        let data = try encoder.encode(user)
        return try await request("/users", method: "POST", body: data)
    }
    
    func updateUser(_ user: User) async throws -> User {
        let data = try encoder.encode(user)
        return try await request("/users/\(user.id)", method: "PUT", body: data)
    }
    
    func deleteUser(id: String) async throws {
        let _: EmptyResponse = try await request("/users/\(id)", method: "DELETE")
    }

    func deleteCurrentUser() async throws {
        let _: EmptyResponse = try await request("/account/delete", method: "POST")
    }
    
    // MARK: - Orders
    func fetchOrders() async throws -> [Order] {
        let data = try await performRequest("/admin/orders")
        if let response = try? decoder.decode(BackendAdminOrdersResponse.self, from: data) {
            return response.orders.map(\.nativeOrder)
        }
        let orders = try decodeArray(BackendOrder.self, from: data, keys: ["orders", "items", "data"])
        return orders.map(\.nativeOrder)
    }
    
    func fetchOrder(id: String) async throws -> Order {
        return try await request("/orders/\(id)")
    }
    
    func fetchUserOrders(userId: String) async throws -> [Order] {
        _ = userId
        let data = try await performRequest("/orders")
        if let response = try? decoder.decode(BackendOrdersEnvelope.self, from: data) {
            return response.orders.map(\.nativeOrder)
        }
        let orders = try decodeArray(BackendOrder.self, from: data, keys: ["orders", "items", "data"])
        return orders.map(\.nativeOrder)
    }
    
    func createOrder(
        _ order: Order,
        deliveryLocation: String? = nil,
        codFee: Double = 0,
        paymentMethodID: String? = nil,
        promoCode: String? = nil,
        userId: String? = nil
    ) async throws -> Order {
        _ = userId
        let payload = BackendCreateOrderRequest(
            order: order,
            deliveryLocation: deliveryLocation ?? order.shippingCity,
            codFee: codFee,
            paymentMethodID: paymentMethodID,
            promoCode: promoCode
        )
        let data = try encoder.encode(payload)
        let responseData = try await performRequest("/orders", method: "POST", body: data)

        if let response = try? decoder.decode(BackendOrdersEnvelope.self, from: responseData),
           let first = response.orders.first {
            return first.nativeOrder
        }

        if let singleOrder = try? decodeObject(BackendOrder.self, from: responseData, keys: ["order", "data"]) {
            return singleOrder.nativeOrder
        }

        throw APIError.notFound("Order response was empty.")
    }
    
    func updateOrderStatus(id: String, status: OrderStatus) async throws -> Order {
        let update = OrderStatusUpdate(status: status)
        let data = try encoder.encode(update)
        let responseData = try await performRequest("/orders/\(id)", method: "PUT", body: data)

        if let order = try? decoder.decode(BackendOrder.self, from: responseData) {
            return order.nativeOrder
        }

        if let order = try? decodeObject(BackendOrder.self, from: responseData, keys: ["order", "data"]) {
            return order.nativeOrder
        }

        throw APIError.notFound("Order response was empty.")
    }
    
    func deleteOrder(id: String) async throws {
        let _: EmptyResponse = try await request("/orders/\(id)", method: "DELETE")
    }
    
    // MARK: - Authentication
    func login(email: String, password: String) async throws -> AuthResponse {
        let credentials = LoginCredentials(email: email, password: password)
        let data = try encoder.encode(credentials)
        let response: AuthResponse = try await request("/auth/signin", method: "POST", body: data)
        if let token = response.token, !token.isEmpty {
            AuthTokenStore.save(token, for: AuthTokenStore.serviceKey)
        }
        return response
    }
    
    func signup(name: String, email: String, password: String, confirmPassword: String, phone: String? = nil) async throws -> AuthResponse {
        let credentials = SignupCredentials(
            name: name,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            phone: phone
        )
        let data = try encoder.encode(credentials)
        let response: AuthResponse = try await request("/auth/signup", method: "POST", body: data)
        if let token = response.token, !token.isEmpty {
            AuthTokenStore.save(token, for: AuthTokenStore.serviceKey)
        }
        return response
    }
    
    func logout() async throws {
        do {
            _ = try await performRequest("/auth/logout", method: "POST")
        } catch {
            AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)
            throw error
        }
        AuthTokenStore.deleteValue(for: AuthTokenStore.serviceKey)
    }

    func validateCOD(governorate: EgyptGovernorate) async throws -> (eligible: Bool, codFee: Double) {
        let payload = ["governorate": governorate.rawValue]
        let data = try encoder.encode(payload)

        let response: CODValidationResponse = try await request("/orders/validate-cod", method: "POST", body: data)
        return (eligible: response.eligible, codFee: response.codFee)
    }

    func validatePromo(code: String) async throws -> PromoValidationResult {
        let payload = PromoValidationRequest(code: code)
        let data = try encoder.encode(payload)

        return try await request("/orders/validate-promo", method: "POST", body: data)
    }

    // MARK: - Cart
    func fetchCart(userId: String) async throws -> Cart {
        _ = userId
        let data = try await performRequest("/cart")
        if let response = try? decoder.decode(BackendCartResponse.self, from: data) {
            return response.nativeCart
        }
        let response = try decodeObject(BackendCartResponse.self, from: data, keys: ["cart", "data"])
        return response.nativeCart
    }
    
    func addToCart(userId: String, productId: String, size: String?, color: String?, quantity: Int) async throws -> Cart {
        let item = CartItem(productId: productId, size: size, color: color, quantity: quantity)
        let data = try encoder.encode(item)
        _ = try await performRequest("/cart/items", method: "POST", body: data)
        return try await fetchCart(userId: userId)
    }

    func updateCartItem(userId: String, productId: String, size: String?, color: String?, quantity: Int) async throws -> Cart {
        let item = CartItem(productId: productId, size: size, color: color, quantity: quantity)
        let data = try encoder.encode(item)
        _ = try await performRequest("/cart/items", method: "PATCH", body: data)
        return try await fetchCart(userId: userId)
    }
    
    func removeFromCart(userId: String, productId: String, size: String?, color: String?) async throws -> Cart {
        let payload = BackendRemoveCartItemRequest(productId: productId, size: size, color: color)
        let data = try encoder.encode(payload)
        _ = try await performRequest("/cart/items", method: "DELETE", body: data)
        return try await fetchCart(userId: userId)
    }
    
    func clearCart(userId: String) async throws -> Cart {
        _ = try await performRequest("/cart", method: "DELETE", body: nil)
        return try await fetchCart(userId: userId)
    }
    
    // MARK: - Analytics
    func fetchAnalytics() async throws -> AnalyticsData {
        let data = try await performRequest("/admin/analytics")
        if let analytics = try? decoder.decode(BackendAnalyticsResponse.self, from: data) {
            return analytics.nativeAnalytics
        }
        let analytics = try decodeObject(BackendAnalyticsResponse.self, from: data, keys: ["analytics", "data"])
        return analytics.nativeAnalytics
    }
    
    func fetchDashboardStats() async throws -> DashboardStats {
        let data = try await performRequest("/admin/analytics")
        if let analytics = try? decoder.decode(BackendAnalyticsResponse.self, from: data) {
            return analytics.nativeDashboardStats
        }
        let analytics = try decodeObject(BackendAnalyticsResponse.self, from: data, keys: ["analytics", "data"])
        return analytics.nativeDashboardStats
    }
}

// MARK: - Supporting Types
struct EmptyResponse: Codable {}

extension APIService {
    func fetchCollections() async throws -> [CollectionFeature] {
        let products = try await fetchProducts()
        let groupedCounts = Dictionary(grouping: products.filter { $0.isValid && !$0.isExcluded }, by: \.category)
            .mapValues(\.count)

        return groupedCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.title < rhs.key.title
                }
                return lhs.value > rhs.value
            }
            .prefix(6)
            .map { category, count in
                CollectionFeature(
                    id: "collection-\(category.rawValue)",
                    title: category.title,
                    subtitle: count == 1 ? "1 live piece ready to shop." : "\(count) live pieces ready to shop.",
                    imageName: APIConfig.resolvedRemoteAssetURLString(for: category.heroImageName),
                    category: category
                )
            }
    }

    func fetchHomeContent() async throws -> CatalogHomeContent {
        let products = try await fetchProducts()
        let liveProducts = products.filter { $0.isValid && !$0.isExcluded }
        let featured = liveProducts
            .sorted { lhs, rhs in
                if lhs.featured == rhs.featured {
                    return lhs.price > rhs.price
                }
                return lhs.featured && !rhs.featured
            }
            .prefix(3)

        let heroStories = featured.enumerated().map { index, product in
            CatalogHomeHero(
                id: "hero-\(product.id)",
                eyebrow: index == 0 ? "Editorial Pick" : "Live Catalog",
                title: product.name,
                subtitle: product.category.title,
                detail: product.summary,
                imageName: APIConfig.resolvedRemoteAssetURLString(for: product.heroImageName),
                buttonTitle: "Shop Now"
            )
        }

        let promotions = [
            CatalogHomePromotion(
                id: "promo-catalog",
                title: "\(liveProducts.count) live products",
                subtitle: "Shop the same catalog now powering the storefront and the iOS app."
            ),
            CatalogHomePromotion(
                id: "promo-delivery",
                title: "Fast Cairo dispatch",
                subtitle: "Checkout shows live delivery and payment availability before order placement."
            ),
        ]

        return CatalogHomeContent(heroStories: heroStories, promotions: promotions)
    }

    func fetchSupportContent() async throws -> SupportContentPayload {
        do {
            async let channelsData = performRequest("/support/channels")
            async let faqsData = performRequest("/support/faqs")
            let (channels, faqs) = try await (
                decoder.decode([SupportChannel].self, from: channelsData),
                decoder.decode([FAQItem].self, from: faqsData)
            )
            return SupportContentPayload(channels: channels, faqs: faqs)
        } catch {
            let data = try await fetchStaticContentFile("support.json")
            return try decoder.decode(SupportContentPayload.self, from: data)
        }
    }

    func fetchLegalDocuments() async throws -> [LegalDocument] {
        do {
            let data = try await performRequest("/legal/documents")
            return try decoder.decode([LegalDocument].self, from: data)
        } catch {
            let data = try await fetchStaticContentFile("legal.json")
            return try decoder.decode(LegalContentPayload.self, from: data).documents
        }
    }

    func decodeProductsPayload(from data: Data) throws -> [Product] {
        if let products = try? decoder.decode([Product].self, from: data) {
            return products
        }

        if let products = try? decodeArray(Product.self, from: data, keys: ["products", "items", "data"]) {
            return products
        }

        let products: [BackendProduct]

        if let decoded = try? decoder.decode([BackendProduct].self, from: data) {
            products = decoded
        } else {
            products = try decodeArray(BackendProduct.self, from: data, keys: ["products", "items", "data"])
        }

        return products.map(\.nativeProduct)
    }

    func fetchStaticContentFile(_ fileName: String) async throws -> Data {
        if APIConfig.usesEmbeddedStaticBackend {
            return try await EmbeddedStaticBackend.shared.bundledContentFile(named: fileName)
        }

        guard let url = URL(string: "\(APIConfig.contentBaseURL)/\(fileName)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return data
    }
}

private struct CODValidationResponse: Codable {
    let eligible: Bool
    let codFee: Double
}

struct LoginCredentials: Codable {
    let email: String
    let password: String
}

struct SignupCredentials: Codable {
    let name: String
    let email: String
    let password: String
    let confirmPassword: String
    let phone: String?
}

private struct SavedProductRequest: Codable {
    let productId: String
}

struct WalletSnapshot: Codable {
    let savedAddresses: [SavedAddress]
    let paymentMethods: [StoredPaymentMethod]
}

struct AuthResponse: Codable {
    let user: User
    let token: String?
}

struct PromoValidationRequest: Codable {
    let code: String
}

struct PromoValidationResult: Codable {
    let isValid: Bool
    let discount: Double
    let message: String?

    enum CodingKeys: String, CodingKey {
        case isValid
        case valid
        case success
        case discount
        case amount
        case message
        case error
    }

    init(isValid: Bool, discount: Double, message: String?) {
        self.isValid = isValid
        self.discount = discount
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isValid =
            try container.decodeIfPresent(Bool.self, forKey: .isValid)
            ?? container.decodeIfPresent(Bool.self, forKey: .valid)
            ?? container.decodeIfPresent(Bool.self, forKey: .success)
            ?? false

        let discount =
            try container.decodeIfPresent(Double.self, forKey: .discount)
            ?? container.decodeIfPresent(Double.self, forKey: .amount)
            ?? 0

        let message =
            try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .error)

        self.init(isValid: isValid, discount: discount, message: message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isValid, forKey: .isValid)
        try container.encode(discount, forKey: .discount)
        try container.encodeIfPresent(message, forKey: .message)
    }
}

struct OrderStatusUpdate: Codable {
    let status: OrderStatus
}

struct CartItem: Codable {
    let productId: String
    let size: String?
    let color: String?
    let quantity: Int
}

// MARK: - User Model
struct User: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var email: String
    var phone: String?
    var isAdmin: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case mongoID = "_id"
        case name, email, phone, isAdmin, createdAt, updatedAt, role
    }

    init(id: String, name: String, email: String, phone: String?, isAdmin: Bool, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRole = try container.decodeIfPresent(String.self, forKey: .role)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .mongoID)
            ?? UUID().uuidString
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Client"
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? (decodedRole == "admin")
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encode(isAdmin, forKey: .isAdmin)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Cart Model
struct Cart: Codable {
    let id: String
    let userId: String
    var items: [CartItemDetail]
    var total: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, items, total
    }
}

struct CartItemDetail: Codable, Identifiable {
    let id: String
    let productId: String
    let product: Product?
    let size: String?
    let color: String?
    var quantity: Int
    let price: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productId, product, size, color, quantity, price
    }
}

// MARK: - Analytics Models
struct AnalyticsData: Codable {
    let totalSales: Double
    let totalOrders: Int
    let totalUsers: Int
    let totalProducts: Int
    let salesByDay: [DailySales]
    let topProducts: [ProductSales]
    let ordersByStatus: [StatusCount]
}

struct DailySales: Codable, Identifiable {
    let id: String
    let date: String
    let amount: Double
    let orders: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case amount
        case orders
    }
    
    init(id: String? = nil, date: String, amount: Double, orders: Int) {
        self.id = id ?? date
        self.date = date
        self.amount = amount
        self.orders = orders
    }
}

struct ProductSales: Codable {
    let productId: String
    let productName: String
    let quantity: Int
    let revenue: Double
}

struct StatusCount: Codable {
    let status: String
    let count: Int
}

struct DashboardStats: Codable {
    let todaySales: Double
    let todayOrders: Int
    let newUsers: Int
    let lowStockProducts: Int
    let pendingOrders: Int
    let recentOrders: [Order]
}

// MARK: - Discover Models
struct DiscoverExperienceSnapshot: Codable {
    let feed: [DiscoverFeedItemData]
    let drops: [DiscoverDropData]
    let challenges: [DiscoverChallengeData]
    let leaderboard: [DiscoverLeaderboardData]
    let styleProfile: DiscoverStyleDNAProfile?
}

struct DiscoverFeedItemData: Identifiable, Hashable, Codable {
    let id: String
    let creatorID: String
    let creatorName: String
    let title: String
    let caption: String
    let score: Int
    let products: [Product]
}

struct DiscoverDropData: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let copy: String
    let stock: Int
    let unlocksAt: Date?
}

struct DiscoverChallengeData: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let prompt: String
    let rewardPoints: Int
}

struct DiscoverLeaderboardData: Identifiable, Hashable, Codable {
    let id: String
    let rank: Int
    let name: String
    let score: Int
}

struct DiscoverCommunityData: Codable {
    let challenges: [DiscoverChallengeData]
    let leaderboard: [DiscoverLeaderboardData]
}

struct DiscoverStyleDNAProfile: Hashable, Codable {
    var style: String
    var palette: String
    var fit: String

    var summary: String {
        "\(style) • \(palette)"
    }
}

struct DiscoverSubscriptionPlan: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let interval: String
    let price: Double
    let currency: String
    let details: String
}

struct DiscoverSubscriptionStatus: Identifiable, Hashable, Codable {
    let subscribed: Bool
    let planID: String?
    let createdAt: Date?

    var id: String { planID ?? "not-subscribed" }

    enum CodingKeys: String, CodingKey {
        case subscribed
        case planID = "planId"
        case createdAt
    }
}

struct DiscoverReservationReceipt: Identifiable, Hashable, Codable {
    let id: String
    let productIDs: [String]
    let status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case productIDs = "productIds"
        case status
        case createdAt
    }
}

struct DiscoverBoostActivation: Hashable, Codable {
    let success: Bool
    let estimatedReach: Int
    let campaignID: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case estimatedReach
        case campaignID = "campaignId"
        case createdAt
    }
}

struct DiscoverDropWaitlistReceipt: Hashable, Codable {
    let success: Bool
    let dropID: String
    let waitlistCount: Int

    enum CodingKeys: String, CodingKey {
        case success
        case dropID = "dropId"
        case waitlistCount
    }
}

struct DiscoverUserState: Hashable, Codable {
    let styleDNA: DiscoverStyleDNAProfile?
    let closetProductIDs: [String]
    let waitlistedDropIDs: [String]
    let votedChallengeIDs: [String]
    let likedOutfitIDs: [String]
    let savedOutfitIDs: [String]
    let followedCreatorIDs: [String]
    let activeSubscription: DiscoverSubscriptionStatus?
    let latestTryBeforeBuy: DiscoverReservationReceipt?
    let latestBoost: DiscoverBoostActivation?

    static let empty = DiscoverUserState(
        styleDNA: nil,
        closetProductIDs: [],
        waitlistedDropIDs: [],
        votedChallengeIDs: [],
        likedOutfitIDs: [],
        savedOutfitIDs: [],
        followedCreatorIDs: [],
        activeSubscription: nil,
        latestTryBeforeBuy: nil,
        latestBoost: nil
    )

    init(
        styleDNA: DiscoverStyleDNAProfile?,
        closetProductIDs: [String],
        waitlistedDropIDs: [String],
        votedChallengeIDs: [String],
        likedOutfitIDs: [String],
        savedOutfitIDs: [String],
        followedCreatorIDs: [String],
        activeSubscription: DiscoverSubscriptionStatus?,
        latestTryBeforeBuy: DiscoverReservationReceipt?,
        latestBoost: DiscoverBoostActivation?
    ) {
        self.styleDNA = styleDNA
        self.closetProductIDs = closetProductIDs
        self.waitlistedDropIDs = waitlistedDropIDs
        self.votedChallengeIDs = votedChallengeIDs
        self.likedOutfitIDs = likedOutfitIDs
        self.savedOutfitIDs = savedOutfitIDs
        self.followedCreatorIDs = followedCreatorIDs
        self.activeSubscription = activeSubscription
        self.latestTryBeforeBuy = latestTryBeforeBuy
        self.latestBoost = latestBoost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        styleDNA = try container.decodeIfPresent(DiscoverStyleDNAProfile.self, forKey: .styleDNA)
        closetProductIDs = try container.decodeIfPresent([String].self, forKey: .closetProductIDs) ?? []
        waitlistedDropIDs = try container.decodeIfPresent([String].self, forKey: .waitlistedDropIDs) ?? []
        votedChallengeIDs = try container.decodeIfPresent([String].self, forKey: .votedChallengeIDs) ?? []
        likedOutfitIDs = try container.decodeIfPresent([String].self, forKey: .likedOutfitIDs) ?? []
        savedOutfitIDs = try container.decodeIfPresent([String].self, forKey: .savedOutfitIDs) ?? []
        followedCreatorIDs = try container.decodeIfPresent([String].self, forKey: .followedCreatorIDs) ?? []
        activeSubscription = try container.decodeIfPresent(DiscoverSubscriptionStatus.self, forKey: .activeSubscription)
        latestTryBeforeBuy = try container.decodeIfPresent(DiscoverReservationReceipt.self, forKey: .latestTryBeforeBuy)
        latestBoost = try container.decodeIfPresent(DiscoverBoostActivation.self, forKey: .latestBoost)
    }

    enum CodingKeys: String, CodingKey {
        case styleDNA = "styleDna"
        case closetProductIDs = "closetProductIds"
        case waitlistedDropIDs = "waitlistedDropIds"
        case votedChallengeIDs = "votedChallengeIds"
        case likedOutfitIDs = "likedOutfitIds"
        case savedOutfitIDs = "savedOutfitIds"
        case followedCreatorIDs = "followedCreatorIds"
        case activeSubscription
        case latestTryBeforeBuy
        case latestBoost
    }
}

enum DiscoverInteractionKind: String, Codable {
    case likedOutfit
    case savedOutfit
    case followedCreator
}

struct DiscoverVoteOutcome: Hashable, Codable {
    let pointsAwarded: Int
    let totalPoints: Int?
}

// MARK: - OrderStatus Identifiable
extension OrderStatus: Identifiable {
    public var id: String { rawValue }
}

private struct APIErrorPayload: Codable {
    let error: String?
    let message: String?

    var resolvedMessage: String? {
        error ?? message
    }
}

private struct ProductImageUploadResponse: Codable {
    let url: String
    let path: String?
}

private struct BackendClientProfile: Codable {
    let name: String?
    let fullName: String?
    let email: String?
    let tier: String?
    let membershipTier: String?
    let city: String?
    let location: String?
    let note: String?
    let bio: String?

    var nativeProfile: ClientProfile {
        ClientProfile(
            name: name ?? fullName ?? "Client",
            email: email ?? "",
            tier: tier ?? membershipTier ?? "Member",
            city: city ?? location ?? "Cairo",
            note: note ?? bio ?? "Manage your account preferences and order activity."
        )
    }
}

private struct BackendClientProfileRequest: Codable {
    let name: String
    let email: String
    let tier: String
    let city: String
    let note: String
}

private struct BackendDiscoverOutfit: Codable {
    let id: String?
    let creatorID: String?
    let creatorName: String?
    let title: String?
    let caption: String?
    let summary: String?
    let score: Int?
    let styleScore: Int?
    let productIDs: [String]?
    let productIds: [String]?
    let products: [BackendDiscoverProductReference]?
    let items: [BackendDiscoverProductReference]?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creatorId"
        case creatorName
        case title
        case caption
        case summary
        case score
        case styleScore
        case productIDs
        case productIds
        case products
        case items
    }

    var resolvedProductIDs: [String] {
        let inline = (products ?? []) + (items ?? [])
        let fromRefs = inline.compactMap(\.productID)
        return (productIDs ?? []) + (productIds ?? []) + fromRefs
    }

    var productReferences: [BackendDiscoverProductReference] {
        (products ?? []) + (items ?? [])
    }
}

private struct BackendDiscoverProductReference: Codable {
    let productID: String?
    let product: BackendProduct?

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            productID = single
            product = nil
            return
        }

        if let backendProduct = try? BackendProduct(from: decoder) {
            product = backendProduct
            productID = backendProduct.id ?? backendProduct.mongoID
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        productID = try container.decodeIfPresent(String.self, forKey: .productID)
            ?? container.decodeIfPresent(String.self, forKey: .productId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        product = try container.decodeIfPresent(BackendProduct.self, forKey: .product)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let productID {
            try container.encode(productID)
        } else {
            try container.encodeNil()
        }
    }

    private enum CodingKeys: String, CodingKey {
        case productID = "productID"
        case productId = "productId"
        case id
        case product
    }
}

private struct BackendDiscoverDrop: Codable {
    let id: String?
    let mongoID: String?
    let name: String?
    let title: String?
    let copy: String?
    let details: String?
    let summary: String?
    let stock: Int?
    let inventory: Int?
    let unlocksAt: Date?
    let startAt: Date?
    let endsAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case mongoID = "_id"
        case name, title, copy, details, summary, stock, inventory, unlocksAt, startAt, endsAt
    }
}

private struct BackendDiscoverChallenge: Codable {
    let id: String?
    let rawID: String?
    let title: String?
    let prompt: String?
    let description: String?
    let rewardPoints: Int?
    let points: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case rawID = "_id"
        case title, prompt, description, rewardPoints, points
    }
}

private struct BackendDiscoverLeaderboardEntry: Codable {
    let id: String?
    let rank: Int?
    let position: Int?
    let name: String?
    let username: String?
    let score: Int?
    let points: Int?
}

private struct BackendDiscoverStyleDNA: Codable {
    let style: String?
    let preferredStyle: String?
    let palette: String?
    let primaryPalette: String?
    let fit: String?
    let fitPreference: String?

    var nativeProfile: DiscoverStyleDNAProfile {
        DiscoverStyleDNAProfile(
            style: style ?? preferredStyle ?? "Minimal Tailored",
            palette: palette ?? primaryPalette ?? "Neutrals",
            fit: fit ?? fitPreference ?? "Regular"
        )
    }
}

private struct BackendDiscoverStyleDNARequest: Codable {
    let style: String
    let palette: String
    let fit: String
}

private struct BackendDiscoverClosetSelectionRequest: Codable {
    let productIDs: [String]

    enum CodingKeys: String, CodingKey {
        case productIDs = "productIds"
    }
}

private struct BackendDiscoverStylistRequest: Codable {
    let message: String
    let productIDs: [String]

    enum CodingKeys: String, CodingKey {
        case message
        case productIDs = "productIds"
    }
}

private struct BackendDiscoverInteractionRequest: Codable {
    let kind: String
    let targetID: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case kind
        case targetID = "targetId"
        case isActive
    }
}

private struct BackendDiscoverStylistResponse: Codable {
    let reply: String?
    let message: String?
}

private struct BackendDiscoverSnapMatchRequest: Codable {
    let mood: String
    let limit: Int
}

private struct BackendDiscoverProductMatch: Codable {
    let productID: String?
    let productId: String?
    let id: String?
    let product: BackendProduct?

    var resolvedProductID: String? {
        productID ?? productId ?? id ?? product?.id ?? product?.mongoID
    }
}

private struct BackendTryBeforeBuyRequest: Codable {
    let productIDs: [String]

    enum CodingKeys: String, CodingKey {
        case productIDs = "productIds"
    }
}

private struct BackendDiscoverSubscriptionPlan: Codable {
    let id: String?
    let name: String?
    let title: String?
    let interval: String?
    let cycle: String?
    let price: Double?
    let amount: Double?
    let currency: String?
    let details: String?
    let description: String?

    var nativePlan: DiscoverSubscriptionPlan {
        DiscoverSubscriptionPlan(
            id: id ?? UUID().uuidString.lowercased(),
            title: name ?? title ?? "Outfit Box",
            interval: interval ?? cycle ?? "Monthly",
            price: price ?? amount ?? 0,
            currency: currency ?? "EGP",
            details: details ?? description ?? "Personalized curated outfit delivery."
        )
    }
}

private struct BackendDiscoverSubscribeRequest: Codable {
    let planID: String

    enum CodingKeys: String, CodingKey {
        case planID = "planId"
    }
}

private struct BackendDiscoverBoostEstimateRequest: Codable {
    let budget: Double
    let days: Int
}

private struct BackendDiscoverBoostEstimateResponse: Codable {
    let estimatedReach: Int?
    let reach: Int?
}

private struct BackendDiscoverDropWaitlistRequest: Codable {
    let dropID: String

    enum CodingKeys: String, CodingKey {
        case dropID = "dropId"
    }
}

private struct BackendDiscoverVoteRequest: Codable {
    let challengeID: String

    enum CodingKeys: String, CodingKey {
        case challengeID = "challengeId"
    }
}

private struct BackendDiscoverVoteResponse: Codable {
    let pointsAwarded: Int?
    let points: Int?
    let totalPoints: Int?
}

private struct BackendProduct: Codable {
    let id: String?
    let mongoID: String?
    let name: String
    let category: String?
    let price: Double
    let description: String?
    let summary: String?
    let story: String?
    let images: [String]?
    let imageNames: [String]?
    let size: [String]?
    let sizes: [String]?
    let colors: [String]?
    let composition: String?
    let care: String?
    let delivery: String?
    let returns: String?
    let badge: String?
    let featured: Bool?
    let rating: Double?
    let reviewCount: Int?
    let reviewsCount: Int?
    let inventory: Int?
    let stock: Int?
    let inventoryCount: Int?
    let available: Bool?
    let inStock: Bool?
    let isAvailable: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case mongoID = "_id"
        case name, category, price, description, summary, story, images, imageNames, size, sizes, colors
        case composition, care, delivery, returns, badge, featured
        case rating, reviewCount, reviewsCount, inventory, stock, inventoryCount, available, inStock, isAvailable
    }

    var nativeProduct: Product {
        let resolvedCategory = ProductCategory(slugOrTitle: category) ?? .shirts
        let backendImages: [String]
        if let imageNames, imageNames.isEmpty == false {
            backendImages = imageNames
        } else {
            backendImages = images ?? []
        }
        let resolvedImages = (backendImages.isEmpty == false ? backendImages : [resolvedCategory.heroImageName])
            .map(APIConfig.resolvedRemoteAssetURLString(for:))
        let resolvedColors = (colors ?? []).map { Colorway(name: $0.capitalized, hex: Colorway.hex(for: $0)) }
        let resolvedBadge = badge.flatMap(ProductBadge.init(rawValue:))
        let resolvedInventory = inventoryCount ?? inventory ?? stock
        let resolvedAvailability = isAvailable ?? available ?? inStock ?? resolvedInventory.map { $0 > 0 }
        let resolvedSummary = summary ?? description ?? ""
        let resolvedStory = story ?? resolvedSummary

        return Product(
            id: id ?? mongoID ?? UUID().uuidString,
            name: name,
            category: resolvedCategory,
            price: price,
            summary: resolvedSummary,
            story: resolvedStory,
            imageNames: resolvedImages,
            sizes: sizes ?? size ?? [],
            colors: resolvedColors,
            composition: composition ?? "",
            care: care ?? "",
            delivery: delivery ?? "",
            returns: returns ?? "",
            badge: resolvedBadge,
            featured: featured ?? (resolvedBadge != nil),
            rating: rating,
            reviewCount: reviewCount ?? reviewsCount,
            inventoryCount: resolvedInventory,
            isAvailable: resolvedAvailability
        )
    }
}

private struct BackendAdminUser: Codable {
    let id: String?
    let mongoID: String?
    let name: String?
    let email: String?
    let phone: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case mongoID = "_id"
        case name, email, phone, createdAt
    }

    var nativeUser: User {
        User(
            id: id ?? mongoID ?? UUID().uuidString,
            name: name ?? "Client",
            email: email ?? "",
            phone: phone,
            isAdmin: false,
            createdAt: createdAt,
            updatedAt: nil
        )
    }
}

private struct BackendOrdersEnvelope: Codable {
    let orders: [BackendOrder]
}

private struct BackendAdminOrdersResponse: Codable {
    let orders: [BackendOrder]
}

private struct BackendOrder: Codable {
    let id: String?
    let mongoID: String?
    let items: [BackendOrderItem]
    let totalPrice: Double?
    let total: Double?
    let subtotal: Double?
    let shippingCost: Double?
    let discount: Double?
    let status: String?
    let createdAt: Date?
    let shippingCity: String?
    let customer: BackendOrderCustomer?

    enum CodingKeys: String, CodingKey {
        case id
        case mongoID = "_id"
        case items, totalPrice, total, subtotal, shippingCost, discount, status, createdAt, shippingCity, customer
    }

    var nativeOrder: Order {
        let resolvedTotal = totalPrice ?? total ?? 0
        return Order(
            id: id ?? mongoID ?? UUID().uuidString,
            createdAt: createdAt,
            status: OrderStatus(status),
            total: resolvedTotal,
            subtotal: subtotal ?? resolvedTotal,
            shippingCost: shippingCost ?? 0,
            discount: discount ?? 0,
            lines: items.map(\.nativeLine),
            shippingCity: shippingCity ?? customer?.city ?? "",
            shippingAddress: customer?.nativeShippingAddress,
            paymentMethod: nil,
            customerName: customer?.name,
            customerEmail: customer?.email,
            customerPhone: customer?.phone,
            shippingMethodName: customer?.shippingMethod
        )
    }
}

private struct BackendOrderItem: Codable {
    let productId: String?
    let id: String?
    let name: String?
    let price: Double?
    let image: String?
    let quantity: Int?
    let size: String?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case productId, name, price, image, quantity, size, color
        case id = "_id"
    }

    var nativeLine: OrderLine {
        OrderLine(
            id: id ?? productId ?? UUID().uuidString,
            name: name ?? "Product",
            imageName: image.map(APIConfig.resolvedRemoteAssetURLString(for:)) ?? "main.jpg",
            quantity: quantity ?? 1,
            price: price ?? 0,
            size: size,
            color: color,
            product: nil
        )
    }
}

private struct BackendOrderCustomer: Codable {
    let name: String?
    let email: String?
    let phone: String?
    let address: String?
    let apartment: String?
    let city: String?
    let postalCode: String?
    let country: String?
    let shippingMethod: String?

    var nativeShippingAddress: ShippingAddress? {
        guard let name, !name.isEmpty else { return nil }
        return ShippingAddress(
            name: name,
            street: address ?? "",
            city: city ?? "",
            postalCode: postalCode ?? "",
            phone: phone ?? "",
            email: email,
            apartment: apartment
        )
    }
}

private struct BackendCreateOrderRequest: Codable {
    let id: String
    let items: [BackendCreateOrderItem]
    let status: String
    let subtotal: Double
    let shippingCost: Double
    let discount: Double
    let shippingCity: String
    let shippingAddress: ShippingAddress?
    let paymentMethod: PaymentMethod?
    let paymentMethodId: String?
    let promoCode: String?
    let deliveryLocation: String
    let codFee: Double
    let customerName: String?
    let customerEmail: String?
    let customerPhone: String?
    let shippingMethodName: String?

    init(order: Order, deliveryLocation: String, codFee: Double, paymentMethodID: String?, promoCode: String?) {
        self.id = order.id
        self.items = order.lines.map(BackendCreateOrderItem.init)
        self.status = order.status.rawValue
        self.subtotal = order.subtotal
        self.shippingCost = order.shippingCost
        self.discount = order.discount
        self.shippingCity = order.shippingCity
        self.shippingAddress = order.shippingAddress
        self.paymentMethod = order.paymentMethod
        self.paymentMethodId = paymentMethodID ?? order.paymentMethod?.type
        self.promoCode = promoCode
        self.deliveryLocation = deliveryLocation
        self.codFee = codFee
        self.customerName = order.customerName
        self.customerEmail = order.customerEmail
        self.customerPhone = order.customerPhone
        self.shippingMethodName = order.shippingMethodName
    }
}

private struct BackendCreateOrderItem: Codable {
    let productId: String
    let quantity: Int
    let size: String?
    let color: String?

    init(line: OrderLine) {
        self.productId = line.product?.id ?? line.id
        self.quantity = line.quantity
        self.size = line.size
        self.color = line.color
    }
}

private struct BackendRemoveCartItemRequest: Codable {
    let productId: String
    let size: String?
    let color: String?
}

private struct BackendCartResponse: Codable {
    let items: [BackendCartItem]

    var nativeCart: Cart {
        let detailItems = items.map(\.nativeItem)
        let total = detailItems.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        return Cart(id: "cart", userId: "current", items: detailItems, total: total)
    }
}

private struct BackendCartItem: Codable {
    let id: String?
    let productId: String?
    let name: String?
    let price: Double?
    let image: String?
    let size: String?
    let color: String?
    let quantity: Int?

    enum CodingKeys: String, CodingKey {
        case productId, name, price, image, size, color, quantity
        case id = "_id"
    }

    var nativeItem: CartItemDetail {
        CartItemDetail(
            id: id ?? productId ?? UUID().uuidString,
            productId: productId ?? id ?? "",
            product: nil,
            size: size,
            color: color,
            quantity: quantity ?? 1,
            price: price ?? 0
        )
    }
}

private struct BackendAnalyticsResponse: Codable {
    let totalRevenue: Double
    let todaySales: Double?
    let ordersToday: Int
    let totalOrders: Int
    let totalCustomers: Int
    let newUsers: Int?
    let pendingOrders: Int?
    let lowStockProducts: Int?
    let bestSellingProducts: [BackendTopProduct]
    let revenueByMonth: [BackendRevenuePoint]
    let ordersByStatus: [String: Int]?

    var nativeAnalytics: AnalyticsData {
        AnalyticsData(
            totalSales: totalRevenue,
            totalOrders: totalOrders,
            totalUsers: totalCustomers,
            totalProducts: bestSellingProducts.count,
            salesByDay: revenueByMonth.map {
                DailySales(id: $0.month, date: $0.month, amount: $0.revenue, orders: 0)
            },
            topProducts: bestSellingProducts.map {
                ProductSales(productId: $0.id, productName: $0.name, quantity: $0.quantity, revenue: 0)
            },
            ordersByStatus: (ordersByStatus ?? [:]).map { StatusCount(status: $0.key, count: $0.value) }
        )
    }

    var nativeDashboardStats: DashboardStats {
        DashboardStats(
            todaySales: todaySales ?? 0,
            todayOrders: ordersToday,
            newUsers: newUsers ?? 0,
            lowStockProducts: lowStockProducts ?? 0,
            pendingOrders: pendingOrders ?? 0,
            recentOrders: []
        )
    }
}

private struct BackendTopProduct: Codable {
    let id: String
    let name: String
    let quantity: Int
}

private struct BackendRevenuePoint: Codable {
    let month: String
    let revenue: Double
}

enum AuthTokenStore {
    static let serviceKey = "aurelien.authToken"
    private static var inMemoryValues: [String: String] = [:]

    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        inMemoryValues[key] = value

        SecItemDelete(identityQuery(for: key) as CFDictionary)

        var addQuery = identityQuery(for: key)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func value(for key: String) -> String? {
        var query = identityQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return inMemoryValues[key]
        }

        inMemoryValues[key] = value
        return value
    }

    static func deleteValue(for key: String) {
        inMemoryValues.removeValue(forKey: key)
        SecItemDelete(identityQuery(for: key) as CFDictionary)
    }

    private static func identityQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.shereenmagdy.aurelien",
            kSecAttrAccount as String: key
        ]
    }
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }
}

private extension Array {
    func uniqued<Value: Hashable>(by keyPath: KeyPath<Element, Value>) -> [Element] {
        var seen = Set<Value>()
        return filter { element in
            let value = element[keyPath: keyPath]
            return seen.insert(value).inserted
        }
    }
}

private extension ProductCategory {
    init?(slugOrTitle: String?) {
        guard let raw = slugOrTitle?
            .lowercased()
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "") else {
            return nil
        }

        switch raw {
        case "jacketscoats", "jacket", "jackets": self = .jackets
        case "coat", "coats": self = .coats
        case "suits", "suit": self = .suits
        case "shirts", "shirt": self = .shirts
        case "knitwear", "knit": self = .knitwear
        case "bagswallets", "bag", "bags": self = .bags
        case "belts", "belt": self = .belts
        case "sunglasses", "glass", "glasses": self = .sunglasses
        case "loafers", "loafer": self = .loafers
        case "sneakers", "sneaker": self = .sneakers
        case "denim": self = .denim
        case "korean": self = .korean
        case "jeans": self = .jeans
        case "boots", "boot": self = .boots
        case "pants", "pant": self = .pants
        case "accessories": self = .accessories
        case "footwear": self = .footwear
        case "lifestyle": self = .lifestyle
        default: return nil
        }
    }
}

private extension OrderStatus {
    init(_ raw: String?) {
        switch raw?.lowercased() {
        case "confirmed": self = .confirmed
        case "preparing", "processing", "packed", "packing": self = .preparing
        case "shipped": self = .shipped
        case "delivered": self = .delivered
        case "cancelled": self = .cancelled
        default: self = .pending
        }
    }
}
