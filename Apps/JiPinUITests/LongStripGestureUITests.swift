import XCTest

final class LongStripGestureUITests: XCTestCase {
    private func editor() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "longStrip"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.scrollViews["canvas-scroll"].waitForExistence(timeout: 5))
        return app
    }

    private func drag(_ app: XCUIApplication, horizontal: Bool = false, forward: Bool = true) {
        // SwiftUI reports this ScrollView's AX frame as the entire screen, including
        // safe-area tool panels. Anchor real touches between navigation and the tool rail.
        let top = app.buttons["editor-export"].frame.maxY + 26
        let bottom = app.buttons["editor-all-tools"].frame.minY - 20
        XCTAssertGreaterThan(bottom - top, 100)
        let visible = CGRect(x: 20, y: top, width: app.frame.width - 40, height: bottom - top)
        let start = CGVector(dx: horizontal ? 0.78 : 0.5, dy: horizontal ? 0.5 : 0.76)
        let end = CGVector(dx: horizontal ? 0.24 : 0.5, dy: horizontal ? 0.5 : 0.25)
        func point(_ value: CGVector) -> XCUICoordinate {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: visible.minX + value.dx * visible.width, dy: visible.minY + value.dy * visible.height))
        }
        let a = point(forward ? start : end)
        let b = point(forward ? end : start)
        a.press(forDuration: 0.02, thenDragTo: b, withVelocity: .default, thenHoldForDuration: 0)
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func canvas(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["editor-canvas"].firstMatch
    }

    private func number(_ app: XCUIApplication, prefix: String) -> Double {
        let text = canvas(app).value as? String ?? ""
        return Double(text.components(separatedBy: prefix).last?.components(separatedBy: "，").first ?? "") ?? -999
    }

    func testVerticalSwipeOnPhotoScrollsAndDoesNotEditTheProject() {
        let app = editor()
        let first = app.buttons["canvas-photo-0"]
        let before = first.frame.minY
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
        drag(app)
        let after = first.frame.minY
        XCTAssertLessThan(after, before - 70, "在照片中心滑动应滚动画布，不应只能从侧边滚动条拖动。")
        XCTAssertFalse(app.buttons["撤销"].isEnabled, "浏览长图不应修改照片或产生撤销记录。")
        keep(app, "403-long-strip-vertical-scroll")
        drag(app, forward: false)
        XCTAssertGreaterThan(first.frame.minY, after + 50, "反向滑动也应正常返回。")
    }

    func testHorizontalSwipeOnPhotoScrollsWithoutAnExtraUndoStep() {
        let app = editor()
        app.segmentedControls.buttons["横向"].tap()
        let first = app.buttons["canvas-photo-0"]
        let before = first.frame.minX
        drag(app, horizontal: true)
        XCTAssertLessThan(first.frame.minX, before - 70, "横向长图也应允许直接在照片上左右滑动。")
        keep(app, "403-long-strip-horizontal-scroll")
        app.buttons["撤销"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["纵向"].isSelected, "滑动不应挡在方向切换的撤销前面。")
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
    }

    func testPhotoTapAndMultitouchPreserveTheToolAndScrollingResumes() {
        let app = editor()
        app.buttons["tool-style"].tap()
        let style = app.buttons["style-inline-cream"]
        XCTAssertTrue(style.waitForExistence(timeout: 5))
        app.buttons["canvas-zoom-out"].tap()
        app.buttons["canvas-zoom-out"].tap()
        let photo = app.buttons["canvas-photo-0"]
        photo.tap()
        XCTAssertTrue(style.exists, "选图不应切换面板，造成浏览窗口跳动。")
        let initialAngle = number(app, prefix: "照片角度 ")
        photo.pinch(withScale: 1.6, velocity: 0.8)
        XCTAssertGreaterThan(number(app, prefix: "照片缩放 "), 1.2)
        XCTAssertTrue(style.exists)
        let zoom = number(app, prefix: "照片缩放 ")
        let pinchAngle = number(app, prefix: "照片角度 ")
        photo.rotate(.pi / 12, withVelocity: 0.6)
        XCTAssertGreaterThan(abs(number(app, prefix: "照片角度 ") - pinchAngle), 10)
        app.buttons["撤销"].tap()
        XCTAssertEqual(number(app, prefix: "照片角度 "), pinchAngle, accuracy: 0.1)
        XCTAssertEqual(number(app, prefix: "照片缩放 "), zoom, accuracy: 0.02)
        app.buttons["撤销"].tap()
        XCTAssertEqual(number(app, prefix: "照片缩放 "), 1, accuracy: 0.02)
        XCTAssertEqual(number(app, prefix: "照片角度 "), initialAngle, accuracy: 0.1)
        let before = photo.frame.minY
        drag(app)
        XCTAssertLessThan(photo.frame.minY, before - 60)
        XCTAssertTrue(style.exists)
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
    }

    func testLongPressStillSwapsPhotosAndCanUndo() {
        let app = editor()
        for _ in 0..<5 { app.buttons["canvas-zoom-out"].tap() }
        let first = app.buttons["canvas-photo-0"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let second = app.buttons["canvas-photo-1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        first.press(forDuration: 0.65, thenDragTo: second)
        XCTAssertTrue((canvas(app).value as? String ?? "").contains("第 2 张"))
        XCTAssertTrue(app.buttons["撤销"].isEnabled)
        app.buttons["撤销"].tap()
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
    }

    func testLiveLongStripScrollsWithoutLeavingLiveToolsAndStillExports() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLiveEditor", "-sampleMode", "longStrip"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["live-preview-open"].exists)
        let first = app.buttons["canvas-photo-0"]
        let before = first.frame.minY
        drag(app)
        XCTAssertLessThan(first.frame.minY, before - 70)
        XCTAssertTrue(app.buttons["live-preview-open"].exists, "浏览不能意外切换 Live 工具面板。")
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
        keep(app, "403-live-long-strip-scroll")
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["live-save-album"].isEnabled)
        keep(app, "403-live-long-strip-export")
    }
}
