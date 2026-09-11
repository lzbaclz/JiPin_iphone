import XCTest

final class LivePhotoUITests: XCTestCase {
    private func openLiveEditor() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLiveEditor"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["tool-livePhoto"].exists)
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        func isVisible() -> Bool {
            guard element.exists else { return false }
            let footerIDs = ["export-save-album", "live-save-album", "live-generate-primary"]
            var bottom = app.frame.maxY - 40
            if !footerIDs.contains(element.identifier) {
                // SwiftUI can report a Form row as hittable even when the fixed action bar covers it.
                // Scroll the row above the footer; otherwise a tap can save instead of generate.
                for id in footerIDs {
                    let footer = app.buttons[id]
                    if footer.exists && footer.isHittable { bottom = min(bottom, footer.frame.minY - 36) }
                }
            }
            return element.isHittable && element.frame.midY > 100 && element.frame.midY < bottom
        }
        for _ in 0..<7 {
            if isVisible() { break }
            app.swipeUp()
        }
        XCTAssertTrue(isVisible())
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testLivePreviewSettingsSaveAndStillExport() {
        let app = openLiveEditor()
        keep(app, "v4-live-editor")
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        keep(app, "v4-native-live-preview")
        app.buttons["live-play"].tap()
        let duration = app.segmentedControls["live-export-duration"]
        reveal(duration, in: app)
        duration.buttons["1.5 秒"].tap()
        let generate = app.buttons["live-generate-primary"]
        reveal(generate, in: app); generate.tap()
        XCTAssertTrue(app.staticTexts["live-message"].waitForExistence(timeout: 60))
        let save = app.buttons["live-save-album"]
        reveal(save, in: app)
        XCTAssertTrue(save.isEnabled)
        addUIInterruptionMonitor(withDescription: "Photo library add permission") { alert in
            let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS '允许' OR label == '好'")).allElementsBoundByIndex
            guard let button = allow.last else { return false }
            button.tap(); return true
        }
        save.tap()
        // Trigger the interruption handler when this simulator has not granted add-only permission.
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 2) { app.tap() }
        assertEditorAfterAlbumSave(app)
        keep(app, "v4-live-saved-to-photos")
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        let still = app.buttons["live-export-still"]
        reveal(still, in: app); still.tap()
        let staticGenerate = app.buttons["export-generate"]
        XCTAssertTrue(staticGenerate.waitForExistence(timeout: 8))
        reveal(staticGenerate, in: app); staticGenerate.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '已生成'")).firstMatch.waitForExistence(timeout: 30))
    }

    func testLiveDraftCanCloseAndReopen() {
        let app = openLiveEditor()
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["home-pick-photos"].waitForExistence(timeout: 15))
        app.tabBars.buttons["草稿"].tap()
        let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS '会动的小日常'")).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 10))
        draft.tap()
        XCTAssertTrue(app.buttons["canvas-live-preview"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        keep(app, "v4-reopened-live-draft")
    }

    func testExtensionLiveDraftHandoffKeepsMotion() {
        let app = XCUIApplication()
        app.launchArguments = ["-quickLiveCollage"]
        app.launch()
        let save = app.buttons["quick-save-live-draft"]
        XCTAssertTrue(save.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["quick-save-album"].label.contains("静态"))
        save.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '草稿已保存'")).firstMatch.waitForExistence(timeout: 15))
        keep(app, "v4-extension-live-draft")
        app.buttons["quick-cancel"].tap()
        app.tabBars.buttons["草稿"].tap()
        let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS '相册快拼'")).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 10)); draft.tap()
        XCTAssertTrue(app.buttons["canvas-live-preview"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
    }

    func testHomeLiveExampleWorksWithoutPhotoPicker() {
        let app = XCUIApplication(); app.launch()
        let sample = app.buttons["home-try-live"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10)); reveal(sample, in: app)
        sample.tap()
        XCTAssertTrue(app.buttons["canvas-live-preview"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["live-preview-open"].exists)
    }

    func testSystemPickerRetainsLivePhotoFromLibrary() {
        let app = openLiveEditor()
        app.buttons["editor-export"].tap()
        let save = app.buttons["live-save-album"]
        XCTAssertTrue(save.waitForExistence(timeout: 60))
        addUIInterruptionMonitor(withDescription: "Add generated Live fixture") { alert in
            let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS '允许' OR label == '好'")).allElementsBoundByIndex
            guard let button = allow.last else { return false }
            button.tap(); return true
        }
        save.tap()
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 2) { app.tap() }
        assertEditorAfterAlbumSave(app)
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["home-pick-photos"].waitForExistence(timeout: 15))
        app.buttons["home-pick-photos"].tap()
        let first = app.images.matching(NSPredicate(format: "identifier == 'PXGGridLayout-Info' AND (label BEGINSWITH '实况照片' OR label CONTAINS[c] 'Live Photo')")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), app.debugDescription)
        // Photos exposes grid content as non-interactive Image AX nodes; its enclosing grid handles taps.
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == '添加' OR label == '完成' OR label == 'Add' OR label == 'Done' OR label == '确认'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        confirm.tap()
        let start = app.buttons["开始"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20), app.debugDescription)
        start.tap()
        let badge = app.buttons["canvas-live-preview"]
        XCTAssertTrue(badge.waitForExistence(timeout: 15), "PhotosPickerItem must retain Live even if its UTType list only advertises JPEG/HEIC.")
        XCTAssertTrue(badge.label.contains("1"))
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-save-album"].waitForExistence(timeout: 60))
        keep(app, "v4-system-picker-live-roundtrip")
    }
}
