import SwiftUI

/// Close and Minimize for the Settings window, drawn in the app instead of the
/// system's title bar buttons (hidden in `ShotCubbyApp`).
struct WindowControls: View {
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            WindowControlButton(symbol: "xmark", label: "Close", tint: Color(hex: 0xFF5F57), active: hovering) {
                NSApp.keyWindow?.close()
            }
            WindowControlButton(symbol: "minus", label: "Minimize", tint: Color(hex: 0xFEBC2E), active: hovering) {
                NSApp.keyWindow?.miniaturize(nil)
            }
        }
        .onHover { hovering = $0 }
    }
}
