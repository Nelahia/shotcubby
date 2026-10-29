import AppKit
import SwiftUI

/// Moves the window when the pointer is pressed and dragged on it. Put behind a
/// strip of the panel (the search bar) so that strip moves the window, while the
/// rest of the panel does not: a press on a screenshot row must start dragging
/// that file, not carry the whole panel with it.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}
