import Carbon.HIToolbox

/// The actions the Spotlight panel can run from the keyboard. Each has a
/// default shortcut and can be rebound in Settings (see `SpotlightShortcuts`).
enum SpotlightCommand: String, CaseIterable, Identifiable {
    case preview, copy, rename, openFolder, trash, settings, actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: return "Preview"
        case .copy: return "Copy"
        case .rename: return "Rename"
        case .openFolder: return "Open Folder"
        case .trash: return "Move to Trash"
        case .settings: return "Settings"
        case .actions: return "Actions menu"
        }
    }

    /// The commands listed in the Actions menu, in display order — the
    /// Actions menu itself is not one of its own rows.
    static let menuOrder: [SpotlightCommand] = [.preview, .copy, .rename, .openFolder, .trash, .settings]

    var isDestructive: Bool { self == .trash }

    /// Draw a separator line above this row in the Actions menu.
    var hasSeparatorBefore: Bool { self == .settings }

    var defaultShortcut: (keyCode: UInt32, modifiers: UInt32) {
        let cmd = UInt32(cmdKey)
        switch self {
        case .preview: return (UInt32(kVK_Return), 0)
        case .copy: return (UInt32(kVK_ANSI_C), cmd)
        case .rename: return (UInt32(kVK_ANSI_E), cmd)
        case .openFolder: return (UInt32(kVK_ANSI_R), cmd)
        case .trash: return (UInt32(kVK_Delete), cmd)
        case .settings: return (UInt32(kVK_ANSI_Comma), cmd)
        case .actions: return (UInt32(kVK_ANSI_K), cmd)
        }
    }
}
