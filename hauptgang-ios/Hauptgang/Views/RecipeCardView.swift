import SwiftUI

/// Card-style recipe display matching web design
/// Two visual modes: with image (gradient overlay) or without (solid background)
struct RecipeCardView: View {
    let recipe: PersistedRecipe

    /// Fixed card height matching web design (224px)
    private let cardHeight: CGFloat = 224

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background layer
            if let imageUrl = recipe.coverImageUrl, let url = URL(string: imageUrl) {
                imageBackgroundView(url: url)
            } else {
                solidBackgroundView
            }

            // Content overlay
            contentView

            // Import status overlay
            if let status = recipe.importStatus {
                importStatusOverlay(status: status)
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        .shadow(
            color: Theme.Shadow.sm.color,
            radius: Theme.Shadow.sm.radius,
            y: Theme.Shadow.sm.y
        )
    }

    // MARK: - Background Views

    @ViewBuilder
    private func imageBackgroundView(url: URL) -> some View {
        // Use Color.clear as sizing anchor - it fills exactly the proposed size (like Shape)
        // AsyncImage in .background doesn't affect layout, .clipped clips overflow
        Color.clear
            .background {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Color.hauptgangSurfaceRaised
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        // Fall back to solid background on error
                        Color.hauptgangCard
                    @unknown default:
                        Color.hauptgangCard
                    }
                }
            }
            .clipped()
            .overlay {
                // Gradient overlay for text readability
                // Matches web: 60% opacity at bottom → 35% at 40% → transparent at 70%
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.6), location: 0),
                        .init(color: .black.opacity(0.35), location: 0.4),
                        .init(color: .clear, location: 0.7)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
    }

    private var solidBackgroundView: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
            .fill(Color.hauptgangSurfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Color.hauptgangBorderSubtle, lineWidth: 1)
            )
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Spacer()

            // Recipe name
            Text(recipe.name)
                .font(.system(.headline, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(hasImage ? .white : .hauptgangTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Time info
            if let totalTime = totalTimeMinutes {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(totalTime)m")
                        .font(.caption)
                }
                .foregroundColor(hasImage ? .white.opacity(0.8) : .hauptgangTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(Theme.Spacing.md)
    }

    // MARK: - Import Status Overlay

    @ViewBuilder
    private func importStatusOverlay(status: String) -> some View {
        switch status {
        case "pending":
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.5)

                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text("Importing...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }

        case "failed":
            ZStack {
                // Semi-transparent red overlay
                Color.hauptgangError.opacity(0.8)

                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text("Import failed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text("We couldn't find a recipe on this page, or this website isn't supported yet.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var hasImage: Bool {
        recipe.coverImageUrl != nil
    }

    /// Combined prep + cook time
    private var totalTimeMinutes: Int? {
        let prep = recipe.prepTime ?? 0
        let cook = recipe.cookTime ?? 0
        let total = prep + cook
        return total > 0 ? total : nil
    }

    /// Whether the recipe is currently being imported
    var isPending: Bool {
        recipe.importStatus == "pending"
    }

    /// Whether the recipe import failed
    var isFailed: Bool {
        recipe.importStatus == "failed"
    }
}

// MARK: - Previews

#Preview("With image") {
    RecipeCardView(
        recipe: PersistedRecipe(
            id: 1,
            name: "Spaghetti Carbonara with Crispy Pancetta",
            prepTime: 15,
            cookTime: 20,
            favorite: true,
            coverImageUrl: "https://images.unsplash.com/photo-1612874742237-6526221588e3?w=400",
            updatedAt: Date()
        )
    )
    .frame(width: 180)
    .padding()
    .background(Color.hauptgangBackground)
}

#Preview("Without image") {
    RecipeCardView(
        recipe: PersistedRecipe(
            id: 2,
            name: "Quick Garden Salad",
            prepTime: 10,
            favorite: false,
            updatedAt: Date()
        )
    )
    .frame(width: 180)
    .padding()
    .background(Color.hauptgangBackground)
}

#Preview("Grid layout") {
    let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    ScrollView {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            RecipeCardView(
                recipe: PersistedRecipe(
                    id: 1,
                    name: "Spaghetti Carbonara",
                    prepTime: 15,
                    cookTime: 20,
                    favorite: true,
                    coverImageUrl: "https://images.unsplash.com/photo-1612874742237-6526221588e3?w=400",
                    updatedAt: Date()
                )
            )
            RecipeCardView(
                recipe: PersistedRecipe(
                    id: 2,
                    name: "Quick Salad",
                    prepTime: 10,
                    favorite: false,
                    updatedAt: Date()
                )
            )
            RecipeCardView(
                recipe: PersistedRecipe(
                    id: 3,
                    name: "Chicken Tikka Masala with Basmati Rice",
                    prepTime: 20,
                    cookTime: 40,
                    favorite: true,
                    coverImageUrl: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400",
                    updatedAt: Date()
                )
            )
            RecipeCardView(
                recipe: PersistedRecipe(
                    id: 4,
                    name: "Avocado Toast",
                    prepTime: 5,
                    favorite: false,
                    updatedAt: Date()
                )
            )
        }
        .padding(Theme.Spacing.lg)
    }
    .background(Color.hauptgangBackground)
}
