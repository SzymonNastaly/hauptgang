import Foundation
import os
import SwiftData
import SwiftUI

@MainActor @Observable
final class ShoppingListViewModel {
    private(set) var items: [PersistedShoppingListItem] = []
    private(set) var isSyncing = false
    private(set) var isOffline = false
    private var recentlyCheckedIds: Set<String> = []

    var uncheckedItems: [PersistedShoppingListItem] {
        items.filter { !$0.isChecked || recentlyCheckedIds.contains($0.clientId) }
    }

    var checkedItems: [PersistedShoppingListItem] {
        items.filter { $0.isChecked && !recentlyCheckedIds.contains($0.clientId) }
    }

    private let repository: ShoppingListRepositoryProtocol
    private let service: ShoppingListServiceProtocol
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "ShoppingListViewModel")

    init(
        repository: ShoppingListRepositoryProtocol? = nil,
        service: ShoppingListServiceProtocol = ShoppingListService.shared
    ) {
        self.repository = repository ?? ShoppingListRepository()
        self.service = service
    }

    func configure(modelContext: ModelContext) {
        repository.configure(modelContext: modelContext)
        loadCachedItems()
    }

    func refresh() async {
        guard !isSyncing else { return }

        isSyncing = true
        isOffline = false

        await syncPendingChanges()

        do {
            let apiItems = try await service.fetchItems()
            try repository.saveItems(apiItems)
            try repository.deleteStaleItems()
            loadCachedItems()
        } catch {
            logger.error("Failed to refresh shopping list: \(error.localizedDescription)")
            if let apiError = error as? APIError, case .networkError = apiError {
                isOffline = true
            }
        }

        isSyncing = false
    }

    func addIngredientsFromRecipe(_ ingredients: [String], recipeId: Int?) {
        let trimmed = ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }

        let newItems = trimmed.map {
            ShoppingListItemCreate(
                clientId: UUID().uuidString,
                name: $0,
                checkedAt: nil,
                sourceRecipeId: recipeId
            )
        }

        do {
            try repository.addLocalItems(newItems)
            loadCachedItems()
            Task { await syncPendingChanges() }
        } catch {
            logger.error("Failed to add ingredients: \(error.localizedDescription)")
        }
    }

    func addCustomItem(_ text: String) {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let newItem = ShoppingListItemCreate(
            clientId: UUID().uuidString,
            name: name,
            checkedAt: nil,
            sourceRecipeId: nil
        )

        do {
            try repository.addLocalItems([ newItem ])
            loadCachedItems()
            Task { await syncPendingChanges() }
        } catch {
            logger.error("Failed to add custom item: \(error.localizedDescription)")
        }
    }

    func toggleItem(_ item: PersistedShoppingListItem) {
        let isChecking = !item.isChecked
        let newCheckedAt = isChecking ? Date() : nil
        let clientId = item.clientId

        do {
            try repository.updateItem(clientId: clientId, checkedAt: newCheckedAt)

            if isChecking {
                recentlyCheckedIds.insert(clientId)
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        recentlyCheckedIds.remove(clientId)
                        loadCachedItems()
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    loadCachedItems()
                }
            }

            Task { await syncPendingChanges() }
        } catch {
            logger.error("Failed to update item: \(error.localizedDescription)")
        }
    }

    func deleteItem(_ item: PersistedShoppingListItem) {
        let serverId = item.serverId

        do {
            try repository.deleteItem(clientId: item.clientId)
            loadCachedItems()
        } catch {
            logger.error("Failed to delete item locally: \(error.localizedDescription)")
        }

        guard let serverId else { return }
        Task {
            do {
                try await service.deleteItem(id: serverId)
            } catch {
                logger.error("Failed to delete item from server: \(error.localizedDescription)")
            }
        }
    }

    func clearData() {
        do {
            try repository.clearAll()
            items = []
        } catch {
            logger.error("Failed to clear shopping list data: \(error.localizedDescription)")
        }
    }

    private func syncPendingChanges() async {
        do {
            let pendingCreates = try repository.getPendingCreates()
            if !pendingCreates.isEmpty {
                let payload = pendingCreates.map {
                    ShoppingListItemCreate(
                        clientId: $0.clientId,
                        name: $0.name,
                        checkedAt: $0.checkedAt,
                        sourceRecipeId: $0.sourceRecipeId
                    )
                }

                let created = try await service.createItems(payload)
                try repository.saveItems(created)
            }

            let pendingUpdates = try repository.getPendingUpdates()
            for item in pendingUpdates {
                guard let serverId = item.serverId else { continue }
                do {
                    let updated = try await service.updateItem(
                        id: serverId,
                        checked: item.isChecked,
                        checkedAt: item.checkedAt
                    )
                    try repository.updateItemFromServer(clientId: item.clientId, response: updated)
                } catch APIError.notFound {
                    // Item was deleted on server (e.g., stale cleanup) — remove local copy
                    logger.info("Item \(serverId) not found on server, removing local copy")
                    try? repository.deleteItem(clientId: item.clientId)
                }
            }
        } catch {
            logger.error("Failed to sync pending changes: \(error.localizedDescription)")
            if let apiError = error as? APIError, case .networkError = apiError {
                isOffline = true
            }
        }
    }

    private func loadCachedItems() {
        do {
            items = try repository.getAllItems()
        } catch {
            logger.error("Failed to load cached shopping list items: \(error.localizedDescription)")
        }
    }
}
