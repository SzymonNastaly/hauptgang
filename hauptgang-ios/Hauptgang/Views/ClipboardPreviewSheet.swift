import SwiftUI

struct ClipboardPreviewSheet: View {
    let text: String
    let onImport: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var previewLines: String {
        self.text.components(separatedBy: .newlines).prefix(5).joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Import from Clipboard?")
                .font(.headline)
                .foregroundStyle(Color.hauptgangTextPrimary)

            Text(self.previewLines)
                .font(.subheadline)
                .foregroundStyle(Color.hauptgangTextSecondary)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.md) {
                Button {
                    self.dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(Color.hauptgangPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Color.hauptgangSurfaceRaised)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PuffyButtonStyle())

                Button {
                    self.onImport()
                } label: {
                    Text("Import")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(self.importButtonBackground)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PuffyButtonStyle())
            }
        }
        .padding(Theme.Spacing.lg)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            Color.hauptgangSurfaceRaised.opacity(0.1)
                .background(.ultraThinMaterial)
        }
    }

    // MARK: - Button Backgrounds

    private var importButtonBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.hauptgangPrimary)
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear, .black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
        }
    }
}
