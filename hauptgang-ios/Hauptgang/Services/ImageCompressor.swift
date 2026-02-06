import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

enum ImageCompressor {
    private static let maxDimension: CGFloat = 3000
    private static let qualityLevels: [CGFloat] = [0.8, 0.6, 0.4]

    /// Compress image data to JPEG within a size limit.
    /// Returns nil if compression is impossible.
    static func compressToJPEG(_ data: Data, maxBytes: Int = 15_000_000) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return compressSource(source, maxBytes: maxBytes)
    }

    /// Compress image from a file URL to JPEG within a size limit.
    /// Preferred for extension use — avoids loading full image into memory.
    static func compressToJPEG(from fileURL: URL, maxBytes: Int = 15_000_000) -> Data? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        return compressSource(source, maxBytes: maxBytes)
    }

    // MARK: - Private

    private static func compressSource(_ source: CGImageSource, maxBytes: Int) -> Data? {
        // Try at original size first
        if let result = tryCompress(source: source, maxPixelSize: nil, maxBytes: maxBytes) {
            return result
        }

        // Downsample to maxDimension and retry
        return tryCompress(source: source, maxPixelSize: maxDimension, maxBytes: maxBytes)
    }

    private static func tryCompress(
        source: CGImageSource,
        maxPixelSize: CGFloat?,
        maxBytes: Int
    ) -> Data? {
        let image: CGImage

        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            image = thumbnail
        } else {
            let transformOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let fullImage = CGImageSourceCreateThumbnailAtIndex(source, 0, transformOptions as CFDictionary) else {
                return nil
            }
            image = fullImage
        }

        for quality in qualityLevels {
            if let data = jpegData(from: image, quality: quality), data.count <= maxBytes {
                return data
            }
        }

        return nil
    }

    private static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
