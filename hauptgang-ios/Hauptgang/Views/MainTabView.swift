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
        TabView(selection: self.$selectedTab) {
            SwiftUI.Tab("Recipes", systemImage: "fork.knife", value: Tab.recipes) {
                RecipesView()
            }

            SwiftUI.Tab("Shopping List", systemImage: "cart", value: Tab.shoppingList) {
                ShoppingListView()
            }

            SwiftUI.Tab("Settings", systemImage: "gearshape", value: Tab.settings) {
                SettingsView()
            }
        }
        .tint(.hauptgangPrimary)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
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
