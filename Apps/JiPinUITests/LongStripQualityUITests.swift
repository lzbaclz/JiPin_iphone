import XCTest

final class LongStripQualityUITests: XCTestCase {
    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLiveEditor", "-sampleMode", "longStrip", "-mixedLiveSample"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["editor-export"].waitForExistence(timeout: 20))
        return app
    }

    private func assertBadgesDoNotOverlap(_ app: XCUIApplication) {
        let live = app.buttons["canvas-live-preview"]
        let photo = app.staticTexts["canvas-output-size"]
        XCTAssertTrue(live.waitForExistence(timeout: 10))
        XCTAssertTrue(photo.exists)
        XCTAssertFalse(live.frame.intersects(photo.frame), "LIVE 标记与照片尺寸不能互相遮盖。")
        XCTAssertTrue(app.frame.contains(live.frame))
        XCTAssertTrue(app.frame.contains(photo.frame))
        XCTAssertTrue(photo.label.contains("照片输出尺寸"))
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testMixedLongStripShowsSeparateDimensionsAndBadgesAfterSaving() {
        let app = launch()
        assertBadgesDoNotOverlap(app)
        keep(app, "longstrip-badges-before-export")
        app.buttons["canvas-live-preview"].tap()
        XCTAssertTrue(app.buttons["live-play"].waitForExistence(timeout: 60))
        let photo = app.descendants(matching: .any)["live-photo-size"].firstMatch
        let motion = app.descendants(matching: .any)["live-motion-size"].firstMatch
        revealExportControl(photo, in: app)
        let photoText = photo.label + " " + (photo.value as? String ?? "")
        XCTAssertTrue(photoText.contains("1440"), photoText)
        revealExportControl(motion, in: app)
        let motionText = motion.label + " " + (motion.value as? String ?? "")
        XCTAssertTrue(motionText.contains("3840"), motionText)
        XCTAssertNotEqual(photoText, motionText)
        keep(app, "longstrip-photo-and-motion-dimensions")
        allowAlbumSave()
        app.buttons["live-save-album"].tap()
        respondToPhotoAlert(app)
        assertEditorAfterAlbumSave(app)
        assertBadgesDoNotOverlap(app)
        keep(app, "longstrip-badges-after-export")
    }

    func testLargeTextKeepsBothBadgesInsideCanvas() {
        let app = launch(largeText: true)
        assertBadgesDoNotOverlap(app)
        keep(app, "longstrip-large-text-badges")
    }
}
