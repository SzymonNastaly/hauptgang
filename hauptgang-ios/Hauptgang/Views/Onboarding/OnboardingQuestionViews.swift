import SwiftUI

// MARK: - Q1: Household size

struct HouseholdQuestionView: View {
    @Binding var selection: HouseholdSize?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            OnboardingQuestionHeader(
                title: "How big is your household?",
                subtitle: "We'll scale recipe servings so you cook the right amount."
            )

            // Household sizes are short — render in a wrap so they stay one row on most devices.
            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(HouseholdSize.allCases) { size in
                    OnboardingChip(
                        label: size.label,
                        isSelected: self.selection == size
                    ) {
                        self.selection = size
                    }
                }
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.xl)
    }
}

// MARK: - Q2: Where you save recipes today

struct SaveTodayQuestionView: View {
    @Binding var selections: Set<SaveTodayOption>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            OnboardingQuestionHeader(
                title: "Where do you save recipes today?",
                subtitle: "Pick all that apply — we'll make it easy to bring them in."
            )

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(SaveTodayOption.allCases) { option in
                    OnboardingChip(
                        label: option.label,
                        isSelected: self.selections.contains(option)
                    ) {
                        self.toggle(option)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private func toggle(_ option: SaveTodayOption) {
        if self.selections.contains(option) {
            self.selections.remove(option)
        } else {
            self.selections.insert(option)
        }
    }
}

// MARK: - Q3: Diet

struct DietQuestionView: View {
    @Binding var selections: Set<DietOption>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            OnboardingQuestionHeader(
                title: "Any dietary preferences?",
                subtitle: "We'll highlight recipes that match. Skip if no restrictions."
            )

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(DietOption.allCases) { option in
                    OnboardingChip(
                        label: option.label,
                        isSelected: self.selections.contains(option)
                    ) {
                        self.toggle(option)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private func toggle(_ option: DietOption) {
        if self.selections.contains(option) {
            self.selections.remove(option)
        } else {
            self.selections.insert(option)
        }
    }
}

// MARK: - FlowLayout

/// Lightweight wrapping layout for chip rows. SwiftUI's built-in `Layout` makes this
/// trivial; we measure each subview at its ideal size, then break to a new row when the
/// proposed width is exceeded.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + self.spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + self.spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let maxWidth = proposal.width ?? bounds.width
        var xPos: CGFloat = bounds.minX
        var yPos: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if xPos + size.width > bounds.minX + maxWidth, xPos > bounds.minX {
                xPos = bounds.minX
                yPos += rowHeight + self.spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: xPos, y: yPos), proposal: ProposedViewSize(size))
            xPos += size.width + self.spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
