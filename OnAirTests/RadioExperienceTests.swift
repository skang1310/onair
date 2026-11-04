import XCTest
@testable import OnAir

final class RadioExperienceTests: XCTestCase {
    func testKBSScheduleIncludesPreviousBroadcastDayAfterMidnight() throws {
        let data = Data(#"[{"channel_code":"25","schedules":[{"program_planned_date":"20261006","program_planned_start_time":"26000000","program_planned_end_time":"28000000","program_title":"새벽 방송"},{"program_planned_date":"20261007","program_planned_start_time":"28000000","program_planned_end_time":"29000000","program_title":"내일 방송"}]}]"#.utf8)
        let date = try XCTUnwrap(CBSProgramParser.time("12:00", day: "2026-10-07"))
        let programs = try ChannelSchedule.parseKBS(data, for: date)
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs.first?.stationKey, "kbscoolfm")
        XCTAssertEqual(programs.first?.startsAt, CBSProgramParser.time("02:00", day: "2026-10-07"))
    }
    func testMBCScheduleFiltersWeekdayAndChannel() throws {
        let data = Data(#"[{"Channel":"STFM","StartTime":"2300","EndTime":"0000","ProgramTitle":"밤 방송","LiveDays":"수"},{"Channel":"FM4U","StartTime":"0900","EndTime":"1100","ProgramTitle":"목요일 방송","LiveDays":"목"}]"#.utf8)
        let date = try XCTUnwrap(CBSProgramParser.time("12:00", day: "2026-10-07"))
        let programs = try ChannelSchedule.parseMBC(data, for: date)
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs.first?.stationKey, "mbcstandard")
        XCTAssertEqual(programs.first?.endsAt, CBSProgramParser.time("00:00", day: "2026-10-08"))
    }
}
