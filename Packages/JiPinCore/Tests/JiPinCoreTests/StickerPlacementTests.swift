import UIKit
import XCTest
@testable import JiPinCore

final class StickerPlacementTests: XCTestCase {
    @MainActor private func session(mode: CollageMode = .longStrip) -> EditorSession {
        EditorSession(project: CollageProject(mode: mode), assets: AssetLibrary(), autosaves: false)
    }

    @MainActor func testEachInsertionUsesCurrentViewportAndUndoRetainsTheOriginalPosition() throws {
        let session = session()
        var point = CGPoint(x: 0.5, y: 0.1)
        session.canvasInsertionPoint = { point }
        session.addSticker("cute-bunny")
        let first = try XCTUnwrap(session.selected)
        XCTAssertEqual(first.transform.centerY, 0.1)
        point = CGPoint(x: 0.4, y: 0.85)
        XCTAssertEqual(session.undo.undoCount, 1, "滚动不能创建编辑记录")
        session.addSticker("cute-bear")
        let second = try XCTUnwrap(session.selected)
        XCTAssertEqual(second.transform.centerX, 0.4)
        XCTAssertEqual(second.transform.centerY, 0.85)
        XCTAssertEqual(session.project.object(id: first.id), first, "新位置只影响新贴图")
        session.undoLast()
        XCTAssertNil(session.project.object(id: second.id))
        point = CGPoint(x: 0.8, y: 0.3)
        session.redoLast()
        XCTAssertEqual(session.project.object(id: second.id), second, "重做应恢复保存的位置")
        let reopened = try JSONDecoder().decode(CollageProject.self, from: JSONEncoder().encode(session.project))
        XCTAssertEqual(reopened.object(id: second.id), second)
    }

    @MainActor func testImportedDecorationsAndShapesUseViewportOnlyForLongStrips() throws {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 120)).image { ctx in
            UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 120))
        }.pngData()!
        let photo = ImportedPhoto(filename: "decoration", data: data, pixelSize: CGSize(width: 80, height: 120), utType: "public.png")
        for mode in CollageMode.allCases {
            let session = session(mode: mode)
            session.canvasInsertionPoint = { CGPoint(x: 0.8, y: 0.2) }
            let expected = mode == .longStrip ? CGPoint(x: 0.8, y: 0.2) : CGPoint(x: 0.5, y: 0.5)
            session.addImageDecoration(photo)
            XCTAssertEqual(session.selected?.transform.centerX, expected.x)
            XCTAssertEqual(session.selected?.transform.centerY, expected.y)
            session.addShape("heart")
            XCTAssertEqual(session.selected?.transform.centerX, expected.x)
            XCTAssertEqual(session.selected?.transform.centerY, expected.y)
            session.addSticker("cute-bunny")
            XCTAssertEqual(session.selected?.transform.centerX, expected.x)
            XCTAssertEqual(session.selected?.transform.centerY, expected.y)
        }
    }

    @MainActor func testUnavailableViewportFallsBackToAValidCanvasPosition() {
        let session = session()
        for point in [CGPoint?.none, CGPoint(x: .nan, y: 0.1)] {
            session.canvasInsertionPoint = { point }
            session.addSticker("cute-bunny")
            XCTAssertEqual(session.selected?.transform.centerX, 0.5)
            XCTAssertEqual(session.selected?.transform.centerY, 0.5)
        }
        session.canvasInsertionPoint = { CGPoint(x: -2, y: 4) }
        session.addSticker("cute-bear")
        XCTAssertEqual(session.selected?.transform.centerX, 0)
        XCTAssertEqual(session.selected?.transform.centerY, 1)
    }
}
