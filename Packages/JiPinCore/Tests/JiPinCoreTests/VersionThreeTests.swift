import XCTest
import UIKit
@testable import JiPinCore

final class VersionThreeTests: XCTestCase {
    private var originals: [StickerDefinition] { StickerCatalog.all.filter { $0.category == .cute || $0.category == .cool } }
    private func transparentProject() -> CollageProject {
        var project = CollageProject(mode: .freeform)
        project.background.isHidden = true
        project.exportPreference = ExportPreference(format: .png, transparentBackground: true)
        return project
    }
    private func pixels(_ image: UIImage) -> [UInt8] {
        let source = image.cgImage!, w = source.width, h = source.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(source, in: CGRect(x: 0,y: 0,width: w,height: h))
        }
        return bytes
    }
    private func render(_ project: CollageProject, size: CGSize = CGSize(width: 240,height: 240)) -> UIImage {
        CollageRenderer.shared.render(project: project, assets: DataAssetLibrary(), canvasSize: size, preview: false)
    }

    func testOriginalCollectionsContainSixteenCuteEightCoolAndSixFrames() {
        XCTAssertEqual(StickerCatalog.stickers(in: .cute).count, 16)
        XCTAssertEqual(StickerCatalog.stickers(in: .cool).count, 8)
        XCTAssertEqual(DecorationFrameCatalog.all.count, 6)
        XCTAssertEqual(Set(originals.map(\.id)).count, 24)
        let keys = originals.compactMap { item -> String? in if case .illustration(let key) = item.render { return key }; return nil }
        XCTAssertEqual(Set(keys), Set(OriginalStickerArt.names))
    }

    func testEveryOriginalRendersDistinctArtworkWithTransparentSurroundings() {
        var outputs = Set<Data>()
        for item in originals {
            var project = transparentProject()
            project.objects = [LayerObject(kind: .sticker, zIndex: 1, transform: CanvasTransform(width: 0.9,height: 0.9), sticker: StickerPayload(stickerID: item.id))]
            let image = render(project), bytes = pixels(image)
            let alphas = stride(from: 3,to: bytes.count,by: 4).map { bytes[$0] }
            XCTAssertEqual(alphas[0], 0, item.id)
            XCTAssertGreaterThan(alphas.filter { $0 > 0 }.count, 1500, item.id)
            XCTAssertLessThan(alphas.filter { $0 > 0 }.count, 45_000, item.id)
            outputs.insert(image.pngData()!)
        }
        XCTAssertEqual(outputs.count, 24)
    }

    func testDecorativeFramesLeaveCenterTransparentAtAllAspectRatios() {
        for frame in DecorationFrameCatalog.all {
            for size in [CGSize(width: 240,height: 320), CGSize(width: 320,height: 240), CGSize(width: 240,height: 240)] {
                var project = transparentProject()
                project.decorationFrame = CanvasDecoration(frameID: frame.id, width: 0.12)
                let image = render(project, size: size), bytes = pixels(image)
                let width = Int(size.width), height = Int(size.height)
                XCTAssertEqual(bytes[3], 255, frame.id)
                for x in stride(from: width / 4, through: width * 3 / 4, by: 15) {
                    for y in stride(from: height / 4, through: height * 3 / 4, by: 15) {
                        XCTAssertEqual(bytes[(y * width + x) * 4 + 3], 0, frame.id)
                    }
                }
            }
        }
    }

    @MainActor func testStickerUsesSquarePixelBoundsOnPortraitAndLongCanvas() {
        for mode in [CollageMode.freeform, .longStrip] {
            var project = CollageProject(mode: mode, canvas: .portrait916)
            project.longStrip = LongStripSpec(direction: .vertical)
            let session = EditorSession(project: project, assets: AssetLibrary(), autosaves: false)
            session.addSticker("cute-bunny")
            let size: CGSize
            if mode == .longStrip {
                switch ExportGeometry.outputSize(for: session.project, assets: session.assets.snapshot) {
                case .ok(let value), .needsChoice(_, let value): size = value
                }
            } else { size = project.canvas.size(maxLongSide: 1000) }
            let rect = session.selected!.transform.cgRect(in: size)
            XCTAssertEqual(rect.width, rect.height, accuracy: 0.01)
            XCTAssertEqual(session.selected?.displayName, "软软兔")
        }
    }

    @MainActor func testFrameAndStickerDraftRoundTripUndoAndModeCopy() throws {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        let store = DraftStore(overridesContainer: location)
        let session = EditorSession(project: transparentProject(), assets: AssetLibrary(), store: store, autosaves: false)
        session.addSticker("cool-orbit")
        session.setDecorationFrame(DecorationFrameCatalog.all[4])
        XCTAssertEqual(session.project.schemaVersion, JiPin.schemaVersion)
        session.undoLast(); XCTAssertNil(session.project.decorationFrame)
        session.redoLast(); XCTAssertNotNil(session.project.decorationFrame)
        try store.save(project: session.project, assets: [:], thumbnailJPEG: nil)
        let reopened = try store.load(id: session.project.id).project
        XCTAssertEqual(reopened.decorationFrame, session.project.decorationFrame)
        XCTAssertEqual(reopened.objects, session.project.objects)
        let copy = ProjectFactory.copy(project: reopened, to: .poster, photos: [])
        XCTAssertEqual(copy.decorationFrame, reopened.decorationFrame)
        XCTAssertEqual(copy.objects.first?.sticker?.stickerID, "cool-orbit")
    }

    func testVersionTwoDraftWithoutFrameStillDecodes() throws {
        var project = transparentProject(); project.schemaVersion = 2
        let data = try JSONEncoder().encode(project)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "decorationFrame")
        let decoded = try JSONDecoder().decode(CollageProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.decorationFrame)
        XCTAssertEqual(decoded.schemaVersion, 2)
    }

    @MainActor func testUnknownFramePreventsSilentIncompleteExport() {
        var project = transparentProject(); project.decorationFrame = CanvasDecoration(frameID: "unknown")
        let session = EditorSession(project: project, assets: AssetLibrary(), autosaves: false)
        XCTAssertTrue(session.missingAssetWarning)
    }

    func testOriginalArtworkFlipAndOpacityAreApplied() {
        var project = transparentProject()
        project.objects = [LayerObject(kind: .sticker, zIndex: 1, transform: CanvasTransform(width: 0.8,height: 0.8), sticker: StickerPayload(stickerID: "cute-bunny"))]
        let original = pixels(render(project))
        project.objects[0].transform.scaleX = -1
        XCTAssertNotEqual(pixels(render(project)), original)
        project.objects[0].opacity = 0.5
        let translucent = pixels(render(project))
        XCTAssertLessThanOrEqual(stride(from: 3,to: translucent.count,by: 4).map { translucent[$0] }.max()!, 128)
    }
}
