import Foundation
@testable import Hauptgang

actor MockRecipeSearchIndex: RecipeSearchIndexProtocol {
    private(set) var configuredUserId: Int?
    private(set) var available = true
    private(set) var rebuildNeeded = false
    private(set) var indexedNames: [SearchIndexNameInput] = []
    private(set) var indexedDetails: [SearchIndexDetailInput] = []
    private(set) var deletedIds: [Int] = []
    var searchResultIds: [Int] = []

    func setAvailable(_ value: Bool) {
        self.available = value
    }

    func configure(userId: Int) async {
        self.configuredUserId = userId
    }

    func isAvailable() async -> Bool {
        self.available
    }

    func needsRebuild() async -> Bool {
        self.rebuildNeeded
    }

    func rebuildIndex(with recipes: [SearchIndexDetailInput]) async {
        self.indexedDetails = recipes
        self.indexedNames = recipes.map { SearchIndexNameInput(id: $0.id, name: $0.name, updatedAt: $0.updatedAt) }
        self.rebuildNeeded = false
    }

    func indexNames(_ recipes: [SearchIndexNameInput]) async {
        self.indexedNames = recipes
    }

    func indexDetails(_ details: [SearchIndexDetailInput]) async {
        self.indexedDetails = details
    }

    func delete(ids: [Int]) async {
        self.deletedIds.append(contentsOf: ids)
    }

    func search(_ query: String, limit: Int) async -> [Int] {
        let limited = Array(self.searchResultIds.prefix(limit))
        return limited
    }

    func reset() async {
        self.configuredUserId = nil
        self.indexedNames = []
        self.indexedDetails = []
        self.deletedIds = []
    }
}
