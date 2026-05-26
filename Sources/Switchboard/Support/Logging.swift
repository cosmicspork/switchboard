import os

/// Shared logger for the app. Categories keep launchd / appearance / config
/// messages separable in Console.app.
enum Log {
    static let subsystem = "com.cosmicspork.switchboard"

    static let helpers = Logger(subsystem: subsystem, category: "helpers")
    static let launchctl = Logger(subsystem: subsystem, category: "launchctl")
    static let appearance = Logger(subsystem: subsystem, category: "appearance")
    static let config = Logger(subsystem: subsystem, category: "config")
}
