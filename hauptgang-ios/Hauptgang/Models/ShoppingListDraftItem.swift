import Foundation

struct ShoppingListDraftItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
    }
}

struct ShoppingListReviewDraft: Identifiable {
    let id = UUID()
    let recipeId: Int
    let items: [ShoppingListDraftItem]
}
