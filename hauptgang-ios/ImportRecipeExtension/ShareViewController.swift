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
        extractURL()
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

    private func extractURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            updateState(.failed("No content found"))
            return
        }

        importTask = Task {
            if let url = await extractURLFromAttachments(attachments) {
                await handleExtractedURL(url)
            } else {
                await MainActor.run {
                    updateState(.failed("Could not extract URL"))
                }
            }
        }
    }

    private func extractURLFromAttachments(_ attachments: [NSItemProvider]) async -> URL? {
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

    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
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

    private func loadURLFromPlainText(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
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

                if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let url = URL(string: text),
                   url.scheme != nil {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
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
