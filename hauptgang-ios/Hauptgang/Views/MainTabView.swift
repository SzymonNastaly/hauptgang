import SwiftUI

/// Main tab view container for authenticated users
struct MainTabView: View {
    @State private var selectedTab: Tab = .recipes
    @State private var shoppingListViewModel = ShoppingListViewModel()

    enum Tab: Hashable {
        case recipes
        case shoppingList
        case mealPlan
        case settings
    }

    var body: some View {
        TabView(selection: self.$selectedTab) {
            SwiftUI.Tab("Recipes", systemImage: "fork.knife", value: Tab.recipes) {
                RecipesView()
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
        }
        .tint(.hauptgangPrimary)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .modifier(TabBarMinimizeModifier())
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
