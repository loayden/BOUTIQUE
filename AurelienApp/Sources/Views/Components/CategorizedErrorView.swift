import SwiftUI

/// Reusable categorized error display component for all screens
struct CategorizedErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    let cacheAge: Int? // Age of cached data in seconds, if available
    
    var body: some View {
        let (category, message, suggestion) = AppErrorHandler.categorize(error)
        
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 44))
                .foregroundColor(BrandPalette.gold)
            
            VStack(spacing: 8) {
                Text(message)
                    .font(.headline)
                    .foregroundColor(BrandPalette.textPrimary)
                
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(BrandPalette.textSecondary)
            }
            .multilineTextAlignment(.center)
            
            if let cacheAge {
                Text("Last updated \(AppErrorHandler.formatCacheAge(seconds: cacheAge))")
                    .font(.caption)
                    .foregroundColor(BrandPalette.textMuted)
            }
            
            if let onRetry {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

/// Inline error banner with optional cache age
struct InlineErrorBanner: View {
    let error: Error
    let onRetry: (() -> Void)?
    let cacheAge: Int? = nil
    
    var body: some View {
        let (category, _, suggestion) = AppErrorHandler.categorize(error)
        
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .foregroundStyle(BrandPalette.gold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.caption)
                    .foregroundStyle(BrandPalette.textPrimary)
                
                Text(suggestion)
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.textSecondary)
            }
            
            Spacer(minLength: 0)
            
            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.caption)
                    .foregroundStyle(BrandPalette.gold)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

/// Preview helper for testing error displays
struct CategorizedErrorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // No internet
            CategorizedErrorView(
                error: URLError(.notConnectedToInternet),
                onRetry: {},
                cacheAge: nil
            )
            
            // Timeout
            CategorizedErrorView(
                error: URLError(.timedOut),
                onRetry: {},
                cacheAge: 300
            )
            
            // Server error
            CategorizedErrorView(
                error: APIError.serverError("500 Internal Server Error"),
                onRetry: {},
                cacheAge: nil
            )
        }
        .padding()
    }
}
