import SwiftUI

/// Displays a single recipe in a list
struct RecipeRowView: View {
    let recipe: PersistedRecipe

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Recipe info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(self.recipe.name)
                        .font(.headline)
                        .foregroundColor(.hauptgangTextPrimary)
                        .lineLimit(2)

                    if self.recipe.favorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.hauptgangPrimary)
                    }
                }

                // Time info
                if let timeText = formattedTime {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(timeText)
                            .font(.caption)
                    }
                    .foregroundColor(.hauptgangTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.hauptgangTextMuted)
        }
        .padding(Theme.Spacing.md)
        .background(Color.hauptgangCard)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(
            color: Theme.Shadow.sm.color,
            radius: Theme.Shadow.sm.radius,
            y: Theme.Shadow.sm.y
        )
    }

    /// Formats prep and cook time into a readable string
    private var formattedTime: String? {
        var parts: [String] = []

        if let prep = recipe.prepTime, prep > 0 {
            parts.append("\(prep)m prep")
        }

        if let cook = recipe.cookTime, cook > 0 {
            parts.append("\(cook)m cook")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " + ")
    }
}

#Preview("With all info") {
    RecipeRowView(
        recipe: PersistedRecipe(
            id: 1,
            name: "Spaghetti Carbonara",
            prepTime: 15,
            cookTime: 20,
            favorite: true,
            updatedAt: Date()
        )
    )
    .padding()
    .background(Color.hauptgangBackground)
}

#Preview("Minimal info") {
    RecipeRowView(
        recipe: PersistedRecipe(
            id: 2,
            name: "Quick Salad",
            favorite: false,
            updatedAt: Date()
        )
    )
    .padding()
    .background(Color.hauptgangBackground)
}
