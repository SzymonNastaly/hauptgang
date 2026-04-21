import os
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeDetailView")

struct RecipeDetailView: View {
    let recipeId: Int

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RecipeDetailViewModel
    @State private var shoppingListViewModel = ShoppingListViewModel()
    @State private var showShoppingListConfirmation = false
    @State private var isCookingMode = false
    @State private var showEditSheet = false

    init(recipeId: Int, viewModel: RecipeDetailViewModel? = nil) {
        self.recipeId = recipeId
        self._viewModel = State(initialValue: viewModel ?? RecipeDetailViewModel())
    }

    /// Hero image height matching design spec
    private let heroImageHeight: CGFloat = 280

    /// Whether we're running on iOS 26+ (where Liquid Glass nav bar is translucent)
    private var isIOS26: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

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
        .modifier(NavigationBarBackgroundModifier())
        .toolbar {
            if self.viewModel.isRefreshing {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.hauptgangTextSecondary)
                }
            }
            if self.viewModel.recipe != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    self.addToShoppingListToolbarButton
                    self.editToolbarButton
                }
            }
        }
        .sheet(isPresented: self.$showEditSheet) {
            if let recipe = self.viewModel.recipe {
                RecipeEditView(recipe: recipe) {
                    Task {
                        await self.viewModel.loadRecipe(id: self.recipeId)
                    }
                }
            }
        }
        .task(id: self.recipeId) {
            logger.info("RecipeDetailView appeared for recipe id: \(self.recipeId)")
            self.viewModel.configure(modelContext: self.modelContext)
            self.shoppingListViewModel.configure(modelContext: self.modelContext)
            await self.viewModel.loadRecipe(id: self.recipeId)
        }
        .onDisappear {
            if self.isCookingMode {
                self.isCookingMode = false
                UIApplication.shared.isIdleTimerDisabled = false
            }
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
                // Hero image
                if recipe.coverImageUrl != nil {
                    self.heroImage(recipe)
                }

                // Content sections
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Cooking mode button when no hero image
                    if recipe.coverImageUrl == nil {
                        HStack {
                            Spacer()
                            self.cookingModeButton
                        }
                    }

                    // Recipe name
                    Text(recipe.name)
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(.hauptgangTextPrimary)

                    // Duration card - only show if any duration data exists
                    if (recipe.prepTime ?? 0) > 0
                        || (recipe.cookTime ?? 0) > 0
                        || (recipe.servings ?? 0) > 0 {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
                .overlay(alignment: .topTrailing) {
                    if recipe.coverImageUrl != nil {
                        self.cookingModeButton
                            .padding(.trailing, Theme.Spacing.lg)
                            .offset(y: -18)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(edges: recipe.coverImageUrl != nil && self.isIOS26 ? .top : [])
    }

    // MARK: - Hero Image

    @ViewBuilder
    private func heroImage(_ recipe: RecipeDetail) -> some View {
        if let url = Constants.API.resolveURL(recipe.coverImageUrl) {
            Color.clear
                .frame(height: self.heroImageHeight)
                .frame(maxWidth: .infinity)
                .background {
                    CachedRecipeImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                            .overlay {
                                ProgressView()
                                    .tint(.hauptgangTextMuted)
                            }
                    } failure: {
                        Color.hauptgangSurfaceRaised
                    }
                }
                .clipped()
                .overlay(alignment: .top) {
                    if self.isIOS26 {
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .frame(height: 100)
                    }
                }
        }
    }

    // MARK: - Duration Card

    private func durationCard(_ recipe: RecipeDetail) -> some View {
        let hasPrep = (recipe.prepTime ?? 0) > 0
        let hasCook = (recipe.cookTime ?? 0) > 0

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
                    self.ingredientRow(ingredient)
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(Color.hauptgangPrimary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(ingredient)
                .font(.body)
                .foregroundColor(.hauptgangTextPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func handleAddIngredients(_ ingredients: [String]) {
        withAnimation(.smooth(duration: 0.4)) {
            self.shoppingListViewModel.addIngredientsFromRecipe(ingredients, recipeId: self.recipeId)
            self.showShoppingListConfirmation = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.smooth(duration: 0.4)) {
                self.showShoppingListConfirmation = false
            }
        }
    }

    // MARK: - Toolbar Actions

    @ViewBuilder
    private var addToShoppingListToolbarButton: some View {
        if let ingredients = self.viewModel.recipe?.ingredients, !ingredients.isEmpty {
            if #available(iOS 26, *) {
                self.addToShoppingListToolbarButtonGlass(ingredients)
            } else {
                self.addToShoppingListToolbarButtonLegacy(ingredients)
            }
        }
    }

    @available(iOS 26, *)
    private func addToShoppingListToolbarButtonGlass(_ ingredients: [String]) -> some View {
        Button {
            self.handleAddIngredients(ingredients)
        } label: {
            Image(systemName: self.showShoppingListConfirmation ? "checkmark.circle.fill" : "cart.badge.plus")
        }
        .tint(self.showShoppingListConfirmation ? Color.hauptgangSuccess : Color.hauptgangPrimary)
        .accessibilityLabel(self.showShoppingListConfirmation ? "Added to shopping list" : "Add to shopping list")
        .accessibilityHint("Adds this recipe's ingredients to your shopping list")
    }

    private func addToShoppingListToolbarButtonLegacy(_ ingredients: [String]) -> some View {
        Button {
            self.handleAddIngredients(ingredients)
        } label: {
            Image(systemName: self.showShoppingListConfirmation ? "cart.fill" : "cart")
        }
        .accessibilityLabel(self.showShoppingListConfirmation ? "Added to shopping list" : "Add to shopping list")
        .accessibilityHint("Adds this recipe's ingredients to your shopping list")
        .tint(self.showShoppingListConfirmation ? .hauptgangSuccess : .hauptgangPrimary)
    }

    @ViewBuilder
    private var editToolbarButton: some View {
        if #available(iOS 26, *) {
            self.editToolbarButtonGlass
        } else {
            self.editToolbarButtonLegacy
        }
    }

    @available(iOS 26, *)
    private var editToolbarButtonGlass: some View {
        Button {
            self.showEditSheet = true
        } label: {
            Image(systemName: "pencil")
        }
        .tint(Color.hauptgangPrimary)
        .accessibilityLabel("Edit recipe")
    }

    private var editToolbarButtonLegacy: some View {
        Button {
            self.showEditSheet = true
        } label: {
            Image(systemName: "pencil")
        }
        .accessibilityLabel("Edit recipe")
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
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Cooking Mode

    private var cookingModeButton: some View {
        Group {
            if #available(iOS 26, *) {
                self.cookingModeButtonGlass
            } else {
                self.cookingModeButtonLegacy
            }
        }
    }

    @available(iOS 26, *)
    @ViewBuilder
    private var cookingModeButtonGlass: some View {
        let button = Button {
            withAnimation(.smooth(duration: 0.4)) {
                self.isCookingMode.toggle()
            }
            UIApplication.shared.isIdleTimerDisabled = self.isCookingMode
        } label: {
            HStack(spacing: 4) {
                Text("Keep Screen On")

                if self.isCookingMode {
                    Text("(active)")
                        .transition(.push(from: .bottom))
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
        }

        if self.isCookingMode {
            button
                .buttonStyle(.glassProminent)
                .tint(Color.hauptgangPrimary)
        } else {
            button
                .buttonStyle(.glass)
                .tint(Color.hauptgangPrimary)
        }
    }

    private var cookingModeButtonLegacy: some View {
        Button {
            withAnimation(.smooth(duration: 0.4)) {
                self.isCookingMode.toggle()
            }
            UIApplication.shared.isIdleTimerDisabled = self.isCookingMode
        } label: {
            HStack(spacing: 4) {
                Text("Keep Screen On")

                if self.isCookingMode {
                    Text("(active)")
                        .transition(.push(from: .bottom))
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(self.isCookingMode ? .white : Color.hauptgangPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(self.isCookingMode ? Color.hauptgangPrimary : Color.hauptgangSurfaceRaised)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.hauptgangPrimary.opacity(self.isCookingMode ? 0 : 0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(PressDownButtonStyle())
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.hauptgangTextPrimary)
    }
}

// MARK: - Navigation Bar Background

private struct NavigationBarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Press Down Button Style

private struct PressDownButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
