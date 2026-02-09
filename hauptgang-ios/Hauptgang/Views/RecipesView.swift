import os
import PhotosUI
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipesView")

struct RecipesView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var recipeViewModel = RecipeViewModel()

    @State private var showingImportOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isScrolledDown = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImportOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Import Recipe", isPresented: $showingImportOptions) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        showingCamera = true
                    }
                }
                Button("Choose from Library") {
                    showingPhotoPicker = true
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await recipeViewModel.importRecipeFromImage(data)
                    }
                    selectedPhotoItem = nil
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { imageData in
                    Task {
                        await recipeViewModel.importRecipeFromImage(imageData)
                    }
                }
                .ignoresSafeArea()
            }
            .onDisappear {
                recipeViewModel.stopPolling()
            }
            .overlay {
                if recipeViewModel.isImporting {
                    importingOverlay
                }
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { recipeViewModel.importError != nil },
                    set: { if !$0 { recipeViewModel.importError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = recipeViewModel.importError {
                    Text(error)
                }
            }
        }
        .offlineToast(isOffline: recipeViewModel.isOffline, showToast: !isScrolledDown)
    }

    // MARK: - Subviews

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Importing recipe...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(Theme.Spacing.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        }
    }

    private var recipeListView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
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
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 10
        } action: { _, isScrolled in
            isScrolledDown = isScrolled
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
