import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipesView")

struct RecipesView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @State private var recipeViewModel = RecipeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if recipeViewModel.recipes.isEmpty && !recipeViewModel.isLoading {
                    emptyStateView
                } else {
                    recipeListView
                }
            }
            .background(Color.hauptgangBackground)
            .navigationTitle("Your Recipes")
            .navigationBarTitleDisplayMode(.large)
            .task {
                logger.info("RecipesView appeared, configuring recipe view model")
                recipeViewModel.configure(modelContext: modelContext)
                await recipeViewModel.refreshRecipes()
            }
            .onChange(of: authManager.authState) { _, newValue in
                if case .unauthenticated = newValue {
                    recipeViewModel.clearData()
                }
            }
        }
    }

    // MARK: - Subviews

    private var recipeListView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                // Error message if present
                if let error = recipeViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.hauptgangError)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                // Recipe cards
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(recipeViewModel.recipes) { recipe in
                        NavigationLink(value: recipe.id) {
                            RecipeCardView(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .refreshable {
            await recipeViewModel.refreshRecipes()
        }
        .navigationDestination(for: Int.self) { recipeId in
            RecipeDetailView(recipeId: recipeId)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "fork.knife")
                .font(.system(size: 60))
                .foregroundColor(.hauptgangTextMuted)

            VStack(spacing: Theme.Spacing.sm) {
                Text("No recipes yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.hauptgangTextPrimary)

                Text("Your recipes will appear here")
                    .font(.subheadline)
                    .foregroundColor(.hauptgangTextSecondary)

                if let error = recipeViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.hauptgangError)
                        .padding(.top, Theme.Spacing.xs)
                }
            }

            Button {
                Task {
                    await recipeViewModel.refreshRecipes()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.hauptgangPrimary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let authManager = AuthManager()
    return RecipesView()
        .environmentObject(authManager)
        .modelContainer(for: PersistedRecipe.self, inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
