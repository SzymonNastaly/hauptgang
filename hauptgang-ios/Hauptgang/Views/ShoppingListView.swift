import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ShoppingListViewModel()
    @State private var newItemText = ""
    @State private var showRemoveAllConfirmation = false
    @FocusState private var isAddItemFocused: Bool

    var body: some View {
        NavigationStack {
            self.screenContent
        }
        .offlineToast(isOffline: self.viewModel.isOffline)
    }

    private var screenContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            self.addItemBar
                .padding(.horizontal, Theme.Spacing.lg)

            if self.viewModel.items.isEmpty {
                self.emptyState
            } else {
                self.listView
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .refreshable {
            await self.viewModel.refresh()
        }
        .background(Color.hauptgangBackground.ignoresSafeArea())
        .onTapGesture {
            self.isAddItemFocused = false
        }
        .navigationTitle(self.cookbookViewModel.activeCookbook?.name ?? "Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            ForEach(self.cookbookViewModel.cookbooks) { cookbook in
                self.cookbookSwitcherButton(cookbook)
            }
        }
        .toolbar {
            if self.viewModel.isSyncing {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.hauptgangTextSecondary)
                }
            }
        }
        .task {
            self.viewModel.configure(modelContext: self.modelContext)
            await self.viewModel.refresh()
        }
        .onChange(of: self.authManager.authState) { _, newValue in
            if case .unauthenticated = newValue {
                self.viewModel.clearData()
            }
        }
        .onChange(of: self.cookbookViewModel.activeCookbook?.id) { _, _ in
            self.viewModel.resetForCookbookSwitch()
            Task { await self.viewModel.refresh() }
        }
        .onChange(of: self.viewModel.didReceiveForbidden) { _, forbidden in
            guard forbidden else { return }
            self.viewModel.didReceiveForbidden = false
            Task {
                await self.cookbookViewModel.handleForbidden()
                await self.viewModel.refresh()
            }
        }
    }

    private func cookbookSwitcherButton(_ cookbook: Cookbook) -> some View {
        Button {
            Task { await self.cookbookViewModel.setActiveCookbook(cookbook) }
        } label: {
            Label(cookbook.name, systemImage: self.cookbookSymbol(for: cookbook))
        }
        .disabled(cookbook.id == self.cookbookViewModel.activeCookbook?.id)
    }

    private func cookbookSymbol(for cookbook: Cookbook) -> String {
        if cookbook.id == self.cookbookViewModel.activeCookbook?.id {
            return "checkmark"
        }
        return cookbook.personal ? "person.fill" : "person.2.fill"
    }

    private var addItemBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Add item", text: self.$newItemText)
                .themeTextField()
                .focused(self.$isAddItemFocused)
                .onSubmit(self.addCustomItem)

            Button {
                self.addCustomItem()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(self.addItemButtonBackground)
            }
            .buttonStyle(PuffyButtonStyle())
            .disabled(self.newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(self.newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
        }
    }

    private var addItemButtonBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Color.hauptgangPrimary)
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear, .black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var listView: some View {
        List {
            if !self.viewModel.uncheckedItems.isEmpty {
                Section {
                    ForEach(self.viewModel.uncheckedItems) { item in
                        self.itemRow(item)
                    }
                    .onDelete { indexSet in
                        self.deleteItems(at: indexSet, from: self.viewModel.uncheckedItems)
                    }
                } header: {
                    HStack {
                        Text("To Buy")
                        Spacer()
                        self.removeAllButton
                    }
                }
            }

            if !self.viewModel.checkedItems.isEmpty {
                Section("Checked") {
                    ForEach(self.viewModel.checkedItems) { item in
                        self.itemRow(item)
                    }
                    .onDelete { indexSet in
                        self.deleteItems(at: indexSet, from: self.viewModel.checkedItems)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func itemRow(_ item: PersistedShoppingListItem) -> some View {
        Button {
            self.viewModel.toggleItem(item)
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

    private var removeAllButton: some View {
        Button {
            self.showRemoveAllConfirmation = true
        } label: {
            Text("Remove All")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.hauptgangTextSecondary)
                .padding(.horizontal, Theme.Spacing.sm + 4)
                .padding(.vertical, Theme.Spacing.xs + 2)
                .background(
                    Capsule()
                        .fill(Color.hauptgangBackground)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.hauptgangTextMuted.opacity(0.4), lineWidth: 1)
                )
        }
        .disabled(self.viewModel.isSyncing)
        .opacity(self.viewModel.isSyncing ? 0.5 : 1.0)
        .buttonStyle(RemoveAllButtonStyle())
        .textCase(nil)
        .confirmationDialog(
            "This will remove all items from your shopping list, including checked items.",
            isPresented: self.$showRemoveAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) {
                Task { await self.viewModel.removeAllItems() }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
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
            .frame(minHeight: UIScreen.main.bounds.height * 0.5)
        }
    }

    private func addCustomItem() {
        let trimmed = self.newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        self.viewModel.addCustomItem(trimmed)
        self.newItemText = ""
        self.isAddItemFocused = false
    }

    private func deleteItems(at indexSet: IndexSet, from items: [PersistedShoppingListItem]) {
        for index in indexSet {
            let item = items[index]
            self.viewModel.deleteItem(item)
        }
    }
}

private struct RemoveAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    let authManager = AuthManager()
    return ShoppingListView()
        .environmentObject(authManager)
        .environment(CookbookViewModel())
        .modelContainer(for: PersistedShoppingListItem.self, inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
