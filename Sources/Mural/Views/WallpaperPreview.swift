import AppKit
import AVFoundation
import SwiftUI

struct WallpaperPreview: View {
    let wallpaper: Wallpaper

    var body: some View {
        Group {
            switch wallpaper.source {
            case .procedural(let preset):
                WallpaperArtwork(preset: preset)
            case .bundled(let url):
                if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            case .imported(let url):
                if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            case .video(let url):
                LoopingVideoPreview(url: url)
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            Color(nsColor: .quaternaryLabelColor)
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LoopingVideoPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(url: url)
    }

    func updateNSView(_ view: LoopingPlayerView, context: Context) {
        view.update(url: url)
    }
}

private final class LoopingPlayerView: NSView {
    private let player = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init(url: URL) {
        super.init(frame: .zero)
        wantsLayer = true
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
        update(url: url)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    func update(url: URL) {
        guard currentURL != url else { return }
        currentURL = url
        player.removeAllItems()
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    deinit {
        player.pause()
    }
}
