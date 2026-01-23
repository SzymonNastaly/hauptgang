import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "fork.knife")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hauptgang")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
