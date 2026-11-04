import SwiftUI

struct WeatherDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = RadioWeatherModel.shared
    @State private var showRegions = false
    private var daylight: Bool { model.weather?.isDay ?? true }
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image(daylight ? "WeatherSkyDay" : "WeatherSkyNight").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
            }.ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(daylight ? 0.12 : 0.15), .black.opacity(0.32)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(model.region.name).font(.system(size: 34, weight: .medium))
                        if let weather = model.weather {
                            Text(weather.temperatureLabel).font(.system(size: 92, weight: .thin)).monospacedDigit()
                            Text(weather.condition).font(.title3)
                            Text(weather.rangeLabel).font(.subheadline.weight(.medium))
                        } else {
                            Text("—°").font(.system(size: 92, weight: .thin))
                            if model.loading { ProgressView().tint(.white) }
                        }
                    }.padding(.vertical, 22).frame(maxWidth: .infinity)
                    if let message = model.message { Text(message).font(.footnote).padding(16).frame(maxWidth: .infinity).background(.ultraThinMaterial, in: .rect(cornerRadius: 22)) }
                    if let weather = model.weather, let details = weather.details {
                        hourly(details)
                        daily(details)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            metric("체감온도", "thermometer.medium", number(details.feelsLike, "°"), "현재 기온 \(weather.temperatureLabel)")
                            metric("습도", "humidity.fill", number(details.humidity, "%"), "이슬점 \(number(details.dewPoint, "°"))")
                            metric("바람", "wind", number(details.wind, " m/s", decimals: 1), "풍향 \(direction(details.direction)) · 돌풍 \(number(details.gusts, " m/s", decimals: 1))")
                            metric("자외선 지수", "sun.max.fill", number(details.uv, "", decimals: 1), "오늘 최대 \(number(details.uvMax, "", decimals: 1))")
                            metric("일출", "sunrise.fill", time(details.sunrise), "일몰 \(time(details.sunset))")
                            metric("강수량", "drop.fill", number(details.precipitation, " mm", decimals: 1), "오늘 예상 누적 · 강수확률 \(weather.rainChance)%")
                            metric("기압", "gauge.with.dots.needle.50percent", number(details.pressure, " hPa"), "해수면 기준")
                            metric("가시거리", "eye.fill", number(details.visibility.map { $0 / 1000 }, " km", decimals: 1), "시간별 예보 기준")
                            metric("구름량", "cloud.fill", number(details.cloudCover, "%"), "현재 하늘을 덮는 구름")
                            metric("일몰", "sunset.fill", time(details.sunset), "일출 \(time(details.sunrise))")
                        }
                        Text("\(koreanDate(weather.measuredAt, format: "M월 d일 HH:mm")) 기준 · 예보 데이터")
                            .font(.caption).opacity(0.75)
                    } else if !model.loading {
                        Button("상세 예보 다시 불러오기") { Task { await model.refresh(force: true) } }.buttonStyle(.glass)
                    }
                    Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!).font(.caption).padding(.bottom, 24)
                }.padding(.horizontal, 20)
            }.refreshable { await model.refresh(force: true) }
        }.foregroundStyle(.white).preferredColorScheme(.dark)
            .safeAreaInset(edge: .top) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.buttonStyle(.glass).accessibilityLabel("날씨 닫기")
                    Spacer()
                    Text("날씨").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { showRegions = true } label: { Image(systemName: "list.bullet").frame(width: 44, height: 44) }.buttonStyle(.glass).accessibilityLabel("날씨 지역 변경")
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
            }
            .accessibilityIdentifier("weather-detail")
            .environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .task { await model.refresh() }
            .sheet(isPresented: $showRegions) { NavigationStack { WeatherSettingsView().toolbar { Button("완료") { showRegions = false } } } }
    }
    private func panel<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).opacity(0.75)
            content()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.75), in: .rect(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.15)) }
    }
    private func hourly(_ details: WeatherDetails) -> some View {
        panel("시간별 예보", symbol: "clock") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(Array(details.hours.enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 12) {
                            Text(index == 0 ? "지금" : koreanDate(hour.date, format: "HH시")).font(.subheadline)
                            Image(systemName: symbol(hour.code, day: hour.isDay)).symbolRenderingMode(.multicolor).font(.title3).frame(height: 26)
                            Text(number(hour.temperature, "°")).font(.title3.weight(.medium))
                            Text(hour.rainChance.map { "\($0)%" } ?? "—").font(.caption2).foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }.accessibilityIdentifier("weather-hourly")
    }
    private func daily(_ details: WeatherDetails) -> some View {
        let minimum = details.days.map(\.low).min() ?? 0
        let maximum = details.days.map(\.high).max() ?? 1
        return panel("10일 예보", symbol: "calendar") {
            VStack(spacing: 14) {
                ForEach(details.days) { day in
                    HStack(spacing: 10) {
                        Text(CBSProgramParser.calendar.isDateInToday(day.date) ? "오늘" : koreanDate(day.date, format: "E")).font(.subheadline.weight(.medium)).frame(width: 38, alignment: .leading)
                        VStack(spacing: 2) {
                            Image(systemName: symbol(day.code, day: true)).symbolRenderingMode(.multicolor).font(.body)
                            if let chance = day.rainChance, chance > 0 { Text("\(chance)%").font(.system(size: 9)).foregroundStyle(.cyan) }
                        }.frame(width: 30)
                        Text(number(day.low, "°")).font(.subheadline).opacity(0.65).frame(width: 30)
                        GeometryReader { proxy in
                            let range = max(maximum - minimum, 1)
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, proxy.size.width * (day.high - day.low) / range))
                                .offset(x: proxy.size.width * (day.low - minimum) / range)
                        }.frame(height: 5)
                        Text(number(day.high, "°")).font(.subheadline).frame(width: 30)
                    }.frame(minHeight: 29)
                }
            }
        }.accessibilityIdentifier("weather-daily")
    }
    private func metric(_ title: String, _ icon: String, _ value: String, _ caption: String) -> some View {
        panel(title, symbol: icon) {
            Text(value).font(.system(size: 27, weight: .regular)).minimumScaleFactor(0.65).lineLimit(1)
            Text(caption).font(.caption).opacity(0.75).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(minHeight: 154, alignment: .top)
    }
    private func number(_ value: Double?, _ suffix: String, decimals: Int = 0) -> String {
        guard let value, value.isFinite else { return "정보 없음" }
        return String(format: "%.*f", decimals, value) + suffix
    }
    private func koreanDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ko_KR"); formatter.timeZone = CBSProgramParser.calendar.timeZone; formatter.dateFormat = format
        return formatter.string(from: date)
    }
    private func time(_ value: Date?) -> String { value.map { koreanDate($0, format: "HH:mm") } ?? "정보 없음" }
    private func direction(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return ["북", "북동", "동", "남동", "남", "남서", "서", "북서"][Int((value.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45) % 8]
    }
    private func symbol(_ code: Int, day: Bool) -> String {
        switch code {
        case 0: day ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: day ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57, 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}
