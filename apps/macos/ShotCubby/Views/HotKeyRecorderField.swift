import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A click-to-record control for a shortcut: click it, then press a key
/// combination with at least one modifier. Escape alone cancels. With
/// `allowsBareKeys`, Return and the function keys are accepted without one.
struct HotKeyRecorderField: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    var allowsBareKeys = false
    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording = true
        } label: {
            Text(isRecording ? "Press a key combination…" : HotKeyPreferences.describe(keyCode: keyCode, modifiers: modifiers))
                .font(.system(size: 12, design: .monospaced))
                .frame(minWidth: 160)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .background(
            KeyCaptureCatcher(isRecording: $isRecording, allowsBareKeys: allowsBareKeys) { newKeyCode, newModifiers in
                keyCode = newKeyCode
                modifiers = newModifiers
            }
        )
    }
}

/// Installs a local key-down monitor only while `isRecording` is true.
private struct KeyCaptureCatcher: NSViewRepresentable {
    @Binding var isRecording: Bool
    let allowsBareKeys: Bool
    let onCapture: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.allowsBareKeys = allowsBareKeys
        context.coordinator.setRecording(isRecording) { isRecording = false }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onCapture: ((UInt32, UInt32) -> Void)?
        var allowsBareKeys = false
        private var monitor: Any?

        func setRecording(_ recording: Bool, stopBinding: @escaping () -> Void) {
            guard recording, monitor == nil else {
                if !recording { teardown() }
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                let relevantFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])

                // Plain Escape (no modifiers) cancels recording without binding anything.
                if event.keyCode == UInt16(kVK_Escape), relevantFlags.isEmpty {
                    self.teardown()
                    stopBinding()
                    return nil
                }

                var carbonModifiers: UInt32 = 0
                if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
                if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
                if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
                if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }

                // Require at least one modifier so plain typing can't be bound
                // (Return and function keys excepted when the caller allows it).
                let bindable = carbonModifiers != 0
                    || (self.allowsBareKeys && SpotlightShortcuts.isBindable(keyCode: UInt32(event.keyCode), modifiers: 0))
                guard bindable else { return nil }

                self.onCapture?(UInt32(event.keyCode), carbonModifiers)
                self.teardown()
                stopBinding()
                return nil
            }
        }

        private func teardown() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { teardown() }
    }
}
