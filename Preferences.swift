import Foundation

enum Preferences {
    static let defaults = UserDefaults.standard
    static func register() {
        defaults.register(defaults: ["enabled": true, "zoneLength": 300,
                                    "zoneWidth": 5, "pollingRate": 120,
                                    "mainDisplayOnly": false])
    }
    static var enabled: Bool { defaults.bool(forKey: "enabled") }
    static var length: Double { min(800, max(100, defaults.double(forKey: "zoneLength"))) }
    static var width: Double { min(20, max(2, defaults.double(forKey: "zoneWidth"))) }
    static var rate: Int { defaults.integer(forKey: "pollingRate") == 60 ? 60 : 120 }
    static var mainDisplayOnly: Bool { defaults.bool(forKey: "mainDisplayOnly") }

    static func resetRegion() {
        for key in ["zoneLength", "zoneWidth", "pollingRate", "mainDisplayOnly"] {
            defaults.removeObject(forKey: key)
        }
    }
}
