import SwiftUI

struct OfflineToast: ViewModifier {
    let isOffline: Bool
    var showToast: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if self.isOffline && self.showToast {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                        Text("Offline")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.hauptgangTextSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .padding(.top, Theme.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: self.isOffline && self.showToast)
    }
}

extension View {
    func offlineToast(isOffline: Bool, showToast: Bool = true) -> some View {
        modifier(OfflineToast(isOffline: isOffline, showToast: showToast))
    }
}
