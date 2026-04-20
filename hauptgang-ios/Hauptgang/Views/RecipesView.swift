import os
import PhotosUI
import RevenueCatUI
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipesView")

/// Lightweight value capturing the info needed for the delete confirmation dialog,
/// avoiding holding a SwiftData model object in @State after deletion.
struct DeleteCandidate: Identifiable {
    let id: Int
    let name: String
}

struct MoveCandidate: Identifiable {
    let id: Int
    let name: String
    let targetCookbookId: Int
    let targetCookbookName: String
}

private struct ClipboardContent: Identifiable {
    let id = UUID()
    let text: String
}

struct RecipesView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    var recipeViewModel: RecipeViewModel

    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isScrolledDown = false
    @State private var navigationPath = NavigationPath()
    @State private var recipeToDelete: DeleteCandidate?
    @State private var recipeToMove: MoveCandidate?
    @State private var clipboardContent: ClipboardContent?

    var body: some View {
        NavigationStack(path: self.$navigationPath) {
            self.recipeContent
        }
        .offlineToast(isOffline: self.networkMonitor.isOffline, showToast: !self.isScrolledDown)
    }

    private var recipeContent: some View {
        self.recipeLayout
            .task {
                logger.info("RecipesView appeared, configuring recipe view model")
                self.recipeViewModel.configure(modelContext: self.modelContext)
                if let userId = self.authManager.authState.user?.id {
                    let cookbookId = self.cookbookViewModel.activeCookbook?.id ?? 0
                    await self.recipeViewModel.configureSearchIndex(userId: userId, cookbookId: cookbookId)
                }
                await self.recipeViewModel.refreshRecipes()
            }
            .onChange(of: self.authManager.authState) { _, newValue in
                self.handleAuthChange(newValue)
            }
            .onChange(of: self.cookbookViewModel.activeCookbook?.id) { _, _ in
                self.handleCookbookSwitch()
            }
            .onChange(of: self.recipeViewModel.didReceiveForbidden) { _, forbidden in
                guard forbidden else { return }
                self.recipeViewModel.didReceiveForbidden = false
                Task {
                    await self.cookbookViewModel.handleForbidden()
                    await self.recipeViewModel.refreshRecipes()
                }
            }
            .onChange(of: self.scenePhase) { oldPhase, newPhase in
                if oldPhase == .background && newPhase == .active {
                    Task {
                        // Refresh cookbooks first — if the initial load failed while offline,
                        // this recovers the cookbook list and active selection.
                        await self.cookbookViewModel.refresh()
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
                    Task { await self.recipeViewModel.importRecipeFromImage(imageData) }
                }
                .ignoresSafeArea()
            }
            .onDisappear {
                self.recipeViewModel.stopPolling()
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
            .sheet(item: self.$clipboardContent) { content in
                ClipboardPreviewSheet(text: content.text) {
                    self.clipboardContent = nil
                    Task { await self.recipeViewModel.importRecipeFromText(content.text) }
                }
            }
    }

    private var recipeLayout: some View {
        Group {
            if self.recipeViewModel.recipes.isEmpty && !self.recipeViewModel.isLoading {
                self.emptyStateView
            } else {
                self.recipeListView
            }
        }
        .background(Color.hauptgangBackground.ignoresSafeArea())
        .navigationTitle(self.cookbookViewModel.activeCookbook?.name ?? "Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            ForEach(self.cookbookViewModel.cookbooks) { cookbook in
                Button {
                    Task { await self.cookbookViewModel.setActiveCookbook(cookbook) }
                } label: {
                    let isActive = cookbook.id == self.cookbookViewModel.activeCookbook?.id
                    Label(
                        cookbook.name,
                        systemImage: isActive ? "checkmark" : (cookbook.personal ? "person.fill" : "person.2.fill")
                    )
                }
                .disabled(cookbook.id == self.cookbookViewModel.activeCookbook?.id)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            self.showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                    Button {
                        self.showingPhotoPicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        if let text = UIPasteboard.general.string, !text.isEmpty {
                            self.clipboardContent = ClipboardContent(text: text)
                        } else {
                            self.recipeViewModel.importError =
                                "Nothing to paste. Copy a recipe to your clipboard first."
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .photosPicker(isPresented: self.$showingPhotoPicker, selection: self.$selectedPhotoItem, matching: .images)
    }

    // MARK: - Handlers

    private func handleAuthChange(_ newValue: AuthManager.AuthState) {
        switch newValue {
        case .unauthenticated:
            self.recipeViewModel.clearData()
        case let .authenticated(user):
            let cookbookId = self.cookbookViewModel.activeCookbook?.id ?? 0
            Task { await self.recipeViewModel.configureSearchIndex(userId: user.id, cookbookId: cookbookId) }
        case .unknown:
            break
        }
    }

    private func handleCookbookSwitch() {
        guard let userId = self.authManager.authState.user?.id else { return }
        let cookbookId = self.cookbookViewModel.activeCookbook?.id ?? 0
        self.recipeViewModel.resetForCookbookSwitch()
        Task {
            await self.recipeViewModel.configureSearchIndex(userId: userId, cookbookId: cookbookId)
            await self.recipeViewModel.refreshRecipes()
        }
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
            .modifier(ImportingOverlayBackground())
        }
    }

    private var recipeListView: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(self.recipeViewModel.successfulRecipes) { recipe in
                    self.recipeRow(recipe)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .scrollDismissesKeyboard(.immediately)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 10
        } action: { _, isScrolled in
            self.isScrolledDown = isScrolled
        }
        .refreshable {
            await self.networkMonitor.refreshStatus()
            await self.cookbookViewModel.refresh()
            await self.recipeViewModel.refreshRecipes()
        }
        .navigationDestination(for: Int.self) { recipeId in
            RecipeDetailView(recipeId: recipeId)
        }
        .overlay(alignment: .bottom) {
            self.failedRecipeBanners
        }
    }

    private func recipeRow(_ recipe: PersistedRecipe) -> some View {
        Button {
            self.navigationPath.append(recipe.id)
        } label: {
            RecipeCardView(recipe: recipe)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let targetCookbook = self.cookbookViewModel.cookbooks.first(where: {
                $0.id != self.cookbookViewModel.activeCookbook?.id
            }) {
                Button {
                    self.recipeToMove = MoveCandidate(
                        id: recipe.id,
                        name: recipe.name,
                        targetCookbookId: targetCookbook.id,
                        targetCookbookName: targetCookbook.name
                    )
                } label: {
                    Label("Move to \(targetCookbook.name)", systemImage: "arrow.right.arrow.left")
                }
            }
            Button(role: .destructive) {
                self.recipeToDelete = DeleteCandidate(id: recipe.id, name: recipe.name)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Recipe",
            isPresented: Binding(
                get: { self.recipeToDelete?.id == recipe.id },
                set: { if !$0 { self.recipeToDelete = nil } }
            ),
            presenting: self.recipeToDelete
        ) { candidate in
            Button("Delete", role: .destructive) {
                Task {
                    await self.recipeViewModel.deleteRecipe(id: candidate.id)
                }
            }
        } message: { _ in
            Text("Are you sure?")
        }
        .confirmationDialog(
            "Move Recipe",
            isPresented: Binding(
                get: { self.recipeToMove?.id == recipe.id },
                set: { if !$0 { self.recipeToMove = nil } }
            ),
            presenting: self.recipeToMove
        ) { candidate in
            Button("Move to \(candidate.targetCookbookName)") {
                Task {
                    await self.recipeViewModel.moveRecipe(
                        id: candidate.id,
                        toCookbookId: candidate.targetCookbookId
                    )
                }
            }
        } message: { candidate in
            Text("Move \"\(candidate.name)\" to \(candidate.targetCookbookName)?")
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

private struct ImportingOverlayBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: Theme.CornerRadius.lg))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        }
    }
}

#Preview {
    let authManager = AuthManager()
    return RecipesView(recipeViewModel: RecipeViewModel())
        .environmentObject(authManager)
        .environment(CookbookViewModel())
        .environment(NetworkMonitor.shared)
        .modelContainer(for: PersistedRecipe.self, inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
