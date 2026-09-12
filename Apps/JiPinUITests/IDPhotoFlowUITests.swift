import XCTest
import UIKit
import ImageIO

/// Deterministic interaction fixtures are intentionally stylized drawings with an
/// explicit mask, not evidence that Vision segmentation works on a photograph.
final class IDPhotoFlowUITests: XCTestCase {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/IDPhotoQA/UIFixture", isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        try makeFixture()
    }

    private func launchFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-idPhotoSample"]
        app.launchEnvironment["JIPIN_IDPHOTO_SAMPLE_PATH"] = fixture.appendingPathComponent("source.png").path
        app.launchEnvironment["JIPIN_IDPHOTO_MASK_PATH"] = fixture.appendingPathComponent("mask.png").path
        app.launchEnvironment["JIPIN_IDPHOTO_FACES_PATH"] = fixture.appendingPathComponent("faces.json").path
        app.launchEnvironment["JIPIN_IDPHOTO_EXPORT_PATH"] = fixture.appendingPathComponent("export.jpg").path
        app.launch()
        XCTAssertTrue(app.buttons["idphoto-export"].waitForExistence(timeout: 20), app.debugDescription)
        waitEnabled(app.buttons["idphoto-export"])
        XCTAssertFalse(app.alerts.firstMatch.exists, "正常加载不能弹出缺失蒙版错误。")
        return app
    }

    private func waitEnabled(_ element: XCUIElement, timeout: TimeInterval = 20) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)], timeout: timeout), .completed)
    }

    private func waitLabel(_ element: XCUIElement, contains value: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", value), object: element)], timeout: 15), .completed, element.label)
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable {
            let panel = app.scrollViews["idphoto-tool-panel"]
            if app.navigationBars["保存证件照"].exists, let collection = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable }) {
                collection.swipeUp()
            } else if panel.exists && panel.isHittable { panel.swipeUp() }
            else if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) { scroll.swipeUp() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func replaceText(_ field: XCUIElement, with value: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
    }

    func test01HomeEntryFiveTemplatesAndCustomValidation() {
        let app = XCUIApplication(); app.launch()
        let entry = app.buttons["idphoto-open"]
        reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.buttons["idphoto-import"].waitForExistence(timeout: 15))
        for id in ["id-25x35", "id-35x49", "id-22x32", "id-35x45", "id-33x48"] {
            let template = app.buttons["idphoto-template-\(id)"]
            XCTAssertTrue(template.exists); template.tap(); XCTAssertTrue(template.isSelected)
        }
        app.buttons["idphoto-custom"].tap()
        let width = app.textFields["idphoto-custom-width"], height = app.textFields["idphoto-custom-height"]
        XCTAssertTrue(width.waitForExistence(timeout: 5))
        replaceText(width, with: "0")
        app.buttons["idphoto-custom-apply"].tap()
        XCTAssertTrue(app.staticTexts["idphoto-custom-error"].waitForExistence(timeout: 5))
        replaceText(width, with: "2048"); replaceText(height, with: "2048")
        app.buttons["idphoto-custom-apply"].tap()
        XCTAssertTrue(app.staticTexts["idphoto-custom-error"].exists, "超过 400 万像素必须拒绝。")
        replaceText(width, with: "601"); replaceText(height, with: "801")
        app.buttons["idphoto-custom-apply"].tap()
        XCTAssertTrue(app.buttons["idphoto-import"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["idphoto-custom-width"].exists)
        keep(app, "IDPhoto-five-template-entry")
    }

    func test02ColorsRetouchResetAndUndoPreserveIndependentEdits() {
        let app = launchFixture()
        for color in ["white", "red", "blue", "blue-white", "light-gray"] {
            let button = app.buttons["idphoto-color-\(color)"]
            waitEnabled(button); button.tap(); XCTAssertTrue(button.isSelected)
        }
        app.buttons["idphoto-tool-retouch"].tap()
        for id in ["brightness", "smoothing", "temperature"] {
            XCTAssertEqual(app.staticTexts["idphoto-\(id)-value"].label, "0")
        }
        app.buttons["idphoto-natural"].tap()
        waitLabel(app.staticTexts["idphoto-brightness-value"], contains: "5")
        XCTAssertEqual(app.staticTexts["idphoto-smoothing-value"].label, "6")
        app.buttons["idphoto-undo"].tap()
        XCTAssertEqual(app.staticTexts["idphoto-brightness-value"].label, "0")
        app.buttons["idphoto-redo"].tap()
        XCTAssertEqual(app.staticTexts["idphoto-smoothing-value"].label, "6")
        app.buttons["idphoto-retouch-reset"].tap()
        XCTAssertEqual(app.staticTexts["idphoto-brightness-value"].label, "0")
        XCTAssertEqual(app.staticTexts["idphoto-smoothing-value"].label, "0")
        app.buttons["idphoto-tool-background"].tap()
        XCTAssertTrue(app.buttons["idphoto-color-light-gray"].isSelected, "重置轻修不能重置底色。")
        keep(app, "IDPhoto-five-color-editor")
    }

    func test03CropBrushAndDraftReopenKeepHistoryAndOutputGeometry() {
        let app = launchFixture()
        app.buttons["idphoto-color-blue"].tap()
        app.buttons["idphoto-tool-size"].tap()
        let bigger = app.buttons["idphoto-zoom-in"]
        reveal(bigger, in: app); bigger.tap()
        XCTAssertEqual(app.staticTexts["idphoto-zoom-value"].label, "108%")
        app.buttons["idphoto-undo"].tap()
        XCTAssertEqual(app.staticTexts["idphoto-zoom-value"].label, "100%")
        app.buttons["idphoto-redo"].tap()
        app.buttons["idphoto-tool-brush"].tap()
        let canvas = app.otherElements["idphoto-preview"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        // Wait for the crop frame before applying a stroke to its displayed pixels.
        let noProcessing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.otherElements["idphoto-processing"])
        _ = XCTWaiter.wait(for: [noProcessing], timeout: 10)
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.6)))
        waitLabel(app.staticTexts["idphoto-stroke-count"], contains: "1 笔")
        app.buttons["idphoto-undo"].tap()
        waitLabel(app.staticTexts["idphoto-stroke-count"], contains: "0 笔")
        app.buttons["idphoto-redo"].tap()
        waitLabel(app.staticTexts["idphoto-stroke-count"], contains: "1 笔")
        keep(app, "IDPhoto-brush-transaction")
        app.buttons["idphoto-close"].tap()
        XCTAssertTrue(app.buttons["idphoto-import"].waitForExistence(timeout: 20))
        let draft = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'idphoto-draft-' AND NOT identifier BEGINSWITH 'idphoto-draft-delete-'")).firstMatch
        reveal(draft, in: app); draft.tap()
        XCTAssertTrue(app.buttons["idphoto-export"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["idphoto-color-blue"].isSelected)
        app.buttons["idphoto-tool-brush"].tap()
        waitLabel(app.staticTexts["idphoto-stroke-count"], contains: "1 笔")
        app.buttons["idphoto-tool-size"].tap()
        reveal(app.staticTexts["idphoto-zoom-value"], in: app)
        XCTAssertEqual(app.staticTexts["idphoto-zoom-value"].label, "108%")
    }

    func test04ExactCustomJPEGAndSuccessfulAlbumSaveDismissesExport() throws {
        let app = launchFixture()
        app.buttons["idphoto-tool-size"].tap()
        let custom = app.buttons["idphoto-custom"]; reveal(custom, in: app); custom.tap()
        replaceText(app.textFields["idphoto-custom-width"], with: "601")
        replaceText(app.textFields["idphoto-custom-height"], with: "801")
        app.buttons["idphoto-custom-apply"].tap()
        let path = fixture.appendingPathComponent("export.jpg")
        try? FileManager.default.removeItem(at: path)
        app.buttons["idphoto-export"].tap()
        let save = app.buttons["idphoto-save-album"]
        waitEnabled(save, timeout: 30)
        let image = try XCTUnwrap(CGImageSourceCreateWithURL(path as CFURL, nil))
        let metadata = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any])
        XCTAssertEqual(metadata[kCGImagePropertyPixelWidth] as? Int, 601)
        XCTAssertEqual(metadata[kCGImagePropertyPixelHeight] as? Int, 801)
        XCTAssertEqual((metadata[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue, 300)
        XCTAssertNil(metadata[kCGImagePropertyGPSDictionary])
        reveal(save, in: app)
        allowAlbumSave(); save.tap(); respondToPhotoAlert(app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["保存证件照"])], timeout: 30), .completed)
        XCTAssertTrue(app.buttons["idphoto-export"].isHittable)
        waitLabel(app.staticTexts["idphoto-notice"], contains: "已保存到相册")
        keep(app, "IDPhoto-save-success-returns-editor")
    }

    func test05NoPersonAnalysisOffersHonestResizeFallback() {
        let app = XCUIApplication()
        app.launchArguments = ["-idPhotoSample"]
        app.launchEnvironment["JIPIN_IDPHOTO_SAMPLE_PATH"] = fixture.appendingPathComponent("source.png").path
        app.launch()
        XCTAssertTrue(app.staticTexts["idphoto-analysis-warning"].waitForExistence(timeout: 40))
        XCTAssertFalse(app.buttons["idphoto-color-blue"].isEnabled)
        XCTAssertTrue(app.buttons["idphoto-retry"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        waitEnabled(app.buttons["idphoto-export"])
        app.buttons["idphoto-export"].tap()
        waitEnabled(app.buttons["idphoto-save-album"])
        keep(app, "IDPhoto-unavailable-analysis-resize-fallback")
    }

    // Run separately after resetting both photos and photos-add privacy on this simulator.
    func test06DeniedAlbumPermissionKeepsPhotoAndExportForRetry() {
        let app = launchFixture()
        app.buttons["idphoto-export"].tap()
        let save = app.buttons["idphoto-save-album"]; waitEnabled(save); reveal(save, in: app)
        addUIInterruptionMonitor(withDescription: "Deny ID photo save") { alert in
            let deny = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Don’t Allow' OR label CONTAINS[c] \"Don't Allow\" OR label CONTAINS '不允许'")).firstMatch
            guard deny.exists else { return false }; deny.tap(); return true
        }
        save.tap()
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 8) { app.tap() }
        let error = app.staticTexts["idphoto-export-message"]
        waitLabel(error, contains: "尚未保存")
        XCTAssertTrue(app.navigationBars["保存证件照"].exists)
        XCTAssertTrue(save.isEnabled)
        XCTAssertTrue(app.buttons["idphoto-file-alternative"].isHittable)
        keep(app, "IDPhoto-save-denied-keeps-export")
    }

    private func makeFixture() throws {
        let size = CGSize(width: 600, height: 840)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let body = CGRect(x: 125, y: 445, width: 350, height: 650)
        let head = CGRect(x: 182, y: 120, width: 236, height: 365)
        let hair = CGRect(x: 175, y: 105, width: 250, height: 220)
        let source = renderer.image { _ in
            UIColor(red: 0.38, green: 0.56, blue: 0.45, alpha: 1).setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.25, green: 0.32, blue: 0.46, alpha: 1).setFill(); UIBezierPath(ovalIn: body).fill()
            UIColor(red: 0.14, green: 0.10, blue: 0.09, alpha: 1).setFill(); UIBezierPath(ovalIn: hair).fill()
            UIColor(red: 0.76, green: 0.59, blue: 0.45, alpha: 1).setFill(); UIBezierPath(ovalIn: head).fill()
            UIColor(red: 0.14, green: 0.10, blue: 0.09, alpha: 1).setFill(); UIBezierPath(ovalIn: CGRect(x: 180, y: 105, width: 240, height: 125)).fill()
            UIColor.black.setFill()
            UIBezierPath(ovalIn: CGRect(x: 235, y: 282, width: 14, height: 13)).fill()
            UIBezierPath(ovalIn: CGRect(x: 349, y: 282, width: 14, height: 13)).fill()
            UIColor(red: 0.52, green: 0.21, blue: 0.22, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 272, y: 389, width: 58, height: 10), cornerRadius: 5).fill()
        }
        let mask = renderer.image { _ in
            UIColor.black.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            for shape in [body, head, hair] { UIBezierPath(ovalIn: shape).fill() }
        }
        try XCTUnwrap(source.pngData()).write(to: fixture.appendingPathComponent("source.png"), options: .atomic)
        try XCTUnwrap(mask.pngData()).write(to: fixture.appendingPathComponent("mask.png"), options: .atomic)
        let faces: [[String: Any]] = [[
            "faceRect": [[0.30, 0.14], [0.40, 0.44]],
            "skinPolygon": [[0.31, 0.23], [0.69, 0.23], [0.67, 0.5], [0.5, 0.58], [0.33, 0.5]],
            "protectedPolygons": [
                [[0.36, 0.31], [0.43, 0.31], [0.43, 0.37], [0.36, 0.37]],
                [[0.57, 0.31], [0.64, 0.31], [0.64, 0.37], [0.57, 0.37]],
                [[0.43, 0.45], [0.57, 0.45], [0.57, 0.49], [0.43, 0.49]]
            ]
        ]]
        try JSONSerialization.data(withJSONObject: faces).write(to: fixture.appendingPathComponent("faces.json"), options: .atomic)
    }
}
