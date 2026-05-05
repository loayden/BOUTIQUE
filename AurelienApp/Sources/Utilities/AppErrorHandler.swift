import Foundation

/// Categorizes API errors and provides user-friendly messages for all root causes
enum AppErrorCategory {
    case noInternet
    case weakSignal
    case timeout
    case unauthorized // 401/403
    case notFound // 404
    case serverDown // 5xx
    case dnsFailure
    case certificateError
    case malformedResponse
    case unknownNetwork
    case offline
    
    var icon: String {
        switch self {
        case .noInternet, .offline: return "wifi.slash"
        case .weakSignal: return "wifi.exclamationmark"
        case .timeout: return "hourglass"
        case .unauthorized: return "lock.slash"
        case .notFound: return "magnifyingglass"
        case .serverDown: return "exclamationmark.triangle.fill"
        case .dnsFailure: return "network"
        case .certificateError: return "lock.open"
        case .malformedResponse: return "exclamationmark.octagon"
        case .unknownNetwork: return "questionmark.circle"
        }
    }
}

/// Enhanced error handler with categorized, user-friendly messages
struct AppErrorHandler {

    @MainActor
    private static func isConnected() -> Bool {
        NetworkMonitor.shared.isConnected
    }

    @MainActor
    private static func isExpensive() -> Bool {
        NetworkMonitor.shared.isExpensive
    }
    
    /// Diagnose and categorize an error
    static func categorize(_ error: Error) -> (category: AppErrorCategory, message: String, suggestion: String) {
        // Check network first
        if !MainActor.assumeIsolated({ isConnected() }) {
            return (
                category: .noInternet,
                message: "No Internet Connection",
                suggestion: "Enable Wi-Fi or cellular data and try again."
            )
        }
        
        // API Error
        if let apiError = error as? APIError {
            return handleAPIError(apiError)
        }
        
        // URLError
        if let urlError = error as? URLError {
            return handleURLError(urlError)
        }
        
        // NSError
        let nsError = error as NSError
        return handleNSError(nsError)
    }
    
    private static func handleAPIError(_ error: APIError) -> (category: AppErrorCategory, message: String, suggestion: String) {
        switch error {
        case .invalidURL:
            return (
                category: .serverDown,
                message: "Invalid Server Configuration",
                suggestion: "The app's server settings are incorrect. Contact support."
            )
            
        case .invalidResponse:
            return (
                category: .malformedResponse,
                message: "Invalid Response from Server",
                suggestion: "The server sent corrupted data. Try again shortly."
            )
            
        case .httpError(let code, let message):
            // Server errors (5xx)
            if (500...599).contains(code) {
                return (
                    category: .serverDown,
                    message: "Server Temporarily Unavailable (\(code))",
                    suggestion: message ?? "The server is under maintenance. Please try again in a few minutes."
                )
            }
            // Conflicts, precondition fails (4xx)
            return (
                category: .unknownNetwork,
                message: "Request Error (\(code))",
                suggestion: message ?? "Please try again."
            )
            
        case .decodingError:
            return (
                category: .malformedResponse,
                message: "Invalid Data Format",
                suggestion: "The server sent unexpected data format. Try updating the app or clearing cache."
            )
            
        case .networkError(let underlyingError):
            return handleURLError(underlyingError as? URLError ?? URLError(.unknown))
            
        case .unauthorized(let message):
            return (
                category: .unauthorized,
                message: "Authentication Required",
                suggestion: message ?? "Your session expired. Please sign in again."
            )
            
        case .notFound(let message):
            return (
                category: .notFound,
                message: "Content Not Found",
                suggestion: message ?? "This item is no longer available. Try going back."
            )
            
        case .serverError(let message):
            return (
                category: .serverDown,
                message: "Server Error",
                suggestion: message ?? "The server encountered an error. Please try again shortly."
            )
        }
    }
    
    private static func handleURLError(_ error: URLError) -> (category: AppErrorCategory, message: String, suggestion: String) {
        let code = error.code
        
        switch code {
        case .notConnectedToInternet:
            return (
                category: .noInternet,
                message: "No Internet Connection",
                suggestion: "Enable Wi-Fi or cellular data and try again."
            )
            
        case .networkConnectionLost, .timedOut:
            if MainActor.assumeIsolated({ isExpensive() }) {
                return (
                    category: .weakSignal,
                    message: "Weak Network Signal",
                    suggestion: "Move closer to your Wi-Fi router or switch networks."
                )
            }
            return (
                category: .timeout,
                message: "Connection Timed Out",
                suggestion: "The request took too long. Check your connection and try again."
            )
            
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return (
                category: .dnsFailure,
                message: "Cannot Reach Server",
                suggestion: "Try switching from Wi-Fi to cellular, or use a VPN. You may be behind a firewall."
            )
            
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate:
            return (
                category: .certificateError,
                message: "Secure Connection Failed",
                suggestion: "Ensure your device date/time is correct. Go to Settings → General → Date & Time."
            )
            
        case .badServerResponse, .dataLengthExceedsMaximum:
            return (
                category: .malformedResponse,
                message: "Bad Response from Server",
                suggestion: "The server sent invalid data. Try again in a moment."
            )
            
        case .cancelled:
            // Don't show UI for cancellations
            return (
                category: .unknownNetwork,
                message: "",
                suggestion: ""
            )
            
        default:
            return (
                category: .unknownNetwork,
                message: "Network Error",
                suggestion: error.localizedDescription.isEmpty ? "Please try again." : error.localizedDescription
            )
        }
    }
    
    private static func handleNSError(_ error: NSError) -> (category: AppErrorCategory, message: String, suggestion: String) {
        // Handle cancellation
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return (
                category: .unknownNetwork,
                message: "",
                suggestion: ""
            )
        }
        
        // Handle JSON decode errors
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case 3840, 4865: // JSONSerialization errors
                return (
                    category: .malformedResponse,
                    message: "Invalid Response Format",
                    suggestion: "The server sent corrupted data. Try again."
                )
            default:
                break
            }
        }
        
        return (
            category: .unknownNetwork,
            message: error.localizedDescription,
            suggestion: "Please try again."
        )
    }
    
    /// Format error for UI display
    static func displayMessage(for error: Error) -> String {
        let (_, message, suggestion) = categorize(error)
        if message.isEmpty {
            return ""
        }
        return suggestion.isEmpty ? message : "\(message)\n\n\(suggestion)"
    }
    
    /// Check if error is a cancellation (should be silent)
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        if (error as NSError).code == NSURLErrorCancelled {
            return true
        }
        return false
    }
    
    /// Format age of cached data
    static func formatCacheAge(seconds: Int) -> String {
        if seconds < 60 {
            return "just now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
