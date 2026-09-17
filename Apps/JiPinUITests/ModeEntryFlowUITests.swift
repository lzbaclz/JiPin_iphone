import XCTest

final class ModeEntryFlowUITests: XCTestCase {
    private func home() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["home-pick-photos"].waitForExistence(timeout: 15))
        return app
    }

    private func chooseMode(_ mode: String, in app: XCUIApplication) {
        let button = app.buttons["mode-\(mode)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            if button.isHittable { break }
            app.swipeUp()
        }
        button.tap()
    }

    private func pick(_ count: Int, in app: XCUIApplication) {
        let photos = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertGreaterThanOrEqual(photos.count, count)
        for i in 0..<count {
            photos.element(boundBy: i).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '添加' OR label BEGINSWITH 'Add' OR label == '完成' OR label == 'Done' OR label == '确认'")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), app.debugDescription)
        done.tap()
    }

    private func assertEditor(_ app: XCUIApplication, modeTitle: String, photoCount: Int) {
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertFalse(app.navigationBars["选择模式"].exists)
        XCTAssertFalse(app.buttons["mode-start"].exists)
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH %@", modeTitle)).firstMatch.exists)
        XCTAssertTrue(app.buttons["canvas-photo-\(photoCount - 1)"].exists)
        XCTAssertFalse(app.buttons["canvas-photo-\(photoCount)"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "direct-\(modeTitle)-editor"
        shot.lifetime = .keepAlways; add(shot)
    }

    func testPreselectedFreeformOpensEditorAfterPickingPhotos() {
        let app = home()
        chooseMode("freeform", in: app); pick(3, in: app)
        assertEditor(app, modeTitle: "自由拼图", photoCount: 3)
    }

    func testPreselectedLongStripOpensEditorAfterPickingPhotos() {
        let app = home()
        chooseMode("longStrip", in: app); pick(3, in: app)
        assertEditor(app, modeTitle: "长图拼接", photoCount: 3)
    }

    func testTemplateAndPosterAskOnlyForTheirSpecificLayout() {
        for (mode, title) in [("template", "选择布局"), ("poster", "选择海报")] {
            let app = home()
            chooseMode(mode, in: app); pick(3, in: app)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 20), app.debugDescription)
            XCTAssertFalse(app.buttons["mode-choice-freeform"].exists)
            XCTAssertFalse(app.buttons["mode-choice-template"].exists)
            XCTAssertTrue(app.buttons["mode-start"].isEnabled)
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "preset-\(mode)-configuration"
            shot.lifetime = .keepAlways; add(shot)
            app.buttons["mode-start"].tap()
            assertEditor(app, modeTitle: mode == "template" ? "模板拼图" : "海报拼图", photoCount: 3)
            app.terminate()
        }
    }

    func testGenericPhotoEntryStillAllowsChoosingMode() {
        let app = home()
        app.buttons["home-pick-photos"].tap(); pick(3, in: app)
        XCTAssertTrue(app.navigationBars["选择模式"].waitForExistence(timeout: 20))
        app.buttons["mode-choice-freeform"].tap()
        app.buttons["mode-start"].tap()
        assertEditor(app, modeTitle: "自由拼图", photoCount: 3)
    }

    func testCancelAndReselectDoNotReuseOldPhotosOrMode() {
        let app = home()
        app.buttons["home-pick-photos"].tap(); pick(3, in: app)
        XCTAssertTrue(app.navigationBars["选择模式"].waitForExistence(timeout: 20))
        app.navigationBars["选择模式"].buttons["取消"].tap()
        chooseMode("freeform", in: app)
        let cancel = app.buttons.matching(NSPredicate(format: "label == '取消' OR label == 'Cancel'")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10)); cancel.tap()
        XCTAssertTrue(app.buttons["home-pick-photos"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["editor-export"].exists)
        app.buttons["home-pick-photos"].tap(); pick(2, in: app)
        XCTAssertTrue(app.navigationBars["选择模式"].waitForExistence(timeout: 20))
        app.buttons["mode-choice-freeform"].tap(); app.buttons["mode-start"].tap()
        assertEditor(app, modeTitle: "自由拼图", photoCount: 2)
    }

    func testTooFewPhotosDoesNotSilentlyChangeTheChosenMode() {
        let app = home()
        chooseMode("template", in: app); pick(1, in: app)
        XCTAssertTrue(app.alerts["无法开始"].waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(app.alerts["无法开始"].staticTexts.matching(NSPredicate(format: "label CONTAINS '模板拼图需要 2–16 张照片'")).firstMatch.exists)
        XCTAssertFalse(app.buttons["editor-export"].exists)
        app.alerts["无法开始"].buttons["好"].tap()
        chooseMode("longStrip", in: app); pick(1, in: app)
        assertEditor(app, modeTitle: "长图拼接", photoCount: 1)
    }

    func testSingleLongStripSavesAndReopensDraft() {
        let app = home()
        chooseMode("longStrip", in: app); pick(1, in: app)
        assertEditor(app, modeTitle: "长图拼接", photoCount: 1)
        XCTAssertTrue(app.staticTexts["照片 1 张，本模式 1–20 张"].exists)
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["export-save-album"].waitForExistence(timeout: 15))
        allowAlbumSave()
        app.buttons["export-save-album"].tap()
        respondToPhotoAlert(app)
        assertEditorAfterAlbumSave(app)
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.tabBars.buttons["草稿"].waitForExistence(timeout: 10))
        app.tabBars.buttons["草稿"].tap()
        let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS '长图拼接'")).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 10), app.debugDescription)
        draft.tap()
        assertEditor(app, modeTitle: "长图拼接", photoCount: 1)
    }

    func testSingleGenericEntryOffersLongStrip() {
        let app = home()
        app.buttons["home-pick-photos"].tap(); pick(1, in: app)
        XCTAssertTrue(app.navigationBars["选择模式"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["mode-choice-longStrip"].isEnabled)
        app.buttons["mode-choice-longStrip"].tap()
        app.buttons["mode-start"].tap()
        assertEditor(app, modeTitle: "长图拼接", photoCount: 1)
    }
}
