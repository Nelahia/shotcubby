import SwiftUI

struct GeneralSettingsPane: View {
    @State private var appearance = AppearancePreferences.current
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showInDock = DockPreferences.showInDock
    @State private var checksAutomatically = AppUpdater.shared.automaticallyChecks

    var body: some View {
        SettingsPage(title: "General", subtitle: "Appearance, startup, the Dock, updates, and the version you are running.") {
            SettingsCard {
                SettingsRow(title: "Appearance") {
                    AppearancePicker(selection: $appearance)
                }
                Divider()
                SettingsRow(title: "Open ShotCubby at session start") {
                    Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.switchOn)
                }
                Divider()
                SettingsRow(title: "Show in the Dock and app switcher", subtitle: "Off: ShotCubby lives in the menu bar only, and ⌘ Tab no longer lists it. The search shortcut still works.") {
                    Toggle("", isOn: $showInDock).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.switchOn)
                }
                Divider()
                SettingsRow(title: "Check for updates automatically") {
                    Toggle("", isOn: $checksAutomatically).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.switchOn)
                }
                Divider()
                SettingsRow(title: "Version \(Self.versionLabel)") {
                    Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
                        .buttonStyle(SettingsButtonStyle())
                }
            }
        }
        .onChange(of: appearance) { _, new in AppearancePreferences.set(new) }
        .onChange(of: launchAtLogin) { _, on in
            guard on != LaunchAtLogin.isEnabled else { return }
            LaunchAtLogin.set(on)
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        .onChange(of: showInDock) { _, show in DockPreferences.set(show) }
        .onChange(of: checksAutomatically) { _, on in AppUpdater.shared.automaticallyChecks = on }
    }

    /// The release version stamped into Info.plist by the release workflow.
    private static var versionLabel: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
