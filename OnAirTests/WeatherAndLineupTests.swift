import XCTest
@testable import OnAir

final class WeatherAndLineupTests: XCTestCase {
    private var date: Date { CBSProgramParser.time("09:00", day: "2026-10-07")! }
    private func weatherData(chance: String = "25", day: Date? = nil) -> Data {
        let start = day ?? CBSProgramParser.calendar.startOfDay(for: date)
        return Data("""
        {"current":{"time":\(date.timeIntervalSince1970),"temperature_2m":19.2,"weather_code":61,"is_day":1},"daily":{"time":[\(start.timeIntervalSince1970)],"temperature_2m_max":[23.1],"temperature_2m_min":[12.5],"precipitation_probability_max":[\(chance)]}}
        """.utf8)
    }
    func testWeatherUsesKoreanDayAndForecastValues() throws {
        let weather = try RadioWeatherService.parse(weatherData(), region: WeatherRegion.cities[0], at: date)
        XCTAssertEqual(weather.temperatureLabel, "19°")
        XCTAssertEqual(weather.condition, "비")
        XCTAssertEqual(weather.rainChance, 25)
        XCTAssertTrue(weather.isToday(at: date))
        XCTAssertFalse(weather.isToday(at: date.addingTimeInterval(86400)))
        XCTAssertTrue(weather.isStale(at: date.addingTimeInterval(3601)))
    }
    func testWeatherRejectsMissingRainAndWrongDay() {
        XCTAssertThrowsError(try RadioWeatherService.parse(weatherData(chance: "null"), region: WeatherRegion.cities[0], at: date))
        XCTAssertThrowsError(try RadioWeatherService.parse(weatherData(chance: "150"), region: WeatherRegion.cities[0], at: date))
        XCTAssertThrowsError(try RadioWeatherService.parse(weatherData(day: date.addingTimeInterval(-86400)), region: WeatherRegion.cities[0], at: date))
        XCTAssertThrowsError(try RadioWeatherService.parse(weatherData(), region: WeatherRegion.cities[0], at: date.addingTimeInterval(10800)))
    }
    func testDetailedWeatherHandlesPartialHourlyArraysAndOldCache() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: weatherData()) as? [String: Any])
        var current = try XCTUnwrap(json["current"] as? [String: Any])
        current["relative_humidity_2m"] = 67; current["wind_speed_10m"] = 3.2
        json["current"] = current
        var daily = try XCTUnwrap(json["daily"] as? [String: Any]); daily["weather_code"] = [61]; daily["precipitation_sum"] = [2.5]; json["daily"] = daily
        json["hourly"] = ["time": [date.timeIntervalSince1970, date.addingTimeInterval(3600).timeIntervalSince1970], "temperature_2m": [19.2, 20], "weather_code": [61], "is_day": [1], "precipitation_probability": [25], "visibility": [12000]] as [String: Any]
        let result = try RadioWeatherService.parse(JSONSerialization.data(withJSONObject: json), region: WeatherRegion.cities[0], at: date)
        XCTAssertEqual(result.details?.hours.count, 1)
        XCTAssertEqual(result.details?.days.count, 1)
        XCTAssertEqual(result.details?.humidity, 67)
        XCTAssertEqual(result.details?.visibility, 12000)
        XCTAssertNil(result.details?.uv)
        let old = try RadioWeatherService.parse(weatherData(), region: WeatherRegion.cities[0], at: date)
        XCTAssertNil(old.details)
        XCTAssertEqual(try JSONDecoder().decode(RadioWeather.self, from: JSONEncoder().encode(result)), result)
    }
    func testCurrentLocationIsRoundedBeforeStorageAndRequest() {
        let region = WeatherRegion.approximate(latitude: 37.571234, longitude: 126.981234)
        XCTAssertEqual(region.latitude, 37.58, accuracy: 0.000001)
        XCTAssertEqual(region.longitude, 126.98, accuracy: 0.000001)
        XCTAssertEqual(region.name, "현재 위치")
    }
    func testLineupSwitchesAtBoundaryAndNeverMixesChannels() {
        let url = URL(string: "https://www.cbs.co.kr/schedule?type=fm")!
        let previous = RadioProgram(stationKey: "cbsstandard", title: "이전 방송", startsAt: date.addingTimeInterval(-3600), endsAt: date, source: url)
        let now = RadioProgram(stationKey: "cbsstandard", title: "현재 방송", startsAt: date, endsAt: date.addingTimeInterval(3600), source: url)
        let next = RadioProgram(stationKey: "cbsstandard", title: "다음 방송", startsAt: now.endsAt, endsAt: now.endsAt.addingTimeInterval(3600), source: url)
        let other = RadioProgram(stationKey: "cbsmusic", title: "다른 채널", startsAt: date.addingTimeInterval(30), endsAt: now.endsAt, source: url)
        let programs = [other, next, previous, now]
        XCTAssertEqual(ProgramLineup.current(in: programs, key: "cbsstandard", at: date), now)
        XCTAssertEqual(ProgramLineup.next(in: programs, key: "cbsstandard", at: date), next)
        XCTAssertEqual(ProgramLineup.current(in: programs, key: "cbsstandard", at: next.startsAt), next)
        XCTAssertNil(ProgramLineup.current(in: programs, key: "missing", at: date))
        XCTAssertNil(ProgramLineup.next(in: programs, key: "cbsstandard", at: next.startsAt))
    }
}
