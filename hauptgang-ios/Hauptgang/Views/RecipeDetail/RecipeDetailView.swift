import os
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeDetailView")

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let recipeId: Int

    @State private var viewModel: RecipeDetailViewModel
    @State private var shoppingListViewModel = ShoppingListViewModel()
    @State private var showShoppingListConfirmation = false
    @State private var isCookingMode = false
    @State private var showEditSheet = false

    private let heroImageHeight: CGFloat = 280

    private var isIOS26: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    private var showsLoadingState: Bool {
        self.viewModel.isLoading && self.viewModel.recipe == nil
    }

    private var errorMessageForDisplay: String? {
        guard !self.showsLoadingState, self.viewModel.recipe == nil else {
            return nil
        }

        return self.viewModel.errorMessage
    }

    init(recipeId: Int, viewModel: RecipeDetailViewModel? = nil) {
        self.recipeId = recipeId
        self._viewModel = State(initialValue: viewModel ?? RecipeDetailViewModel())
    }

    var body: some View {
        ZStack {
            if let recipe = self.viewModel.recipe {
                RecipeDetailContentView(
                    recipe: recipe,
                    heroImageHeight: self.heroImageHeight,
                    isIOS26: self.isIOS26,
                    isCookingMode: self.isCookingMode,
                    onToggleCookingMode: self.toggleCookingMode
                )
            }

            if self.showsLoadingState {
                RecipeDetailLoadingView()
            }

            if let errorMessage = self.errorMessageForDisplay {
                RecipeDetailErrorView(message: errorMessage, onRetry: self.retryLoad)
            }
        }
        .background(Color.hauptgangBackground)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(NavigationBarBackgroundModifier())
        .toolbar {
            if let recipe = self.viewModel.recipe {
                RecipeDetailToolbarContent(
                    ingredients: recipe.ingredients,
                    showShoppingListConfirmation: self.showShoppingListConfirmation,
                    onAddToShoppingList: { self.handleAddIngredients(recipe.ingredients) },
                    onEdit: self.showEditRecipe
                )
            }
        }
        .sheet(isPresented: self.$showEditSheet) {
            if let recipe = self.viewModel.recipe {
                RecipeEditView(recipe: recipe, onSave: self.reloadRecipeAfterEdit)
            }
        }
        .task(id: self.recipeId) {
            await self.loadRecipeTask()
        }
        .onDisappear {
            self.resetCookingModeIfNeeded()
        }
    }

    private func loadRecipeTask() async {
        logger.info("RecipeDetailView appeared for recipe id: \(self.recipeId)")
        self.viewModel.configure(modelContext: self.modelContext)
        self.shoppingListViewModel.configure(modelContext: self.modelContext)
        await self.viewModel.loadRecipe(id: self.recipeId)
    }

    private func retryLoad() {
        Task {
            await self.viewModel.loadRecipe(id: self.recipeId)
        }
    }

    private func reloadRecipeAfterEdit() {
        Task {
            await self.viewModel.loadRecipe(id: self.recipeId)
        }
    }

    private func showEditRecipe() {
        self.showEditSheet = true
    }

    private func toggleCookingMode() {
        withAnimation(.smooth(duration: 0.4)) {
            self.isCookingMode.toggle()
        }
        UIApplication.shared.isIdleTimerDisabled = self.isCookingMode
    }

    private func resetCookingModeIfNeeded() {
        guard self.isCookingMode else {
            return
        }

        self.isCookingMode = false
        UIApplication.shared.isIdleTimerDisabled = false
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
}

private struct RecipeDetailLoadingView: View {
    var body: some View {
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
}

private struct RecipeDetailErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.hauptgangError)

            Text(self.message)
                .font(.subheadline)
                .foregroundColor(.hauptgangTextSecondary)
                .multilineTextAlignment(.center)

            Button(action: self.onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.hauptgangPrimary)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NavigationBarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview("With data") {
    NavigationStack {
        RecipeDetailView(recipeId: 1)
    }
}

#Preview("Loading") {
    NavigationStack {
        RecipeDetailView(recipeId: 999)
    }
}
