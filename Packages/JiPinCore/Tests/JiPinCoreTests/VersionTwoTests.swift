import XCTest
import UIKit
@testable import JiPinCore

final class VersionTwoTests: XCTestCase {
    private func photo(_ color: UIColor = .orange, size: CGSize = CGSize(width: 80, height: 80)) -> ImportedPhoto {
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1; format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: size, format: format).image { c in
            color.setFill(); c.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill(); c.fill(CGRect(x: 0, y: size.height * 0.5, width: size.width, height: 3))
        }
        return ImportedPhoto(filename: "fixture.png", data: image.pngData()!, pixelSize: size, utType: "public.png")
    }
    private func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    func testRecommendationRespondsToPhotoAndCanvasAspect() {
        let wide = Array(repeating: CGSize(width: 160, height: 80), count: 2)
        let tall = Array(repeating: CGSize(width: 80, height: 160), count: 2)
        XCTAssertEqual(LayoutRecommender.ranked(photoSizes: wide, canvas: .square).first?.id, "g2-v")
        XCTAssertEqual(LayoutRecommender.ranked(photoSizes: tall, canvas: .square).first?.id, "g2-h")
        XCTAssertNotEqual(LayoutRecommender.ranked(photoSizes: wide, canvas: .square).first?.retainedArea,
                          LayoutRecommender.ranked(photoSizes: wide, canvas: .portrait916).first?.retainedArea)
    }

    func testRecommendationUnknownSizeIsStableAndAllCountsAreCovered() {
        for count in 2...16 {
            let input = Array(repeating: CGSize.zero, count: count)
            let first = LayoutRecommender.ranked(photoSizes: input, canvas: .square)
            XCTAssertFalse(first.isEmpty)
            XCTAssertEqual(first, LayoutRecommender.ranked(photoSizes: input, canvas: .square))
            XCTAssertTrue(first.allSatisfy { $0.retainedArea.isFinite && $0.layout.photoCount == count })
        }
    }

    func testRecommendedCreationKeepsPhotoOrder() {
        let photos = [photo(.red, size: CGSize(width: 160, height: 80)), photo(.blue, size: CGSize(width: 160, height: 80))]
        let project = ProjectFactory.make(mode: .template, photos: photos)
        XCTAssertEqual(project.layoutID, "g2-v")
        XCTAssertEqual(project.photoOrder, photos.map(\.id))
        XCTAssertEqual(project.photoLayers.map { $0.photo?.assetID }, photos.map(\.id))
    }

    func testAllDividerExtremesPreserveCompleteTiling() {
        for layout in CollageGridLayoutCatalog.all {
            XCTAssertTrue(LayoutDividerEngine.isValid(layout.cells), layout.id)
            for divider in LayoutDividerEngine.dividers(in: layout.cells) {
                for value in [-100.0, 0.42, 100] {
                    let next = LayoutDividerEngine.moving(divider, to: value, in: layout.cells)
                    XCTAssertTrue(LayoutDividerEngine.isValid(next), "\(layout.id) \(divider.id)")
                    XCTAssertEqual(next.count, layout.photoCount)
                }
            }
        }
    }

    @MainActor func testDividerUndoAndDraftRoundTrip() throws {
        let photos = [photo(.red), photo(.blue)]
        let project = ProjectFactory.make(mode: .template, photos: photos, layoutID: "g2-h")
        let store = DraftStore(overridesContainer: try root())
        let assets = AssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let session = EditorSession(project: project, assets: assets, store: store, autosaves: false)
        let divider = try XCTUnwrap(LayoutDividerEngine.dividers(in: project.resolvedGridLayout!.cells).first)
        session.beginGesture(); session.moveDivider(divider, to: 0.65); session.endGesture()
        XCTAssertEqual(session.project.customLayoutCells?.first?.width ?? 0, 0.65, accuracy: 0.0001)
        try store.save(project: session.project, assets: assets.images, thumbnailJPEG: nil)
        XCTAssertEqual(try store.load(id: project.id).project.customLayoutCells, session.project.customLayoutCells)
        session.undoLast(); XCTAssertNil(session.project.customLayoutCells)
        session.redoLast(); XCTAssertNotNil(session.project.customLayoutCells)
        session.changeLayout(CollageGridLayoutCatalog.layout(id: "g2-v")!)
        XCTAssertNil(session.project.customLayoutCells)
    }

    func testOldDraftWithoutNewFieldDecodesAndBrokenCustomLayoutFallsBack() throws {
        var project = ProjectFactory.make(mode: .template, photos: [photo(), photo()], layoutID: "g2-h")
        project.schemaVersion = 1
        let data = try JSONEncoder().encode(project)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "customLayoutCells")
        var decoded = try JSONDecoder().decode(CollageProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.customLayoutCells)
        decoded.customLayoutCells = [NormalizedRect(x: 0, y: 0, width: 1, height: 1)]
        XCTAssertEqual(decoded.resolvedGridLayout?.cells.count, 2)
    }

    func testStyleContainsNoUserAssetReferencesAndSurvivesStoreReload() throws {
        var project = ProjectFactory.make(mode: .freeform, photos: [photo()])
        project.background.kind = .image; project.background.imageAssetID = UUID()
        project.objects.append(LayerObject(kind: .text, zIndex: 10, text: TextPayload(text: "私人文字")))
        let recipe = StyleRecipe(name: "复用", project: project)
        let data = try JSONEncoder().encode(recipe)
        let string = String(decoding: data, as: UTF8.self)
        for id in project.photoOrder { XCTAssertFalse(string.contains(id.uuidString)) }
        XCTAssertFalse(string.contains("私人文字"))
        XCTAssertNil(recipe.background.imageAssetID)
        XCTAssertEqual(recipe.background.kind, .solid)
        let store = StyleRecipeStore(directory: try root())
        try store.save([recipe]); XCTAssertEqual(try store.load(), [recipe])
    }

    @MainActor func testStylePreservesLockedLayersCropsAndUndo() throws {
        let photos = [photo(.red), photo(.blue)]
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.objects[0].isLocked = true
        project.objects[1].photo?.crop.left = 0.1
        let session = EditorSession(project: project, assets: AssetLibrary(), autosaves: false)
        session.applyStyle(StyleRecipeCatalog.all[2])
        XCTAssertEqual(session.project.objects[0], project.objects[0])
        XCTAssertEqual(session.project.objects[1].photo?.crop, project.objects[1].photo?.crop)
        XCTAssertEqual(session.project.objects[1].photo?.polaroid, true)
        XCTAssertEqual(session.project.photoOrder, project.photoOrder)
        session.undoLast(); XCTAssertEqual(session.project.objects, project.objects)
        XCTAssertEqual(session.project.background, project.background)
    }

    @MainActor func testSyncEffectsSkipsLocksAndDoesNotCopyCropOrMosaic() {
        let photos = [photo(), photo(), photo()]
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.objects[0].photo?.colorAdjust.brightness = 0.2
        project.objects[0].photo?.filterID = "film"; project.objects[0].photo?.filterIntensity = 0.36
        project.objects[0].photo?.crop.top = 0.2
        project.objects[0].photo?.coverBlocks = [CoverBlock(rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5))]
        project.objects[2].isLocked = true
        let session = EditorSession(project: project, assets: AssetLibrary(), autosaves: false)
        session.syncSelectedPhotoEffects()
        XCTAssertEqual(session.project.objects[1].photo?.filterIntensity, 0.36)
        XCTAssertEqual(session.project.objects[1].photo?.colorAdjust.brightness, 0.2)
        XCTAssertEqual(session.project.objects[1].photo?.crop, .identity)
        XCTAssertEqual(session.project.objects[1].photo?.coverBlocks.count, 0)
        XCTAssertEqual(session.project.objects[2], project.objects[2])
        session.undoLast(); XCTAssertEqual(session.project.objects, project.objects)
    }

    func testDarkStyleKeepsPosterTextReadableAndRespectsTextLocks() {
        var project = CollageProject(mode: .poster)
        project.objects = [LayerObject(kind: .text, zIndex: 1, text: TextPayload(text: "标题")),
                           LayerObject(kind: .text, zIndex: 2, isLocked: true, text: TextPayload(text: "锁定文字"))]
        let originalLocked = project.objects[1]
        let styled = StyleRecipeCatalog.all.last!.applying(to: project)
        XCTAssertEqual(styled.objects[0].text?.colorHex, "#FFF6E8")
        XCTAssertEqual(styled.objects[0].text?.text, "标题")
        XCTAssertEqual(styled.objects[1], originalLocked)
    }

    func testPagesCoverEveryPixelInBothDirectionsIncludingRemainder() throws {
        for direction in [StripDirection.vertical, .horizontal] {
            let size = direction == .vertical ? CGSize(width: 101, height: 1043) : CGSize(width: 1043, height: 101)
            let plan = try PageExportPlan.make(size: size, direction: direction, length: .reading)
            XCTAssertEqual(plan.regions.count, 9)
            var end: CGFloat = 0
            for region in plan.regions {
                XCTAssertEqual(direction == .vertical ? region.minY : region.minX, end)
                end = direction == .vertical ? region.maxY : region.maxX
            }
            XCTAssertEqual(end, 1043)
        }
    }

    func testPagesRejectNonfiniteAndExcessiveInput() {
        for size in [CGSize(width: CGFloat.infinity, height: 1), CGSize(width: 0, height: 10),
                     CGSize(width: 1440, height: 1_000_000)] {
            XCTAssertThrowsError(try PageExportPlan.make(size: size, direction: .vertical, length: .reading))
        }
    }

    func testPageRenderAndReassemblyMatchesWholeImage() throws {
        let photos = [photo(.red), photo(.green), photo(.blue)]
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        for direction in [StripDirection.vertical, .horizontal] {
            var project = ProjectFactory.make(mode: .longStrip, photos: photos)
            project.longStrip?.direction = direction
            project.exportPreference.format = .png
            let size = direction == .vertical ? CGSize(width: 80, height: 240) : CGSize(width: 240, height: 80)
            let plan = try PageExportPlan.make(size: size, direction: direction, length: .reading)
            let whole = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: false)
            let format = UIGraphicsImageRendererFormat.default(); format.scale = 1; format.preferredRange = .standard
            let joined = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                for region in plan.regions { PagedExporter.renderPage(project: project, assets: assets, plan: plan, region: region).draw(in: region) }
            }
            XCTAssertEqual(pixels(whole), pixels(joined), "\(direction) page seams changed pixels")
            let batch = try PagedExporter.export(project: project, assets: assets, plan: plan, directory: root())
            XCTAssertEqual(batch.files.count, 3)
            XCTAssertEqual(batch.files.map(\.lastPathComponent), ["01-极拼.png", "02-极拼.png", "03-极拼.png"])
            for (file, region) in zip(batch.files, plan.regions) {
                let data = try Data(contentsOf: file)
                XCTAssertEqual(ImageIOHelpers.pixelSize(of: data), region.size)
                XCTAssertFalse(ImageIOHelpers.containsGPS(data))
            }
        }
    }

    func testFailedSecondPageRemovesIncompleteBatchAndPreservesOtherFiles() throws {
        let location = try root()
        let sentinel = location.appendingPathComponent("keep.txt")
        try Data([42]).write(to: sentinel)
        let project = CollageProject(mode: .longStrip)
        let plan = try PageExportPlan.make(size: CGSize(width: 80, height: 240), direction: .vertical, length: .square)
        var writes = 0
        XCTAssertThrowsError(try PagedExporter.export(project: project, assets: DataAssetLibrary(), plan: plan, directory: location) { data, file in
            writes += 1
            if writes == 2 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)) }
            try data.write(to: file)
        })
        XCTAssertEqual(writes, 2)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: location.path), ["keep.txt"])
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([42]))
    }

    func testCancelledBatchDoesNotLeaveGeneratedPages() throws {
        let location = try root()
        let plan = try PageExportPlan.make(size: CGSize(width: 80, height: 240), direction: .vertical, length: .square)
        XCTAssertThrowsError(try PagedExporter.export(project: CollageProject(mode: .longStrip), assets: DataAssetLibrary(), plan: plan, directory: location) { data, file in
            try data.write(to: file)
            throw CancellationError()
        }) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: location.path).isEmpty)
    }

    private func pixels(_ image: UIImage) -> [UInt8] {
        let cg = image.cgImage!, w = image.cgImage!.width, h = image.cgImage!.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { ptr in
            let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return bytes
    }
}
