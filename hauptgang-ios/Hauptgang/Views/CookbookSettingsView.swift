import SwiftUI

struct CookbookSettingsView: View {
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @State private var showingCreateSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLeaveConfirmation = false
    @State private var showingInviteLink = false
    @State private var inviteURL: String?
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        List {
            if let personal = cookbookViewModel.personalCookbook {
                self.cookbookSection(personal, isPersonal: true)
            }

            if let shared = cookbookViewModel.sharedCookbook {
                self.cookbookSection(shared, isPersonal: false)
            } else {
                Section {
                    Button {
                        self.showingCreateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.hauptgangPrimary)
                            Text("Create Shared Cookbook")
                        }
                    }
                } footer: {
                    Text("Share recipes and shopping lists with your partner or family.")
                }
            }
        }
        .navigationTitle("Cookbooks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: self.$showingCreateSheet) {
            CreateCookbookSheet()
        }
        .sheet(isPresented: self.$showingInviteLink) {
            if let url = self.inviteURL {
                ShareLinkSheet(url: url)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { self.errorMessage != nil },
            set: { if !$0 { self.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = self.errorMessage {
                Text(msg)
            }
        }
        .confirmationDialog(
            "Delete Shared Cookbook?",
            isPresented: self.$showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await self.deleteSharedCookbook() }
            }
        } message: {
            Text("All recipes in this cookbook will be permanently deleted. This cannot be undone.")
        }
        .confirmationDialog(
            "Leave Shared Cookbook?",
            isPresented: self.$showingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task { await self.leaveSharedCookbook() }
            }
        } message: {
            Text("Your recipes will stay in the shared cookbook. You can rejoin later with a new invitation.")
        }
    }

    // MARK: - Sections

    private func cookbookSection(_ cookbook: Cookbook, isPersonal: Bool) -> some View {
        Section {
            HStack {
                Image(systemName: isPersonal ? "person.fill" : "person.2.fill")
                    .foregroundStyle(Color.hauptgangPrimary)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(cookbook.name)
                        .font(.body)
                        .foregroundStyle(Color.hauptgangTextPrimary)
                    Text("\(cookbook.recipeCount) recipes")
                        .font(.caption)
                        .foregroundStyle(Color.hauptgangTextSecondary)
                }
            }

            if !isPersonal {
                // Members
                ForEach(cookbook.members) { member in
                    HStack {
                        Image(systemName: member.role == "owner" ? "crown.fill" : "person.fill")
                            .font(.caption)
                            .foregroundStyle(member.role == "owner" ? Color.hauptgangAmber : .hauptgangTextMuted)
                        Text(member.email)
                            .font(.subheadline)
                            .foregroundStyle(Color.hauptgangTextPrimary)
                        Spacer()
                        Text(member.role.capitalized)
                            .font(.caption)
                            .foregroundStyle(Color.hauptgangTextSecondary)
                    }
                }

                // Invite button (owner only)
                if self.cookbookViewModel.isSharedCookbookOwner {
                    Button {
                        Task { await self.generateInviteLink() }
                    } label: {
                        HStack {
                            Image(systemName: "link.badge.plus")
                            Text(self.isWorking ? "Generating..." : "Generate Invite Link")
                        }
                    }
                    .disabled(self.isWorking)
                }

                // Leave / Delete
                if self.cookbookViewModel.isSharedCookbookOwner {
                    Button(role: .destructive) {
                        self.showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Cookbook")
                        }
                    }
                } else {
                    Button(role: .destructive) {
                        self.showingLeaveConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Leave Cookbook")
                        }
                    }
                }
            }
        } header: {
            Text(isPersonal ? "Personal" : "Shared")
        }
    }

    // MARK: - Actions

    private func generateInviteLink() async {
        self.isWorking = true
        defer { self.isWorking = false }

        do {
            let response = try await cookbookViewModel.createInvitation()
            self.inviteURL = response.inviteUrl
            self.showingInviteLink = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func deleteSharedCookbook() async {
        do {
            try await self.cookbookViewModel.deleteSharedCookbook()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func leaveSharedCookbook() async {
        do {
            try await self.cookbookViewModel.leaveSharedCookbook()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Create Cookbook Sheet

private struct CreateCookbookSheet: View {
    @Environment(CookbookViewModel.self) private var cookbookViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var moveRecipes = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Cookbook Name", text: self.$name)
                } header: {
                    Text("Name")
                }

                Section {
                    Toggle("Move all personal recipes", isOn: self.$moveRecipes)
                } footer: {
                    Text(
                        "When enabled, your existing recipes and shopping list items will move to the shared cookbook."
                    )
                }

                if let error = self.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.hauptgangError)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("New Shared Cookbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { self.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await self.create() }
                    }
                    .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isCreating)
                }
            }
        }
    }

    private func create() async {
        let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        self.isCreating = true
        defer { self.isCreating = false }

        do {
            let cookbook = try await cookbookViewModel.createSharedCookbook(
                name: trimmedName,
                moveRecipes: self.moveRecipes
            )
            await self.cookbookViewModel.setActiveCookbook(cookbook)
            self.dismiss()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Share Link Sheet

private struct ShareLinkSheet: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.hauptgangPrimary)

                Text("Invite Link Created")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.hauptgangTextPrimary)

                Text("Share this link with someone to invite them to your cookbook.")
                    .font(.subheadline)
                    .foregroundStyle(Color.hauptgangTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)

                ShareLink(item: self.url) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(.hauptgangPrimary)
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CookbookSettingsView()
    }
    .environment(CookbookViewModel())
}
