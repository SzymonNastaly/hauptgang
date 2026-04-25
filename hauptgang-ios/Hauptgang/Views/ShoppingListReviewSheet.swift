import SwiftUI

struct ShoppingListReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let recipeId: Int
    let shoppingListViewModel: ShoppingListViewModel

    @State private var items: [ShoppingListDraftItem]
    @State private var checkedSectionExpanded = true

    init(
        recipeId: Int,
        initialItems: [ShoppingListDraftItem],
        shoppingListViewModel: ShoppingListViewModel
    ) {
        self.recipeId = recipeId
        self.shoppingListViewModel = shoppingListViewModel
        self._items = State(initialValue: initialItems)
    }

    private var uncheckedItems: [ShoppingListDraftItem] {
        self.items.filter { !$0.isChecked }
    }

    private var checkedItems: [ShoppingListDraftItem] {
        self.items.filter(\.isChecked)
    }

    private var addButtonTitle: String {
        "Add \(self.uncheckedItems.count)"
    }

    private var displayUncheckedItems: [ShoppingListDisplayItem] {
        self.uncheckedItems.map { item in
            ShoppingListDisplayItem(
                id: item.id.uuidString,
                name: item.name,
                isChecked: item.isChecked,
                onTap: { self.toggleItem(item) },
                onDelete: nil
            )
        }
    }

    private var displayCheckedItems: [ShoppingListDisplayItem] {
        self.checkedItems.map { item in
            ShoppingListDisplayItem(
                id: item.id.uuidString,
                name: item.name,
                isChecked: item.isChecked,
                onTap: { self.toggleItem(item) },
                onDelete: nil
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ShoppingListSectionsContent(
                    uncheckedItems: self.displayUncheckedItems,
                    checkedItems: self.displayCheckedItems,
                    checkedSectionExpanded: self.$checkedSectionExpanded
                ) {
                    EmptyView()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background(Color.hauptgangBackground.ignoresSafeArea())
            .navigationTitle("Add to Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        self.dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(self.addButtonTitle) {
                        self.confirmAdd()
                    }
                    .disabled(self.uncheckedItems.isEmpty)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func toggleItem(_ item: ShoppingListDraftItem) {
        guard let index = self.items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.snappy(duration: 0.25)) {
            self.items[index].isChecked.toggle()
        }
    }

    private func confirmAdd() {
        let ingredients = self.uncheckedItems.map(\.name)
        self.shoppingListViewModel.addIngredientsFromRecipe(ingredients, recipeId: self.recipeId)
        self.dismiss()
    }
}

#Preview {
    ShoppingListReviewSheet(
        recipeId: 1,
        initialItems: [
            ShoppingListDraftItem(name: "2 onions"),
            ShoppingListDraftItem(name: "1 bunch parsley"),
            ShoppingListDraftItem(name: "500g pasta", isChecked: true)
        ],
        shoppingListViewModel: ShoppingListViewModel()
    )
}
