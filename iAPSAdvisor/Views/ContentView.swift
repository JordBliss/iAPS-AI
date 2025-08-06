import SwiftUI

struct ContentView: View {
    @State private var teamID: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to iAPSAdvisor")
                .font(.headline)
            TextField("TEAMID", text: $teamID)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            Button("Print App Group") {
                let appGroup = "group.com.\(teamID).loopkit.LoopGroup"
                print(appGroup)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
