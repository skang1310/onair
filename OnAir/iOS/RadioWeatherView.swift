import SwiftUI
import CoreLocation
import WidgetKit

@MainActor @Observable final class RadioWeatherModel: NSObject, CLLocationManagerDelegate {
    static let shared = RadioWeatherModel()
    var region = WeatherStore.region
    var weather: RadioWeather?
    var loading = false
    var locating = false
    var message: String?
    private let locationManager = CLLocationManager()
    private var locationTimeout: Task<Void, Never>?
    private override init() {
        super.init()
        weather = WeatherStore.read(region: region)
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    func select(_ value: WeatherRegion) async {
        locating = false; locationTimeout?.cancel(); locationManager.stopUpdatingLocation()
        region = value; WeatherStore.select(value); weather = WeatherStore.read(region: value); message = nil
        WidgetCenter.shared.reloadTimelines(ofKind: "OnAirWeatherRadio")
        await refresh(force: true)
    }
    func refresh(force: Bool = false) async {
        let selected = region
        if !force, let weather, weather.details != nil, weather.isToday(), Date.now.timeIntervalSince(weather.fetchedAt) < 1800 { return }
        loading = true
        do {
            let result = try await RadioWeatherService.fetch(region: selected)
            guard selected == region else { return }
            weather = result; WeatherStore.save(result); message = nil
            WidgetCenter.shared.reloadTimelines(ofKind: "OnAirWeatherRadio")
        } catch {
            guard selected == region else { return }
            weather = WeatherStore.read(region: selected)
            message = weather == nil ? "날씨를 가져오지 못했어요. 잠시 후 다시 시도해 주세요." : "연결이 어려워 마지막으로 받은 예보를 표시합니다."
        }
        if selected == region { loading = false }
    }
    func useCurrentLocation() {
        guard !locating else { return }
        message = nil; locating = true
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: requestLocation()
        default: locating = false; message = "위치 권한이 꺼져 있어요. 지역을 직접 선택하거나 iPhone 설정에서 권한을 변경해 주세요."
        }
    }
    private func requestLocation() {
        locationManager.requestLocation()
        locationTimeout?.cancel()
        locationTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, self.locating else { return }
            self.locating = false; self.message = "위치를 확인하지 못했어요. 지역을 직접 선택해 주세요."
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.locating else { return }
            if status == .authorizedWhenInUse || status == .authorizedAlways { self.requestLocation() }
            else if status != .notDetermined { self.locating = false; self.message = "위치 권한 없이도 지역을 선택해서 날씨를 볼 수 있어요." }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0, abs(location.timestamp.timeIntervalSinceNow) < 300 else { return }
        let region = WeatherRegion.approximate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        Task { @MainActor in
            guard self.locating else { return }
            await self.select(region)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.locating else { return }
            self.locationTimeout?.cancel(); self.locating = false; self.message = "위치를 확인하지 못했어요. 지역을 직접 선택해 주세요."
        }
    }
}
struct RadioWeatherCard: View {
    @State private var model = RadioWeatherModel.shared
    @State private var showSettings = false
    var body: some View {
        Button { showSettings = true } label: {
            HStack(spacing: 8) {
                Image(systemName: model.weather?.symbol ?? "cloud.sun").symbolRenderingMode(.multicolor)
                Text(model.region.name).fontWeight(.medium)
                if let weather = model.weather { Text("\(weather.temperatureLabel) · \(weather.condition)") }
                else { Text(model.loading ? "날씨 확인 중" : "날씨 확인") }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }.font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 44).contentShape(Rectangle())

        }.buttonStyle(.plain).foregroundStyle(.primary).accessibilityIdentifier("weather-card")
            .fullScreenCover(isPresented: $showSettings) { WeatherDetailView() }
    }
}
struct WeatherSettingsView: View {
    @State private var model = RadioWeatherModel.shared
    var body: some View {
        Form {
            Section {
                Picker("날씨 지역", selection: Binding(get: { model.region.id }, set: { id in if let region = WeatherRegion.cities.first(where: { $0.id == id }) { Task { await model.select(region) } } })) {
                    ForEach(WeatherRegion.cities) { Text($0.name).tag($0.id) }
                    if model.region.id.hasPrefix("location-") { Text("현재 위치").tag(model.region.id) }
                }.accessibilityIdentifier("weather-region-picker")
                Button { model.useCurrentLocation() } label: { Label(model.locating ? "위치 확인 중…" : "현재 위치 사용", systemImage: "location") }.disabled(model.locating)
            } header: { Text("내 지역") } footer: { Text("기본 지역은 서울입니다. 현재 위치는 버튼을 누를 때만 확인하고 대략적인 좌표로 예보를 요청합니다. 위젯은 여기서 선택한 지역을 사용합니다.") }
            if let weather = model.weather, weather.isToday() {
                Section("오늘 날씨") {
                    LabeledContent("현재", value: "\(weather.temperatureLabel) · \(weather.condition)")
                    LabeledContent("최고 / 최저", value: weather.rangeLabel)
                    LabeledContent("오늘 강수확률", value: "\(weather.rainChance)%")
                    LabeledContent("예보 시각", value: weather.measuredAt.formatted(date: .omitted, time: .shortened))
                    if weather.isStale() { Text("저장된 예보입니다. 최신 날씨를 다시 확인해 주세요.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            if let message = model.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            Button { Task { await model.refresh(force: true) } } label: { if model.loading { ProgressView("날씨 갱신 중") } else { Label("날씨 새로고침", systemImage: "arrow.clockwise") } }.disabled(model.loading)
            Section { Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!) }.font(.footnote)
        }.navigationTitle("날씨와 지역").navigationBarTitleDisplayMode(.inline).tint(LiquidRadioTheme.accent)
            .environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .task { await model.refresh() }
    }
}
struct RadioProgramSummary: View {
    let station: Station
    var compact = false
    @State private var schedule = ProgramSchedule.shared
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: compact ? 4 : 9) {
                let current = schedule.current(for: station, at: context.date)
                let next = schedule.next(for: station, at: context.date)
                if let current, !compact {
                    HStack(alignment: .firstTextBaseline, spacing: 8) { Text("지금").font(.caption2.bold()).opacity(0.65); Text(current.title).font(compact ? .caption : .subheadline.weight(.medium)).lineLimit(1) }
                } else if !compact { Text(station.subtitle).font(.subheadline).opacity(0.8).lineLimit(2) }
                if let next {
                    HStack(alignment: .firstTextBaseline, spacing: 8) { Text("다음").font(.caption2.bold()).opacity(0.65); Text(next.startsAt, style: .time).font(.caption.monospacedDigit()); Text(next.title).font(.caption).lineLimit(1) }.opacity(0.8)
                } else if current != nil { Text("다음 일정은 편성표에서 확인하세요").font(.caption2).opacity(0.65) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.environment(\.timeZone, CBSProgramParser.calendar.timeZone).accessibilityIdentifier("program-summary")
    }
}

#if DEBUG
struct WeatherWidgetPreview: View {
    @State private var model = RadioWeatherModel.shared
    var body: some View {
        VStack(spacing: 28) {
            Text("날씨와 라디오").font(.title2.bold())
            let entry = WeatherRadioEntry(date: .now, radio: .init(date: .now, snapshot: SharedStore.read()), weather: model.weather, region: model.region, programs: ProgramLineup.read())
            WeatherRadioWidgetView(entry: entry, familyOverride: .systemMedium).padding(16).frame(width: 350, height: 170).background(.background, in: .rect(cornerRadius: 28))
            WeatherRadioWidgetView(entry: entry, familyOverride: .systemSmall).padding(16).frame(width: 170, height: 170).background(.background, in: .rect(cornerRadius: 28))
            Text("날씨: Open-Meteo · 실제 위젯은 홈 화면에서 추가하세요").font(.caption).foregroundStyle(.secondary)
        }.padding().task { await model.refresh() }
    }
}
#endif
