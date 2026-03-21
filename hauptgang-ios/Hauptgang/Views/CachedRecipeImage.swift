import SwiftUI
import UIKit

struct CachedRecipeImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let cache: RecipeImageCache
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure

    @State private var phase: Phase = .empty

    init(
        url: URL?,
        cache: RecipeImageCache = .shared,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.cache = cache
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
            case let .success(image):
                content(image)
            case .failure:
                failure()
            }
        }
        .task(id: url) {
            await self.load()
        }
    }

    @MainActor
    private func load() async {
        guard let url else {
            phase = .failure
            return
        }

        phase = .empty

        do {
            let image = try await cache.image(for: url)
            if Task.isCancelled {
                return
            }
            phase = .success(Image(uiImage: image))
        } catch {
            if Task.isCancelled {
                return
            }
            phase = .failure
        }
    }

    enum Phase {
        case empty
        case success(Image)
        case failure
    }
}
