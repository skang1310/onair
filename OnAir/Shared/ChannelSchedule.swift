import Foundation

enum ChannelSchedule {
    static let kbsChannels = ["21": "kbs1radio", "22": "kbs2r", "23": "kbs3r", "24": "kbsclassicfm", "25": "kbscoolfm", "26": "kbshanminjok"]
    static func officialURL(for station: Station) -> URL? {
        let key = station.catalogKey
        if key == "cbsstandard" || key == "cbsmusic" { return URL(string: "https://www.cbs.co.kr/schedule?type=\(key == "cbsstandard" ? "fm" : "musicFm")") }
        if key.hasPrefix("kbs") { return URL(string: "https://schedule.kbs.co.kr/index.html?sname=schedule&stype=table&type=radioList") }
        if key.hasPrefix("mbc") { return URL(string: "https://miniwebapp.imbc.com/index?channel=\(key == "mbcstandard" ? "sfm" : key == "mbcfm4u" ? "mfm" : "chm")") }
        if key.hasPrefix("sbs") { return URL(string: "https://www.sbs.co.kr/schedule") }
        return station.homepageURL
    }
    struct KBSChannel: Decodable {
        let channel_code: String
        let schedules: [KBSRow]
    }
    struct KBSRow: Decodable {
        let program_planned_date: String
        let program_planned_start_time: String
        let program_planned_end_time: String
        let program_title: String
        let programming_table_title: String?
    }
    static func parseKBS(_ data: Data, for date: Date) throws -> [RadioProgram] {
        let day = CBSProgramParser.dayKey(date)
        let channels = try JSONDecoder().decode([KBSChannel].self, from: data)
        return channels.flatMap { channel -> [RadioProgram] in
            guard let key = kbsChannels[channel.channel_code] else { return [] }
            return channel.schedules.compactMap { row in
                let rowDay = row.program_planned_date
                guard rowDay.count == 8 else { return nil }
                let calendarDay = String(rowDay.prefix(4)) + "-" + String(rowDay.dropFirst(4).prefix(2)) + "-" + String(rowDay.suffix(2))
                func time(_ value: String) -> Date? {
                    guard value.count >= 4, let hour = Int(value.prefix(2)), let minute = Int(value.dropFirst(2).prefix(2)), (0...47).contains(hour), (0...59).contains(minute), let midnight = CBSProgramParser.time("00:00", day: calendarDay) else { return nil }
                    return CBSProgramParser.calendar.date(byAdding: .minute, value: hour * 60 + minute, to: midnight)
                }
                guard let start = time(row.program_planned_start_time), var end = time(row.program_planned_end_time) else { return nil }
                if end <= start { end = end.addingTimeInterval(86400) }
                guard let midnight = CBSProgramParser.time("00:00", day: day), start < midnight.addingTimeInterval(86400), end > midnight else { return nil }
                let title = row.programming_table_title.flatMap { $0.isEmpty ? nil : $0 } ?? row.program_title
                guard !title.isEmpty else { return nil }
                return RadioProgram(stationKey: key, title: title, startsAt: start, endsAt: end, source: URL(string: "https://schedule.kbs.co.kr/index.html?sname=schedule&stype=table&type=radioList")!)
            }
        }.sorted { $0.startsAt < $1.startsAt }
    }
    struct MBCRow: Decodable {
        let Channel: String
        let StartTime: String
        let EndTime: String
        let ProgramTitle: String
        let LiveDays: String
    }
    static func parseMBC(_ data: Data, for date: Date) throws -> [RadioProgram] {
        let day = CBSProgramParser.dayKey(date)
        let weekday = ["일", "월", "화", "수", "목", "금", "토"][CBSProgramParser.calendar.component(.weekday, from: date) - 1]
        let rows = try JSONDecoder().decode([MBCRow].self, from: data)
        let keys = ["STFM": "mbcstandard", "FM4U": "mbcfm4u", "CHAM": "mbcallthat"]
        var seen = Set<String>()
        return rows.compactMap { row in
            guard row.LiveDays.contains(weekday), let key = keys[row.Channel], !row.ProgramTitle.isEmpty else { return nil }
            func time(_ value: String) -> Date? {
                guard value.count == 4 else { return nil }
                return CBSProgramParser.time(String(value.prefix(2)) + ":" + String(value.suffix(2)), day: day)
            }
            guard let start = time(row.StartTime), var end = time(row.EndTime) else { return nil }
            if end <= start { end = end.addingTimeInterval(86400) }
            let program = RadioProgram(stationKey: key, title: row.ProgramTitle, startsAt: start, endsAt: end, source: URL(string: "https://miniwebapp.imbc.com/index?channel=\(key == "mbcstandard" ? "sfm" : key == "mbcfm4u" ? "mfm" : "chm")")!)
            guard seen.insert(program.id).inserted else { return nil }
            return program
        }.sorted { $0.startsAt < $1.startsAt }
    }
    static func fetchMBC(for date: Date) async throws -> [RadioProgram] {
        var request = URLRequest(url: URL(string: "https://miniapi.imbc.com/Schedule/schedulelist")!); request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 3_000_000 else { throw URLError(.badServerResponse) }
        return try parseMBC(data, for: date)
    }
    static func fetchKBS(for date: Date) async throws -> [RadioProgram] {
        let day = CBSProgramParser.dayKey(date).replacingOccurrences(of: "-", with: "")
        let previous = CBSProgramParser.dayKey(date.addingTimeInterval(-86400)).replacingOccurrences(of: "-", with: "")
        let url = URL(string: "https://static.api.kbs.co.kr/mediafactory/v1/schedule/weekly?local_station_code=00&channel_code=21,22,23,24,25,26&program_planned_date_from=\(previous)&program_planned_date_to=\(day)")!
        var request = URLRequest(url: url); request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 3_000_000 else { throw URLError(.badServerResponse) }
        return try parseKBS(data, for: date)
    }
}
