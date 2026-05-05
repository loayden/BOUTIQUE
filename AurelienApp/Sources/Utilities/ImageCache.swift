import UIKit

/// Image cache with NSCache and prefetching
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func prefetch(urls: [URL]) {
        for url in urls {
            Task {
                if let data = try? await NetworkClient.shared.fetch(url),
                   let image = UIImage(data: data) {
                    self.setImage(image, forKey: url.absoluteString)
                }
            }
        }
    }
}
