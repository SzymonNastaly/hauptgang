import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UIKit

actor RecipeImageCache {
    static let shared = RecipeImageCache()

    enum CacheError: Error {
        case badResponse
        case invalidImageData
    }

    private let session: URLSession
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let maxAge: TimeInterval
    private let maxDiskSizeBytes: Int64
    private let memoryCache = NSCache<NSString, UIImage>()

    private var inFlightRequests: [String: Task<UIImage, Error>] = [:]
    private var inFlightDownloads: [String: Task<Data, Error>] = [:]

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil,
        maxAge: TimeInterval = 60 * 60 * 24 * 14,
        maxDiskSizeBytes: Int64 = 150 * 1024 * 1024,
        memoryCountLimit: Int = 200
    ) {
        self.session = session
        self.fileManager = fileManager
        self.maxAge = maxAge
        self.maxDiskSizeBytes = maxDiskSizeBytes

        let baseDirectory = cacheDirectory
            ?? URL.cachesDirectory.appendingPathComponent("RecipeImageCache", isDirectory: true)
        self.cacheDirectory = baseDirectory

        self.memoryCache.countLimit = memoryCountLimit
    }

    func image(for url: URL, maxPixelSize: CGFloat? = nil) async throws -> UIImage {
        let memoryKey = self.memoryCacheKey(for: url, maxPixelSize: maxPixelSize)
        let keyObject = memoryKey as NSString

        if let cached = self.memoryCache.object(forKey: keyObject) {
            return cached
        }

        if let inFlight = self.inFlightRequests[memoryKey] {
            return try await inFlight.value
        }

        let task = Task<UIImage, Error> {
            try await self.loadImage(for: url, memoryKey: memoryKey, keyObject: keyObject, maxPixelSize: maxPixelSize)
        }
        self.inFlightRequests[memoryKey] = task
        defer { self.inFlightRequests[memoryKey] = nil }

        return try await task.value
    }

    private func loadImage(
        for url: URL,
        memoryKey: String,
        keyObject: NSString,
        maxPixelSize: CGFloat?
    ) async throws -> UIImage {
        let diskKey = url.absoluteString

        if let data = try self.readDiskDataIfFresh(for: diskKey) {
            do {
                let image = try self.decodeImage(from: data, maxPixelSize: maxPixelSize)
                self.memoryCache.setObject(image, forKey: keyObject, cost: data.count)
                return image
            } catch {
                try? self.fileManager.removeItem(at: self.fileURLForKey(diskKey))
            }
        }

        let data = try await self.downloadData(for: url, diskKey: diskKey)
        let image = try self.decodeImage(from: data, maxPixelSize: maxPixelSize)
        self.memoryCache.setObject(image, forKey: keyObject, cost: data.count)

        return image
    }

    private func downloadData(for url: URL, diskKey: String) async throws -> Data {
        if let inFlight = self.inFlightDownloads[diskKey] {
            return try await inFlight.value
        }

        let task = Task<Data, Error> {
            let (data, response) = try await self.session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
                throw CacheError.badResponse
            }
            try self.writeToDisk(data: data, key: diskKey)
            try self.evictDiskIfNeeded()
            return data
        }
        self.inFlightDownloads[diskKey] = task
        defer { self.inFlightDownloads[diskKey] = nil }

        return try await task.value
    }

    private func readDiskDataIfFresh(for key: String) throws -> Data? {
        try self.ensureCacheDirectoryExists()

        let fileURL = self.fileURLForKey(key)
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let attributes = try self.fileManager.attributesOfItem(atPath: fileURL.path)
        let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast
        if Date().timeIntervalSince(modifiedAt) > self.maxAge {
            try? self.fileManager.removeItem(at: fileURL)
            return nil
        }

        let data = try Data(contentsOf: fileURL)

        // Touch the file on successful read so LRU eviction uses recent accesses.
        try? self.fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        return data
    }

    private func decodeImage(from data: Data, maxPixelSize: CGFloat?) throws -> UIImage {
        guard let maxPixelSize, maxPixelSize > 0 else {
            guard let image = UIImage(data: data) else {
                throw CacheError.invalidImageData
            }
            return image
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CacheError.invalidImageData
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(ceil(maxPixelSize))
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CacheError.invalidImageData
        }

        return UIImage(cgImage: cgImage)
    }

    private func writeToDisk(data: Data, key: String) throws {
        try self.ensureCacheDirectoryExists()
        let fileURL = self.fileURLForKey(key)
        try data.write(to: fileURL, options: .atomic)
    }

    private func evictDiskIfNeeded() throws {
        let files = try self.fileManager.contentsOfDirectory(
            at: self.cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var totalSize: Int64 = 0
        var entries: [(url: URL, modifiedAt: Date, size: Int64)] = []

        for file in files {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let size = Int64(values.fileSize ?? 0)
            let modifiedAt = values.contentModificationDate ?? .distantPast
            totalSize += size
            entries.append((url: file, modifiedAt: modifiedAt, size: size))
        }

        guard totalSize > self.maxDiskSizeBytes else {
            return
        }

        let sorted = entries.sorted { $0.modifiedAt < $1.modifiedAt }
        for entry in sorted where totalSize > self.maxDiskSizeBytes {
            try? self.fileManager.removeItem(at: entry.url)
            totalSize -= entry.size
        }
    }

    private func ensureCacheDirectoryExists() throws {
        if !self.fileManager.fileExists(atPath: self.cacheDirectory.path) {
            try self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func memoryCacheKey(for url: URL, maxPixelSize: CGFloat?) -> String {
        guard let maxPixelSize, maxPixelSize > 0 else {
            return url.absoluteString
        }

        return "\(url.absoluteString)#\(Int(ceil(maxPixelSize)))"
    }

    private func fileURLForKey(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.compactMap { String(format: "%02x", $0) }.joined() + ".img"
        return self.cacheDirectory.appendingPathComponent(filename, isDirectory: false)
    }
}
