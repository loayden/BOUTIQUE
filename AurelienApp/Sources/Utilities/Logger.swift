import Foundation

enum Logger {
    static func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG] \(message)")
        #endif
    }
    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }
    static func info(_ message: String) {
        print("[INFO] \(message)")
    }
}
