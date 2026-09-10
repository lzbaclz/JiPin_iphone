import XCTest
import UIKit
@testable import JiPinCore

final class CanvasInteractionTests: XCTestCase {
    private func layer() -> LayerObject {
        var layer = LayerObject.photo(assetID: UUID(), slotID: "c0", zIndex: 0,
                                       transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 1))
        layer.photo?.crop.zoom = 2
        return layer
    }
    func testZoomAndRotationKeepTheSamePhotoPointUnderTheFingers() {
        let canvas = CGSize(width: 300, height: 300), frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        let image = CGSize(width: 1200, height: 1800)
        for mirrored in [false, true] {
            var before = layer(); before.transform.rotation = 28
            before.transform.scaleX = mirrored ? -1 : 1
            before.transform.scaleY = -1
            let anchor = CGPoint(x: 145, y: 128), destination = CGPoint(x: 161, y: 153)
            let operation = CanvasManipulation(object: before, canvas: canvas, cell: frame, imageSize: image, anchor: anchor)
            let after = operation.applying(centroid: destination, scale: 1.3, rotation: 21)
            let a = LayoutEngine.canvasPointToPhoto(anchor, payload: before.photo!, cell: frame, imageSize: image,
                rotation: before.transform.rotation, scaleX: before.transform.scaleX, scaleY: before.transform.scaleY)
            let b = LayoutEngine.canvasPointToPhoto(destination, payload: after.photo!, cell: frame, imageSize: image,
                rotation: after.transform.rotation, scaleX: after.transform.scaleX, scaleY: after.transform.scaleY)
            XCTAssertEqual(a.x, b.x, accuracy: 0.00001)
            XCTAssertEqual(a.y, b.y, accuracy: 0.00001)
        }
    }
    func testLargeZoomCanPanToTheActualImageEdgeWithoutExposingBackground() {
        var before = layer(); before.photo?.crop.zoom = 4
        let frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        let operation = CanvasManipulation(object: before, canvas: frame.size, cell: frame, imageSize: frame.size, anchor: CGPoint(x: 100, y: 100))
        let after = operation.applying(centroid: CGPoint(x: 900, y: -800), scale: 1, rotation: 0)
        XCTAssertEqual(after.photo!.crop.offsetX, 1.5, accuracy: 0.0001)
        XCTAssertEqual(after.photo!.crop.offsetY, -1.5, accuracy: 0.0001)
        let fitted = LayoutEngine.fittedRect(imageSize: frame.size, in: frame, mode: .fill, crop: after.photo!.crop)
        XCTAssertLessThanOrEqual(fitted.minX, 0); XCTAssertGreaterThanOrEqual(fitted.maxY, 200)
    }
    func testScaleAndRotationAreAbsoluteAndDoNotAccumulateRoundingDrift() {
        let before = layer(), frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        let operation = CanvasManipulation(object: before, canvas: frame.size, cell: frame, imageSize: frame.size, anchor: CGPoint(x: 100, y: 100))
        let end = CGPoint(x: 112, y: 123)
        let after = operation.applying(centroid: end, scale: 1.2, rotation: 30)
        let reverse = CanvasManipulation(object: after, canvas: frame.size, cell: frame, imageSize: frame.size, anchor: end)
            .applying(centroid: CGPoint(x: 100, y: 100), scale: 1 / 1.2, rotation: -30)
        XCTAssertEqual(reverse.photo!.crop.zoom, before.photo!.crop.zoom, accuracy: 0.00001)
        XCTAssertEqual(reverse.photo!.crop.offsetX, before.photo!.crop.offsetX, accuracy: 0.00001)
        XCTAssertEqual(reverse.photo!.crop.offsetY, before.photo!.crop.offsetY, accuracy: 0.00001)
        XCTAssertEqual(reverse.transform.rotation, before.transform.rotation, accuracy: 0.00001)
    }
    func testFreeformTransformsAroundTheTouchAnchor() {
        var before = layer(); before.photo?.slotID = nil
        before.transform = CanvasTransform(centerX: 0.4, centerY: 0.5, width: 0.4, height: 0.6, rotation: 10)
        let canvas = CGSize(width: 400, height: 500), anchor = CGPoint(x: 135, y: 230), destination = CGPoint(x: 170, y: 250)
        let operation = CanvasManipulation(object: before, canvas: canvas, cell: nil, imageSize: canvas, anchor: anchor)
        let after = operation.applying(centroid: destination, scale: 1.4, rotation: 15)
        let a = LayoutEngine.canvasPointToPhoto(anchor, payload: before.photo!, cell: before.transform.cgRect(in: canvas), imageSize: canvas, rotation: before.transform.rotation)
        let b = LayoutEngine.canvasPointToPhoto(destination, payload: after.photo!, cell: after.transform.cgRect(in: canvas), imageSize: canvas, rotation: after.transform.rotation)
        XCTAssertEqual(a.x, b.x, accuracy: 0.00001); XCTAssertEqual(a.y, b.y, accuracy: 0.00001)
        XCTAssertEqual(after.transform.width / after.transform.height, before.transform.width / before.transform.height, accuracy: 0.00001)
    }
    @MainActor func testOneMultitouchSessionMakesOneUndoAndFreezesRecommendations() {
        var project = CollageProject(mode: .freeform); project.objects = [layer()]; project.photoOrder = [project.objects[0].photo!.assetID]
        let session = EditorSession(project: project, assets: AssetLibrary(), autosaves: false)
        session.beginGesture()
        for n in 0..<100 {
            session.beginGesture()
            session.setSelectedRotation(Double(n))
            XCTAssertEqual(session.undo.undoCount, 0)
            XCTAssertEqual(session.recommendationProject, project)
        }
        session.endGesture(); session.endGesture()
        XCTAssertEqual(session.undo.undoCount, 1)
        session.undoLast()
        XCTAssertEqual(session.project.objects, project.objects)
        session.beginGesture(); session.endGesture()
        XCTAssertEqual(session.undo.undoCount, 0)
        session.beginGesture(); session.setSelectedRotation(55); session.cancelGesture()
        XCTAssertEqual(session.project.objects, project.objects); XCTAssertEqual(session.undo.undoCount, 0)
    }
    func testGeometryPreviewReusesDecodedAndFilteredPixels() {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1400)).image { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1000, height: 1400))
        }.jpegData(compressionQuality: 0.9)!
        var photo = layer().photo!; photo.filterID = FilterCatalog.all[1].id
        let cache = PreviewAssets(DataAssetLibrary(images: [photo.assetID: data]))
        for n in 0..<100 {
            photo.crop.zoom = 1 + Double(n) / 40
            photo.crop.offsetX = Double(n) / 300
            XCTAssertNotNil(cache.processedPhoto(photo, maxLongSide: CGFloat(300 + n), targetSize: CGSize(width: 300, height: 300)))
        }
        XCTAssertEqual(cache.decodeCount, 1)
        XCTAssertEqual(cache.effectCount, 1)
        photo.colorAdjust.brightness = 0.2
        _ = cache.processedPhoto(photo, maxLongSide: 500, targetSize: CGSize(width: 300, height: 300))
        XCTAssertEqual(cache.decodeCount, 1); XCTAssertEqual(cache.effectCount, 2)
    }

    @MainActor func testNoOpGestureResumesThePreviouslyPendingAutosave() async throws {
        let root = try MediaFileLease.temporary(prefix: "Gesture-Save-Test")
        let store = DraftStore(overridesContainer: root.directory)
        let session = EditorSession(project: CollageProject(mode: .freeform), assets: AssetLibrary(), store: store)
        session.updateProject { $0.name = "尚在等待自动保存的修改" }
        session.beginGesture(); session.endGesture()
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(try store.load(id: session.project.id).project.name, session.project.name)
        XCTAssertFalse(session.isGestureActive)
    }
    func testPreviewCacheReattachesSourcesForTheNextFrame() async throws {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 240)).image { c in
            UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 180, height: 240))
        }.pngData()!
        let photo = ImportedPhoto(filename: "red", data: data, pixelSize: CGSize(width: 180, height: 240), utType: "public.png")
        let project = ProjectFactory.make(mode: .freeform, photos: [photo])
        let assets = DataAssetLibrary(images: [photo.id: data])
        let request = PreviewRequest(project: project, displaySize: CGSize(width: 240, height: 240), displayScale: 1)
        let renderer = PreviewRendering()
        let first = await renderer.render(request, assets: assets)
        let second = await renderer.render(request, assets: assets)
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.pngData(), second?.pngData(), "释放原始输入引用后，下一帧仍应有相同的照片内容")
    }

    func testFourLargePhotosPreviewBenchmark() {
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1; format.opaque = true
        let size = CGSize(width: 2400, height: 3200)
        let photos = (0..<4).map { index -> ImportedPhoto in
            let data = UIGraphicsImageRenderer(size: size, format: format).image { c in
                UIColor(red: CGFloat(index) / 5, green: 0.4, blue: 0.7, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: size))
                for n in 0..<40 {
                    UIColor.white.withAlphaComponent(0.6).setFill()
                    c.fill(CGRect(x: n * 60, y: n * 70, width: 30, height: 900))
                }
            }.jpegData(compressionQuality: 0.92)!
            return ImportedPhoto(filename: "benchmark", data: data, pixelSize: size, utType: "public.jpeg")
        }
        let library = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let cached = PreviewAssets(library)
        let project = ProjectFactory.make(mode: .template, photos: photos, layoutID: "g4-grid")
        func render(_ assets: AssetProviding, frames: Int) -> Double {
            let start = CACurrentMediaTime()
            for n in 0..<frames { autoreleasepool {
                var edited = project; edited.objects[0].photo?.crop.zoom = 1.2 + Double(n) * 0.02
                edited.objects[0].transform.rotation = Double(n)
                _ = CollageRenderer.shared.render(project: edited, assets: assets, canvasSize: CGSize(width: 600, height: 600), preview: true)
            } }
            return (CACurrentMediaTime() - start) * 1000 / Double(frames)
        }
        _ = render(cached, frames: 1)
        let uncachedMS = render(library, frames: 30), cachedMS = render(cached, frames: 30)
        print(String(format: "GESTURE_BENCHMARK uncached=%.2fms cached=%.2fms speedup=%.2fx", uncachedMS, cachedMS, uncachedMS / max(cachedMS, 0.001)))
        XCTAssertEqual(cached.decodeCount, 4, "30 次拖动/缩放/旋转预览不能反复解码四张原图")
    }
}
