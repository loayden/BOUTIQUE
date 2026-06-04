import Foundation
import os

enum Logger {
    private static let runtime = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.shereenmagdy.aurelien",
        category: "runtime"
    )

    static func debug(_ message: String) {
        #if DEBUG
        runtime.debug("\(message, privacy: .public)")
        #endif
    }

    static func error(_ message: String) {
        runtime.error("\(message, privacy: .public)")
    }

    static func info(_ message: String) {
        runtime.info("\(message, privacy: .public)")
    }
}
