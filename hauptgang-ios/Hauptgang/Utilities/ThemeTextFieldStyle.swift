import SwiftUI

struct ThemeTextFieldModifier: ViewModifier {
    var isError: Bool = false
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused(self.$isFocused)
            .padding(Theme.Spacing.md)
            .background(self.isError ? Color.hauptgangError.opacity(0.1) : Color.hauptgangCard)
            .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
            .contentShape(Rectangle())
            .onTapGesture { self.isFocused = true }
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
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(pressed ? 0.90 : 1.0)
            .brightness(pressed ? -0.12 : 0)
            .shadow(
                color: Color.hauptgangPrimary.opacity(pressed ? 0.08 : 0.2),
                radius: pressed ? 1 : 3,
                y: pressed ? 1 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Color.black.opacity(pressed ? 0.15 : 0))
            )
            .animation(.easeInOut(duration: 0.15), value: pressed)
    }
}

// MARK: - View Extension

extension View {
    func themeTextField(isError: Bool = false) -> some View {
        self.modifier(ThemeTextFieldModifier(isError: isError))
    }

    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    func puffyButton() -> some View {
        self.buttonStyle(PuffyButtonStyle())
    }
}
