import CryptoKit
import Foundation
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

    func image(for url: URL) async throws -> UIImage {
        let key = url.absoluteString
        let keyObject = key as NSString

        if let cached = memoryCache.object(forKey: keyObject) {
            return cached
        }

        if let inFlight = inFlightRequests[key] {
            return try await inFlight.value
        }

        let task = Task<UIImage, Error> {
            try await self.loadImage(for: url, key: key, keyObject: keyObject)
        }
        self.inFlightRequests[key] = task
        defer { inFlightRequests[key] = nil }

        return try await task.value
    }

    private func loadImage(for url: URL, key: String, keyObject: NSString) async throws -> UIImage {
        if let diskImage = try readDiskImageIfFresh(for: key) {
            self.memoryCache.setObject(diskImage, forKey: keyObject)
            return diskImage
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw CacheError.badResponse
        }
        guard let image = UIImage(data: data) else {
            throw CacheError.invalidImageData
        }

        try self.writeToDisk(data: data, key: key)
        self.memoryCache.setObject(image, forKey: keyObject, cost: data.count)
        try self.evictDiskIfNeeded()

        return image
    }

    private func readDiskImageIfFresh(for key: String) throws -> UIImage? {
        try self.ensureCacheDirectoryExists()

        let fileURL = self.fileURLForKey(key)
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast
        if Date().timeIntervalSince(modifiedAt) > self.maxAge {
            try? self.fileManager.removeItem(at: fileURL)
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        guard let image = UIImage(data: data) else {
            try? self.fileManager.removeItem(at: fileURL)
            return nil
        }

        // Touch the file on successful read so LRU eviction uses recent accesses.
        try? self.fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        return image
    }

    private func writeToDisk(data: Data, key: String) throws {
        try self.ensureCacheDirectoryExists()
        let fileURL = self.fileURLForKey(key)
        try data.write(to: fileURL, options: .atomic)
    }

    private func evictDiskIfNeeded() throws {
        let files = try fileManager.contentsOfDirectory(
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
            try? fileManager.removeItem(at: entry.url)
            totalSize -= entry.size
        }
    }

    private func ensureCacheDirectoryExists() throws {
        if !self.fileManager.fileExists(atPath: self.cacheDirectory.path) {
            try self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func fileURLForKey(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.compactMap { String(format: "%02x", $0) }.joined() + ".img"
        return self.cacheDirectory.appendingPathComponent(filename, isDirectory: false)
    }
}
