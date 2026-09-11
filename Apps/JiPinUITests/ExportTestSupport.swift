import XCTest

extension XCTestCase {
    func assertEditorAfterAlbumSave(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let closed = ["导出", "导出 Live", "长图分页"].map { title in
            XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars[title])
        }
        XCTAssertEqual(XCTWaiter.wait(for: closed, timeout: 60), .completed, "保存成功后应关闭整个导出流程。", file: file, line: line)
        XCTAssertTrue(app.buttons["editor-export"].isHittable, "应回到可操作的编辑器。", file: file, line: line)
    }

    func allowAlbumSave() {
        addUIInterruptionMonitor(withDescription: "Allow adding exported photos") { alert in
            let buttons = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS '允许' OR label == '好'")).allElementsBoundByIndex
            guard let allow = buttons.last else { return false }
            allow.tap(); return true
        }
    }

    func respondToPhotoAlert(_ app: XCUIApplication) {
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 2) { app.tap() }
    }

    func revealExportControl(_ element: XCUIElement, in app: XCUIApplication) {
        func visible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            var bottom = app.frame.maxY - 32
            for id in ["export-save-album", "live-save-album", "live-generate-primary"] where id != element.identifier {
                let footer = app.buttons[id]
                if footer.exists, footer.isHittable { bottom = min(bottom, footer.frame.minY - 25) }
            }
            return element.frame.midY > 120 && element.frame.midY < bottom
        }
        for _ in 0..<7 where !visible() { app.swipeUp() }
        XCTAssertTrue(visible(), app.debugDescription)
    }
}
