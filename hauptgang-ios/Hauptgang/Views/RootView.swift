import SwiftUI

/// Root view that handles authentication routing
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var cookbookViewModel = CookbookViewModel()
    @State private var showingInvitation = false
    @State private var invitationToken: String?

    var body: some View {
        Group {
            switch self.authManager.authState {
            case .unknown:
                SplashView()
            case .unauthenticated:
                LoginView()
            case .authenticated:
                MainTabView()
            }
        }
        .environment(self.cookbookViewModel)
        // Note: animation removed to prevent iOS 26 Liquid Glass tab bar background initialization bug
        // .animation(.easeInOut(duration: 0.3), value: self.authManager.authState)
        .task {
            await self.authManager.checkAuthStatus()
        }
        .onChange(of: self.authManager.authState) { _, newValue in
            Task {
                switch newValue {
                case let .authenticated(user):
                    await CookbookContext.shared.configure(userId: user.id)
                    self.cookbookViewModel.configure(userId: user.id)
                    await self.cookbookViewModel.loadCookbooks()
                    await self.subscriptionManager.identify(userId: String(user.id))
                    await self.subscriptionManager.refreshStatus()

                    // Check for invitation stored while unauthenticated
                    if let storedToken = self.deepLinkRouter.consumeStoredToken() {
                        self.invitationToken = storedToken
                        self.showingInvitation = true
                    }
                case .unauthenticated:
                    await self.cookbookViewModel.reset()
                    await self.subscriptionManager.reset()
                case .unknown:
                    break
                }
            }
        }
        .onChange(of: self.deepLinkRouter.pendingInvitationToken) { _, token in
            guard let token else { return }
            self.deepLinkRouter.clearPendingInvitation()

            if self.authManager.authState.isAuthenticated {
                self.invitationToken = token
                self.showingInvitation = true
            } else {
                // Not logged in — store token and present after login
                self.deepLinkRouter.storePendingToken(token)
            }
        }
        .sheet(isPresented: self.$showingInvitation) {
            if let token = self.invitationToken {
                InvitationView(token: token) {
                    self.showingInvitation = false
                    self.invitationToken = nil
                }
                .environment(self.cookbookViewModel)
            }
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.hauptgangBackground

            Image("LaunchLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview("Splash") {
    SplashView()
}

#Preview("Root - Authenticated") {
    let authManager = AuthManager()
    let subscriptionManager = SubscriptionManager()
    return RootView()
        .environmentObject(authManager)
        .environmentObject(subscriptionManager)
        .environment(DeepLinkRouter())
}
