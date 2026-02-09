import SwiftUI

/// Main tab view container for authenticated users
struct MainTabView: View {
    @State private var selectedTab: Tab = .recipes

    enum Tab: Hashable {
        case recipes
        case shoppingList
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }
                .tag(Tab.recipes)

            ShoppingListView()
                .tabItem {
                    Label("Shopping List", systemImage: "cart")
                }
                .tag(Tab.shoppingList)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(.hauptgangPrimary)
    }
}

#Preview {
    let authManager = AuthManager()
    return MainTabView()
        .environmentObject(authManager)
        .modelContainer(for: [PersistedRecipe.self, PersistedShoppingListItem.self], inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
