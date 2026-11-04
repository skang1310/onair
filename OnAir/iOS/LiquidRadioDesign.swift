import SwiftUI

enum LiquidRadioTheme {
    static let accent = Color(red: 1, green: 0.43, blue: 0.08)
    static func colors(_ palette: Int) -> [Color] {
        switch palette % 4 {
        case 0: [Color(red: 0.51, green: 0.38, blue: 0.87), Color(red: 0.24, green: 0.29, blue: 0.63)]
        case 1: [Color(red: 0.22, green: 0.64, blue: 0.66), Color(red: 0.13, green: 0.34, blue: 0.49)]
        case 2: [Color(red: 0.45, green: 0.49, blue: 0.91), Color(red: 0.27, green: 0.24, blue: 0.57)]
        default: [Color(red: 0.9, green: 0.51, blue: 0.39), Color(red: 0.61, green: 0.28, blue: 0.42)]
        }
    }
}
struct LiquidRadioBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Color(uiColor: scheme == .dark ? .systemBackground : UIColor(red: 0.97, green: 0.965, blue: 0.95, alpha: 1))
            .ignoresSafeArea().accessibilityHidden(true)
    }
}
struct LiquidStationMark: View {
    let station: Station
    var size: CGFloat = 52
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18).fill(LinearGradient(colors: LiquidRadioTheme.colors(station.palette), startPoint: .topLeading, endPoint: .bottomTrailing))
            if let asset = station.logoAsset {
                Image(asset).resizable().scaledToFit().padding(size * 0.12)
                    .background(asset == "StationLogoMBC" ? Color(red: 0.12, green: 0.14, blue: 0.2) : Color.white, in: .rect(cornerRadius: size * 0.12)).padding(size * 0.12)
            } else { Image(systemName: "waveform").font(.system(size: size * 0.4)).foregroundStyle(.white) }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
struct LiquidStationCard: View {
    let station: Station
    let favorite: Bool
    let playing: Bool
    let play: () -> Void
    let toggleFavorite: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button(action: play) {
                HStack(spacing: 13) {
                    LiquidStationMark(station: station, size: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(station.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                        Text(station.category + (RadioFrequency.label(station) == "LIVE" ? " · 인터넷 라디오" : " · FM " + RadioFrequency.label(station))).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: playing ? "waveform" : "play.fill").font(.system(size: 13)).foregroundStyle(playing ? LiquidRadioTheme.accent : .secondary)
                }.frame(maxWidth: .infinity, minHeight: 54).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(station.name) 재생").accessibilityIdentifier("station-play-\(station.catalogKey)")
            Button(action: toggleFavorite) { Image(systemName: favorite ? "heart.fill" : "heart").font(.system(size: 16)).frame(width: 44, height: 44) }
                .buttonStyle(.plain).foregroundStyle(favorite ? LiquidRadioTheme.accent : .secondary)
                .accessibilityLabel("\(station.name) 즐겨찾기 변경")
                .accessibilityIdentifier("station-favorite-\(station.catalogKey)").accessibilityValue(favorite ? "저장됨" : "저장 안 됨")
        }.padding(.vertical, 9).padding(.horizontal, 10)
            .background(playing ? LiquidRadioTheme.accent.opacity(0.05) : .clear, in: .rect(cornerRadius: 12))
            .overlay(alignment: .bottom) { Rectangle().fill(.primary.opacity(0.05)).frame(height: 0.5).padding(.leading, 71) }
    }
}
struct LiquidSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

struct LiquidPlayerArtwork: View {
    let station: Station
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.19, green: 0.24, blue: 0.29), Color(red: 0.07, green: 0.10, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.035), lineWidth: proxy.size.width * 0.12).frame(width: proxy.size.width * 0.95).offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.2)
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("ON AIR").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2); Spacer(); Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(LiquidRadioTheme.accent) }
                    Spacer()
                    LiquidStationMark(station: station, size: proxy.size.width * 0.28)
                    Text(station.name).font(.system(size: max(16, proxy.size.width * 0.085), weight: .bold)).tracking(-0.7).lineLimit(2)
                    HStack { Text(RadioFrequency.label(station)).font(.system(size: 11, design: .monospaced)); Spacer(); Text("YOUR DAILY FREQUENCY").font(.system(size: 6, weight: .medium, design: .monospaced)).tracking(1) }.foregroundStyle(.white.opacity(0.5))
                }.padding(proxy.size.width * 0.1)
            }.foregroundStyle(.white).clipShape(.rect(cornerRadius: 24))
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
