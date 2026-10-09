//
//  ShotKeepSpotlight.swift
//  ShotKeep
//
//  A Spotlight-style floating panel, opened by a global shortcut, to search
//  and act on captures from the keyboard.
//  Needs Shot, ShotActions, Theme and ShotKeepGlyph from ShotKeepPopover.swift.
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
//      ⌘⌫       move to Trash
//

import SwiftUI
import AppKit
import ImageIO
import Carbon.HIToolbox

// MARK: - Global hot key

final class GlobalHotKey {
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
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x53484B50), id: 1) // 'SHKP'
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
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

        let root = SpotlightView(
            model: model,
            onCopy: { [weak self] in self?.copySelected() },
            onPreview: { [weak self] in self?.previewSelected() },
            onReveal: { [weak self] in self?.revealSelected() },
            onDelete: { [weak self] in self?.deleteSelected() },
            onClose: { [weak self] in self?.closeOrClearSearch() }
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
    let onPreview: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

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
            Rectangle().fill(t.line).frame(height: 1)
            hints
        }
        .frame(width: 720, height: 460)
        .background(t.bg)
        .foregroundStyle(t.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(t.line))
        .onAppear { searchFocused = true }
        .onChange(of: model.showCount) { _, _ in searchFocused = true }
    }

    private func searchRow(count: Int) -> some View {
        HStack(spacing: 12) {
            ShotKeepGlyph().frame(width: 24, height: 24).foregroundStyle(t.ink)
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

    private var hints: some View {
        HStack(spacing: 16) {
            HintButton(key: "↩", label: "Copy", action: onCopy)
            HintButton(key: "⌘↩", label: "Preview", action: onPreview)
            HintButton(key: "⌘R", label: "Open Folder", action: onReveal)
            HintButton(key: "⌘E", label: "Rename", action: model.beginRename)
            HintButton(key: "⌘⌫", label: "Trash", action: onDelete)
            Spacer()
            HintButton(key: "esc", label: "Close", action: onClose)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
    }
}

/// Each hint in the footer doubles as a button — clicking "Rename" does the
/// same thing pressing ⌘E would.
private struct HintButton: View {
    let key: String
    let label: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.resolve(scheme)
        Button(action: action) {
            HStack(spacing: 6) {
                Text(key)
                    .font(spotMono(11))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(t.line))
                Text(label).font(.system(size: 12))
            }
            .foregroundStyle(hovering ? t.ink : t.muted)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
