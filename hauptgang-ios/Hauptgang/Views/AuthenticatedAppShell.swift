import SwiftData
import SwiftUI

/// Authenticated-user container that owns the startup splash overlay and starts the session.
/// All authenticated tabs are rendered inside this shell so that startup readiness has a
/// single, explicit owner.
struct AuthenticatedAppShell: View {
    @Environment(\.modelContext) private var modelContext

    let user: User
    let session: AuthenticatedSessionViewModel

    @State private var showsStartupSplash = true

    var body: some View {
        ZStack {
            MainTabView()
                .environment(self.session)
                .environment(self.session.cookbookViewModel)

            if self.showsStartupSplash {
                SplashView()
                    .zIndex(1)
            }
        }
        .onChange(of: self.user.id) { _, _ in
            self.showsStartupSplash = true
        }
        .task(id: self.user.id) {
            await self.session.start(user: self.user, modelContext: self.modelContext)
        }
        .onChange(of: self.session.canDismissStartupSplash, initial: true) { _, canDismiss in
            guard canDismiss, self.showsStartupSplash else { return }
            // Animation kept minimal to avoid iOS 26 Liquid Glass tab bar background init glitch.
            withAnimation(.easeOut(duration: 0.08)) {
                self.showsStartupSplash = false
            }
        }
    }
}
