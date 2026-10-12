import SwiftUI

/// Hosting controller for the status-item popover that closes it on Esc.
///
/// A transient `NSPopover` closes on outside clicks but not on Esc: the key
/// press travels up the responder chain as `cancelOperation(_:)` and nothing
/// answers it. Anything inside that handles Esc itself first — the rename
/// field's `onExitCommand` — still wins, so Esc cancels a rename before it
/// closes the popover.
final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
