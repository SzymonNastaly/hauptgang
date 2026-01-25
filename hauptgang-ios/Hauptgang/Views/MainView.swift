import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "MainView")

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @State private var recipeViewModel = RecipeViewModel()
    @State private var showingLogoutConfirmation = false

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .tint(.hauptgangPrimary)
                }
            }
            .confirmationDialog(
                "Sign out?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task {
                        recipeViewModel.clearData()
                        await authManager.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
            .task {
                logger.info("MainView appeared, configuring recipe view model")
                recipeViewModel.configure(modelContext: modelContext)
                await recipeViewModel.refreshRecipes()
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
                        RecipeCardView(recipe: recipe)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .refreshable {
            await recipeViewModel.refreshRecipes()
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
    return MainView()
        .environmentObject(authManager)
        .modelContainer(for: PersistedRecipe.self, inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
