import os
import PhotosUI
import RevenueCatUI
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
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: self.$navigationPath) {
            Group {
                if self.recipeViewModel.recipes.isEmpty && !self.recipeViewModel.isLoading {
                    self.emptyStateView
                } else {
                    self.recipeListView
                }
            }
            .background(Color.hauptgangBackground.ignoresSafeArea())
            .navigationTitle("Your Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.showingImportOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Import Recipe", isPresented: self.$showingImportOptions) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        self.showingCamera = true
                    }
                }
                Button("Choose from Library") {
                    self.showingPhotoPicker = true
                }
            }
            .photosPicker(isPresented: self.$showingPhotoPicker, selection: self.$selectedPhotoItem, matching: .images)
            .task {
                logger.info("RecipesView appeared, configuring recipe view model")
                self.recipeViewModel.configure(modelContext: self.modelContext)
                if let userId = self.authManager.authState.user?.id {
                    await self.recipeViewModel.configureSearchIndex(userId: userId)
                }
                await self.recipeViewModel.refreshRecipes()
            }
            .onChange(of: self.authManager.authState) { _, newValue in
                switch newValue {
                case .unauthenticated:
                    self.recipeViewModel.clearData()
                case let .authenticated(user):
                    Task { await self.recipeViewModel.configureSearchIndex(userId: user.id) }
                case .unknown:
                    break
                }
            }
            .onChange(of: self.scenePhase) { oldPhase, newPhase in
                if oldPhase == .background && newPhase == .active {
                    logger.info("App became active, refreshing recipes")
                    Task {
                        await self.recipeViewModel.refreshRecipes()
                    }
                }
            }
            .onChange(of: self.selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await self.recipeViewModel.importRecipeFromImage(data)
                    }
                    self.selectedPhotoItem = nil
                }
            }
            .fullScreenCover(isPresented: self.$showingCamera) {
                CameraView { imageData in
                    Task {
                        await self.recipeViewModel.importRecipeFromImage(imageData)
                    }
                }
                .ignoresSafeArea()
            }
            .onDisappear {
                self.recipeViewModel.stopPolling()
            }
            .searchable(text: self.$searchQuery, isPresented: self.$isSearching, prompt: "Search recipes")
            .onChange(of: self.searchQuery) { _, newValue in
                Task { await self.recipeViewModel.search(query: newValue) }
            }
            .overlay {
                if self.recipeViewModel.isImporting {
                    self.importingOverlay
                }
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { self.recipeViewModel.importError != nil },
                    set: { if !$0 { self.recipeViewModel.importError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = recipeViewModel.importError {
                    Text(error)
                }
            }
            .sheet(isPresented: Binding(
                get: { self.recipeViewModel.shouldShowPaywall },
                set: { self.recipeViewModel.shouldShowPaywall = $0 }
            )) {
                PaywallView()
            }
        }
        .offlineToast(isOffline: self.recipeViewModel.isOffline, showToast: !self.isScrolledDown)
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
                    let displayedRecipes = self.searchQuery.isEmpty
                        ? self.recipeViewModel.successfulRecipes
                        : self.recipeViewModel.searchResults
                    ForEach(displayedRecipes) { recipe in
                        Button {
                            if self.searchQuery.isEmpty {
                                self.isSearching = false
                            }
                            self.navigationPath.append(recipe.id)
                        } label: {
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
            self.isScrolledDown = isScrolled
        }
        .refreshable {
            await self.recipeViewModel.refreshRecipes()
        }
        .navigationDestination(for: Int.self) { recipeId in
            RecipeDetailView(recipeId: recipeId)
        }
        .overlay(alignment: .bottom) {
            self.failedRecipeBanners
        }
    }

    /// Floating error banners with swipe-to-dismiss
    private var failedRecipeBanners: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(self.recipeViewModel.failedRecipes) { recipe in
                ErrorBannerView(recipe: recipe) {
                    Task {
                        await self.recipeViewModel.dismissFailedRecipe(recipe)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, Theme.Spacing.sm)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.recipeViewModel.failedRecipes.count)
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
                    await self.recipeViewModel.refreshRecipes()
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
