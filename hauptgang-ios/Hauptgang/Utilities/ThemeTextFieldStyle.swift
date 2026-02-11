import SwiftUI

struct ThemeTextFieldStyle: TextFieldStyle {
    var isError: Bool = false

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Theme.Spacing.md)
            .background(Color.hauptgangCard)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(
                        self.isError ? Color.hauptgangError : Color.hauptgangBorderSubtle,
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(
                self.isEnabled
                    ? (configuration.isPressed ? Color.hauptgangPrimaryHover : Color.hauptgangPrimary)
                    : Color.hauptgangTextMuted
            )
            .cornerRadius(Theme.CornerRadius.md)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Puffy Button Style

struct PuffyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .shadow(
                color: Color.hauptgangPrimary.opacity(configuration.isPressed ? 0.15 : 0.4),
                radius: configuration.isPressed ? 1 : 4,
                y: configuration.isPressed ? 1 : 3
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extension

extension View {
    func themeTextField(isError: Bool = false) -> some View {
        self.textFieldStyle(ThemeTextFieldStyle(isError: isError))
    }

    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    func puffyButton() -> some View {
        self.buttonStyle(PuffyButtonStyle())
    }
}
