import SwiftUI

let players = ["com.spotify.client", "com.apple.Music"]

func osa(_ source: String) -> NSAppleEventDescriptor? {
    var error: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
    return error == nil ? result : nil
}

// Never script an app that isn't running: AppleScript would launch it.
func isRunning(_ id: String) -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty
}

final class NowPlaying: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var playing = false
    @Published var cover: NSImage?
    private var player = players[0]
    private var coverKey = ""

    init() {
        // Both apps broadcast on every track/state change, so no polling is needed.
        let names = ["com.spotify.client.PlaybackStateChanged", "com.apple.Music.playerInfo"]
        for (name, id) in zip(names, players) {
            DistributedNotificationCenter.default().addObserver(
                forName: .init(name), object: nil, queue: .main
            ) { [weak self] note in
                // "Stopped" is also sent on quit; scripting the app then would relaunch it.
                self?.refresh(id, stopped: note.userInfo?["Player State"] as? String == "Stopped")
            }
        }
        for id in players {
            refresh(id)
            if playing { break }
        }
    }

    func send(_ command: String) {
        guard isRunning(player) else { return }
        _ = osa("tell application id \"\(player)\" to \(command)")
    }

    private func refresh(_ id: String, stopped: Bool = false) {
        let art = id == players[0] ? "artwork url of current track" : "\"\""
        let script = """
        tell application id "\(id)"
            if player state is stopped then return ""
            return (name of current track) & linefeed & (artist of current track) & linefeed & (player state as text) & linefeed & \(art)
        end tell
        """
        let parts = !stopped && isRunning(id)
            ? (osa(script)?.stringValue ?? "").components(separatedBy: "\n") : []
        guard parts.count == 4 else {
            if id == player {
                title = ""; artist = ""; playing = false; cover = nil; coverKey = ""
            }
            return
        }
        let isPlaying = parts[2] == "playing"
        // A paused player must not steal the widget from the one being listened to.
        guard isPlaying || id == player || title.isEmpty else { return }
        player = id
        title = parts[0]
        artist = parts[1]
        playing = isPlaying
        let trackKey = id + parts[0] + parts[1] + parts[3]
        if trackKey != coverKey {
            coverKey = trackKey
            loadCover(id, parts[3], key: trackKey)
        }
    }

    private func loadCover(_ id: String, _ urlString: String, key: String, retry: Bool = true) {
        if !urlString.isEmpty, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                let image = data.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async { if self.coverKey == key { self.cover = image } }
            }.resume()
            return
        }
        cover = osa("tell application id \"\(id)\" to get raw data of artwork 1 of current track")
            .flatMap { NSImage(data: $0.data) }
        // Music often has no artwork yet when a streamed track starts: try once more.
        if cover == nil, retry {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.coverKey == key, isRunning(id) {
                    self.loadCover(id, urlString, key: key, retry: false)
                }
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
    @State private var hover = false

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
            .overlay { controls.opacity(hover ? 1 : 0) }
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
        .onHover { inside in withAnimation(.easeInOut(duration: 0.15)) { hover = inside } }
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
