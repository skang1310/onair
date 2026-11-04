import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif
#if os(iOS) && !WIDGET_EXTENSION
import UserNotifications
#endif

enum NewsTopic: String, CaseIterable, Identifiable, Codable {
    case all = "전체", headlines = "종합 뉴스", economy = "경제", discussion = "시사 토론", local = "지역 뉴스"
    var id: String { rawValue }
    static func classify(_ title: String) -> NewsTopic? {
        let text = title.lowercased()
        if text.contains("경제") || text.contains("금융") || text.contains("증시") { return .economy }
        if text.contains("토론") || text.contains("시사") || text.contains("뉴스쇼") { return .discussion }
        if text.contains("지역") || text.contains("부산") || text.contains("대구") || text.contains("충북") { return .local }
        if text.contains("뉴스") || text.contains("news") { return .headlines }
        return nil
    }
}
struct RadioProgram: Codable, Identifiable, Sendable, Equatable {
    let stationKey: String
    let title: String
    let startsAt: Date
    let endsAt: Date
    let source: URL
    var id: String { "\(stationKey)-\(Int(startsAt.timeIntervalSince1970))" }
    var followKey: String { stationKey + "|" + title }
    var topic: NewsTopic? { NewsTopic.classify(title) }
    func isLive(at date: Date) -> Bool { startsAt <= date && date < endsAt }
}
enum CBSProgramParser {
    struct Row: Decodable { let startTime: String; let endTime: String; let date: String; let name: String }
    static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }
    static func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func time(_ text: String, day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        let clock = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3, clock.count == 2, (0...24).contains(clock[0]), (0...59).contains(clock[1]), clock[0] != 24 || clock[1] == 0 else { return nil }
        guard let midnight = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return calendar.date(byAdding: .minute, value: clock[0] * 60 + clock[1], to: midnight)
    }
    static func parse(_ data: Data, for date: Date) throws -> [RadioProgram] {
        let rows = try JSONDecoder().decode([String: [Row]].self, from: data)
        var programs: [RadioProgram] = []
        for (channel, key) in [("fm", "cbsstandard"), ("musicfm", "cbsmusic")] {
            for row in rows[channel] ?? [] where row.date == dayKey(date) {
                guard !row.name.isEmpty, let start = time(row.startTime, day: row.date), var end = time(row.endTime, day: row.date) else { continue }
                if end <= start { end = calendar.date(byAdding: .day, value: 1, to: end)! }
                programs.append(.init(stationKey: key, title: row.name, startsAt: start, endsAt: end, source: URL(string: "https://www.cbs.co.kr/schedule?type=\(channel == "fm" ? "fm" : "musicFm")")!))
            }
        }
        return programs.sorted { $0.startsAt < $1.startsAt }
    }
}
@MainActor @Observable final class ProgramSchedule {
    static let shared = ProgramSchedule()
    var programs: [RadioProgram] = []
    var loading = false
    var message: String?
    var updatedAt: Date?
    private init() {}
    func refresh(force: Bool = false) async {
        guard !loading else { return }
        if !force, let updatedAt, Date.now.timeIntervalSince(updatedAt) < 900, CBSProgramParser.dayKey(updatedAt) == CBSProgramParser.dayKey(.now) { return }
        loading = true; defer { loading = false }
        programs.removeAll { CBSProgramParser.dayKey($0.startsAt) != CBSProgramParser.dayKey(.now) }
        let date = Date.now
        let midnight = CBSProgramParser.calendar.startOfDay(for: date)
        let cached = (UserDefaults.standard.data(forKey: "program-cache").flatMap { try? JSONDecoder().decode([RadioProgram].self, from: $0) } ?? []).filter { $0.endsAt > midnight && $0.startsAt < midnight.addingTimeInterval(86400) }
        programs = cached
        var failures = [String]()
        for broadcaster in ["CBS", "KBS", "MBC"] {
            do {
                let result: [RadioProgram]
                if broadcaster == "KBS" { result = try await ChannelSchedule.fetchKBS(for: date) }
                else if broadcaster == "MBC" { result = try await ChannelSchedule.fetchMBC(for: date) }
                else {
                    var request = URLRequest(url: URL(string: "https://www.cbs.co.kr/schedule/radio/ajax")!); request.httpMethod = "POST"; request.timeoutInterval = 15
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 3_000_000 else { throw URLError(.badServerResponse) }
                    result = try CBSProgramParser.parse(data, for: date)
                }
                guard !result.isEmpty else { throw URLError(.cannotParseResponse) }
                programs.removeAll { $0.stationKey.hasPrefix(broadcaster.lowercased()) }
                programs.append(contentsOf: result)
            } catch { failures.append(broadcaster) }
        }
        programs.sort { $0.startsAt < $1.startsAt }
        updatedAt = failures.isEmpty ? date : nil
        message = failures.isEmpty ? nil : failures.joined(separator: " · ") + " 편성표 연결이 어려워요. 저장된 오늘 일정 또는 공식 편성표를 확인해 주세요."
        UserDefaults.standard.set(try? JSONEncoder().encode(programs), forKey: "program-cache")
        SharedStore.defaults.set(try? JSONEncoder().encode(programs), forKey: "widget-programs")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "OnAirWeatherRadio")
        #endif
        #if os(iOS) && !WIDGET_EXTENSION
        await ProgramReminders.shared.reschedule(programs)
        #endif
    }

    func next(for station: Station, at date: Date = .now) -> RadioProgram? { ProgramLineup.next(in: programs, key: station.catalogKey, at: date) }
    func current(for station: Station, at date: Date = .now) -> RadioProgram? { programs.first { $0.stationKey == station.catalogKey && $0.isLive(at: date) } }
}
#if os(iOS) && !WIDGET_EXTENSION
@MainActor @Observable final class ProgramReminders {
    static let shared = ProgramReminders()
    var followed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "followed-programs") ?? [])
    var message: String?
    var scheduledIDs = Set<String>()
    private init() {}
    func toggle(_ program: RadioProgram) async {
        if followed.contains(program.followKey) {
            followed.remove(program.followKey)
        } else {
            do {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) else { message = "알림이 꺼져 있어요. iPhone 설정에서 온에어 알림을 켜 주세요."; return }
                followed.insert(program.followKey)
                if program.startsAt <= .now { message = "프로그램을 저장했어요. 다음 방송 알림은 편성표를 갱신할 때 예약됩니다." }
            } catch { message = "알림 권한을 확인하지 못했어요."; return }
        }
        UserDefaults.standard.set(Array(followed), forKey: "followed-programs")
        await reschedule(ProgramSchedule.shared.programs)
    }
    func reschedule(_ programs: [RadioProgram]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("program.") }.map(\.identifier))
        let upcoming = programs.filter { followed.contains($0.followKey) && $0.startsAt > .now }.sorted { $0.startsAt < $1.startsAt }
        for program in upcoming.prefix(40) {
            let content = UNMutableNotificationContent(); content.title = "곧 시작하는 라디오"; content.body = program.title; content.sound = .default
            content.userInfo = ["stationKey": program.stationKey]
            let fire = max(program.startsAt.addingTimeInterval(-300), Date.now.addingTimeInterval(2))
            var components = CBSProgramParser.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
            components.timeZone = CBSProgramParser.calendar.timeZone
            do { try await center.add(UNNotificationRequest(identifier: "program." + program.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))) }
            catch { message = "일부 방송 알림을 저장하지 못했어요." }
        }
        scheduledIDs = Set(await center.pendingNotificationRequests().map(\.identifier))
    }
    func remove(_ key: String) async {
        followed.remove(key); UserDefaults.standard.set(Array(followed), forKey: "followed-programs"); await reschedule(ProgramSchedule.shared.programs)
    }
}
final class RadioNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = RadioNotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let key = response.notification.request.content.userInfo["stationKey"] as? String
        await MainActor.run {
            let library = StationLibrary()
            if let station = library.stations.first(where: { $0.catalogKey == key }) { RadioPlayer.shared.play(station) }
        }
    }
}
#endif
