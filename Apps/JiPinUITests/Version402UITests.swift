import XCTest

final class Version402UITests: XCTestCase {
    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testRealPhotoModePreviewStartsTheSelectedPoster() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleModePicker", "-samplePhotoCount", "4"]
        app.launch()
        let preview = app.descendants(matching: .any)["mode-result-preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        XCTAssertTrue(preview.isHittable)
        XCTAssertTrue(app.buttons["mode-start"].isHittable)
        app.buttons["mode-choice-poster"].tap()
        XCTAssertTrue(preview.label.contains("海报"))
        keep(app, "402-real-photo-mode-preview")
        app.buttons["mode-start"].tap()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        app.buttons["editor-more"].tap()
        XCTAssertTrue(app.buttons["复制到其他模式"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["图层列表"].exists)
        keep(app, "402-readable-editor-menu")
        app.buttons["图层列表"].tap()
        XCTAssertTrue(app.navigationBars["图层"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '周末，去远一点'")).firstMatch.exists)
    }

    func testInlineStyleCanUndoAndAllToolsOpensLabeledTextControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        XCTAssertTrue(app.buttons["tool-style"].waitForExistence(timeout: 10))
        app.buttons["tool-style"].tap()
        app.buttons["style-inline-cream"].tap()
        XCTAssertTrue(app.buttons["撤销"].isEnabled)
        keep(app, "402-inline-styles")
        app.buttons["撤销"].tap()
        XCTAssertFalse(app.buttons["撤销"].isEnabled)
        app.buttons["editor-all-tools"].tap()
        app.buttons["tool-menu-text"].tap()
        app.buttons["添加文字"].tap()
        if app.buttons["收起键盘"].exists { app.buttons["收起键盘"].tap() }
        let size = app.sliders["text-size-slider"]
        XCTAssertTrue(size.waitForExistence(timeout: 5))
        let panel = app.scrollViews["editor-tool-panel"]
        for _ in 0..<4 where !size.isHittable { panel.swipeUp() }
        XCTAssertTrue(size.isHittable)
        size.adjust(toNormalizedSliderPosition: 0.6)
        XCTAssertTrue(app.buttons["撤销"].isEnabled)
        let line = app.sliders["text-line-spacing-slider"]
        for _ in 0..<4 where !line.isHittable { panel.swipeUp() }
        XCTAssertTrue(line.isHittable)
        XCTAssertEqual(size.label, "文字字号")
        XCTAssertEqual(line.label, "文字行距")
        keep(app, "402-labeled-text-controls")
    }

    func testPrimarySaveIsVisibleAndSavesWithoutGenerateStep() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleEditor", "-sampleMode", "template"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        let save = app.buttons["export-save-album"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        XCTAssertTrue(save.isHittable)
        XCTAssertLessThan(save.frame.maxY, app.frame.maxY - 20)
        keep(app, "402-primary-save")
        addUIInterruptionMonitor(withDescription: "Photo add permission") { alert in
            guard let button = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS '允许' OR label == '好'")).allElementsBoundByIndex.last else { return false }
            button.tap(); return true
        }
        save.tap()
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 2) { app.tap() }
        assertEditorAfterAlbumSave(app)
        keep(app, "402-saved-with-one-action")
    }

    func testHomeLiveSampleLoadsBundledMediaAndPreviewsBeforeFullExport() {
        let app = XCUIApplication(); app.launch()
        let sample = app.buttons["home-try-live"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        for _ in 0..<4 where !sample.isHittable { app.swipeUp() }
        sample.tap()
        XCTAssertTrue(app.buttons["canvas-live-preview"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 45))
        XCTAssertTrue(app.staticTexts["预览已就绪。保存时将生成 1440 清晰度的成品。"].exists)
        XCTAssertTrue(app.buttons["live-save-album"].isHittable)
        keep(app, "402-fast-live-preview")
    }
}
