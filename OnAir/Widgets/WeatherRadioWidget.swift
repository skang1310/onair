import SwiftUI
import WidgetKit

struct WeatherRadioProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeatherRadioEntry {
        .init(date: .now, radio: .init(date: .now, snapshot: .init(station: .preview, favorites: [], isPlaying: false, updatedAt: .now)), weather: nil, region: WeatherRegion.cities[0], programs: [])
    }
    func snapshot(for configuration: RadioWidgetConfiguration, in context: Context) async -> WeatherRadioEntry {
        let region = WeatherStore.region
        return .init(date: .now, radio: .init(date: .now, snapshot: SharedStore.read(), choice: configuration.choice), weather: WeatherStore.read(region: region), region: region, programs: ProgramLineup.read())
    }
    func timeline(for configuration: RadioWidgetConfiguration, in context: Context) async -> Timeline<WeatherRadioEntry> {
        let weather = await WeatherStore.refreshIfNeeded()
        let date = Date.now, snapshot = SharedStore.read(), region = WeatherStore.region, programs = ProgramLineup.read()
        let radio = RadioEntry(date: date, snapshot: snapshot, choice: configuration.choice)
        let boundaries = programs.filter { $0.stationKey == radio.station?.catalogKey }.flatMap { [$0.startsAt, $0.endsAt] }.filter { $0 > date && $0 < date.addingTimeInterval(1800) }
        let dates = Array(Set([date] + boundaries)).sorted()
        let entries = dates.map { WeatherRadioEntry(date: $0, radio: .init(date: $0, snapshot: snapshot, choice: configuration.choice), weather: weather?.region == region ? weather : WeatherStore.read(region: region), region: region, programs: programs) }
        return Timeline(entries: entries, policy: .after(date.addingTimeInterval(1800)))
    }
}
struct WeatherRadioWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OnAirWeatherRadio", intent: RadioWidgetConfiguration.self, provider: WeatherRadioProvider()) { WeatherRadioWidgetView(entry: $0) }
            .configurationDisplayName("날씨와 라디오").description("내 지역의 날씨와 지금·다음 방송을 함께 확인하고 재생해요.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
