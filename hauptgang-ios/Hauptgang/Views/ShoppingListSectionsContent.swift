import SwiftUI

struct ShoppingListDisplayItem: Identifiable {
    let id: String
    let name: String
    let isChecked: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?
}

struct ShoppingListSectionsContent<UncheckedHeaderTrailing: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let uncheckedItems: [ShoppingListDisplayItem]
    let checkedItems: [ShoppingListDisplayItem]
    @Binding var checkedSectionExpanded: Bool
    let uncheckedHeaderTrailing: UncheckedHeaderTrailing

    init(
        uncheckedItems: [ShoppingListDisplayItem],
        checkedItems: [ShoppingListDisplayItem],
        checkedSectionExpanded: Binding<Bool>,
        @ViewBuilder uncheckedHeaderTrailing: () -> UncheckedHeaderTrailing
    ) {
        self.uncheckedItems = uncheckedItems
        self.checkedItems = checkedItems
        self._checkedSectionExpanded = checkedSectionExpanded
        self.uncheckedHeaderTrailing = uncheckedHeaderTrailing()
    }

    private var gridColumns: [GridItem] {
        if self.horizontalSizeClass == .compact {
            return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3)
        } else {
            return [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: Theme.Spacing.sm)]
        }
    }

    private var shouldShowUncheckedSection: Bool {
        !self.uncheckedItems.isEmpty || !self.checkedItems.isEmpty
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if self.shouldShowUncheckedSection {
                Section {
                    if !self.uncheckedItems.isEmpty {
                        LazyVGrid(columns: self.gridColumns, spacing: Theme.Spacing.sm) {
                            ForEach(self.uncheckedItems) { item in
                                ShoppingListItemTile(item: item)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                                        removal: .identity
                                    ))
                            }
                        }
                        .animation(.snappy(duration: 0.25), value: self.uncheckedItems.map(\.id))
                    }
                } header: {
                    HStack {
                        Text("To Buy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.hauptgangTextSecondary)
                            .textCase(.uppercase)
                        Spacer()
                        self.uncheckedHeaderTrailing
                    }
                }
            }

            if !self.checkedItems.isEmpty {
                Section {
                    if self.checkedSectionExpanded {
                        LazyVGrid(columns: self.gridColumns, spacing: Theme.Spacing.sm) {
                            ForEach(self.checkedItems) { item in
                                ShoppingListItemTile(item: item)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                                        removal: .identity
                                    ))
                            }
                        }
                        .animation(.snappy(duration: 0.25), value: self.checkedItems.map(\.id))
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
        }
    }
}

private struct ShoppingListItemTile: View {
    let item: ShoppingListDisplayItem

    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            self.item.onTap()
        } label: {
            Text(self.item.name)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .foregroundStyle(self.item.isChecked ? Color.hauptgangTextMuted : Color.hauptgangTextPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Theme.Spacing.sm)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(self.item.isChecked ? Color.hauptgangSurfaceRaised : Color.hauptgangCard)
                        .shadow(
                            color: Color.black.opacity(self.item.isChecked ? 0 : 0.06),
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
            if let onDelete = self.item.onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel(self.item.name)
        .accessibilityValue(self.item.isChecked ? "Bought" : "To buy")
        .accessibilityHint(self.item.isChecked ? "Double-tap to move back to shopping list" : "Double-tap to mark as bought")
        .accessibilityAction(named: "Delete") {
            self.item.onDelete?()
        }
    }
}
