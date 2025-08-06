import SwiftUI

struct ContentView: View {
    @State private var teamID: String = ""
    @State private var nightscoutURL: String = ""
    @State private var apiToken: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to iAPSAdvisor")
                .font(.headline)
            TextField("TEAMID", text: $teamID)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            TextField("Nightscout URL", text: $nightscoutURL)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            TextField("API Token (optional)", text: $apiToken)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            Button("Print App Group") {
                let appGroup = "group.com.\(teamID).loopkit.LoopGroup"
                print(appGroup)
            }
            Button("Fetch BG Readings") {
                guard let url = URL(string: nightscoutURL) else {
                    print("Invalid URL")
                    return
                }
                let service = NightscoutService(baseURL: url, apiToken: apiToken.isEmpty ? nil : apiToken)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let startDate = formatter.string(from: Date())
                Task {
                    do {
                        let readings = try await service.fetchBGReadings(startDate: startDate)
                        print(readings)
                    } catch {
                        print("Error fetching BG readings: \(error)")
                    }
                }
            }
            Button("Fetch Insulin Events") {
                guard let url = URL(string: nightscoutURL) else {
                    print("Invalid URL")
                    return
                }
                let service = NightscoutService(baseURL: url, apiToken: apiToken.isEmpty ? nil : apiToken)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let startDate = formatter.string(from: Date())
                Task {
                    do {
                        let events = try await service.fetchInsulinTreatments(startDate: startDate)
                        print(events)
                    } catch {
                        print("Error fetching insulin events: \(error)")
                    }
                }
            }
            Button("Fetch Carb Events") {
                guard let url = URL(string: nightscoutURL) else {
                    print("Invalid URL")
                    return
                }
                let service = NightscoutService(baseURL: url, apiToken: apiToken.isEmpty ? nil : apiToken)
                Task {
                    do {
                        let events = try await service.fetchCarbIntake()
                        print(events)
                    } catch {
                        print("Error fetching carb events: \(error)")
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
