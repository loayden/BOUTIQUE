import SwiftUI
import UIKit

enum BrandMediaLibrary {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()

    static func image(named fileName: String) -> UIImage? {
        let key = fileName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        if let localImage = loadFromLocalFile(named: fileName) {
            let resized = localImage.resized(maxSize: CGSize(width: 800, height: 1200))
            cache.setObject(resized, forKey: key, cost: resized.cacheCost)
            return resized
        }

        // Extract base name without path and extension
        let cleanName = (fileName as NSString).lastPathComponent
        let nameWithoutExt = (cleanName as NSString).deletingPathExtension

        // Remove spaces for asset catalog compatibility
        let assetName = nameWithoutExt.replacingOccurrences(of: " ", with: "_")

        // Try Assets.xcassets first (recommended for iOS)
        if let image = UIImage(named: assetName) {
            let resized = image.resized(maxSize: CGSize(width: 800, height: 1200))
            cache.setObject(resized, forKey: key, cost: resized.cacheCost)
            return resized
        }

        // Fallback: Try original name in asset catalog
        if let image = UIImage(named: nameWithoutExt) {
            let resized = image.resized(maxSize: CGSize(width: 800, height: 1200))
            cache.setObject(resized, forKey: key, cost: resized.cacheCost)
            return resized
        }

        // Fallback: Try loading from bundle resources
        if let image = loadFromBundle(named: cleanName) {
            let resized = image.resized(maxSize: CGSize(width: 800, height: 1200))
            cache.setObject(resized, forKey: key, cost: resized.cacheCost)
            return resized
        }

        return nil
    }

    private static func loadFromLocalFile(named fileName: String) -> UIImage? {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let url = URL(string: trimmed), url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }

        guard trimmed.hasPrefix("/") else { return nil }
        return UIImage(contentsOfFile: trimmed)
    }

    private static func loadFromBundle(named fileName: String) -> UIImage? {
        let bundle = Bundle.main
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.lowercased()

        // Debug: Print bundle path
        #if DEBUG
        print("[BrandMediaLibrary] Looking for: \(fileName)")
        print("[BrandMediaLibrary] Bundle path: \(bundle.bundlePath)")
        #endif

        // Try with original extension
        if let path = bundle.path(forResource: name, ofType: ext.isEmpty ? nil : ext),
           let image = UIImage(contentsOfFile: path) {
            #if DEBUG
            print("[BrandMediaLibrary] Found at: \(path)")
            #endif
            return image
        }

        // Try common image extensions
        for imageExt in ["jpg", "jpeg", "png", "JPG", "JPEG", "PNG"] {
            if let path = bundle.path(forResource: name, ofType: imageExt),
               let image = UIImage(contentsOfFile: path) {
                #if DEBUG
                print("[BrandMediaLibrary] Found with ext .\(imageExt) at: \(path)")
                #endif
                return image
            }
        }

        // Try with URL API
        if let url = bundle.url(forResource: name, withExtension: ext.isEmpty ? "jpg" : ext),
           let image = UIImage(contentsOfFile: url.path) {
            #if DEBUG
            print("[BrandMediaLibrary] Found via URL: \(url.path)")
            #endif
            return image
        }

        // Try without extension (if file has no extension)
        if let path = bundle.path(forResource: fileName, ofType: nil),
           let image = UIImage(contentsOfFile: path) {
            #if DEBUG
            print("[BrandMediaLibrary] Found without extension: \(path)")
            #endif
            return image
        }

        #if DEBUG
        print("[BrandMediaLibrary] Image not found: \(fileName)")
        #endif
        return nil
    }
}

private extension UIImage {
    var cacheCost: Int {
        guard let cgImage else {
            return Int(size.width * size.height * scale * scale * 4)
        }
        return cgImage.bytesPerRow * cgImage.height
    }

    func resized(maxSize: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }

        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let scaleRatio = min(max(0.01, widthRatio), max(0.01, heightRatio), 1)

        let targetSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        guard targetSize.width > 0, targetSize.height > 0 else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
