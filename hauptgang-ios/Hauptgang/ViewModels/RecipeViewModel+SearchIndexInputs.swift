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
                ingredients: Self.searchableIngredients(structured: $0.structuredIngredients, raw: $0.ingredients),
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
                ingredients: Self.searchableIngredients(
                    structured: $0.structuredIngredients ?? [],
                    raw: $0.ingredients
                ),
                instructions: $0.instructions,
                updatedAt: $0.updatedAt
            )
        }
    }

    /// Build ingredient tokens for the fuzzy search index. Prefer the parsed
    /// `name` for cleaner matches; fall back to `raw` when name is empty or
    /// the row hasn't been parsed yet.
    private static func searchableIngredients(
        structured: [StructuredIngredient],
        raw: [String]
    ) -> [String] {
        guard !structured.isEmpty else { return raw }

        return structured.map { ingredient in
            let name = (ingredient.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? ingredient.raw : name
        }
    }
}
