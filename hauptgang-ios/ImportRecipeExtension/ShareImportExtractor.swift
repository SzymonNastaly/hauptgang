import Foundation
import UniformTypeIdentifiers

enum ShareImportExtractor {
    static func extractURL(from attachments: [NSItemProvider]) async -> URL? {
        let urlType = UTType.url.identifier
        let plainTextType = UTType.plainText.identifier

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                if let url = await loadURL(from: provider, typeIdentifier: urlType) {
                    return url
                }
            }
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(plainTextType) {
                if let url = await loadURLFromPlainText(from: provider, typeIdentifier: plainTextType) {
                    return url
                }
            }
        }

        return nil
    }

    static func extractImageFileURL(from attachments: [NSItemProvider]) async -> URL? {
        let imageType = UTType.image.identifier

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(imageType) {
                if let url = await loadImageFileURL(from: provider, typeIdentifier: imageType) {
                    return url
                }
            }
        }

        return nil
    }

    static func urlFromPlainText(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            return nil
        }
        return url
    }

    // MARK: - Private

    private static func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let nsurl = item as? NSURL, let url = nsurl as URL? {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadURLFromPlainText(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let text: String?
                if let str = item as? String {
                    text = str
                } else if let data = item as? Data {
                    text = String(data: data, encoding: .utf8)
                } else {
                    text = nil
                }

                continuation.resume(returning: text.flatMap { urlFromPlainText($0) })
            }
        }
    }

    private static func loadImageFileURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
