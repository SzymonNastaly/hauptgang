import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {
    private var importState: ImportState = .extracting
    private var hostingController: UIHostingController<ImportRecipeView>?
    private var importTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractContent()
    }

    deinit {
        importTask?.cancel()
    }

    private func setupUI() {
        let importView = makeImportView(state: importState)
        let hostingController = UIHostingController(rootView: importView)
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    private func updateState(_ newState: ImportState) {
        importState = newState
        hostingController?.rootView = makeImportView(state: newState)
    }

    private func makeImportView(state: ImportState) -> ImportRecipeView {
        ImportRecipeView(
            state: state,
            onClose: { [weak self] in self?.close() },
            onOpenApp: { [weak self] in self?.openMainApp() }
        )
    }

    private func extractContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            updateState(.failed("No content found"))
            return
        }

        importTask = Task {
            // Try URL first — URL scraping gives better results than photo OCR
            if let url = await ShareImportExtractor.extractURL(from: attachments) {
                await handleExtractedURL(url)
                return
            }

            // Fall back to image
            if let imageFileURL = await ShareImportExtractor.extractImageFileURL(from: attachments) {
                await handleExtractedImage(imageFileURL)
                return
            }

            await MainActor.run {
                updateState(.failed("Could not extract recipe content"))
            }
        }
    }

    private func handleExtractedURL(_ url: URL) async {
        await MainActor.run {
            updateState(.importing(url))
        }

        guard await KeychainService.shared.getToken() != nil else {
            await MainActor.run {
                updateState(.notAuthenticated)
            }
            return
        }

        do {
            _ = try await RecipeImportService.shared.importRecipe(from: url)
            await MainActor.run {
                updateState(.success)
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                close()
            }
        } catch {
            await MainActor.run {
                updateState(.failed(error.localizedDescription))
            }
        }
    }

    private func handleExtractedImage(_ fileURL: URL) async {
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await MainActor.run {
            updateState(.importing(nil))
        }

        guard await KeychainService.shared.getToken() != nil else {
            await MainActor.run {
                updateState(.notAuthenticated)
            }
            return
        }

        guard let compressed = ImageCompressor.compressToJPEG(from: fileURL) else {
            await MainActor.run {
                updateState(.failed("Could not process image"))
            }
            return
        }

        do {
            _ = try await RecipeImportService.shared.importRecipe(from: compressed)
            await MainActor.run {
                updateState(.success)
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                close()
            }
        } catch {
            await MainActor.run {
                updateState(.failed(error.localizedDescription))
            }
        }
    }

    private func openMainApp() {
        guard let appURL = URL(string: "hauptgang://") else { return }
        extensionContext?.open(appURL) { [weak self] _ in
            self?.close()
        }
    }

    private func close() {
        importTask?.cancel()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
