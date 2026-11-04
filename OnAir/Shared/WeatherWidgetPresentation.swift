#if os(iOS)
import SwiftUI
import WidgetKit

struct WeatherRadioEntry: TimelineEntry {
    let date: Date
    let radio: RadioEntry
    let weather: RadioWeather?
    let region: WeatherRegion
    let programs: [RadioProgram]
}
struct WeatherRadioWidgetView: View {
    let entry: WeatherRadioEntry
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var environmentFamily
    private var family: WidgetFamily { familyOverride ?? environmentFamily }
    private var weather: RadioWeather? { entry.weather.flatMap { $0.isToday(at: entry.date) ? $0 : nil } }
    private var current: RadioProgram? { entry.radio.station.flatMap { ProgramLineup.current(in: entry.programs, key: $0.catalogKey, at: entry.date) } }
    private var next: RadioProgram? { entry.radio.station.flatMap { ProgramLineup.next(in: entry.programs, key: $0.catalogKey, at: entry.date) } }
    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { Image(systemName: weather?.symbol ?? "cloud.sun").symbolRenderingMode(.multicolor); Text(entry.region.name).lineLimit(1) }.font(.caption.weight(.medium))
                Text(weather?.temperatureLabel ?? "—°").font(.system(size: 36, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.7)
                Text(family == .systemSmall ? weather.map { "\($0.condition) · 강수 \($0.rainChance)%" } ?? "예보 확인 필요" : weather?.condition ?? "예보 확인 필요").font(.caption).foregroundStyle(.secondary)
                if let weather {
                    if family == .systemMedium { Text(weather.rangeLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                    if family == .systemMedium { Text("강수 \(weather.rainChance)%").font(.caption2).foregroundStyle(.secondary) }
                    if family == .systemMedium, weather.isStale(at: entry.date) { Text("최근 예보").font(.caption2).foregroundStyle(.secondary) }
                }
                if family == .systemSmall { HStack { Text(entry.radio.station?.name ?? "온에어").font(.caption2.bold()).lineLimit(1); Spacer(minLength: 2); playButton } }
            }.frame(maxWidth: family == .systemSmall ? .infinity : nil, alignment: .leading)
            if family == .systemMedium {
                Rectangle().fill(.primary.opacity(0.09)).frame(width: 1).padding(.vertical, 5)
                VStack(alignment: .leading, spacing: 9) {
                    HStack { Text("온에어").font(.caption2.bold()).foregroundStyle(.secondary); Spacer(); playButton }
                    Text(entry.radio.station?.name ?? "좋은 하루, 좋은 소리").font(.headline).lineLimit(1).widgetAccentable()
                    Text(current?.title ?? (entry.radio.connecting ? "방송 연결 중" : entry.radio.active ? "지금 듣는 중" : "라디오 듣기")).font(.caption).lineLimit(2)
                    if let next {
                        HStack(spacing: 4) { Text("다음"); Text(next.startsAt, style: .time); Text(next.title) }.font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text("Open-Meteo").font(.system(size: 9)).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.containerBackground(for: .widget) { Color.clear }
            .environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .widgetURL(URL(string: "onair://weather"))
    }
    var playButton: some View {
        Button(intent: RadioPlaybackIntent(stationID: entry.radio.station?.id ?? "", shouldPause: entry.radio.active || entry.radio.connecting)) {
            Image(systemName: entry.radio.active || entry.radio.connecting ? "pause.circle.fill" : "play.circle.fill").font(.system(size: family == .systemSmall ? 26 : 30)).foregroundStyle(RadioDesign.coral).frame(minWidth: 30, minHeight: 30)
        }.buttonStyle(.plain).accessibilityLabel(entry.radio.active || entry.radio.connecting ? "일시정지" : "라디오 재생")
    }
}

#endif
