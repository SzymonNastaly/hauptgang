import SwiftUI

struct SearchInputBar: View {
    @Binding var text: String
    let prompt: String
    var icon: String = "magnifyingglass"
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: self.icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.placeholderText))

                TextField(self.prompt, text: self.$text)
                    .font(.system(size: 17))
                    .focused(self.$isFocused)
                    .submitLabel(self.onSubmit != nil ? .done : .search)
                    .onSubmit {
                        self.onSubmit?()
                    }
            }
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .background(Color(.tertiarySystemFill), in: .capsule)

            if self.isFocused {
                Button {
                    self.text = ""
                    self.isFocused = false
                    self.onCancel?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.placeholderText))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: self.isFocused)
    }
}
