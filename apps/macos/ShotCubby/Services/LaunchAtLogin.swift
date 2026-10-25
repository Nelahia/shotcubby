import ServiceManagement
import os

/// Whether ShotCubby opens when the user logs in. macOS keeps the switch (it
/// shows under System Settings → General → Login Items), so it is read back
/// from the system rather than stored here.
enum LaunchAtLogin {
    private static let logger = Logger(subsystem: "com.nelahian.shotcubby", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Could not change launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }
}
