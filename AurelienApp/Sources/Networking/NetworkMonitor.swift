import Foundation

enum NetworkError: LocalizedError {
    case noInternetConnection
    case constrainedDataMode
    case weakSignal
    case dnsResolutionFailed
    case certificateValidationFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection. Please check your Wi-Fi or cellular data and try again."
        case .constrainedDataMode:
            return "Low Data Mode is enabled. Disable it to use this feature."
        case .weakSignal:
            return "Weak network signal. Move closer to your Wi-Fi router or try again shortly."
        case .dnsResolutionFailed:
            return "Can't reach the server. Check if you're behind a firewall or try switching networks."
        case .certificateValidationFailed:
            return "Secure connection failed. Ensure your device date/time is correct."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noInternetConnection:
            return "Enable Wi-Fi or cellular data in Settings."
        case .constrainedDataMode:
            return "Settings → Cellular → Low Data Mode → Toggle Off"
        case .weakSignal:
            return "Try moving to a different location or reconnecting to Wi-Fi."
        case .dnsResolutionFailed:
            return "Try switching from Wi-Fi to cellular or use a VPN."
        case .certificateValidationFailed:
            return "Go to Settings → General → Date & Time and ensure it's correct."
        case .unknown:
            return "Tap Retry to try again."
        }
    }
}
