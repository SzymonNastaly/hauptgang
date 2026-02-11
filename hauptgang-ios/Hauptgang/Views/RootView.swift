import SwiftUI

/// Root view that handles authentication routing
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

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
        // Note: animation removed to prevent iOS 26 Liquid Glass tab bar background initialization bug
        // .animation(.easeInOut(duration: 0.3), value: self.authManager.authState)
        .task {
            await self.authManager.checkAuthStatus()
        }
        .onChange(of: self.authManager.authState) { _, newValue in
            Task {
                switch newValue {
                case let .authenticated(user):
                    await self.subscriptionManager.identify(userId: String(user.id))
                case .unauthenticated:
                    await self.subscriptionManager.reset()
                case .unknown:
                    break
                }
            }
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.hauptgangBackground
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 60))
                    .foregroundColor(.hauptgangPrimary)

                Text("Hauptgang")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.hauptgangTextPrimary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .hauptgangPrimary))
                    .padding(.top, Theme.Spacing.lg)
            }
        }
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
}
