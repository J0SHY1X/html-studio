import Foundation

enum AutoSaveInterval: Double, CaseIterable, Identifiable {
    case off = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case threeMinutes = 180
    case fiveMinutes = 300

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .thirtySeconds: return "每 30 秒"
        case .oneMinute: return "每 1 分钟"
        case .threeMinutes: return "每 3 分钟"
        case .fiveMinutes: return "每 5 分钟"
        }
    }

    static func from(seconds: Double) -> AutoSaveInterval {
        allCases.first { $0.rawValue == seconds } ?? .off
    }
}

enum AutoSavePreferences {
    static let intervalKey = "HTMLStudio.autoSaveIntervalSeconds"
}
