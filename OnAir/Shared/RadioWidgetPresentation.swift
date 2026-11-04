#if os(iOS) || os(watchOS)
import SwiftUI
import WidgetKit
import AppIntents
enum WidgetRadioChoice: String, AppEnum {
    case recent, morning, commute, bedtime
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "방송 선택")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.recent: "최근 방송", .morning: "출근 프리셋", .commute: "퇴근 프리셋", .bedtime: "취침 프리셋"]
    var presetKind: RadioPresetKind? { RadioPresetKind(rawValue: rawValue) }
}
struct RadioEntry: TimelineEntry {
    let date: Date
    let snapshot: ListeningSnapshot
    var choice: WidgetRadioChoice = .recent
    var night = false
    var preset: RadioPreset? { RadioPresets.read().first { $0.kind == choice.presetKind } }
    var station: Station? { preset?.station ?? snapshot.station ?? snapshot.favorites.first ?? Station.curated.first }
    var active: Bool { station?.id == snapshot.station?.id && snapshot.isPlaying }
    var connecting: Bool { station?.id == snapshot.station?.id && snapshot.buffering == true }
}
struct RadioWidgetView: View {
    var entry: RadioEntry
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var environmentFamily
    var family: WidgetFamily { familyOverride ?? environmentFamily }
    @Environment(\.isLuminanceReduced) var reduced
    var body: some View {
        Group {
            if family == .accessoryCircular {
                playbackButton
            } else if family == .accessoryInline {
                Text("온에어 · \(entry.station?.name ?? "라디오 듣기")")
            } else if family == .accessoryRectangular {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.station?.name ?? "좋아하는 주파수").font(.headline).lineLimit(1)
                        Text(entry.connecting ? "연결 중" : entry.active ? "재생 중" : "라디오 듣기").font(.caption2)
                    }
                    Spacer(minLength: 4); playbackButton
                }
            } else if entry.night {
                nightView
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Label("온에어", systemImage: "dot.radiowaves.left.and.right").font(.caption.bold()).widgetAccentable(); Spacer(); playbackButton }
                    HStack(spacing: 10) {
                        if let station = entry.station { StationArtwork(station: station).frame(width: 46, height: 46) }
                        Text(entry.station?.name ?? "일상에, 좋은 주파수.").font(.title3.bold()).lineLimit(2)
                    }
                    Text(entry.connecting ? "방송 연결 중…" : entry.active ? "지금 듣는 중" : "눌러서 방송 듣기").font(.caption).foregroundStyle(.secondary)
                    #if os(iOS)
                    if family == .systemMedium {
                        HStack {
                            ForEach(Array(entry.snapshot.favorites.prefix(3))) { station in
                                Button(intent: RadioPlaybackIntent(stationID: station.id, shouldPause: false)) { Text(station.name).font(.caption2.bold()).lineLimit(1) }.buttonStyle(.bordered)
                            }
                        }
                    }
                    #endif
                }
            }
        }.containerBackground(for: .widget) { entry.night ? Color(red: 0.055, green: 0.065, blue: 0.085) : Color.clear }
        .foregroundStyle(entry.night ? Color.white : Color.primary)
        .widgetURL(SharedStore.link(entry.station))
    }
    @ViewBuilder var playbackButton: some View {
        if let kind = entry.choice.presetKind, !entry.active, !entry.connecting {
            Button(intent: PlayRadioPresetIntent(kind: kind)) { buttonIcon }.buttonStyle(.plain).accessibilityLabel("프리셋 재생")
        } else {
            Button(intent: RadioPlaybackIntent(stationID: entry.station?.id ?? "", shouldPause: entry.active || entry.connecting)) { buttonIcon }.buttonStyle(.plain).accessibilityLabel(entry.active || entry.connecting ? "일시정지" : "방송 재생")
        }
    }
    var buttonIcon: some View {
        Image(systemName: entry.active || entry.connecting ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: family == .accessoryCircular ? 30 : 32)).foregroundStyle(entry.night || reduced ? Color.orange : RadioDesign.coral)
            .frame(minWidth: 36, minHeight: 36)
    }
    var nightView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "moon.stars").foregroundStyle(.orange); Text("침대 옆 라디오").font(.caption2); Spacer() }
            Text(entry.date, format: .dateTime.hour().minute()).font(.system(size: 34, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
            HStack { Text(entry.station?.name ?? "오늘도 편안한 밤").font(.subheadline.bold()).lineLimit(2); Spacer(minLength: 4); playbackButton }
            if entry.station?.id == entry.snapshot.station?.id, let end = entry.snapshot.sleepEnd, end > entry.date {
                HStack { Image(systemName: "moon.zzz"); Text(timerInterval: entry.date...end, countsDown: true) }.font(.caption.monospacedDigit()).foregroundStyle(.orange)
            } else { Text(entry.active ? "지금 듣는 중" : entry.preset?.sleepMinutes.map { "\($0)분 취침 프리셋" } ?? "편안하게 라디오 듣기").font(.caption2).foregroundStyle(.orange) }
        }
    }
}

#endif
