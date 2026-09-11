import XCTest

final class LivePreviewRefreshUITests: XCTestCase {
    private func openPreview(mode: String = "longStrip", mixed: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLiveEditor", "-sampleMode", mode]
        if mixed { app.launchArguments.append("-mixedLiveSample") }
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 20))
        app.buttons["editor-export"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func waitForPreview(_ app: XCUIApplication, duration: String, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND value == %@", duration),
            object: app.buttons["live-play"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed,
                       "预览必须恢复，并且编码时长匹配最后的选择。", file: file, line: line)
    }

    func testDurationChangeAutomaticallyRegeneratesLongStripPreview() {
        let app = openPreview()
        let duration = app.segmentedControls["live-export-duration"]
        revealExportControl(duration, in: app)
        duration.buttons["2 秒"].tap()
        let ready = app.buttons["live-play"].waitForExistence(timeout: 30)
        keep(app, "405-duration-change-preview")
        XCTAssertTrue(ready, "更改时长后应自动恢复可播放的预览，不需要另找生成按钮。")
        guard ready else { return }
        waitForPreview(app, duration: "2 秒")
        for choice in ["1.5 秒", "3 秒"] {
            duration.buttons[choice].tap()
            waitForPreview(app, duration: choice)
            app.buttons["live-play"].tap()
        }
        keep(app, "405-all-durations-playable")
    }

    func testRapidChangesKeepLatestDurationAndMixedLiveCanSave() {
        let app = openPreview(mixed: true)
        let duration = app.segmentedControls["live-export-duration"]
        revealExportControl(duration, in: app)
        for choice in ["1.5 秒", "2 秒", "3 秒", "2 秒"] {
            XCTAssertTrue(duration.buttons[choice].isEnabled)
            duration.buttons[choice].tap()
        }
        waitForPreview(app, duration: "2 秒")
        XCTAssertTrue(duration.buttons["2 秒"].isSelected)
        XCTAssertFalse(app.staticTexts["live-message"].label.contains("已取消"))
        keep(app, "405-latest-mixed-preview")
        allowAlbumSave()
        app.buttons["live-save-album"].tap()
        respondToPhotoAlert(app)
        assertEditorAfterAlbumSave(app)
        XCTAssertTrue(app.segmentedControls["live-duration"].buttons["2 秒"].isSelected)
        keep(app, "405-mixed-save-back-to-editor")
    }

    func testClosingDuringRefreshCanReopenAndUndoDuration() {
        let app = openPreview(mode: "template")
        let duration = app.segmentedControls["live-export-duration"]
        revealExportControl(duration, in: app)
        duration.buttons["2 秒"].tap()
        app.navigationBars["导出 Live"].buttons["关闭"].tap()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 10))
        app.buttons["editor-export"].tap()
        waitForPreview(app, duration: "2 秒")
        keep(app, "405-reopened-during-refresh")
        app.navigationBars["导出 Live"].buttons["关闭"].tap()
        app.buttons["撤销"].tap()
        XCTAssertTrue(app.segmentedControls["live-duration"].buttons["3 秒"].isSelected)
        app.buttons["editor-export"].tap()
        waitForPreview(app, duration: "3 秒")
    }

    func testQualityChangeAndManualRegenerationRemainPlayable() {
        let app = openPreview(mode: "template")
        let quality = app.buttons["live-quality"]
        revealExportControl(quality, in: app)
        quality.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS '标准'")).firstMatch.tap()
        waitForPreview(app, duration: "3 秒")
        XCTAssertTrue(app.staticTexts["live-message"].label.contains("1080"))
        let generate = app.buttons["live-generate"]
        revealExportControl(generate, in: app)
        generate.tap()
        waitForPreview(app, duration: "3 秒")
        keep(app, "405-quality-and-manual-preview")
    }
}
