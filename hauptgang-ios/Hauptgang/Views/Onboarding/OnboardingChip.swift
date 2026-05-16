import SwiftUI

/// Tappable chip used by every onboarding question. Visually swaps between selected
/// (filled brown) and unselected (white with subtle border) states.
struct OnboardingChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Text(self.label)
                .font(.system(.body, design: .default))
                .fontWeight(.medium)
                .foregroundColor(self.isSelected ? .white : .hauptgangTextPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(self.isSelected ? Color.hauptgangPrimary : Color.hauptgangCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(
                        self.isSelected ? Color.clear : Color.hauptgangBorderSubtle,
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(self.isSelected ? 0.08 : 0.04), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: self.isSelected)
    }
}

/// Shared header used at the top of every onboarding question screen.
struct OnboardingQuestionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(self.title)
                .font(.system(.title, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(.hauptgangTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(self.subtitle)
                .font(.subheadline)
                .foregroundColor(.hauptgangTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
