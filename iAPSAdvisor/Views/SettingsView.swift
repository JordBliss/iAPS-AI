import SwiftUI

struct SettingsView: View {
    @AppStorage("nightscoutURL") private var nightscoutURL: String = ""
    @AppStorage("nightscoutAPIToken") private var apiToken: String = ""
    @AppStorage("adjustmentLimit") private var adjustmentLimit: Double = 10

    var body: some View {
        Form {
            Section("Nightscout") {
                TextField("Nightscout URL", text: $nightscoutURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Secret", text: $apiToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("AI Guardrails") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max change")
                        Spacer()
                        Text("\(Int(adjustmentLimit))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $adjustmentLimit, in: 0...50, step: 1)
                    Text("Limits how much the AI can modify Loop settings in a single update. Default is 10%.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
