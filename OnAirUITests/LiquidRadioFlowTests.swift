import XCTest

@MainActor final class LiquidRadioFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testThreeTabsAndAppearanceSettingsRemainUsable() throws {
        let app = XCUIApplication(); app.launch();
        XCTAssertTrue(app.buttons["hero-play"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.tabBars.buttons["홈"].exists)
        XCTAssertFalse(app.otherElements["주파수 다이얼"].exists)
        app.tabBars.buttons["방송국"].tap()
        XCTAssertTrue(app.navigationBars["방송국"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        app.tabBars.buttons["보관함"].tap()
        XCTAssertTrue(app.staticTexts["나의 라디오"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["빠른 재생"].exists)
        XCTAssertFalse(app.buttons["quick-slot-1"].exists)
        app.buttons["설정"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["appearance-picker"].exists)
        XCTAssertFalse(app.buttons["노래 찾기 설정"].exists)
        app.buttons["완료"].tap()
        XCTAssertTrue(app.navigationBars["보관함"].exists)
        app.terminate()
    }
    func testStationSearchAndSavedFavorite() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-showStations", "-favoriteStationID", "3043d560-4358-4583-9e29-9fce6777a09c"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("CBS\n")
        XCTAssertTrue(app.buttons["station-play-cbsmusic"].waitForExistence(timeout: 8))
        app.tabBars.buttons["보관함"].tap()
        XCTAssertTrue(app.buttons["station-play-cbsmusic"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testScheduleChannelSelection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-showSchedule"]
        app.launch()
        XCTAssertTrue(app.navigationBars["오늘의 편성표"].waitForExistence(timeout: 12))
        let picker = app.descendants(matching: .any)["schedule-channel-picker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap()
        app.buttons["KBS Cool FM"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["KBS Cool FM"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["schedule-station-name"].label, "KBS Cool FM")
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "채널별 편성표"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate()
    }

    func testMinimalPlayerControlsAndSchedule() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-showPlayer", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["재생 화면 닫기"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["이전 방송국"].exists)
        XCTAssertTrue(app.buttons["다음 방송국"].exists)
        XCTAssertTrue(app.buttons["취침 타이머"].exists)
        app.buttons["오늘의 편성표"].tap()
        XCTAssertTrue(app.navigationBars["오늘의 편성표"].waitForExistence(timeout: 8))
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["재생 화면 닫기"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "심플 플레이어"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["재생 화면 닫기"].tap()
        XCTAssertTrue(app.tabBars.buttons["홈"].waitForExistence(timeout: 5))
        app.terminate()
    }

}
