import SwiftUI

struct ContentView: View {
    @State private var teamID: String = ""
    @AppStorage("nightscoutURL") private var nightscoutURL: String = ""
    @AppStorage("nightscoutAPIToken") private var apiToken: String = ""
    @AppStorage("adjustmentLimit") private var adjustmentLimit: Double = 10
    @State private var statusMessage: String = ""
    @State private var settingsPreview: String = ""
    @State private var basalSchedule: [String] = []
    @State private var segmentSummaries: [DaySegmentSummary] = []
    @State private var isLoadingSummary = false

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        loopActions
                        basalPreview
                        settingsPreviewView
                        Divider()
                        nightscoutActions
                        summaryView
                        status
                    }
                    .padding()
                }
                .navigationTitle("iAPSAdvisor")
            }
            .tabItem { Label("Advisor", systemImage: "stethoscope") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome to iAPSAdvisor")
                .font(.headline)
            if !nightscoutURL.isEmpty {
                Text("Using Nightscout: \(nightscoutURL)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("AI adjustments capped at \(Int(adjustmentLimit))% per change")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var loopActions: some View {
        VStack(spacing: 12) {
            Group {
                TextField("TEAMID", text: $teamID)
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
        }
    }

    private var basalPreview: some View {
        Group {
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
        }
    }

    private var settingsPreviewView: some View {
        Group {
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
        }
    }

    private var nightscoutActions: some View {
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
            Button(isLoadingSummary ? "Summarizing…" : "Summarize Today by Time of Day") {
                summarizeDaySegments()
            }
            .disabled(isLoadingSummary)
        }
        .buttonStyle(.bordered)
    }

    private var summaryView: some View {
        Group {
            if !segmentSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nightscout day summary")
                        .font(.subheadline.weight(.semibold))
                    Text("Guarded by a \(Int(adjustmentLimit))% adjustment limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(segmentSummaries) { summary in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.segment.displayName)
                                .font(.subheadline.weight(.semibold))
                            if let average = summary.averageGlucose {
                                Text("Average glucose: \(Int(average)) mg/dL")
                                    .font(.caption)
                            } else {
                                Text("No glucose data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Insulin: \(summary.totalInsulin, specifier: "%.1f") U")
                                .font(.caption)
                            Text("Carbs: \(summary.totalCarbs, specifier: "%.1f") g")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var status: some View {
        Group {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
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

    private func makeNightscoutService() -> NightscoutService? {
        guard !nightscoutURL.isEmpty, let url = URL(string: nightscoutURL) else {
            statusMessage = "Invalid Nightscout URL"
            return nil
        }
        return NightscoutService(baseURL: url, apiToken: apiToken.isEmpty ? nil : apiToken)
    }

    private func startDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func fetchBGReadings() {
        guard let service = makeNightscoutService() else { return }
        let startDate = startDateString()
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
        guard let service = makeNightscoutService() else { return }
        let startDate = startDateString()
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
        guard let service = makeNightscoutService() else { return }
        let startDate = startDateString()
        Task {
            do {
                let events = try await service.fetchCarbIntake(startDate: startDate)
                print(events)
                statusMessage = "Fetched \(events.count) carb events"
            } catch {
                statusMessage = "Error fetching carb events: \(error.localizedDescription)"
            }
        }
    }

    private func summarizeDaySegments() {
        guard let service = makeNightscoutService() else { return }
        isLoadingSummary = true
        Task {
            do {
                let summaries = try await service.fetchSegmentedSummary()
                await MainActor.run {
                    segmentSummaries = summaries
                    statusMessage = "Summarized Nightscout data with \(Int(adjustmentLimit))% adjustment cap"
                    isLoadingSummary = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error summarizing data: \(error.localizedDescription)"
                    isLoadingSummary = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
