import SwiftData
import SwiftUI

struct MealPlanRecipePicker: View {
    let cookbookId: Int
    let dateString: String
    let onRecipePicked: (PersistedRecipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var recipes: [PersistedRecipe] = []

    var body: some View {
        NavigationStack {
            Group {
                if self.filteredRecipes.isEmpty {
                    self.emptyState
                } else {
                    self.recipeList
                }
            }
            .background(Color.hauptgangBackground.ignoresSafeArea())
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { self.dismiss() }
                }
            }
            .searchable(text: self.$searchText, prompt: "Search recipes")
            .onAppear { self.loadRecipes() }
        }
    }

    private var filteredRecipes: [PersistedRecipe] {
        if self.searchText.isEmpty {
            return self.recipes
        }
        return self.recipes.filter { $0.name.localizedStandardContains(self.searchText) }
    }

    private var recipeList: some View {
        List(self.filteredRecipes, id: \.id) { recipe in
            Button {
                self.onRecipePicked(recipe)
                self.dismiss()
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    self.recipeImage(recipe)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(recipe.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.hauptgangTextPrimary)
                            .lineLimit(2)

                        if let totalTime = self.totalTime(recipe) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("\(totalTime)m")
                                    .font(.caption)
                            }
                            .foregroundStyle(Color.hauptgangTextSecondary)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .listRowBackground(Color.hauptgangBackground)
            .listRowSeparator(.hidden, edges: recipe.id == self.filteredRecipes.first?.id ? .top : [])
            .listRowSeparator(.hidden, edges: recipe.id == self.filteredRecipes.last?.id ? .bottom : [])
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func recipeImage(_ recipe: PersistedRecipe) -> some View {
        Group {
            if let url = Constants.API.resolveURL(recipe.coverImageUrl) {
                CachedRecipeImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.hauptgangSurfaceRaised
                } failure: {
                    Color.hauptgangSurfaceRaised
                }
            } else {
                Color.hauptgangSurfaceRaised
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Color.hauptgangTextMuted)
                            .font(.caption)
                    }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundStyle(Color.hauptgangTextMuted)
            Text("No recipes found")
                .font(.subheadline)
                .foregroundStyle(Color.hauptgangTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func totalTime(_ recipe: PersistedRecipe) -> Int? {
        let total = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0)
        return total > 0 ? total : nil
    }

    private func loadRecipes() {
        do {
            let descriptor = FetchDescriptor<PersistedRecipe>()
            self.recipes = try self.modelContext.fetch(descriptor)
                .filter { $0.cookbookId == self.cookbookId && $0.importStatus != "failed" }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            self.recipes = []
        }
    }
}
