//
//  ShotNestSpotlight.swift
//  ShotNest
//
//  A Spotlight-style floating panel, opened by a global shortcut, to search
//  and act on captures from the keyboard.
//  Needs Shot, ShotActions, Theme and ShotNestGlyph from ShotNestPopover.swift.
//  Target: macOS 14+. The global shortcut uses Carbon hot keys, which need
//  no Accessibility or Input Monitoring permission.
//
//  Hook-up (keep both objects alive, e.g. as AppDelegate properties):
//
//      spotlight = SpotlightController(shots: { store.shots }, actions: actions)
//      hotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_2),
//                            modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
//          self?.spotlight.toggle()
//      }
//
//  Keys inside the panel:
//      ↑ ↓      move selection          ↩       copy image and close
//      ⌘↩       preview in default app  ⌘R      open folder (Finder) and close
//      ⌘E       rename                  esc     cancel rename, else clear search, else close
//      ⌘⌫       move to Trash           ⌘,      open Settings
//      ⌘K       open the Actions menu (↑↓ to move, ↩ to run, esc to close the menu only)
//

import SwiftUI
import AppKit
import ImageIO
import Carbon.HIToolbox
import os

// MARK: - Global hot key

/// Carbon hotkey IDs only need to be unique among *simultaneously*
/// registered hotkeys, but every GlobalHotKey instance reused this same
/// literal — harmless on its own, except registerHotKey() (AppDelegate)
/// used to build the replacement before releasing the old one, so for one
/// call the same ID was briefly registered twice. Incrementing per
/// instance removes any doubt about that id colliding with itself.
private var nextHotKeyID: UInt32 = 1

final class GlobalHotKey {
    private let logger = Logger(subsystem: "com.nelahian.shotnest", category: "GlobalHotKey")
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// - Parameters:
    ///   - keyCode: a `kVK_…` virtual key code, e.g. `UInt32(kVK_ANSI_2)`.
    ///   - modifiers: Carbon flags, e.g. `UInt32(cmdKey | shiftKey)`.
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x53484B50), id: nextHotKeyID)
        nextHotKeyID += 1
        let registerStatus = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)

        if installStatus != noErr || registerStatus != noErr {
            logger.error("""
            Hotkey setup failed for keyCode \(keyCode) modifiers \(modifiers): \
            InstallEventHandler=\(installStatus) RegisterEventHotKey=\(registerStatus)
            """)
        } else {
            logger.notice("Hotkey registered: keyCode \(keyCode) modifiers \(modifiers)")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

// MARK: - Model

@MainActor
final class SpotlightModel: ObservableObject {
    @Published var shots: [Shot] = []
    @Published var query = "" { didSet { selection = results.first?.id } }
    @Published var selection: URL?
    @Published var showCount = 0
    @Published var renaming: URL?
    @Published var renameDraft = ""
    @Published var showActions = false
    @Published var actionIndex = 0

    var results: [Shot] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let sorted = shots.sorted { $0.date > $1.date }
        let matched = q.isEmpty ? sorted : sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return Array(matched.prefix(60))
    }

    var selected: Shot? { results.first { $0.id == selection } }

    func move(_ delta: Int) {
        let list = results
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selection } ?? 0
        selection = list[max(0, min(list.count - 1, current + delta))].id
    }

    func remove(_ shot: Shot) {
        let list = results
        let index = list.firstIndex(of: shot) ?? 0
        shots.removeAll { $0.id == shot.id }
        let remaining = results
        selection = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }

    func beginRename() {
        guard let shot = selected else { return }
        renameDraft = shot.name
        renaming = shot.id
    }
}

// MARK: - Panel + controller

private final class SpotlightPanel: NSPanel {
    var onResignKey: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

@MainActor
final class SpotlightController {
    private let model = SpotlightModel()
    private let provider: () -> [Shot]
    private let actions: ShotActions
    private let panel: SpotlightPanel
    private var keyMonitor: Any?
    /// Built once in init, since every entry's `run` closure already
    /// resolves against the selection at the time it's invoked — no need
    /// to recompute the list itself on every access. Read by handle(_:) to
    /// run the highlighted entry, and by the view to render the footer and
    /// the dropdown menu.
    private let menuActions: [SpotlightAction]

    private static let size = NSSize(width: 720, height: 460)

    init(shots provider: @escaping () -> [Shot], actions: ShotActions) {
        self.provider = provider
        self.actions = actions

        panel = SpotlightPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                               styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                               backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow

        menuActions = [
            SpotlightAction(title: "Copy", keys: "↩", run: { [weak self] in self?.copySelected() }),
            SpotlightAction(title: "Preview", keys: "⌘↩", run: { [weak self] in self?.previewSelected() }),
            SpotlightAction(title: "Rename", keys: "⌘E", run: { [weak self] in self?.model.beginRename() }),
            SpotlightAction(title: "Open Folder", keys: "⌘R", run: { [weak self] in self?.revealSelected() }),
            SpotlightAction(title: "Move to Trash", keys: "⌘⌫", destructive: true, run: { [weak self] in self?.deleteSelected() }),
            SpotlightAction(title: "Settings", keys: "⌘,", separatorBefore: true, run: { [weak self] in self?.actions.openSettings() })
        ]

        let root = SpotlightView(
            model: model,
            onCopy: { [weak self] in self?.copySelected() },
            menuActions: menuActions
        )
        panel.contentView = NSHostingView(rootView: root)
        panel.onResignKey = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        model.shots = provider()
        model.query = ""
        model.selection = model.results.first?.id
        model.showCount += 1

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let origin = NSPoint(x: visible.midX - Self.size.width / 2,
                                 y: visible.midY - Self.size.height / 2 + visible.height * 0.08)
            panel.setFrame(NSRect(origin: origin, size: Self.size), display: true)
        }
        panel.makeKeyAndOrderFront(nil)

        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.panel.isKeyWindow else { return event }
                return self.handle(event) ? nil : event
            }
        }
    }

    func hide() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    private func copySelected() {
        guard let shot = model.selected else { return }
        actions.copy(shot)
        hide()
    }

    private func previewSelected() {
        guard let shot = model.selected else { return }
        actions.open(shot)
        hide()
    }

    private func revealSelected() {
        guard let shot = model.selected else { return }
        actions.reveal(shot)
        hide()
    }

    private func deleteSelected() {
        guard let shot = model.selected else { return }
        actions.delete(shot)
        model.remove(shot)
    }

    private func closeOrClearSearch() {
        if model.query.isEmpty { hide() } else { model.query = "" }
    }

    private func commitRename() {
        guard let shot = model.selected else { model.renaming = nil; return }
        let newName = model.renameDraft
        model.renaming = nil
        actions.rename(shot, newName)
        model.shots = provider()
        if !model.results.contains(where: { $0.id == model.selection }) {
            model.selection = model.results.first?.id
        }
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)

        if model.renaming != nil {
            switch Int(event.keyCode) {
            case kVK_Return, kVK_ANSI_KeypadEnter:
                commitRename(); return true
            case kVK_Escape:
                model.renaming = nil; return true
            default:
                return false
            }
        }

        if model.showActions {
            switch Int(event.keyCode) {
            case kVK_DownArrow:
                model.actionIndex = min(model.actionIndex + 1, menuActions.count - 1); return true
            case kVK_UpArrow:
                model.actionIndex = max(model.actionIndex - 1, 0); return true
            case kVK_Return, kVK_ANSI_KeypadEnter:
                model.showActions = false
                menuActions[model.actionIndex].run()
                return true
            case kVK_Escape:
                model.showActions = false; return true
            default:
                return false
            }
        }

        switch Int(event.keyCode) {
        case kVK_DownArrow:
            model.move(1); return true
        case kVK_UpArrow:
            model.move(-1); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if command { previewSelected() } else { copySelected() }
            return true
        case kVK_Escape:
            closeOrClearSearch(); return true
        case kVK_ANSI_R where command:
            revealSelected(); return true
        case kVK_ANSI_C where command:
            copySelected(); return true
        case kVK_ANSI_E where command:
            model.beginRename(); return true
        case kVK_ANSI_Comma where command:
            actions.openSettings(); return true
        case kVK_ANSI_K where command:
            model.actionIndex = 0
            model.showActions = true
            return true
        case kVK_Delete where command:
            deleteSelected(); return true
        default:
            return false
        }
    }
}

// MARK: - View

private func spotMono(_ size: CGFloat) -> Font {
    .system(size: size, design: .monospaced)
}

struct SpotlightView: View {
    @ObservedObject var model: SpotlightModel
    let onCopy: () -> Void
    let menuActions: [SpotlightAction]

    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var scheme
    private var t: Theme { .resolve(scheme) }

    var body: some View {
        let results = model.results
        VStack(spacing: 0) {
            searchRow(count: results.count)
            Rectangle().fill(t.line).frame(height: 1)
            if results.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    list(results).frame(width: 300)
                    Rectangle().fill(t.line).frame(width: 1)
                    preview
                }
            }
            SpotlightFooter(primary: Array(menuActions.prefix(2)), showActions: $model.showActions)
        }
        .frame(width: 720, height: 460)
        .background(t.bg)
        .foregroundStyle(t.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(t.line))
        .overlay(alignment: .bottomTrailing) {
            if model.showActions {
                SpotlightActionsMenu(actions: menuActions, highlighted: $model.actionIndex) {
                    model.showActions = false
                }
                .padding(.trailing, 8).padding(.bottom, 46)
            }
        }
        .onAppear { searchFocused = true }
        .onChange(of: model.showCount) { _, _ in searchFocused = true }
    }

    private func searchRow(count: Int) -> some View {
        HStack(spacing: 12) {
            ShotNestGlyph().frame(width: 24, height: 24).foregroundStyle(t.ink)
            TextField("Search screenshots", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .focused($searchFocused)
            Text("\(count)")
                .font(spotMono(12))
                .foregroundStyle(t.muted)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(t.line, in: Capsule())
                .accessibilityLabel("\(count) results")
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
    }

    private func list(_ results: [Shot]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results) { shot in
                        SpotlightRow(shot: shot, selected: shot.id == model.selection,
                                     renaming: $model.renaming, draft: $model.renameDraft)
                            .id(shot.id)
                            .onTapGesture(count: 2) { model.renaming = nil; model.selection = shot.id; onCopy() }
                            .onTapGesture { model.renaming = nil; model.selection = shot.id }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selection) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let shot = model.selected {
            VStack(alignment: .leading, spacing: 12) {
                SpotlightImage(url: shot.url, maxPoints: 420)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 3) {
                    Text(shot.url.lastPathComponent)
                        .font(spotMono(13))
                        .lineLimit(1).truncationMode(.middle)
                    Text("\(shot.date.formatted(date: .abbreviated, time: .shortened)) · \(shot.source == .clipboard ? "from clipboard" : "file")")
                        .font(.system(size: 12))
                        .foregroundStyle(t.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(model.query.isEmpty ? "No screenshots yet" : "No screenshot named “\(model.query)”")
                .font(.system(size: 14, weight: .medium))
            Text(model.query.isEmpty ? "Press ⌘⇧4 and it lands here." : "Try fewer letters.")
                .font(.system(size: 12)).foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Footer: two primary hints + an "Actions" menu for the rest
//
// The menu is drawn inside the panel on purpose: a real NSMenu or .popover
// is a separate window, so the panel would lose key status and close
// itself. Every shortcut keeps working directly (see handle(_:) above);
// the menu is just where people who don't know them yet can discover them.

struct SpotlightAction: Identifiable {
    let id = UUID()
    let title: String
    /// Display string for the shortcut, e.g. "⌘↩".
    let keys: String
    var destructive = false
    /// Draw a separator line above this row in the menu.
    var separatorBefore = false
    let run: () -> Void
}

private struct SpotlightFooter: View {
    /// The first two actions, shown inline. Keep menuActions ordered with
    /// the most frequent ones first.
    let primary: [SpotlightAction]
    @Binding var showActions: Bool

    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.resolve(scheme)
        HStack(spacing: 18) {
            ForEach(primary) { action in
                HStack(spacing: 6) {
                    KeyCap(action.keys)
                    Text(action.title)
                }
                .foregroundStyle(t.muted)
            }
            Spacer()
            Button { showActions.toggle() } label: {
                HStack(spacing: 8) {
                    Text("Actions").fontWeight(.medium).foregroundStyle(t.ink)
                    KeyCap("⌘K")
                }
                .padding(.leading, 10).padding(.trailing, 6)
                .frame(height: 28)
                .background(hovering || showActions ? t.line : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .accessibilityLabel("More actions, Command K")
        }
        .font(.system(size: 12))
        .padding(.leading, 16).padding(.trailing, 8)
        .frame(height: 40)
        .overlay(alignment: .top) { Rectangle().fill(t.line).frame(height: 1) }
    }
}

private struct SpotlightActionsMenu: View {
    let actions: [SpotlightAction]
    @Binding var highlighted: Int
    let dismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.resolve(scheme)
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                if action.separatorBefore {
                    Rectangle().fill(t.line).frame(height: 1)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                }
                Button {
                    dismiss()
                    action.run()
                } label: {
                    HStack {
                        Text(action.title)
                            .foregroundStyle(action.destructive ? Color.red : t.ink)
                        Spacer()
                        KeyCap(action.keys)
                    }
                    .font(.system(size: 13))
                    .padding(.leading, 10).padding(.trailing, 8)
                    .frame(height: 30)
                    .background(index == highlighted ? t.accent.opacity(0.2) : .clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { if $0 { highlighted = index } }
            }
        }
        .padding(5)
        .frame(width: 248)
        .background(t.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(t.line))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

/// One cap per shortcut ("⌘↩" in a single box) instead of one box per key.
private struct KeyCap: View {
    let text: String
    @Environment(\.colorScheme) private var scheme
    init(_ text: String) { self.text = text }

    var body: some View {
        let t = Theme.resolve(scheme)
        Text(text)
            .font(spotMono(11))
            .foregroundStyle(t.muted)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(t.line))
    }
}

private struct SpotlightRow: View {
    let shot: Shot
    let selected: Bool
    @Binding var renaming: URL?
    @Binding var draft: String
    @FocusState private var fieldFocused: Bool
    @Environment(\.colorScheme) private var scheme

    private var isRenaming: Bool { renaming == shot.id }

    var body: some View {
        let t = Theme.resolve(scheme)
        HStack(spacing: 10) {
            SpotlightImage(url: shot.url, maxPoints: 56, fill: true)
                .frame(width: 52, height: 39)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(t.line))
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("Name", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .focused($fieldFocused)
                } else {
                    Text(shot.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1).truncationMode(.middle)
                }
                Text(shot.date.formatted(.relative(presentation: .named)))
                    .font(spotMono(11))
                    .foregroundStyle(t.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(selected ? t.accent.opacity(0.2) : .clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .onChange(of: renaming) { _, newValue in
            if newValue == shot.id { fieldFocused = true }
        }
    }
}

// MARK: - Image loading

private struct SpotlightImage: View {
    let url: URL
    let maxPoints: CGFloat
    var fill = false

    @State private var image: NSImage?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let t = Theme.resolve(scheme)
        ZStack {
            if fill { t.tile }
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
                    .clipShape(RoundedRectangle(cornerRadius: fill ? 0 : 8, style: .continuous))
            }
        }
        .task(id: url) {
            image = await SpotlightImageCache.shared.image(for: url, maxPixel: maxPoints * displayScale)
        }
    }
}

@MainActor
private final class SpotlightImageCache {
    static let shared = SpotlightImageCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(for url: URL, maxPixel: CGFloat) async -> NSImage? {
        let key = "\(url.path)#\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let cgImage = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }
}
