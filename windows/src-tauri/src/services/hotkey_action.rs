/// The global shortcuts the app registers. Each one is independently
/// rebindable from Settings; this enum is the single list of them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HotkeyAction {
    Spotlight,
    FullScreenCapture,
    RegionCapture,
}

impl HotkeyAction {
    pub const ALL: [HotkeyAction; 3] = [
        HotkeyAction::Spotlight,
        HotkeyAction::FullScreenCapture,
        HotkeyAction::RegionCapture,
    ];

    /// Stable key used in the config file and across the IPC boundary.
    pub fn id(self) -> &'static str {
        match self {
            HotkeyAction::Spotlight => "spotlight",
            HotkeyAction::FullScreenCapture => "full_screen",
            HotkeyAction::RegionCapture => "region",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|action| action.id() == id)
    }

    pub fn label(self) -> &'static str {
        match self {
            HotkeyAction::Spotlight => "Open Spotlight search",
            HotkeyAction::FullScreenCapture => "Capture full screen",
            HotkeyAction::RegionCapture => "Capture a region",
        }
    }

    /// The capture defaults mirror macOS's Cmd+Shift+3/4 (as Alt+Shift).
    pub fn default_hotkey(self) -> &'static str {
        match self {
            HotkeyAction::Spotlight => "Ctrl+/",
            HotkeyAction::FullScreenCapture => "Alt+Shift+3",
            HotkeyAction::RegionCapture => "Alt+Shift+4",
        }
    }
}
