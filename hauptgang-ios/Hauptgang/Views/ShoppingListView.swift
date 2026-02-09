import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ShoppingListViewModel()
    @State private var newItemText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.sm) {
                addItemBar
                    .padding(.horizontal, Theme.Spacing.lg)

                if viewModel.items.isEmpty && !viewModel.isSyncing {
                    emptyState
                } else {
                    listView
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .background(Color.hauptgangBackground)
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.isSyncing {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.hauptgangTextSecondary)
                    }
                }
            }
            .task {
                viewModel.configure(modelContext: modelContext)
                await viewModel.refresh()
            }
            .onChange(of: authManager.authState) { _, newValue in
                if case .unauthenticated = newValue {
                    viewModel.clearData()
                }
            }
        }
        .offlineToast(isOffline: viewModel.isOffline)
    }

    private var addItemBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Add item", text: $newItemText)
                    .themeTextField()
                    .onSubmit(addCustomItem)

                Button {
                    addCustomItem()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(Color.hauptgangPrimary)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
                }
                .buttonStyle(.plain)
            }

        }
    }

    private var listView: some View {
        List {
            if !viewModel.uncheckedItems.isEmpty {
                Section("To Buy") {
                    ForEach(viewModel.uncheckedItems) { item in
                        itemRow(item)
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet, from: viewModel.uncheckedItems)
                    }
                }
            }

            if !viewModel.checkedItems.isEmpty {
                Section("Checked") {
                    ForEach(viewModel.checkedItems) { item in
                        itemRow(item)
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet, from: viewModel.checkedItems)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func itemRow(_ item: PersistedShoppingListItem) -> some View {
        Button {
            viewModel.toggleItem(item)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isChecked ? Color.hauptgangSuccess : .hauptgangTextMuted)
                    .contentTransition(.symbolEffect(.replace))

                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isChecked ? Color.hauptgangTextSecondary : .hauptgangTextPrimary)
                    .strikethrough(item.isChecked, color: .hauptgangTextMuted)
                    .opacity(item.isChecked ? 0.6 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.hauptgangBackground)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()

            Image(systemName: "cart")
                .font(.system(size: 50))
                .foregroundStyle(Color.hauptgangTextMuted)

            Text("Your shopping list is empty")
                .font(.headline)
                .foregroundStyle(Color.hauptgangTextPrimary)

            Text("Add items from a recipe or type your own")
                .font(.subheadline)
                .foregroundStyle(Color.hauptgangTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func addCustomItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.addCustomItem(trimmed)
        newItemText = ""
    }

    private func deleteItems(at indexSet: IndexSet, from items: [PersistedShoppingListItem]) {
        for index in indexSet {
            let item = items[index]
            viewModel.deleteItem(item)
        }
    }

}

#Preview {
    let authManager = AuthManager()
    return ShoppingListView()
        .environmentObject(authManager)
        .modelContainer(for: PersistedShoppingListItem.self, inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
