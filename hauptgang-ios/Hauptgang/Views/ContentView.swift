import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootView()
            .onChange(of: self.scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                NetworkMonitor.shared.appDidBecomeActive()
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environment(DeepLinkRouter())
}
