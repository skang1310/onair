import Foundation

struct WeatherRegion: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    static let cities: [WeatherRegion] = [
        .init(id: "seoul", name: "서울", latitude: 37.57, longitude: 126.98),
        .init(id: "busan", name: "부산", latitude: 35.18, longitude: 129.08),
        .init(id: "incheon", name: "인천", latitude: 37.46, longitude: 126.71),
        .init(id: "daegu", name: "대구", latitude: 35.87, longitude: 128.60),
        .init(id: "daejeon", name: "대전", latitude: 36.35, longitude: 127.38),
        .init(id: "gwangju", name: "광주", latitude: 35.16, longitude: 126.85),
        .init(id: "ulsan", name: "울산", latitude: 35.54, longitude: 129.31),
        .init(id: "sejong", name: "세종", latitude: 36.48, longitude: 127.29),
        .init(id: "suwon", name: "수원", latitude: 37.26, longitude: 127.03),
        .init(id: "chuncheon", name: "춘천", latitude: 37.88, longitude: 127.73),
        .init(id: "cheongju", name: "청주", latitude: 36.64, longitude: 127.49),
        .init(id: "jeonju", name: "전주", latitude: 35.82, longitude: 127.15),
        .init(id: "mokpo", name: "목포", latitude: 34.81, longitude: 126.39),
        .init(id: "andong", name: "안동", latitude: 36.57, longitude: 128.73),
        .init(id: "changwon", name: "창원", latitude: 35.23, longitude: 128.68),
        .init(id: "jeju", name: "제주", latitude: 33.50, longitude: 126.53)
    ]
    static func approximate(latitude: Double, longitude: Double) -> WeatherRegion {
        let lat = (latitude * 50).rounded() / 50, lon = (longitude * 50).rounded() / 50
        return .init(id: String(format: "location-%.2f-%.2f", lat, lon), name: "현재 위치", latitude: lat, longitude: lon)
    }
}
struct RadioWeather: Codable, Equatable, Sendable {
    let region: WeatherRegion
    let temperature: Double
    let high: Double
    let low: Double
    let rainChance: Int
    let code: Int
    let isDay: Bool
    let forecastDay: Date
    let measuredAt: Date
    let fetchedAt: Date
    var details: WeatherDetails? = nil
    var temperatureLabel: String { String(format: "%.0f°", temperature) }
    var rangeLabel: String { String(format: "최고 %.0f° · 최저 %.0f°", high, low) }
    var condition: String {
        switch code {
        case 0: "맑음"
        case 1, 2: "구름 조금"
        case 3: "흐림"
        case 45, 48: "안개"
        case 51...57: "이슬비"
        case 61...67, 80...82: "비"
        case 71...77, 85, 86: "눈"
        case 95...99: "뇌우"
        default: "날씨 정보"
        }
    }
    var symbol: String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57, 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud"
        }
    }
    func isToday(at date: Date = .now) -> Bool { CBSProgramParser.calendar.isDate(forecastDay, inSameDayAs: date) }
    func isStale(at date: Date = .now) -> Bool { date.timeIntervalSince(fetchedAt) > 3600 }
}
struct WeatherHour: Codable, Equatable, Identifiable, Sendable {
    let date: Date; let temperature: Double; let code: Int; let isDay: Bool; let rainChance: Int?
    var id: Date { date }
}
struct WeatherDay: Codable, Equatable, Identifiable, Sendable {
    let date: Date; let high: Double; let low: Double; let code: Int; let rainChance: Int?
    var id: Date { date }
}
struct WeatherDetails: Codable, Equatable, Sendable {
    let hours: [WeatherHour]; let days: [WeatherDay]
    let feelsLike: Double?; let humidity: Double?; let wind: Double?; let direction: Double?; let gusts: Double?; let pressure: Double?; let cloudCover: Double?
    let visibility: Double?; let uv: Double?; let dewPoint: Double?; let precipitation: Double?; let uvMax: Double?
    let sunrise: Date?; let sunset: Date?
}
enum RadioWeatherService {
    struct Response: Decodable {
        struct Current: Decodable {
            let time: Double; let temperature_2m: Double; let weather_code: Int; let is_day: Int
            let relative_humidity_2m: Double?; let apparent_temperature: Double?; let precipitation: Double?
            let cloud_cover: Double?; let pressure_msl: Double?; let wind_speed_10m: Double?
            let wind_direction_10m: Double?; let wind_gusts_10m: Double?
        }
        struct Daily: Decodable {
            let time: [Double]; let temperature_2m_max: [Double]; let temperature_2m_min: [Double]; let precipitation_probability_max: [Int?]
            let weather_code: [Int?]?; let precipitation_sum: [Double?]?; let sunrise: [Double?]?; let sunset: [Double?]?; let uv_index_max: [Double?]?
        }
        struct Hourly: Decodable {
            let time: [Double]; let temperature_2m: [Double?]; let weather_code: [Int?]
            let precipitation_probability: [Int?]; let is_day: [Int?]
            let visibility: [Double?]?; let uv_index: [Double?]?; let dew_point_2m: [Double?]?
        }
        let current: Current; let daily: Daily; let hourly: Hourly?
    }
    static func element<T>(_ array: [T]?, _ index: Int) -> T? {
        guard let array, array.indices.contains(index) else { return nil }; return array[index]
    }
    static func parse(_ data: Data, region: WeatherRegion, at date: Date) throws -> RadioWeather {
        let value = try JSONDecoder().decode(Response.self, from: data)
        guard let index = value.daily.time.firstIndex(where: { CBSProgramParser.calendar.isDate(Date(timeIntervalSince1970: $0), inSameDayAs: date) }), value.daily.temperature_2m_max.indices.contains(index), value.daily.temperature_2m_min.indices.contains(index), value.daily.precipitation_probability_max.indices.contains(index), let chance = value.daily.precipitation_probability_max[index], (0...100).contains(chance), value.current.temperature_2m.isFinite, value.daily.temperature_2m_max[index].isFinite, value.daily.temperature_2m_min[index].isFinite, value.daily.temperature_2m_min[index] <= value.daily.temperature_2m_max[index], abs(Date(timeIntervalSince1970: value.current.time).timeIntervalSince(date)) < 7200 else { throw URLError(.cannotParseResponse) }
        var result = RadioWeather(region: region, temperature: value.current.temperature_2m, high: value.daily.temperature_2m_max[index], low: value.daily.temperature_2m_min[index], rainChance: chance, code: value.current.weather_code, isDay: value.current.is_day == 1, forecastDay: Date(timeIntervalSince1970: value.daily.time[index]), measuredAt: Date(timeIntervalSince1970: value.current.time), fetchedAt: date)
        if let hourly = value.hourly {
            let hours = hourly.time.indices.compactMap { i -> WeatherHour? in
                guard let temperature = element(hourly.temperature_2m, i) ?? nil, let code = element(hourly.weather_code, i) ?? nil, let day = element(hourly.is_day, i) ?? nil, temperature.isFinite else { return nil }
                return WeatherHour(date: Date(timeIntervalSince1970: hourly.time[i]), temperature: temperature, code: code, isDay: day == 1, rainChance: element(hourly.precipitation_probability, i) ?? nil)
            }
            let nearest = hourly.time.indices.min { abs(hourly.time[$0] - value.current.time) < abs(hourly.time[$1] - value.current.time) }
            let days = value.daily.time.indices.compactMap { i -> WeatherDay? in
                guard let high = element(value.daily.temperature_2m_max, i), let low = element(value.daily.temperature_2m_min, i), let code = element(value.daily.weather_code, i) ?? nil, high.isFinite, low.isFinite, low <= high else { return nil }
                return WeatherDay(date: Date(timeIntervalSince1970: value.daily.time[i]), high: high, low: low, code: code, rainChance: element(value.daily.precipitation_probability_max, i) ?? nil)
            }
            let c = value.current
            result.details = WeatherDetails(hours: Array(hours.filter { $0.date >= date.addingTimeInterval(-3600) }.prefix(25)), days: days,
                feelsLike: c.apparent_temperature, humidity: c.relative_humidity_2m, wind: c.wind_speed_10m, direction: c.wind_direction_10m, gusts: c.wind_gusts_10m, pressure: c.pressure_msl, cloudCover: c.cloud_cover,
                visibility: nearest.flatMap { element(hourly.visibility, $0) ?? nil }, uv: nearest.flatMap { element(hourly.uv_index, $0) ?? nil }, dewPoint: nearest.flatMap { element(hourly.dew_point_2m, $0) ?? nil },
                precipitation: element(value.daily.precipitation_sum, index) ?? nil, uvMax: element(value.daily.uv_index_max, index) ?? nil,
                sunrise: (element(value.daily.sunrise, index) ?? nil).map { Date(timeIntervalSince1970: $0) }, sunset: (element(value.daily.sunset, index) ?? nil).map { Date(timeIntervalSince1970: $0) })
        }
        return result
    }
    static func fetch(region: WeatherRegion) async throws -> RadioWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(region.latitude)), .init(name: "longitude", value: String(region.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day,relative_humidity_2m,apparent_temperature,precipitation,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code,precipitation_sum,sunrise,sunset,uv_index_max"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day,visibility,uv_index,dew_point_2m"),
            .init(name: "wind_speed_unit", value: "ms"), .init(name: "timezone", value: "Asia/Seoul"), .init(name: "timeformat", value: "unixtime"), .init(name: "forecast_days", value: "10")
        ]
        var request = URLRequest(url: components.url!); request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 500_000 else { throw URLError(.badServerResponse) }
        return try parse(data, region: region, at: .now)
    }
}
enum WeatherStore {
    static var region: WeatherRegion { SharedStore.defaults.data(forKey: "weather-region").flatMap { try? JSONDecoder().decode(WeatherRegion.self, from: $0) } ?? WeatherRegion.cities[0] }
    static func select(_ region: WeatherRegion) {
        for key in SharedStore.defaults.dictionaryRepresentation().keys where key.hasPrefix("weather-location-") && key != "weather-" + region.id { SharedStore.defaults.removeObject(forKey: key) }
        SharedStore.defaults.set(try? JSONEncoder().encode(region), forKey: "weather-region")
    }
    static func read(region: WeatherRegion, at date: Date = .now) -> RadioWeather? {
        guard let data = SharedStore.defaults.data(forKey: "weather-" + region.id), let weather = try? JSONDecoder().decode(RadioWeather.self, from: data), weather.region == region, weather.isToday(at: date) else { return nil }
        return weather
    }
    static func save(_ weather: RadioWeather) {
        // Keep only the selected forecast; a region change discards the previous location.
        for key in SharedStore.defaults.dictionaryRepresentation().keys where key.hasPrefix("weather-location-") && key != "weather-" + weather.region.id { SharedStore.defaults.removeObject(forKey: key) }
        SharedStore.defaults.set(try? JSONEncoder().encode(weather), forKey: "weather-" + weather.region.id)
    }
    static func refreshIfNeeded() async -> RadioWeather? {
        let selected = region, cached = read(region: region)
        if let cached, cached.details != nil, Date.now.timeIntervalSince(cached.fetchedAt) < 1800 { return cached }
        do {
            let weather = try await RadioWeatherService.fetch(region: selected)
            if region == selected { save(weather) }
            return weather
        } catch { return cached }
    }
}
enum ProgramLineup {
    static func current(in programs: [RadioProgram], key: String, at date: Date) -> RadioProgram? { programs.first { $0.stationKey == key && $0.isLive(at: date) } }
    static func next(in programs: [RadioProgram], key: String, at date: Date) -> RadioProgram? {
        programs.filter { $0.stationKey == key && $0.startsAt > date && $0.startsAt < date.addingTimeInterval(86400) }.min { $0.startsAt < $1.startsAt }
    }
    static func read() -> [RadioProgram] { SharedStore.defaults.data(forKey: "widget-programs").flatMap { try? JSONDecoder().decode([RadioProgram].self, from: $0) } ?? [] }
}
