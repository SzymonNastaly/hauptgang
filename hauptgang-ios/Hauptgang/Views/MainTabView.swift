import SwiftUI

/// Main tab view container for authenticated users
struct MainTabView: View {
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @State private var selectedTab: Tab = .recipes
    @State private var shoppingListViewModel = ShoppingListViewModel()
    @State private var recipeViewModel = RecipeViewModel()
    @State private var searchQuery = ""
    @State private var showsStartupSplash = true

    enum Tab: Hashable {
        case recipes
        case shoppingList
        case mealPlan
        case settings
        case search
    }

    var body: some View {
        ZStack {
            self.tabContent

            if self.showsStartupSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .tint(.hauptgangPrimary)
        .modifier(TabBarBackgroundModifier())
        .modifier(TabBarMinimizeModifier())
        .modifier(TabSearchActivationModifier())
        .onChange(of: self.searchQuery) { _, newValue in
            Task { await self.recipeViewModel.search(query: newValue) }
        }
        .onChange(of: self.startupCanDismissSplash, initial: true) { _, canDismiss in
            guard canDismiss, self.showsStartupSplash else { return }
            withAnimation(.easeOut(duration: 0.08)) {
                self.showsStartupSplash = false
            }
        }
    }

    private var tabContent: some View {
        TabView(selection: self.$selectedTab) {
            SwiftUI.Tab("Recipes", systemImage: "fork.knife", value: Tab.recipes) {
                RecipesView(
                    recipeViewModel: self.recipeViewModel,
                    suppressTransientUI: self.showsStartupSplash
                )
            }

            SwiftUI.Tab("Shopping List", systemImage: "cart", value: Tab.shoppingList) {
                ShoppingListView(viewModel: self.shoppingListViewModel)
            }

            SwiftUI.Tab("Meal Plan", systemImage: "calendar", value: Tab.mealPlan) {
                MealPlanView()
            }

            SwiftUI.Tab("Settings", systemImage: "gearshape", value: Tab.settings) {
                SettingsView()
            }

            SwiftUI.Tab(value: Tab.search, role: .search) {
                RecipeSearchView(recipeViewModel: self.recipeViewModel, searchQuery: self.$searchQuery)
            }
        }
    }

    private var startupCanDismissSplash: Bool {
        self.cookbookViewModel.error != nil || (
            !self.cookbookViewModel.isLoading &&
            self.cookbookViewModel.activeCookbook != nil &&
            self.recipeViewModel.hasResolvedInitialContent
        )
    }
}

private struct TabBarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.toolbarBackgroundVisibility(.visible, for: .tabBar)
        }
    }
}

private struct TabBarMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

private struct TabSearchActivationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabViewSearchActivation(.searchTabSelection)
        } else {
            content
        }
    }
}

#Preview {
    let authManager = AuthManager()
    return MainTabView()
        .environmentObject(authManager)
        .environment(CookbookViewModel())
        .modelContainer(
            for: [
                PersistedRecipe.self,
                PersistedShoppingListItem.self,
                PersistedMealPlanDay.self,
                PersistedMealPlanEntry.self
            ],
            inMemory: true
        )
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
