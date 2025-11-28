import SwiftUI

struct ContentView: View {
    @State private var teamID: String = ""
    @State private var nightscoutURL: String = ""
    @State private var apiToken: String = ""
    @State private var statusMessage: String = ""
    @State private var settingsPreview: String = ""
    @State private var basalSchedule: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Welcome to iAPSAdvisor")
                    .font(.headline)

                Group {
                    TextField("TEAMID", text: $teamID)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    TextField("Nightscout URL", text: $nightscoutURL)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    TextField("API Token (optional)", text: $apiToken)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                HStack {
                    Button("Load Loop Settings") {
                        loadLoopSettings()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Print App Group") {
                        let appGroup = "group.com.\(teamID).loopkit.LoopGroup"
                        print(appGroup)
                        statusMessage = "App Group: \(appGroup)"
                    }
                }

                if !basalSchedule.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Basal schedule from Loop")
                            .font(.subheadline.weight(.semibold))
                        ForEach(basalSchedule, id: \.self) { entry in
                            Text(entry)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                }

                if !settingsPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("freeaps_settings.json preview")
                            .font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal) {
                            Text(settingsPreview)
                                .font(.system(.footnote, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button("Stamp advisor signature") {
                            writeAdvisorSignature()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }

                Divider()

                VStack(spacing: 12) {
                    Button("Fetch BG Readings") {
                        fetchBGReadings()
                    }
                    Button("Fetch Insulin Events") {
                        fetchInsulinEvents()
                    }
                    Button("Fetch Carb Events") {
                        fetchCarbEvents()
                    }
                }
                .buttonStyle(.bordered)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }

    private func loadLoopSettings() {
        let provider = LoopSettingsProvider(teamID: teamID)
        do {
            let snapshot = try provider.loadSnapshot()
            if let url = snapshot.nightscoutURL {
                nightscoutURL = url
            }
            if let token = snapshot.apiSecret {
                apiToken = token
            }
            basalSchedule = snapshot.basalSchedule
            settingsPreview = snapshot.rawJSONString
            statusMessage = "Loaded freeaps_settings.json from \(snapshot.fileLocation)"
        } catch {
            statusMessage = "Unable to load Loop settings: \(error.localizedDescription)"
            settingsPreview = ""
            basalSchedule = []
        }
    }

    private func writeAdvisorSignature() {
        let provider = LoopSettingsProvider(teamID: teamID)
        do {
            try provider.writeAdvisorSignature()
            statusMessage = "Stamped freeaps_settings.json with advisor signature"
        } catch {
            statusMessage = "Unable to write advisor signature: \(error.localizedDescription)"
        }
    }

    private func fetchBGReadings() {
        guard let url = URL(string: nightscoutURL) else {
            statusMessage = "Invalid Nightscout URL"
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
                statusMessage = "Fetched \(readings.count) BG readings"
            } catch {
                statusMessage = "Error fetching BG readings: \(error.localizedDescription)"
            }
        }
    }

    private func fetchInsulinEvents() {
        guard let url = URL(string: nightscoutURL) else {
            statusMessage = "Invalid Nightscout URL"
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
                statusMessage = "Fetched \(events.count) insulin events"
            } catch {
                statusMessage = "Error fetching insulin events: \(error.localizedDescription)"
            }
        }
    }

    private func fetchCarbEvents() {
        guard let url = URL(string: nightscoutURL) else {
            statusMessage = "Invalid Nightscout URL"
            return
        }
        let service = NightscoutService(baseURL: url, apiToken: apiToken.isEmpty ? nil : apiToken)
        Task {
            do {
                let events = try await service.fetchCarbIntake()
                print(events)
                statusMessage = "Fetched \(events.count) carb events"
            } catch {
                statusMessage = "Error fetching carb events: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}
