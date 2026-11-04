import SwiftUI

struct RadioDiscoveryHero: View {
    let stations: [Station]
    @State private var player = RadioPlayer.shared
    @State private var schedule = ProgramSchedule.shared
    @Environment(\.openURL) private var openURL
    @State private var showNight = false
    @State private var showShare = false
    private var station: Station? { player.station ?? stations.first { $0.catalogKey == "cbsmusic" } ?? stations.first }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                if let station {
                    Button { if player.station == nil { player.play(station) }; openURL(URL(string: "onair://player")!) } label: { LiquidPlayerArtwork(station: station).frame(width: 112, height: 112).shadow(color: .black.opacity(0.08), radius: 12, y: 7) }.buttonStyle(.plain).accessibilityLabel("재생 화면 열기").contextMenu { Button("탁상 라디오", systemImage: "moon.stars") { showNight = true }; Button("방송 공유", systemImage: "square.and.arrow.up") { showShare = true } }
                    VStack(alignment: .leading, spacing: 9) {
                        Text(player.isPlaying ? "지금 듣는 방송" : "오늘의 선택").font(.caption).foregroundStyle(.secondary)
                        Text(station.name).font(.system(size: 21, weight: .bold)).lineLimit(2)
                        Text(RadioFrequency.label(station) == "LIVE" ? "인터넷 라디오" : "FM " + RadioFrequency.label(station)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        if player.station?.catalogKey == station.catalogKey { player.toggle() } else { player.play(station) }
                    } label: {
                        Image(systemName: player.isPlaying || player.buffering ? "pause.fill" : "play.fill").font(.system(size: 17, weight: .semibold)).frame(width: 46, height: 46)
                    }.buttonStyle(.glassProminent).tint(LiquidRadioTheme.accent).buttonBorderShape(.circle).accessibilityLabel(player.isPlaying || player.buffering ? "일시정지" : "방송 듣기").accessibilityIdentifier("hero-play")
                }
            }
            if player.station != nil {
                HStack { Text(player.connectionLabel).font(.caption).foregroundStyle(.secondary); Spacer(); if player.error != nil { Button("다시 시도") { player.resume() }.font(.caption.weight(.semibold)) } }
            }
        }.padding(.vertical, 8)
            .fullScreenCover(isPresented: $showNight) { BedsideRadioView() }
            .sheet(isPresented: $showShare) { if let station { NavigationStack { ShareRadioView(station: station) } } }
            .onAppear { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
            .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications() }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                if UIDevice.current.userInterfaceIdiom == .phone && UIDevice.current.orientation.isLandscape { showNight = true }
            }
            #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-showNight") { showNight = true }
                if ProcessInfo.processInfo.arguments.contains("-showShare") { showShare = true }
            }
            #endif
    }
}

