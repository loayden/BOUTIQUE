import Foundation

/// API response cache with versioning and stale-while-revalidate
final class APICache {
    static let shared = APICache()
    private let cache = NSCache<NSString, NSData>()
    private let version = 1

    private init() {}

    func data(forKey key: String) -> Data? {
        cache.object(forKey: cacheKey(key)) as Data?
    }

    func setData(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: cacheKey(key))
    }

    private func cacheKey(_ key: String) -> NSString {
        "v\(version)_\(key)" as NSString
    }
}
