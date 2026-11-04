import XCTest

@MainActor final class RadioFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testActualCBSScheduleAndEconomyFilter() throws {
        let app = XCUIApplication(); app.launchArguments = ["-showNews"]; app.launch()
        app.buttons.matching(identifier: "뉴스·시사").allElementsBoundByIndex.last?.tap()
        XCTAssertTrue(app.buttons["경제"].waitForExistence(timeout: 15))
        app.buttons["경제"].tap()
        XCTAssertTrue(app.staticTexts["CBS 경제연구실"].waitForExistence(timeout: 25))
        XCTAssertFalse(app.staticTexts["CBS news"].exists)
        app.buttons["CBS 경제연구실 시작 알림 설정"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        else if springboard.buttons["허용"].exists { springboard.buttons["허용"].tap() }
        XCTAssertTrue(app.staticTexts["시작 5분 전 알림 예약됨"].waitForExistence(timeout: 10))
        app.buttons["CBS 경제연구실 시작 알림 해제"].tap()
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "뉴스 경제 분류"; capture.lifetime = .keepAlways; add(capture)
        app.terminate()
    }
    func testPresetEditorAndWidgetPresentation() throws {
        let app = XCUIApplication(); app.launchArguments = ["-showFavorites"]; app.launch()
        XCTAssertTrue(app.buttons["취침 라디오 설정"].waitForExistence(timeout: 10))
        app.buttons["취침 라디오 설정"].tap()
        XCTAssertTrue(app.navigationBars["취침 라디오"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["저장"].exists)
        app.buttons["저장"].tap()
        app.terminate(); app.launchArguments = ["-showWidgets"]; app.launch()
        XCTAssertTrue(app.staticTexts["침대 옆 라디오 · 스탠바이"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["프리셋 재생"].exists)
        app.buttons["프리셋 재생"].tap()
        let pause = app.buttons.matching(identifier: "일시정지").firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["KBS Classic FM"].firstMatch.exists)
        pause.tap()
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "라디오와 야간 위젯 표시"; capture.lifetime = .keepAlways; add(capture)
        app.terminate()
    }
    func testBackgroundAudioAdvancesWhileOnHomeScreen() async throws {
        let app = XCUIApplication(bundleIdentifier: "kr.davidkang.onair")
        app.launchArguments = ["-showPlayer", "-playStationID", "cbs-standard-fm", "-verifyBackgroundAudio"]
        app.launch()
        XCTAssertTrue(app.staticTexts["지금 듣는 중"].firstMatch.waitForExistence(timeout: 40))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "새 플레이어"; capture.lifetime = .keepAlways; add(capture)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        let background = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); background.name = "홈 화면에서 재생"; background.lifetime = .keepAlways; add(background)
        try await Task.sleep(for: .seconds(18))
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.staticTexts["background-audio-verified"].waitForExistence(timeout: 5))
        app.buttons["일시정지"].firstMatch.tap()
        app.terminate()
    }

}
