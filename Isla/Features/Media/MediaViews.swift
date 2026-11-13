//
//  MediaViews.swift
//  Isla
//

import SwiftUI

/// The large Now Playing card used in the Nook.
struct NowPlayingCard: View {
    private let media = NowPlayingService.shared
    private let lyrics = LyricsService.shared
    @State private var showLyrics = false

    var body: some View {
        IslaCard(padding: 12) {
            if let info = media.info, media.hasActiveMedia {
                HStack(alignment: .top, spacing: 14) {
                    artwork
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                MarqueeText(text: info.title, font: .system(size: 14, weight: .semibold))
                                Text(info.artist.isEmpty ? (media.appName ?? "") : info.artist)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            if lyrics.hasSyncedLyrics {
                                Button {
                                    withAnimation(IslaMotion.content) { showLyrics.toggle() }
                                } label: {
                                    Image(systemName: "quote.bubble.fill")
                                        .foregroundStyle(showLyrics ? Color.white : .secondary)
                                }
                                .buttonStyle(NotchIconButtonStyle(size: 24))
                                .help(String(localized: "Lyrics"))
                                .accessibilityLabel(Text("Lyrics"))
                            }
                        }

                        Spacer(minLength: 6)

                        if showLyrics && lyrics.hasSyncedLyrics {
                            LyricsTicker(info: info)
                                .transition(.blurReplace)
                        } else {
                            ScrubBar(info: info, tint: media.accentColor ?? .white)
                                .transition(.blurReplace)
                        }

                        Spacer(minLength: 6)

                        TransportControls(size: 1)
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                IdleMediaView()
            }
        }
    }

    private var artwork: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.height, 150)
            ZStack(alignment: .bottomTrailing) {
                ArtworkThumbnail(size: side, radius: 14)
                    .shadow(color: (media.accentColor ?? .black).opacity(0.45), radius: 14, y: 6)
                    // A new song swaps the cover with a soft blur instead of a cut.
                    .id(media.info.map { "\($0.title)|\($0.artist)" } ?? "")
                    .transition(.blurReplace)
                    .animation(IslaMotion.content, value: media.info?.title)
                    .scaleEffect(media.isPlaying ? 1 : 0.94)
                    .animation(IslaMotion.activity, value: media.isPlaying)
                if let icon = media.appIcon, media.artwork != nil {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .shadow(radius: 2)
                        .offset(x: 5, y: 5)
                }
            }
            .onTapGesture { media.openPlayer() }
            .help(String(localized: "Open \(media.appName ?? "player")"))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct TransportControls: View {
    var size: CGFloat = 1
    private let media = NowPlayingService.shared

    var body: some View {
        HStack(spacing: 18 * size) {
            Button { media.previous() } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(NotchIconButtonStyle(size: 32 * size))

            Button { media.togglePlayPause() } label: {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(NotchIconButtonStyle(size: 40 * size, prominent: true))

            Button { media.next() } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(NotchIconButtonStyle(size: 32 * size))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Draggable playback progress, extrapolated every frame.
struct ScrubBar: View {
    let info: NowPlayingInfo
    var tint: Color = .white
    @State private var dragValue: Double?
    @State private var hovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = dragValue ?? info.elapsed(at: context.date)
            let duration = max(info.duration, 0.1)
            VStack(spacing: 4) {
                GeometryReader { proxy in
                    let progress = min(1, max(0, elapsed / duration))
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.16))
                        Capsule()
                            .fill(tint)
                            .frame(width: max(4, proxy.size.width * progress))
                    }
                    .frame(height: hovering || dragValue != nil ? 7 : 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(1, max(0, value.location.x / proxy.size.width))
                            dragValue = ratio * duration
                        }
                        .onEnded { value in
                            let ratio = min(1, max(0, value.location.x / proxy.size.width))
                            NowPlayingService.shared.seek(to: ratio * duration)
                            dragValue = nil
                        })
                    .onHover { hovering = $0 }
                    .animation(IslaMotion.snappy, value: hovering)
                }
                .frame(height: 10)

                HStack {
                    Text(elapsed.clockString)
                    Spacer()
                    Text(info.duration > 0 ? "-" + max(0, info.duration - elapsed).clockString : "")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Current lyric line with the previous and next lines fading around it.
struct LyricsTicker: View {
    let info: NowPlayingInfo
    private let lyrics = LyricsService.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let current = lyrics.line(at: info.elapsed(at: context.date))
            let index = current?.id ?? -1
            VStack(alignment: .leading, spacing: 2) {
                Text(index >= 0 ? lyrics.lines[index].text : "♪")
                    .font(.system(size: 13.5, weight: .bold))
                    .lineLimit(2)
                    .contentTransition(.opacity)
                if index + 1 < lyrics.lines.count {
                    Text(lyrics.lines[index + 1].text)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(IslaInk.faint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth(duration: 0.35), value: index)
        }
    }
}

struct IdleMediaView: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                Image(systemName: "music.note")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(IslaInk.faint)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing playing")
                    .font(.system(size: 14, weight: .semibold))
                Text("Play something in Music, Spotify or your browser and it will appear here.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Button("Music") { launch("com.apple.Music") }
                    Button("Spotify") { launch("com.spotify.client") }
                }
                .buttonStyle(NotchPillButtonStyle())
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private func launch(_ bundle: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
