import Foundation

struct LoopSettingsSnapshot {
    let nightscoutURL: String?
    let apiSecret: String?
    let basalSchedule: [String]
    let fileLocation: String
    let rawJSONString: String
}

enum LoopSettingsProviderError: LocalizedError {
    case missingTeamID
    case containerUnavailable
    case settingsFileNotFound
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingTeamID:
            return "Provide a Loop team ID before loading settings."
        case .containerUnavailable:
            return "Unable to reach the Loop app group container."
        case .settingsFileNotFound:
            return "freeaps_settings.json was not found in the app group container."
        case .invalidJSON:
            return "freeaps_settings.json is not valid JSON."
        }
    }
}

final class LoopSettingsProvider {
    private let teamID: String
    private let fileManager: FileManager

    init(teamID: String, fileManager: FileManager = .default) {
        self.teamID = teamID
        self.fileManager = fileManager
    }

    private func locateSettingsFile() throws -> URL {
        guard !teamID.isEmpty else {
            throw LoopSettingsProviderError.missingTeamID
        }

        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.\(teamID).loopkit.LoopGroup") else {
            throw LoopSettingsProviderError.containerUnavailable
        }

        if let enumerator = fileManager.enumerator(at: containerURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "freeaps_settings.json" {
                return fileURL
            }
        }

        let directURL = containerURL.appendingPathComponent("freeaps_settings.json")
        if fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }

        throw LoopSettingsProviderError.settingsFileNotFound
    }

    func loadSnapshot() throws -> LoopSettingsSnapshot {
        let fileURL = try locateSettingsFile()
        let data = try Data(contentsOf: fileURL)
        let rawJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let dictionary = rawJSON else {
            throw LoopSettingsProviderError.invalidJSON
        }

        let nightscoutURL = inferNightscoutURL(from: dictionary)
        let apiSecret = inferAPIToken(from: dictionary)
        let basalSchedule = inferBasalSchedule(from: dictionary)
        let prettyJSON = (try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""

        return LoopSettingsSnapshot(
            nightscoutURL: nightscoutURL,
            apiSecret: apiSecret,
            basalSchedule: basalSchedule,
            fileLocation: fileURL.path,
            rawJSONString: prettyJSON
        )
    }

    func writeAdvisorSignature() throws {
        let fileURL = try locateSettingsFile()
        let data = try Data(contentsOf: fileURL)
        guard var dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LoopSettingsProviderError.invalidJSON
        }

        dictionary["iAPSAdvisorLastTouched"] = ISO8601DateFormatter().string(from: Date())

        let serialized = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        try serialized.write(to: fileURL, options: .atomic)
    }

    private func inferNightscoutURL(from dictionary: [String: Any]) -> String? {
        let candidateKeys = dictionary.keys.filter { $0.lowercased().contains("nightscout") || $0.lowercased().contains("siteurl") || $0.lowercased().contains("url") }

        for key in candidateKeys {
            if let value = dictionary[key] as? String, value.lowercased().contains("http") {
                return value
            }
        }

        if let preferences = dictionary["preferences"] as? [String: Any] {
            let nestedKeys = preferences.keys.filter { $0.lowercased().contains("nightscout") || $0.lowercased().contains("siteurl") || $0.lowercased().contains("url") }
            for key in nestedKeys {
                if let value = preferences[key] as? String, value.lowercased().contains("http") {
                    return value
                }
            }
        }

        return nil
    }

    private func inferAPIToken(from dictionary: [String: Any]) -> String? {
        let possibleKeys = ["apiSecret", "apisecret", "api_token", "token", "secret", "nightscoutToken", "nightscoutSecret"]

        for key in possibleKeys {
            if let token = dictionary[key] as? String, !token.isEmpty {
                return token
            }
        }

        if let preferences = dictionary["preferences"] as? [String: Any] {
            for key in possibleKeys {
                if let token = preferences[key] as? String, !token.isEmpty {
                    return token
                }
            }
        }

        return nil
    }

    private func inferBasalSchedule(from dictionary: [String: Any]) -> [String] {
        var results: [String] = []

        if let basal = dictionary["basal"] as? [[String: Any]] {
            for entry in basal {
                if let start = entry["startTime"] as? String, let rate = entry["rate"] as? Double {
                    results.append("\(start) – \(rate) U/hr")
                }
            }
        }

        if results.isEmpty, let schedule = dictionary["basal_schedule"] as? [[String: Any]] {
            for entry in schedule {
                if let start = entry["start"] as? String, let rate = entry["value"] as? Double {
                    results.append("\(start) – \(rate) U/hr")
                }
            }
        }

        return results
    }
}
