import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipesView")

struct RecipesView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase == .background && newPhase == .active {
                    logger.info("App became active, refreshing recipes")
                    Task {
                        await recipeViewModel.refreshRecipes()
                    }
                }
            }
            .onDisappear {
                recipeViewModel.stopPolling()
            }
        }
    }

    // MARK: - Subviews

    private var recipeListView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                // Global error message (API failures)
                if let error = recipeViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.hauptgangError)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                // Successful recipe cards
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(recipeViewModel.successfulRecipes) { recipe in
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
        .overlay(alignment: .bottom) {
            failedRecipeBanners
        }
    }

    /// Floating error banners with swipe-to-dismiss
    private var failedRecipeBanners: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(recipeViewModel.failedRecipes) { recipe in
                ErrorBannerView(recipe: recipe) {
                    Task {
                        await recipeViewModel.dismissFailedRecipe(recipe)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, Theme.Spacing.sm)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: recipeViewModel.failedRecipes.count)
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
