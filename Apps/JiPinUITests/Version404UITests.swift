import XCTest

final class Version404UITests: XCTestCase {
    private func openExport(live: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [live ? "-sampleLiveEditor" : "-sampleEditor", "-sampleMode", "longStrip"]
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 20))
        app.buttons["editor-export"].tap()
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func quality(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["export-quality"].firstMatch
    }

    private func qualityText(_ element: XCUIElement) -> String {
        element.label + " " + (element.value as? String ?? "")
    }

    func testLongStripDefaultsToHDAndSuccessfulSaveReturnsToEditor() {
        let app = openExport()
        let selectedQuality = quality(app)
        XCTAssertTrue(selectedQuality.waitForExistence(timeout: 10))
        XCTAssertTrue(qualityText(selectedQuality).contains("高清"))
        let dimensions = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '输出约'")).firstMatch
        XCTAssertTrue(dimensions.label.replacingOccurrences(of: ",", with: "").hasPrefix("输出约 1440×"), dimensions.label)
        keep(app, "404-hd-export-default")
        allowAlbumSave()
        app.buttons["export-save-album"].tap()
        respondToPhotoAlert(app)
        assertEditorAfterAlbumSave(app)
        keep(app, "404-saved-back-to-editor")
    }

    func testExplicitStandardChoiceSurvivesReopeningExport() {
        let app = openExport()
        XCTAssertTrue(quality(app).waitForExistence(timeout: 10))
        quality(app).tap()
        app.buttons["标准"].tap()
        XCTAssertTrue(qualityText(quality(app)).contains("标准"))
        app.navigationBars["导出"].buttons["关闭"].tap()
        app.buttons["editor-export"].tap()
        XCTAssertTrue(quality(app).waitForExistence(timeout: 10))
        XCTAssertTrue(qualityText(quality(app)).contains("标准"), "默认高清不能覆盖用户主动选择的标准尺寸。")
    }

    func testSavingStillFromLiveClosesBothExportSheets() {
        let app = openExport(live: true)
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["live-message"].label.contains("保存后照片为 1440 ×"))
        let still = app.buttons["live-export-still"]
        revealExportControl(still, in: app); still.tap()
        XCTAssertTrue(app.buttons["export-save-album"].waitForExistence(timeout: 10))
        allowAlbumSave()
        app.buttons["export-save-album"].tap()
        respondToPhotoAlert(app)
        assertEditorAfterAlbumSave(app)
    }

    func testSavingAllPagesClosesTheCompleteExportFlow() {
        let app = openExport()
        let pages = app.buttons["export-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 10))
        revealExportControl(pages, in: app); pages.tap()
        let generate = app.buttons["pages-generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        revealExportControl(generate, in: app); generate.tap()
        XCTAssertTrue(app.staticTexts["pages-result"].waitForExistence(timeout: 60))
        let save = app.buttons["pages-save-album"]
        revealExportControl(save, in: app)
        allowAlbumSave(); save.tap()
        respondToPhotoAlert(app)
        assertEditorAfterAlbumSave(app)
    }

    // Run separately on a fresh simulator so Photos starts with undetermined access.
    func testDeniedAlbumPermissionKeepsExportOpenForRetry() {
        let app = openExport()
        let save = app.buttons["export-save-album"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        addUIInterruptionMonitor(withDescription: "Deny adding photos") { alert in
            let deny = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Don’t Allow' OR label CONTAINS[c] \"Don't Allow\" OR label CONTAINS '不允许'")).firstMatch
            guard deny.exists else { return false }
            deny.tap(); return true
        }
        save.tap()
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 10) { app.tap() }
        let error = app.staticTexts["export-message"]
        XCTAssertTrue(error.waitForExistence(timeout: 20))
        XCTAssertTrue(error.label.contains("未获得添加照片权限"), error.label)
        XCTAssertTrue(app.navigationBars["导出"].exists)
        XCTAssertTrue(save.isEnabled)
        keep(app, "404-denied-save-keeps-export")
    }
}
