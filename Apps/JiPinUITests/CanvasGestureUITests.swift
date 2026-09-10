import XCTest

final class CanvasGestureUITests: XCTestCase {
    private func editor() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["-sampleEditor", "-sampleMode", "template", "-sampleLayout", "g4-grid"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 15))
        return app
    }
    private func canvas(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["editor-canvas"].firstMatch }
    private func number(_ app: XCUIApplication, prefix: String) -> Double {
        let text = canvas(app).value as? String ?? ""
        let value = text.components(separatedBy: prefix).last?.components(separatedBy: "，").first ?? ""
        return Double(value) ?? -999
    }
    func testPinchAndRotateUseTheTouchedPhotoAndOneUndoEach() {
        let app = editor()
        let photo = app.buttons["canvas-photo-2"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
        photo.pinch(withScale: 1.7, velocity: 0.8)
        XCTAssertTrue((canvas(app).value as? String ?? "").contains("第 3 张"))
        XCTAssertGreaterThan(number(app, prefix: "照片缩放 "), 1.25)
        let zoom = number(app, prefix: "照片缩放 ")
        let initialAngle = number(app, prefix: "照片角度 ")
        photo.rotate(.pi / 8, withVelocity: 0.6)
        XCTAssertGreaterThan(abs(number(app, prefix: "照片角度 ") - initialAngle), 12)
        app.buttons["撤销"].tap()
        XCTAssertEqual(number(app, prefix: "照片角度 "), initialAngle, accuracy: 0.1)
        XCTAssertEqual(number(app, prefix: "照片缩放 "), zoom, accuracy: 0.02)
        app.buttons["撤销"].tap()
        XCTAssertEqual(number(app, prefix: "照片缩放 "), 1, accuracy: 0.02)
    }
    func testSlowPhotoDragKeepsPublishingFramesAndDoesNotSwapOnCrossingCell() {
        let app = editor(), surface = canvas(app)
        let photo = app.buttons["canvas-photo-0"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        photo.pinch(withScale: 1.8, velocity: 1)
        let before = number(app, prefix: "预览帧 ")
        let a = photo.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.3))
        let b = photo.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.9))
        a.press(forDuration: 0.05, thenDragTo: b, withVelocity: XCUIGestureVelocity(rawValue: 50), thenHoldForDuration: 0)
        XCTAssertGreaterThan(number(app, prefix: "预览帧 ") - before, 4, "拖动期间必须持续显示中间帧，不能一直取消到松手才刷新")
        let across = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25))
        a.press(forDuration: 0.05, thenDragTo: across, withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertTrue((surface.value as? String ?? "").contains("第 1 张"), "普通拖动跨过格线应继续调整原照片")
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "v4-gesture-drag"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testLongPressDragExplicitlySwapsAndCanUndo() {
        let app = editor(), surface = canvas(app)
        let first = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25))
        let second = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25))
        first.press(forDuration: 0.65, thenDragTo: second)
        XCTAssertTrue((surface.value as? String ?? "").contains("第 2 张"))
        XCTAssertTrue(app.buttons["撤销"].isEnabled)
        app.buttons["撤销"].tap()
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
    }
    func testPreciseAdjustmentsAndDrawingStillWork() {
        let app = editor()
        app.buttons["tool-adjust"].tap()
        let plus = app.buttons["adjust-rotate-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        plus.tap()
        XCTAssertEqual(number(app, prefix: "照片角度 "), 1, accuracy: 0.01)
        app.buttons["adjust-reset-position"].tap()
        XCTAssertEqual(number(app, prefix: "照片角度 "), 0, accuracy: 0.01)
        let doodle = app.buttons["tool-doodle"]
        let rail = app.scrollViews.containing(.button, identifier: "tool-doodle").firstMatch
        rail.swipeLeft(); rail.swipeLeft()
        doodle.tap()
        let surface = canvas(app)
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6))
        start.press(forDuration: 0.05, thenDragTo: end)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "v4-gesture-drawing"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["tool-layer"].tap()
        XCTAssertTrue(app.navigationBars["图层"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["涂鸦"].firstMatch.exists, "原生手势层关闭后仍应能生成完整的涂鸦图层")
    }
}
