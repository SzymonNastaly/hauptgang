import SwiftUI

struct MealPlanView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MealPlanViewModel()
    @State private var pickerDate: String?

    var body: some View {
        NavigationStack {
            self.screenContent
        }
        .offlineToast(isOffline: self.viewModel.isOffline)
    }

    private var screenContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                MealPlanDayCard(
                    dateString: self.viewModel.todayDateString,
                    day: self.viewModel.todayDay,
                    entries: self.viewModel.todayEntries,
                    isOffline: self.viewModel.isOffline,
                    isSelecting: self.viewModel.isSelecting,
                    onAddTapped: { self.pickerDate = self.viewModel.todayDateString },
                    onDeleteEntry: { self.deleteEntry($0) },
                    onToggleVote: { self.toggleVote($0) },
                    onSelect: { self.selectEntry($0) },
                    onDeselect: { self.deselectDay(self.viewModel.todayDateString) }
                )

                MealPlanDayCard(
                    dateString: self.viewModel.tomorrowDateString,
                    day: self.viewModel.tomorrowDay,
                    entries: self.viewModel.tomorrowEntries,
                    isOffline: self.viewModel.isOffline,
                    isSelecting: self.viewModel.isSelecting,
                    onAddTapped: { self.pickerDate = self.viewModel.tomorrowDateString },
                    onDeleteEntry: { self.deleteEntry($0) },
                    onToggleVote: { self.toggleVote($0) },
                    onSelect: { self.selectEntry($0) },
                    onDeselect: { self.deselectDay(self.viewModel.tomorrowDateString) }
                )
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Color.hauptgangBackground.ignoresSafeArea())
        .navigationTitle(self.cookbookViewModel.activeCookbook?.name ?? "Meal Plan")
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
        .refreshable {
            if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
                await self.viewModel.refresh(cookbookId: cookbookId)
            }
        }
        .task {
            self.viewModel.configure(modelContext: self.modelContext)
            if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
                await self.viewModel.refresh(cookbookId: cookbookId)
            }
        }
        .onChange(of: self.authManager.authState) { _, newValue in
            if case .unauthenticated = newValue {
                self.viewModel.clearData()
            }
        }
        .onChange(of: self.cookbookViewModel.activeCookbook?.id) { _, _ in
            self.viewModel.resetForCookbookSwitch()
            Task {
                if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
                    await self.viewModel.refresh(cookbookId: cookbookId)
                }
            }
        }
        .onChange(of: self.viewModel.didReceiveForbidden) { _, forbidden in
            guard forbidden else { return }
            self.viewModel.didReceiveForbidden = false
            Task {
                await self.cookbookViewModel.handleForbidden()
                if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
                    await self.viewModel.refresh(cookbookId: cookbookId)
                }
            }
        }
        .navigationDestination(for: Int.self) { recipeId in
            RecipeDetailView(recipeId: recipeId)
        }
        .sheet(item: self.$pickerDate) { date in
            if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
                MealPlanRecipePicker(cookbookId: cookbookId, dateString: date) { recipe in
                    self.viewModel.addEntry(cookbookId: cookbookId, date: date, recipe: recipe)
                }
            } else {
                EmptyView()
            }
        }
    }

    private func cookbookSwitcherButton(_ cookbook: Cookbook) -> some View {
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

    private func deleteEntry(_ entry: PersistedMealPlanEntry) {
        if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
            withAnimation {
                self.viewModel.deleteEntry(entry, cookbookId: cookbookId)
            }
        }
    }

    private func toggleVote(_ entry: PersistedMealPlanEntry) {
        if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
            self.viewModel.toggleVote(entry: entry, cookbookId: cookbookId)
        }
    }

    private func selectEntry(_ entry: PersistedMealPlanEntry) {
        if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
            self.viewModel.selectEntry(entry, cookbookId: cookbookId)
        }
    }

    private func deselectDay(_ date: String) {
        if let cookbookId = self.cookbookViewModel.activeCookbook?.id {
            self.viewModel.deselectDay(date: date, cookbookId: cookbookId)
        }
    }
}

// MARK: - String + Identifiable for sheet binding

extension String: @retroactive Identifiable {
    public var id: String {
        self
    }
}

#Preview {
    let authManager = AuthManager()
    return MealPlanView()
        .environmentObject(authManager)
        .environment(CookbookViewModel())
        .modelContainer(
            for: [PersistedRecipe.self, PersistedMealPlanDay.self, PersistedMealPlanEntry.self],
            inMemory: true
        )
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
