import XCTest

@MainActor final class WeatherRadioFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testManualWeatherRegionDoesNotRequireLocationPermission() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["weather-card"].waitForExistence(timeout: 12))
        app.buttons["weather-card"].tap()
        XCTAssertTrue(app.buttons["날씨 닫기"].waitForExistence(timeout: 5))
        app.buttons["날씨 지역 변경"].tap()
        XCTAssertTrue(app.navigationBars["날씨와 지역"].waitForExistence(timeout: 5))
        let picker = app.descendants(matching: .any)["weather-region-picker"].firstMatch
        XCTAssertTrue(picker.exists); picker.tap()
        app.buttons["부산"].firstMatch.tap()
        XCTAssertTrue(app.buttons["현재 위치 사용"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["Weather data by Open-Meteo"].exists || app.links["Weather data by Open-Meteo"].exists)
        app.buttons["완료"].tap()
        XCTAssertTrue(app.buttons["날씨 닫기"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["부산"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["시간별 예보"].waitForExistence(timeout: 15))
        let detail = XCTAttachment(screenshot: app.screenshot()); detail.name = "전체 화면 날씨"; detail.lifetime = .keepAlways; add(detail)
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.staticTexts["습도"].firstMatch.exists)
        let metrics = XCTAttachment(screenshot: app.screenshot()); metrics.name = "날씨 상세 지표"; metrics.lifetime = .keepAlways; add(metrics)
        app.buttons["날씨 닫기"].tap()
        XCTAssertTrue(app.buttons["weather-card"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "날씨와 라디오 홈"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate()
    }
}
