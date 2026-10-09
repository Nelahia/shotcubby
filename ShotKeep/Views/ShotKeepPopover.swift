//
//  ShotKeepPopover.swift
//  ShotKeep
//
//  Popover UI: header, source filter, thumbnail grid grouped by day,
//  hover actions, inline rename, folder-access card, footer.
//  Target: macOS 14+, SwiftUI + AppKit, no dependencies.
//
//  Hook-up (in your status item controller):
//
//      let view = PopoverView(
//          shots: store.shots,                       // newest first or any order
//          accessFailure: store.accessFailure,         // nil once readable
//          watchedFolder: store.screenshotFolder,    // e.g. ~/Desktop
//          keepFolder: store.keepFolder,             // ~/ShotKeep
//          actions: .live(chooseFolder: { store.pickFolder() },
//                         openSettings: { /* show your settings window */ })
//      )
//      popover.contentViewController = NSHostingController(rootView: view)
//

import SwiftUI
import AppKit
import ImageIO

// MARK: - Model

struct Shot: Identifiable, Hashable {
    enum Source { case file, clipboard }

    let url: URL
    let date: Date
    let source: Source

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

// MARK: - Actions

struct ShotActions {
    var open: (Shot) -> Void
    var copy: (Shot) -> Void
    var reveal: (Shot) -> Void
    var delete: (Shot) -> Void
    /// Second argument is the new base name, without extension.
    var rename: (Shot, String) -> Void
    var openSpotlight: () -> Void
    var openPrivacySettings: () -> Void
    var relaunch: () -> Void
    var chooseFolder: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void

    /// Default implementations. Your folder watcher should pick up the
    /// rename / delete and refresh `shots` on its own.
    static func live(chooseFolder: @escaping () -> Void,
                     openSettings: @escaping () -> Void) -> ShotActions {
        ShotActions(
            open: { NSWorkspace.shared.open($0.url) },
            copy: { shot in
                guard let image = NSImage(contentsOf: shot.url) else { return }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([image])
            },
            reveal: { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) },
            delete: { shot in
                do { try FileManager.default.trashItem(at: shot.url, resultingItemURL: nil) }
                catch { NSSound.beep() }
            },
            rename: { shot, newName in
                let clean = newName
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty, clean != shot.name else { return }
                let dest = shot.url.deletingLastPathComponent()
                    .appendingPathComponent(clean)
                    .appendingPathExtension(shot.url.pathExtension)
                guard !FileManager.default.fileExists(atPath: dest.path) else { NSSound.beep(); return }
                do { try FileManager.default.moveItem(at: shot.url, to: dest) }
                catch { NSSound.beep() }
            },
            openSpotlight: {},
            openPrivacySettings: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                    NSWorkspace.shared.open(url)
                }
            },
            relaunch: {},
            chooseFolder: chooseFolder,
            openSettings: openSettings,
            quit: { NSApp.terminate(nil) }
        )
    }
}

// MARK: - Theme

struct Theme {
    let bg: Color
    let panel: Color
    let ink: Color
    let muted: Color
    let line: Color
    let accent: Color
    let tile: Color
    let warn: Color

    /// Fixed dark navy from the app icon — used on the always-dark thumbnail
    /// scrim, where it shouldn't flip with light/dark mode like `ink` does.
    static let logoPrimary = Color(hex: 0x14191D)

    static func resolve(_ scheme: ColorScheme) -> Theme {
        scheme == .dark
            ? Theme(bg: Color(hex: 0x14191D), panel: Color(hex: 0x1E262B), ink: Color(hex: 0xF1F5F7),
                    muted: Color(hex: 0x9AA8B1), line: Color.white.opacity(0.10), accent: Color(hex: 0x35D6E6),
                    tile: Color(hex: 0x232C32), warn: Color(hex: 0xF2B25C))
            : Theme(bg: Color(hex: 0xF6F8FA), panel: Color(hex: 0xFFFFFF), ink: Color(hex: 0x0C1216),
                    muted: Color(hex: 0x56646E), line: Color.black.opacity(0.10), accent: Color(hex: 0x0FB6C9),
                    tile: Color(hex: 0xE3E9ED), warn: Color(hex: 0xA85A00))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

// MARK: - Glyph (viewfinder brackets around a kept shot)

struct ShotKeepGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            let scale = CGAffineTransform(scaleX: s, y: s)

            var brackets = Path()
            brackets.move(to: CGPoint(x: 3, y: 8))
            brackets.addArc(tangent1End: CGPoint(x: 3, y: 3), tangent2End: CGPoint(x: 8, y: 3), radius: 2.5)
            brackets.addLine(to: CGPoint(x: 8, y: 3))
            brackets.move(to: CGPoint(x: 16, y: 3))
            brackets.addArc(tangent1End: CGPoint(x: 21, y: 3), tangent2End: CGPoint(x: 21, y: 8), radius: 2.5)
            brackets.addLine(to: CGPoint(x: 21, y: 8))
            brackets.move(to: CGPoint(x: 21, y: 16))
            brackets.addArc(tangent1End: CGPoint(x: 21, y: 21), tangent2End: CGPoint(x: 16, y: 21), radius: 2.5)
            brackets.addLine(to: CGPoint(x: 16, y: 21))
            brackets.move(to: CGPoint(x: 8, y: 21))
            brackets.addArc(tangent1End: CGPoint(x: 3, y: 21), tangent2End: CGPoint(x: 3, y: 16), radius: 2.5)
            brackets.addLine(to: CGPoint(x: 3, y: 16))
            ctx.stroke(brackets.applying(scale), with: .foreground,
                       style: StrokeStyle(lineWidth: 2 * s, lineCap: .round, lineJoin: .round))

            var sheet = Path()
            sheet.move(to: CGPoint(x: 9.5, y: 7.25))
            sheet.addLine(to: CGPoint(x: 14.5, y: 7.25))
            ctx.stroke(sheet.applying(scale), with: .foreground,
                       style: StrokeStyle(lineWidth: 1.75 * s, lineCap: .round))

            let card = Path(roundedRect: CGRect(x: 7, y: 9.75, width: 10, height: 7.25), cornerRadius: 1.75)
            ctx.fill(card.applying(scale), with: .foreground)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Popover

struct PopoverView: View {
    let shots: [Shot]
    let accessFailure: FolderAccessFailure?
    let watchedFolder: URL
    let keepFolder: URL
    let actions: ShotActions

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", files = "Files", clipboard = "Clipboard"
        var id: String { rawValue }
        func matches(_ shot: Shot) -> Bool {
            switch self {
            case .all: return true
            case .files: return shot.source == .file
            case .clipboard: return shot.source == .clipboard
            }
        }
    }

    @State private var filter: Filter = .all
    @State private var renaming: URL?
    @Environment(\.colorScheme) private var scheme
    private var t: Theme { .resolve(scheme) }

    private var visible: [Shot] { shots.filter(filter.matches) }

    private var groups: [(day: Date, shots: [Shot])] {
        Dictionary(grouping: visible) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, shots: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let failure = accessFailure {
                AccessCard(failure: failure, watchedFolder: watchedFolder, keepFolder: keepFolder, actions: actions)
                    .padding(.horizontal, 14)
            } else {
                filterBar.padding(.horizontal, 14)
            }
            content
            Rectangle().fill(t.line).frame(height: 1)
            footer
        }
        .frame(width: 360)
        .background(t.bg)
        .foregroundStyle(t.ink)
        .font(.system(size: 13))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            ShotKeepGlyph()
                .frame(width: 18, height: 18)
                .foregroundStyle(t.ink)
            Text("ShotKeep").font(.system(size: 14, weight: .semibold))
            Text("\(visible.count)")
                .font(mono(11))
                .foregroundStyle(t.muted)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(t.line, in: Capsule())
                .accessibilityLabel("\(visible.count) screenshots")
            Spacer()
            IconButton(symbol: "gearshape", label: "Settings", action: actions.openSettings)
        }
        .padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 10)
    }

    // MARK: Filter

    private var filterBar: some View {
        HStack(spacing: 2) {
            ForEach(Filter.allCases) { item in
                let selected = item == filter
                Button { filter = item } label: {
                    HStack(spacing: 6) {
                        Text(item.rawValue).font(.system(size: 12, weight: .medium))
                        Text("\(shots.filter(item.matches).count)").font(mono(11)).opacity(0.7)
                    }
                    .foregroundStyle(selected ? t.ink : t.muted)
                    .frame(maxWidth: .infinity).frame(height: 26)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(t.panel)
                                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(t.line))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(t.line, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Grid

    // A fixed height here (not just a cap on the populated branch) matters:
    // NSHostingController auto-sizes the popover to its SwiftUI content's
    // fitting size. Letting the empty state size to its natural (much
    // shorter) height made the popover shrink when a filter had zero
    // results — and switching back to a populated filter never grew it
    // back, since a ScrollView's fitting height depends on the size last
    // proposed to it rather than requesting its own. Both branches now
    // always occupy the same height, so the popover never resizes at all.
    @ViewBuilder private var content: some View {
        Group {
            if visible.isEmpty {
                VStack(spacing: 6) {
                    ShotKeepGlyph().frame(width: 28, height: 28).foregroundStyle(t.muted)
                    Text("No screenshots yet").font(.system(size: 13, weight: .medium))
                    Text("Press ⌘⇧4 and it lands here.").font(.system(size: 12)).foregroundStyle(t.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.day) { group in
                            Text(dayLabel(group.day).uppercased())
                                .font(mono(11)).tracking(0.7)
                                .foregroundStyle(t.muted)
                                .padding(.top, 12).padding(.bottom, 8)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                                ForEach(group.shots) { shot in
                                    ShotTile(shot: shot, renaming: $renaming, actions: actions)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 14)
                }
            }
        }
        .frame(height: 400)
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.day().month(.wide))
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            FooterButton(action: actions.openSpotlight) {
                Image(systemName: "magnifyingglass")
                Text("Open Spotlight")
                KeyHint("⌘O")
            }
            .keyboardShortcut("o", modifiers: .command)
            Spacer()
            FooterButton(action: actions.quit) {
                Text("Quit").foregroundStyle(t.muted)
                KeyHint("⌘Q")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(6)
    }
}

// MARK: - Tile

private struct ShotTile: View {
    let shot: Shot
    @Binding var renaming: URL?
    let actions: ShotActions

    @State private var hovering = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.colorScheme) private var scheme
    private var t: Theme { .resolve(scheme) }

    private var isRenaming: Bool { renaming == shot.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Thumbnail(url: shot.url)
                .overlay {
                    if hovering && !isRenaming {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.55))
                            RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(t.accent, lineWidth: 1.5)
                            HStack(spacing: 4) {
                                OverlayButton(symbol: "doc.on.doc", label: "Copy") { actions.copy(shot) }
                                OverlayButton(symbol: "folder", label: "Reveal in Finder") { actions.reveal(shot) }
                                OverlayButton(symbol: "trash", label: "Delete") { actions.delete(shot) }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { actions.open(shot) }

            if isRenaming {
                TextField("Name", text: $draft)
                    .textFieldStyle(.plain)
                    .font(mono(11))
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(t.panel, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(t.accent, lineWidth: 2))
                    .focused($fieldFocused)
                    .onSubmit(commit)
                    .onExitCommand { renaming = nil }
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused { commit() }
                    }
            } else {
                Text(shot.name)
                    .font(mono(11))
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: beginRename)
                    .help("Double-click to rename")
            }

            HStack {
                Text(shot.date.formatted(date: .omitted, time: .shortened))
                Spacer()
                Text(shot.source == .clipboard ? "Clipboard" : shot.url.pathExtension.uppercased())
            }
            .font(mono(10))
            .foregroundStyle(t.muted)
            .padding(.horizontal, 5)
        }
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
        }
        .contextMenu {
            Button("Open") { actions.open(shot) }
            Button("Rename", action: beginRename)
            Button("Copy") { actions.copy(shot) }
            Button("Reveal in Finder") { actions.reveal(shot) }
            Divider()
            Button("Move to Trash", role: .destructive) { actions.delete(shot) }
        }
    }

    private func beginRename() {
        draft = shot.name
        renaming = shot.id
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func commit() {
        guard isRenaming else { return }
        renaming = nil
        actions.rename(shot, draft)
    }
}

// MARK: - Thumbnail

private struct Thumbnail: View {
    let url: URL
    @State private var image: NSImage?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let t = Theme.resolve(scheme)
        t.tile
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(t.line))
            .task(id: url) {
                image = await ThumbnailCache.shared.image(for: url, maxPixel: 120 * displayScale)
            }
    }
}

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    func image(for url: URL, maxPixel: CGFloat) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let cgImage = await Task.detached(priority: .utility) { () -> CGImage? in
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
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

// MARK: - Folder access card

private struct AccessCard: View {
    let failure: FolderAccessFailure
    let watchedFolder: URL
    let keepFolder: URL
    let actions: ShotActions
    @Environment(\.colorScheme) private var scheme

    // MARK: - Copy
    //
    // Each case names the thing the user has to act on. A cloud-synced
    // folder is granted in a different System Settings pane than a plain
    // Desktop, under the provider's name rather than "screenshot folder" —
    // so the card has to say "OneDrive", or the instruction doesn't match
    // what's actually on screen in System Settings.

    private var title: String {
        switch failure {
        case .cloudProvider(let name): return "Let ShotKeep read your \(name) folder"
        case .protectedFolder: return "Let ShotKeep read your screenshot folder"
        case .missing: return "That screenshot folder is gone"
        }
    }

    private var explanation: String {
        switch failure {
        case .cloudProvider(let name):
            return "Your screenshots land in a folder \(name) syncs, and macOS keeps those behind their own permission. Allow ShotKeep under Files and Folders — the Desktop switch doesn't cover this one."
        case .protectedFolder:
            return "macOS needs your OK before ShotKeep can move new screenshots out of it. Nothing else in the folder is touched."
        case .missing:
            return "ShotKeep can't find the folder it was watching. Pick the folder your screenshots actually go to."
        }
    }

    private var settingsLabel: String {
        switch failure {
        case .cloudProvider: return "Open Files & Folders"
        default: return "Open Privacy Settings"
        }
    }

    var body: some View {
        let t = Theme.resolve(scheme)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().frame(width: 7, height: 7)
                Text("Clipboard captures only").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(t.warn)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(explanation)
                    .foregroundStyle(t.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text(tilde(watchedFolder))
                Image(systemName: "arrow.right").foregroundStyle(t.accent)
                Text(tilde(keepFolder))
                Spacer(minLength: 0)
            }
            .font(mono(12))
            .lineLimit(1).truncationMode(.middle)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(t.bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(t.line))

            if case .missing = failure {
                Button(action: actions.chooseFolder) {
                    Text("Choose Folder…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.bg)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(t.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            } else {
                VStack(spacing: 6) {
                    Button(action: actions.openPrivacySettings) {
                        Text(settingsLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(t.bg)
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(t.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)

                    // macOS caches the denial for the life of the process, so a
                    // grant given just now can't reach the already-running app.
                    // This is the same thing System Settings calls "Quit &
                    // Reopen" — without it the card looks broken to someone who
                    // just said yes.
                    Button(action: actions.relaunch) {
                        Text("Already allowed? Relaunch ShotKeep")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(t.accent)

                    Button(action: actions.chooseFolder) {
                        Text("Use a different folder…")
                            .foregroundStyle(t.muted)
                            .frame(maxWidth: .infinity).frame(height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(t.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(t.line))
    }

    private func tilde(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - Small controls

private struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.resolve(scheme)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? t.ink : t.muted)
                .frame(width: 30, height: 30)
                .background(hovering ? t.line : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct OverlayButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(hovering ? Theme.logoPrimary : Color.white.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct FooterButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.resolve(scheme)
        Button(action: action) {
            HStack(spacing: 8) { label() }
                .padding(.horizontal, 8).frame(height: 30)
                .background(hovering ? t.line : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct KeyHint: View {
    let text: String
    @Environment(\.colorScheme) private var scheme
    init(_ text: String) { self.text = text }

    var body: some View {
        let t = Theme.resolve(scheme)
        Text(text)
            .font(mono(11))
            .foregroundStyle(t.muted)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(t.line))
    }
}

// MARK: - Preview

#Preview("Grid") {
    let now = Date()
    let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("ShotKeep")
    let sample: [Shot] = (0..<9).map { i in
        Shot(url: folder.appendingPathComponent("Screenshot \(i).png"),
             date: now.addingTimeInterval(Double(-i) * 4 * 3600),
             source: i % 3 == 0 ? .clipboard : .file)
    }
    return PopoverView(shots: sample, accessFailure: nil,
                       watchedFolder: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop"),
                       keepFolder: folder,
                       actions: .live(chooseFolder: {}, openSettings: {}))
}

#Preview("Needs access") {
    let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("ShotKeep")
    return PopoverView(shots: [], accessFailure: .protectedFolder,
                       watchedFolder: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop"),
                       keepFolder: folder,
                       actions: .live(chooseFolder: {}, openSettings: {}))
}

#Preview("Needs cloud access") {
    let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("ShotKeep")
    return PopoverView(shots: [], accessFailure: .cloudProvider(name: "OneDrive"),
                       watchedFolder: URL(fileURLWithPath: NSHomeDirectory())
                           .appendingPathComponent("Library/CloudStorage/OneDrive-Example/Desktop"),
                       keepFolder: folder,
                       actions: .live(chooseFolder: {}, openSettings: {}))
}
