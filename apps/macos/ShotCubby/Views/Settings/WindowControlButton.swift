import SwiftUI

/// One round button of the Settings window's own controls. It stays muted until
/// the pointer is over the pair, then takes its color and shows its symbol.
struct WindowControlButton: View {
    let symbol: String
    let label: String
    let tint: Color
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(active ? tint : SettingsStyle.raised)
                .frame(width: 13, height: 13)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.6))
                        .opacity(active ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
