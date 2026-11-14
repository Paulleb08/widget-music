import SwiftUI

let music = "com.apple.Music"

func osa(_ source: String) -> NSAppleEventDescriptor? {
    var error: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
    return error == nil ? result : nil
}

// Never script Music when it isn't running: AppleScript would launch it.
func musicIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: music).isEmpty
}

final class NowPlaying: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var playing = false
    @Published var cover: NSImage?
    // Not @State: its macro plugin ships only with full Xcode, not the Command Line Tools.
    @Published var hover = false
    private var coverKey = ""

    init() {
        // Music broadcasts on every track/state change, so no polling is needed.
        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.Music.playerInfo"), object: nil, queue: .main
        ) { [weak self] note in
            // "Stopped" is also sent on quit; scripting Music then would relaunch it.
            self?.refresh(stopped: note.userInfo?["Player State"] as? String == "Stopped")
        }
        refresh()
    }

    func send(_ command: String) {
        guard musicIsRunning() else { return }
        _ = osa("tell application id \"\(music)\" to \(command)")
    }

    private func refresh(stopped: Bool = false) {
        let script = """
        tell application id "\(music)"
            if player state is stopped then return ""
            return (name of current track) & linefeed & (artist of current track) & linefeed & (player state as text)
        end tell
        """
        let parts = !stopped && musicIsRunning()
            ? (osa(script)?.stringValue ?? "").components(separatedBy: "\n") : []
        guard parts.count == 3 else {
            title = ""; artist = ""; playing = false; cover = nil; coverKey = ""
            return
        }
        title = parts[0]
        artist = parts[1]
        playing = parts[2] == "playing"
        let key = parts[0] + "\n" + parts[1]
        if key != coverKey {
            coverKey = key
            loadCover(key: key)
        }
    }

    private func loadCover(key: String, retry: Bool = true) {
        cover = osa("tell application id \"\(music)\" to get raw data of artwork 1 of current track")
            .flatMap { NSImage(data: $0.data) }
        // Music often has no artwork yet when a streamed track starts: try once more.
        if cover == nil, retry {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.coverKey == key, musicIsRunning() { self.loadCover(key: key, retry: false) }
            }
        }
    }
}

struct Backdrop: ViewModifier {
    let colored: Bool
    let cover: NSImage?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if colored {
            content
                .background {
                    ZStack {
                        Color.black
                        if let cover {
                            Image(nsImage: cover).resizable().scaledToFill()
                                .blur(radius: 30).opacity(0.85)
                        }
                    }
                }
                .clipShape(shape)
                .environment(\.colorScheme, .dark)
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                content.background(.ultraThinMaterial, in: shape)
            }
            #else
            content.background(.ultraThinMaterial, in: shape)
            #endif
        }
    }
}

struct WidgetView: View {
    @ObservedObject var np: NowPlaying
    @AppStorage("style") private var style = "glass"

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Color.gray.opacity(0.3)
                if let image = np.cover {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note").font(.system(size: 60)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .overlay { controls.opacity(np.hover ? 1 : 0) }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 2) {
                Text(np.title.isEmpty ? "Aucune lecture" : np.title).font(.headline)
                Text(np.artist.isEmpty ? " " : np.artist).font(.subheadline).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(width: 200)
        }
        .padding(12)
        .modifier(Backdrop(colored: style == "color", cover: np.cover))
        .onHover { inside in withAnimation(.easeInOut(duration: 0.15)) { np.hover = inside } }
    }

    private var controls: some View {
        ZStack {
            Color.black.opacity(0.4)
            HStack(spacing: 24) {
                button("backward.fill", "Précédent") { np.send("previous track") }
                button(np.playing ? "pause.fill" : "play.fill", np.playing ? "Pause" : "Lecture") {
                    np.send("playpause")
                }
                .font(.system(size: 36))
                button("forward.fill", "Suivant") { np.send("next track") }
            }
            .font(.system(size: 22))

            Menu {
                Picker("Style", selection: $style) {
                    Text("Liquid Glass").tag("glass")
                    Text("Coloré").tag("color")
                }
                .pickerStyle(.inline)
                Divider()
                Button("Quitter") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Paramètres")
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)  // keeps the gear white on the dark scrim
    }

    private func button(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }
}

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let host = NSHostingView(rootView: WidgetView(np: NowPlaying()))
let panel = Panel(
    contentRect: NSRect(origin: .zero, size: host.fittingSize),
    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.contentView = host
panel.isOpaque = false
panel.backgroundColor = .clear
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
panel.isMovableByWindowBackground = true
if !panel.setFrameUsingName("MusicWidget") { panel.center() }
panel.setFrameAutosaveName("MusicWidget")
panel.orderFrontRegardless()
app.run()
