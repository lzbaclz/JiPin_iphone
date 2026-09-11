import XCTest

final class StickerViewportUITests: XCTestCase {
    private func editor(horizontal: Bool = false, zoomed: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "longStrip"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 15))
        if horizontal { app.segmentedControls.buttons["横向"].tap() }
        if zoomed { for _ in 0..<2 { app.buttons["canvas-zoom-in"].tap() } }
        app.buttons["editor-all-tools"].tap()
        app.buttons["tool-menu-sticker"].tap()
        XCTAssertTrue(app.buttons["sticker-library-open"].waitForExistence(timeout: 5))
        return app
    }

    private func viewport(_ app: XCUIApplication) -> CGRect {
        let top = app.navigationBars.firstMatch.frame.maxY
        let bottom = app.buttons["editor-all-tools"].frame.minY - 8
        return CGRect(x: 16, y: top, width: app.frame.width - 32, height: bottom - top)
    }

    private func scroll(_ app: XCUIApplication, horizontal: Bool = false) {
        let rect = viewport(app)
        let start = CGPoint(x: rect.minX + rect.width * (horizontal ? 0.8 : 0.5), y: rect.minY + rect.height * (horizontal ? 0.5 : 0.78))
        let end = CGPoint(x: rect.minX + rect.width * (horizontal ? 0.2 : 0.5), y: rect.minY + rect.height * (horizontal ? 0.5 : 0.22))
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: start.x, dy: start.y)).press(forDuration: 0.02,
            thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)), withVelocity: .default, thenHoldForDuration: 0)
    }

    private func addFromLibrary(_ app: XCUIApplication, id: String = "cute-bunny") {
        app.buttons["sticker-library-open"].tap()
        XCTAssertTrue(app.buttons["sticker-add-\(id)"].waitForExistence(timeout: 5))
        app.buttons["sticker-add-\(id)"].tap()
        XCTAssertTrue(app.buttons["sticker-library-open"].waitForExistence(timeout: 5))
    }

    private func assertCentered(_ app: XCUIApplication, index: Int = 0) -> XCUIElement {
        let sticker = app.buttons["canvas-sticker-\(index)"]
        XCTAssertTrue(sticker.waitForExistence(timeout: 5))
        let visible = viewport(app), frame = sticker.frame
        XCTAssertTrue(sticker.isHittable, "添加后必须能直接操作贴图")
        XCTAssertEqual(frame.midX, visible.midX, accuracy: 14, "贴图应在当前可见画面的水平中心")
        XCTAssertEqual(frame.midY, visible.midY, accuracy: 14, "贴图应在当前可见画面的垂直中心")
        return sticker
    }

    private func keep(_ app: XCUIApplication, name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }

    func testTopOfLongStripAddsStickerInViewAndCanDragImmediately() {
        let app = editor()
        addFromLibrary(app)
        let sticker = assertCentered(app)
        keep(app, name: "sticker-at-visible-top-center")
        let before = sticker.frame
        let start = sticker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.03, thenDragTo: start.withOffset(CGVector(dx: 45, dy: 55)), withVelocity: .default, thenHoldForDuration: 0)
        XCTAssertGreaterThan(sticker.frame.midY, before.midY + 30)
        app.buttons["撤销"].tap()
        _ = assertCentered(app)
        app.buttons["撤销"].tap()
        XCTAssertFalse(app.buttons["canvas-sticker-0"].exists)
    }

    func testScrolledVerticalLongStripUsesLatestViewportForEverySticker() {
        let app = editor(zoomed: true)
        let photo = app.buttons["canvas-photo-0"]
        let start = photo.frame.minY
        for _ in 0..<3 { scroll(app) }
        XCTAssertLessThan(photo.frame.minY, start - 150)
        addFromLibrary(app)
        let first = assertCentered(app)
        let firstY = first.frame.midY
        // Browse from the side of the photo, away from the selected sticker.
        let rect = viewport(app), origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: rect.minX + 20, dy: rect.maxY - 65)).press(forDuration: 0.02,
            thenDragTo: origin.withOffset(CGVector(dx: rect.minX + 20, dy: rect.minY + 80)))
        XCTAssertLessThan(first.frame.midY, firstY - 70)
        addFromLibrary(app, id: "cute-bear")
        _ = assertCentered(app, index: 1)
        keep(app, name: "sticker-at-scrolled-zoomed-center")
    }

    func testScrolledHorizontalLongStripAddsStickerAtVisibleCenter() {
        let app = editor(horizontal: true, zoomed: true)
        let photo = app.buttons["canvas-photo-0"]
        let start = photo.frame.minX
        for _ in 0..<3 { scroll(app, horizontal: true) }
        XCTAssertLessThan(photo.frame.minX, start - 150)
        addFromLibrary(app)
        _ = assertCentered(app)
        keep(app, name: "sticker-at-horizontal-visible-center")
    }
}
