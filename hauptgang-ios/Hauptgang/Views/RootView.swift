import SwiftUI

/// Root view that handles authentication routing
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                SplashView()
            case .unauthenticated:
                LoginView()
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.authState)
        .task {
            await authManager.checkAuthStatus()
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
    return RootView()
        .environmentObject(authManager)
}
