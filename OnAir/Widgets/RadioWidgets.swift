import SwiftUI
import WidgetKit
#if os(iOS)
import ActivityKit
#endif

import AppIntents

struct RadioWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "나의 주파수 설정"
    @Parameter(title: "방송", default: .recent) var choice: WidgetRadioChoice
}
struct NightRadioConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "침대 옆 라디오 설정"
    @Parameter(title: "방송", default: .bedtime) var choice: WidgetRadioChoice
}
struct RadioProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<RadioWidgetConfiguration>] { [.init(intent: RadioWidgetConfiguration(), description: "최근 방송")] }
    func placeholder(in context: Context) -> RadioEntry { .init(date: .now, snapshot: .init(station: .preview, favorites: [], isPlaying: false, updatedAt: .now)) }
    func snapshot(for configuration: RadioWidgetConfiguration, in context: Context) async -> RadioEntry { .init(date: .now, snapshot: SharedStore.read(), choice: configuration.choice) }
    func timeline(for configuration: RadioWidgetConfiguration, in context: Context) async -> Timeline<RadioEntry> {
        Timeline(entries: [.init(date: .now, snapshot: SharedStore.read(), choice: configuration.choice)], policy: .after(.now.addingTimeInterval(900)))
    }
}
struct NightRadioProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<NightRadioConfiguration>] { [.init(intent: NightRadioConfiguration(), description: "취침 라디오")] }
    func placeholder(in context: Context) -> RadioEntry { .init(date: .now, snapshot: .init(station: .preview, favorites: [], isPlaying: false, updatedAt: .now), choice: .bedtime, night: true) }
    func snapshot(for configuration: NightRadioConfiguration, in context: Context) async -> RadioEntry { .init(date: .now, snapshot: SharedStore.read(), choice: configuration.choice, night: true) }
    func timeline(for configuration: NightRadioConfiguration, in context: Context) async -> Timeline<RadioEntry> {
        let snapshot = SharedStore.read()
        let entries = (0..<15).map { RadioEntry(date: Date.now.addingTimeInterval(Double($0 * 60)), snapshot: snapshot, choice: configuration.choice, night: true) }
        return Timeline(entries: entries, policy: .after(.now.addingTimeInterval(900)))
    }
}
struct OnAirWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OnAirRadio", intent: RadioWidgetConfiguration.self, provider: RadioProvider()) { RadioWidgetView(entry: $0) }
            .configurationDisplayName("나의 주파수").description("최근 방송이나 프리셋을 선택하고 바로 재생해요.")
            #if os(watchOS)
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
            #else
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
            #endif
    }
}
#if os(iOS)
struct MinimalRadioWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OnAirMinimalRadio", intent: RadioWidgetConfiguration.self, provider: RadioProvider()) { entry in
            VStack(spacing: 20) {
                Text(entry.station?.name ?? "온에어").font(.headline).multilineTextAlignment(.center).lineLimit(2)
                RadioWidgetView(entry: entry).playbackButton
            }.frame(maxWidth: .infinity, maxHeight: .infinity).containerBackground(.clear, for: .widget).widgetURL(SharedStore.link(entry.station))
        }.configurationDisplayName("미니 라디오").description("방송국과 재생 버튼만 간결하게 표시합니다.").supportedFamilies([.systemSmall])
    }
}
#endif
#if os(iOS)
struct NightRadioWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OnAirNightRadio", intent: NightRadioConfiguration.self, provider: NightRadioProvider()) { RadioWidgetView(entry: $0) }
            .configurationDisplayName("침대 옆 라디오").description("스탠바이에 추가해 시계, 방송, 취침 타이머를 확인해요.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif
#if os(iOS)
private struct LiveStationLogo: View {
    let stationID: String
    let size: CGFloat
    var body: some View {
        if let station = ([SharedStore.read().station].compactMap { $0 } + Station.curated).first(where: { $0.id == stationID }) {
            StationArtwork(station: station, cornerRadius: size * 0.22)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .frame(width: size, height: size)
                .foregroundStyle(RadioDesign.coral)
        }
    }
}

struct OnAirLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadioActivityAttributes.self) { context in
            HStack(spacing: 16) {
                LiveStationLogo(stationID: context.attributes.stationID, size: 56)
                VStack(alignment: .leading, spacing: 5) { Text(context.state.stationName).font(.headline); Text(context.state.buffering ? "방송 연결 중…" : "온에어 · 지금 듣는 중").font(.caption) }
                Spacer(); Image(systemName: "antenna.radiowaves.left.and.right")
            }.padding().activityBackgroundTint(RadioDesign.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { LiveStationLogo(stationID: context.attributes.stationID, size: 28) }
                DynamicIslandExpandedRegion(.trailing) { Text("ON AIR").font(.caption.bold()) }
                DynamicIslandExpandedRegion(.bottom) { Text(context.state.stationName).font(.headline).padding(.bottom, 10) }
            } compactLeading: { LiveStationLogo(stationID: context.attributes.stationID, size: 24) }
              compactTrailing: { Image(systemName: "dot.radiowaves.left.and.right") }
              minimal: { LiveStationLogo(stationID: context.attributes.stationID, size: 24) }
              .widgetURL(URL(string: "onair://player"))
        }
    }
}
#endif
#if os(iOS)
@available(iOS 27.0, *)
struct RadioPanelWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OnAirPanel", intent: RadioWidgetConfiguration.self, provider: RadioProvider()) { RadioPanelView(entry: $0) }
            .configurationDisplayName("라디오 패널").description("주파수와 즐겨찾기를 크게 보고 바로 재생합니다.")
            .supportedFamilies([.systemLarge, .systemExtraLargePortrait])
    }
}
#endif
@main struct RadioWidgetBundle: WidgetBundle {
    var body: some Widget {
        OnAirWidget()
        #if os(iOS)
        OnAirLiveActivity()
        NightRadioWidget()
        WeatherRadioWidget()
        MinimalRadioWidget()
        OnAirRadioControl()
        if #available(iOS 27.0, *) { RadioPanelWidget() }
        #endif
    }
}
