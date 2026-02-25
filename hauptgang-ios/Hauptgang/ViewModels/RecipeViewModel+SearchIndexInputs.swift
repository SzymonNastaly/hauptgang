import Foundation

extension RecipeViewModel {
    func nameInputs(from recipes: [PersistedRecipe]) -> [SearchIndexNameInput] {
        recipes.map {
            SearchIndexNameInput(id: $0.id, name: $0.name, updatedAt: $0.updatedAt)
        }
    }

    func detailInputs(from recipes: [PersistedRecipe]) -> [SearchIndexDetailInput] {
        recipes.map {
            SearchIndexDetailInput(
                id: $0.id,
                name: $0.name,
                ingredients: $0.ingredients,
                instructions: $0.instructions,
                updatedAt: $0.updatedAt
            )
        }
    }

    func detailInputs(from recipes: [RecipeDetail]) -> [SearchIndexDetailInput] {
        recipes.map {
            SearchIndexDetailInput(
                id: $0.id,
                name: $0.name,
                ingredients: $0.ingredients,
                instructions: $0.instructions,
                updatedAt: $0.updatedAt
            )
        }
    }
}
