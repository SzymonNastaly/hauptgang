import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "MainView")

/// Hides toolbar background on iOS 18+ to avoid Liquid Glass effect
struct HiddenToolbarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @State private var recipeViewModel = RecipeViewModel()
    @State private var showingLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.hauptgangBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with user info
                    headerView
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.sm)

                    // Recipe list or empty state
                    if recipeViewModel.recipes.isEmpty && !recipeViewModel.isLoading {
                        emptyStateView
                    } else {
                        recipeListView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Color.hauptgangPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .modifier(HiddenToolbarBackgroundModifier())
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

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Your Recipes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.hauptgangTextPrimary)

                if let user = authManager.authState.user {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.hauptgangTextSecondary)
                }
            }

            Spacer()

            // Recipe count badge
            if !recipeViewModel.recipes.isEmpty {
                Text("\(recipeViewModel.recipes.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.hauptgangPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.hauptgangPrimary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
            }
        }
    }

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
