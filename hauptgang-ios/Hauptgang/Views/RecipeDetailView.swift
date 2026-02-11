import os
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeDetailView")

struct RecipeDetailView: View {
    let recipeId: Int

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RecipeDetailViewModel
    @State private var shoppingListViewModel = ShoppingListViewModel()
    @State private var showShoppingListConfirmation = false

    init(recipeId: Int, viewModel: RecipeDetailViewModel? = nil) {
        self.recipeId = recipeId
        self._viewModel = State(initialValue: viewModel ?? RecipeDetailViewModel())
    }

    /// Hero image height matching design spec
    private let heroImageHeight: CGFloat = 280

    var body: some View {
        Group {
            if self.viewModel.isLoading && self.viewModel.recipe == nil {
                self.loadingView
            } else if let error = viewModel.errorMessage, viewModel.recipe == nil {
                self.errorView(message: error)
            } else if let recipe = viewModel.recipe {
                self.recipeContent(recipe)
            }
        }
        .background(Color.hauptgangBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if self.viewModel.isRefreshing {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.hauptgangTextSecondary)
                }
            }
        }
        .task(id: self.recipeId) {
            logger.info("RecipeDetailView appeared for recipe id: \(self.recipeId)")
            self.viewModel.configure(modelContext: self.modelContext)
            self.shoppingListViewModel.configure(modelContext: self.modelContext)
            await self.viewModel.loadRecipe(id: self.recipeId)
        }
    }

    /// Whether the current recipe has a hero image
    private var hasHeroImage: Bool {
        self.viewModel.recipe?.coverImageUrl != nil
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.hauptgangPrimary)
            Text("Loading recipe...")
                .font(.subheadline)
                .foregroundColor(.hauptgangTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.hauptgangError)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.hauptgangTextSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await self.viewModel.loadRecipe(id: self.recipeId)
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.hauptgangPrimary)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipe Content

    private func recipeContent(_ recipe: RecipeDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image - only show if recipe has a cover image
                if recipe.coverImageUrl != nil {
                    self.heroImage(recipe)
                }

                // Content sections
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Recipe name
                    Text(recipe.name)
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(.hauptgangTextPrimary)

                    // Duration card - only show if any duration data exists
                    let hasDurationData = (recipe.prepTime ?? 0) > 0
                        || (recipe.cookTime ?? 0) > 0
                        || (recipe.servings ?? 0) > 0

                    if hasDurationData {
                        self.durationCard(recipe)
                    }

                    // Ingredients section
                    if !recipe.ingredients.isEmpty {
                        self.ingredientsSection(recipe.ingredients)
                    }

                    // Instructions section
                    if !recipe.instructions.isEmpty {
                        self.instructionsSection(recipe.instructions)
                    }

                    // Notes section
                    if let notes = recipe.notes, !notes.isEmpty {
                        self.notesSection(notes)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(edges: recipe.coverImageUrl != nil ? .top : [])
    }

    // MARK: - Hero Image

    @ViewBuilder
    private func heroImage(_ recipe: RecipeDetail) -> some View {
        if let url = Constants.API.resolveURL(recipe.coverImageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.2)
                        .overlay {
                            ProgressView()
                                .tint(.hauptgangTextMuted)
                        }
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    // Show muted background on load failure
                    Color.hauptgangSurfaceRaised
                @unknown default:
                    Color.hauptgangSurfaceRaised
                }
            }
            .frame(height: self.heroImageHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            // Top gradient for status bar readability
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.5), location: 0),
                        .init(color: .black.opacity(0.25), location: 0.4),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120) // Covers status bar + Dynamic Island + some extra
            }
        }
    }

    // MARK: - Duration Card

    private func durationCard(_ recipe: RecipeDetail) -> some View {
        let hasPrep = (recipe.prepTime ?? 0) > 0
        let hasCook = (recipe.cookTime ?? 0) > 0
        let hasServings = (recipe.servings ?? 0) > 0

        return HStack(spacing: 0) {
            if let prepTime = recipe.prepTime, prepTime > 0 {
                self.durationItem(icon: "clock", label: "Prep", value: "\(prepTime)m")
            }

            if let cookTime = recipe.cookTime, cookTime > 0 {
                if hasPrep {
                    Divider()
                        .frame(height: 32)
                }
                self.durationItem(icon: "flame", label: "Cook", value: "\(cookTime)m")
            }

            if let servings = recipe.servings, servings > 0 {
                if hasPrep || hasCook {
                    Divider()
                        .frame(height: 32)
                }
                self.durationItem(icon: "person.2", label: "Servings", value: "\(servings)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.hauptgangSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
    }

    private func durationItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.hauptgangPrimary)

            Text(value)
                .font(.headline)
                .foregroundColor(.hauptgangTextPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(.hauptgangTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ingredients Section

    private func ingredientsSection(_ ingredients: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            self.sectionHeader("Ingredients")

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ingredient in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Circle()
                            .fill(Color.hauptgangPrimary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(ingredient)
                            .font(.body)
                            .foregroundColor(.hauptgangTextPrimary)
                    }
                }
            }

            Button {
                self.shoppingListViewModel.addIngredientsFromRecipe(ingredients, recipeId: self.recipeId)
                self.showShoppingListConfirmation = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    self.showShoppingListConfirmation = false
                }
            } label: {
                Label("Add to shopping list", systemImage: "cart.badge.plus")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.hauptgangPrimary)

            if self.showShoppingListConfirmation {
                Label("Added to shopping list", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.hauptgangSuccess)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Instructions Section

    private func instructionsSection(_ instructions: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            self.sectionHeader("Steps")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        // Step number badge
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.hauptgangPrimary)
                            .clipShape(Circle())

                        Text(instruction)
                            .font(.body)
                            .foregroundColor(.hauptgangTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            self.sectionHeader("Notes")

            Text(notes)
                .font(.body)
                .foregroundColor(.hauptgangTextSecondary)
                .italic()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.hauptgangTextPrimary)
    }
}

// MARK: - Previews

#Preview("With data") {
    // Can inject a mock ViewModel for testing/previews
    NavigationStack {
        RecipeDetailView(recipeId: 1)
    }
}

#Preview("Loading") {
    NavigationStack {
        RecipeDetailView(recipeId: 999)
    }
}
