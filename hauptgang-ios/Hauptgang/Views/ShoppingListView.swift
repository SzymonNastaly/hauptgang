import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let viewModel: ShoppingListViewModel
    @State private var showRemoveAllConfirmation = false
    @State private var addItemText = ""

    var body: some View {
        NavigationStack {
            self.screenContent
        }
        .offlineToast(isOffline: self.networkMonitor.isOffline)
    }

    private var screenContent: some View {
        Group {
            if self.viewModel.items.isEmpty {
                self.emptyState
            } else {
                self.gridView
            }
        }
        .refreshable {
            await self.networkMonitor.refreshStatus()
            await self.viewModel.refresh()
        }
        .background(Color.hauptgangBackground.ignoresSafeArea())
        .navigationTitle(self.cookbookViewModel.activeCookbook?.name ?? "Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            CookbookTitleMenu(
                cookbooks: self.cookbookViewModel.cookbooks,
                activeCookbookId: self.cookbookViewModel.activeCookbook?.id,
                onSelect: self.selectCookbook
            )
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

    private func selectCookbook(_ cookbook: Cookbook) {
        Task {
            await self.cookbookViewModel.setActiveCookbook(cookbook)
        }
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3)
        } else {
            return [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: Theme.Spacing.sm)]
        }
    }

    private var gridView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ShoppingAddItemBar(viewModel: self.viewModel, text: self.$addItemText)

                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if !self.viewModel.uncheckedItems.isEmpty {
                        self.uncheckedSection
                    }

                    if !self.viewModel.checkedItems.isEmpty {
                        self.checkedSection
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var uncheckedSection: some View {
        Section {
            LazyVGrid(columns: self.gridColumns, spacing: Theme.Spacing.sm) {
                ForEach(self.viewModel.uncheckedItems, id: \.scopedClientId) { item in
                    self.itemTile(item)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .identity
                        ))
                }
            }
            .animation(.snappy(duration: 0.25), value: self.viewModel.uncheckedItems.map(\.scopedClientId))
        } header: {
            HStack {
                Text("To Buy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.hauptgangTextSecondary)
                    .textCase(.uppercase)
                Spacer()
                self.removeAllButton
            }
        }
    }

    @State private var checkedSectionExpanded = true

    private var checkedSection: some View {
        Section {
            if self.checkedSectionExpanded {
                LazyVGrid(columns: self.gridColumns, spacing: Theme.Spacing.sm) {
                    ForEach(self.viewModel.checkedItems, id: \.scopedClientId) { item in
                        self.itemTile(item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.5).combined(with: .opacity),
                                removal: .identity
                            ))
                    }
                }
                .animation(.snappy(duration: 0.25), value: self.viewModel.checkedItems.map(\.scopedClientId))
            }
        } header: {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    self.checkedSectionExpanded.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Already Got")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.hauptgangTextSecondary)
                        .textCase(.uppercase)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hauptgangTextMuted)
                        .rotationEffect(.degrees(self.checkedSectionExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func itemTile(_ item: PersistedShoppingListItem) -> some View {
        let isChecked = item.isChecked

        return Button {
            HapticManager.shared.lightTap()
            self.viewModel.toggleItem(item)
        } label: {
            Text(item.name)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isChecked ? Color.hauptgangTextMuted : .hauptgangTextPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Theme.Spacing.sm)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(isChecked ? Color.hauptgangSurfaceRaised : .hauptgangCard)
                        .shadow(
                            color: Color.black.opacity(isChecked ? 0 : 0.06),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )

        }
        .buttonStyle(.plain)
        .geometryGroup()
        .contentShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        .contextMenu {
            Button(role: .destructive) {
                self.viewModel.deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(item.name)
        .accessibilityValue(isChecked ? "Bought" : "To buy")
        .accessibilityHint(isChecked ? "Double-tap to move back to shopping list" : "Double-tap to mark as bought")
        .accessibilityAction(named: "Delete") {
            self.viewModel.deleteItem(item)
        }
    }

    @ViewBuilder
    private var removeAllButton: some View {
        if #available(iOS 26, *) {
            self.removeAllButtonGlass
        } else {
            self.removeAllButtonLegacy
        }
    }

    @available(iOS 26, *)
    private var removeAllButtonGlass: some View {
        Button {
            self.showRemoveAllConfirmation = true
        } label: {
            Text("Remove All")
                .font(.caption)
                .fontWeight(.medium)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .disabled(self.viewModel.isSyncing)
        .opacity(self.viewModel.isSyncing ? 0.5 : 1.0)
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

    private var removeAllButtonLegacy: some View {
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
                ShoppingAddItemBar(viewModel: self.viewModel, text: self.$addItemText)

                Spacer()

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
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

}

struct ShoppingAddItemBar: View {
    let viewModel: ShoppingListViewModel
    @Binding var text: String

    var body: some View {
        SearchInputBar(text: self.$text, prompt: "Add item", icon: "plus", onSubmit: {
            self.addItem()
        }, keepFocusOnSubmit: true)
    }

    private func addItem() {
        let trimmed = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.viewModel.addCustomItem(trimmed)
        self.text = ""
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
    return ShoppingListView(viewModel: ShoppingListViewModel())
        .environmentObject(authManager)
        .environment(CookbookViewModel())
        .environment(NetworkMonitor.shared)
        .modelContainer(for: PersistedShoppingListItem.self, inMemory: true)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
