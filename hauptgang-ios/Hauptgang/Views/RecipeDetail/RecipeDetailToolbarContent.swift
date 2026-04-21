import SwiftUI

struct RecipeDetailToolbarContent: ToolbarContent {
    let ingredients: [String]
    let showShoppingListConfirmation: Bool
    let onAddToShoppingList: () -> Void
    let onEdit: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            self.addToShoppingListButton
            self.editButton
        }
    }

    @ViewBuilder
    private var addToShoppingListButton: some View {
        if !self.ingredients.isEmpty {
            if #available(iOS 26, *) {
                Button(action: self.onAddToShoppingList) {
                    Image(systemName: self.showShoppingListConfirmation ? "checkmark.circle.fill" : "cart.badge.plus")
                }
                .tint(self.showShoppingListConfirmation ? Color.hauptgangSuccess : Color.hauptgangPrimary)
                .accessibilityLabel(self.showShoppingListConfirmation ? "Added to shopping list" : "Add to shopping list")
                .accessibilityHint("Adds this recipe's ingredients to your shopping list")
            } else {
                Button(action: self.onAddToShoppingList) {
                    Image(systemName: self.showShoppingListConfirmation ? "cart.fill" : "cart")
                }
                .accessibilityLabel(self.showShoppingListConfirmation ? "Added to shopping list" : "Add to shopping list")
                .accessibilityHint("Adds this recipe's ingredients to your shopping list")
                .tint(self.showShoppingListConfirmation ? .hauptgangSuccess : .hauptgangPrimary)
            }
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if #available(iOS 26, *) {
            Button(action: self.onEdit) {
                Image(systemName: "pencil")
            }
            .tint(Color.hauptgangPrimary)
            .accessibilityLabel("Edit recipe")
        } else {
            Button(action: self.onEdit) {
                Image(systemName: "pencil")
            }
            .accessibilityLabel("Edit recipe")
        }
    }
}
