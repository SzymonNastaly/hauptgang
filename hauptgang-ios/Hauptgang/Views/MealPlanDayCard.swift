import SwiftUI

struct MealPlanDayCard: View {
    let dateString: String
    let day: PersistedMealPlanDay?
    let entries: [PersistedMealPlanEntry]
    let isOffline: Bool
    let isSelecting: Bool
    let onAddTapped: () -> Void
    let onDeleteEntry: (PersistedMealPlanEntry) -> Void
    let onToggleVote: (PersistedMealPlanEntry) -> Void
    let onSelect: (PersistedMealPlanEntry) -> Void
    let onDeselect: () -> Void

    private var isSelected: Bool { day?.isSelected == true }
    private var selectedEntry: PersistedMealPlanEntry? {
        guard let selectedId = day?.selectedEntryId else { return nil }
        return entries.first { $0.serverId == selectedId }
    }

    private var canInteract: Bool { !isOffline && !isSelecting }
    private func canDelete(_ entry: PersistedMealPlanEntry) -> Bool {
        entry.syncState == .pendingCreate || !self.isOffline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            self.header

            if self.isSelected, let entry = self.selectedEntry {
                self.selectedView(entry: entry)
            } else if self.entries.isEmpty {
                self.emptyView
            } else {
                self.votingView
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.hauptgangCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl))
        .shadow(
            color: Theme.Shadow.sm.color,
            radius: Theme.Shadow.sm.radius,
            y: Theme.Shadow.sm.offsetY
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(MealPlanViewModel.displayDate(for: self.dateString))
                .font(.headline)
                .foregroundStyle(Color.hauptgangTextPrimary)

            Spacer()

            Text(self.weekdayName)
                .font(.subheadline.weight(.light))
                .foregroundStyle(Color.hauptgangTextSecondary)
        }
    }

    private var weekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: self.dateString) else { return "" }
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        Button {
            self.onAddTapped()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "plus")
                    .font(.body)
                Text("Add meal")
                    .font(.subheadline)
            }
            .foregroundStyle(Color.hauptgangPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voting State

    private var votingView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(self.entries, id: \.scopedId) { entry in
                    self.entryRow(entry)
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.xs,
                            leading: 0,
                            bottom: Theme.Spacing.xs,
                            trailing: 0
                        ))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading) {
                            if self.canInteract && entry.syncState != .pendingCreate {
                                Button {
                                    self.onSelect(entry)
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle.fill")
                                }
                                .tint(Color.hauptgangSuccess)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if self.canDelete(entry) {
                                Button(role: .destructive) {
                                    self.onDeleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: CGFloat(self.entries.count) * 72)

            Button {
                self.onAddTapped()
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Add meal")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.hauptgangPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private func entryRow(_ entry: PersistedMealPlanEntry) -> some View {
        ZStack {
            NavigationLink(value: entry.recipeId) {
                EmptyView()
            }
            .opacity(0)

            HStack(spacing: Theme.Spacing.md) {
                self.recipeImage(entry)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(entry.recipeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.hauptgangTextPrimary)
                        .lineLimit(2)

                    if entry.syncState == .pendingCreate {
                        Text("Syncing...")
                            .font(.caption2)
                            .foregroundStyle(Color.hauptgangTextMuted)
                    }
                }

                Spacer()

                self.voteButton(entry)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private func recipeImage(_ entry: PersistedMealPlanEntry) -> some View {
        Group {
            if let url = Constants.API.resolveURL(entry.recipeCoverImageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.hauptgangSurfaceRaised
                    }
                }
            } else {
                Color.hauptgangSurfaceRaised
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Color.hauptgangTextMuted)
                            .font(.subheadline)
                    }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
    }

    private func voteButton(_ entry: PersistedMealPlanEntry) -> some View {
        Button {
            self.onToggleVote(entry)
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(entry.voteCount > 0 ? "\(entry.voteCount)" : "")
                    .font(.body)
                    .foregroundStyle(Color.hauptgangTextSecondary)
                    .frame(minWidth: 16, alignment: .trailing)
                Image(systemName: entry.votedByCurrentUser ? "heart.fill" : "heart")
                    .foregroundStyle(entry.votedByCurrentUser ? Color.hauptgangPrimary : Color.hauptgangTextMuted)
            }
            .font(.title3)
        }
        .disabled(self.isOffline || entry.syncState == .pendingCreate)
        .buttonStyle(.plain)
    }

    // MARK: - Selected State

    private func selectedView(entry: PersistedMealPlanEntry) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            NavigationLink(value: entry.recipeId) {
                HStack(spacing: Theme.Spacing.md) {
                    self.recipeImage(entry)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Selected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.hauptgangSuccess)

                        Text(entry.recipeName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.hauptgangTextPrimary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button {
                self.onDeselect()
            } label: {
                Text("Change")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.hauptgangPrimary)
            }
            .disabled(self.isOffline || self.isSelecting)
        }
    }
}
