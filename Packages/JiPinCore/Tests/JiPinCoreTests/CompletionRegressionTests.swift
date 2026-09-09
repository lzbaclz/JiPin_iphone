import XCTest
import UIKit
import UniformTypeIdentifiers
@testable import JiPinCore

final class CompletionRegressionTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func photo(_ color: UIColor = .orange) -> ImportedPhoto {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }
        let data = image.pngData()!
        return ImportedPhoto(filename: "fixture.png", data: data, pixelSize: image.size, utType: UTType.png.identifier)
    }

    func testFailedReplacementPreservesPreviousDraftAndThumbnail() throws {
        let root = try directory()
        let store = DraftStore(overridesContainer: root)
        let image = photo()
        var project = ProjectFactory.make(mode: .freeform, photos: [image])
        project.name = "原来的草稿"
        let assets = [image.id: image.data]
        try store.save(project: project, assets: assets, thumbnailJPEG: Data([1, 2, 3]))
        let failing = DraftStore(overridesContainer: root, commit: { _, _ in
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        })
        project.name = "尚未保存的修改"
        XCTAssertThrowsError(try failing.save(project: project, assets: assets, thumbnailJPEG: Data([4]))) {
            XCTAssertEqual($0 as? DraftStoreError, .diskFull)
        }
        XCTAssertEqual(try store.load(id: project.id).project.name, "原来的草稿")
        XCTAssertEqual(store.thumbnailData(id: project.id), Data([1, 2, 3]))
        XCTAssertEqual(store.listDrafts().count, 1)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: store.draftsRoot.path).contains { $0.hasSuffix(".tmp") })
        try store.save(project: project, assets: assets, thumbnailJPEG: Data([4]))
        XCTAssertEqual(try store.load(id: project.id).project.name, project.name)
    }

    func testIndependentStoresSerializeCommitsAndKeepAllReferencedAssets() throws {
        let root = try directory()
        let fixtures = (0..<16).map { _ in photo() }
        let errors = FailureBox()
        DispatchQueue.concurrentPerform(iterations: fixtures.count) { index in
            let store = DraftStore(overridesContainer: root)
            let image = fixtures[index]
            let project = ProjectFactory.make(mode: .freeform, photos: [image])
            do { try store.save(project: project, assets: [image.id: image.data], thumbnailJPEG: nil) }
            catch { errors.append(error) }
        }
        XCTAssertEqual(errors.count, 0)
        let store = DraftStore(overridesContainer: root)
        XCTAssertEqual(store.listDrafts().count, fixtures.count)
        XCTAssertEqual(store.sharedAssetFileCount(), fixtures.count)
        for draft in store.listDrafts() {
            XCTAssertEqual(try store.load(id: draft.id).assets.count, 1)
        }
    }

    func testMissingOrConflictingAssetsDoNotReplaceSavedDraft() throws {
        let root = try directory()
        let store = DraftStore(overridesContainer: root)
        let image = photo()
        let project = ProjectFactory.make(mode: .freeform, photos: [image])
        try store.save(project: project, assets: [image.id: image.data], thumbnailJPEG: nil)
        let persisted = try store.load(id: project.id).project
        var broken = project
        broken.photoOrder = [UUID()]
        broken.objects[0].photo?.assetID = broken.photoOrder[0]
        XCTAssertThrowsError(try store.save(project: broken, assets: [:], thumbnailJPEG: nil))
        XCTAssertThrowsError(try store.save(project: project, assets: [image.id: photo(.blue).data], thumbnailJPEG: nil))
        let loaded = try store.load(id: project.id)
        XCTAssertEqual(loaded.project, persisted)
        XCTAssertEqual(loaded.assets[image.id], image.data)
    }

    func testStoreWorkingCopiesAreExcludedFromBackup() throws {
        let store = DraftStore(overridesContainer: try directory())
        try store.prepare()
        for folder in [store.draftsRoot, store.sharedAssetsRoot, store.cacheRoot] {
            XCTAssertEqual(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        }
    }

    func testTransparentPNGImportRetainsAlphaAndPNGFormat() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 12, y: 12, width: 24, height: 24))
        }
        let sanitized = try XCTUnwrap(ImageIOHelpers.sanitizedImageData(from: image.pngData()!))
        XCTAssertEqual(ImageIOHelpers.typeIdentifier(of: sanitized), UTType.png.identifier)
        let decoded = try XCTUnwrap(ImageIOHelpers.fullImage(from: sanitized))
        XCTAssertTrue(ImageIOHelpers.hasAlpha(decoded))
        XCTAssertEqual(rgba(decoded, x: 0, y: 0).3, 0)
        XCTAssertEqual(rgba(decoded, x: 24, y: 24).3, 255)
        let extensionResult = ExtensionIngest.process([(filename: "透明贴纸.png", data: sanitized)])
        XCTAssertEqual(extensionResult.photos.first?.utType, UTType.png.identifier)
        XCTAssertEqual(rgba(try XCTUnwrap(extensionResult.photos.first.flatMap { ImageIOHelpers.fullImage(from: $0.data) }), x: 0, y: 0).3, 0)
    }

    func testUIImageImportBakesOrientation() throws {
        let source = try XCTUnwrap(UIImage(data: photo().data)?.cgImage)
        let rotated = UIImage(cgImage: source, scale: 1, orientation: .right)
        let data = try XCTUnwrap(ImageIOHelpers.sanitizedImageData(from: rotated))
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: data), CGSize(width: 60, height: 80))
        XCTAssertFalse(ImageIOHelpers.containsGPS(data))
    }

    func testImportHonorsDecodePixelLimit() throws {
        let data = try XCTUnwrap(ImageIOHelpers.sanitizedImageData(from: photo().data, maxLongSide: 40, maxPixelCount: 600))
        let size = ImageIOHelpers.pixelSize(of: data)
        XCTAssertLessThanOrEqual(size.width * size.height, 600)
        XCTAssertLessThanOrEqual(max(size.width, size.height), 40)
    }

    func testPreviewRendererUsesResolvedDisplaySizeAndRetinaScale() async throws {
        let image = photo()
        let project = ProjectFactory.make(mode: .freeform, photos: [image])
        let initial = PreviewRequest(project: project, displaySize: CGSize(width: 10, height: 10), displayScale: 3)
        let fitted = PreviewRequest(project: project, displaySize: CGSize(width: 300, height: 400), displayScale: 3)
        XCTAssertNotEqual(initial, fitted)
        let rendered = await PreviewRendering.shared.render(fitted, assets: DataAssetLibrary(images: [image.id: image.data]))
        XCTAssertEqual(rendered?.size, CGSize(width: 900, height: 1200))
        XCTAssertNotEqual(fitted, PreviewRequest(project: project, displaySize: CGSize(width: 300, height: 400), displayScale: 3, zoom: 2))
    }

    func testLongStripPreviewAndExportUseProportionalSpacing() throws {
        let photos = [photo(), photo(.blue)]
        var project = ProjectFactory.make(mode: .longStrip, photos: photos)
        project.spacing = 0.08
        project.outerMargin = 0.1
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        guard case .ok(let full) = ExportGeometry.outputSize(for: project, assets: assets) else { return XCTFail("unexpected limit") }
        let reduced = CGSize(width: full.width / 4, height: full.height / 4)
        let largeFrames = CollageRenderer.shared.resolvedFrames(project: project, canvasSize: full, assets: assets)
        let smallFrames = CollageRenderer.shared.resolvedFrames(project: project, canvasSize: reduced, assets: assets)
        for id in largeFrames.keys {
            XCTAssertEqual(try XCTUnwrap(largeFrames[id]).minY / 4, try XCTUnwrap(smallFrames[id]).minY, accuracy: 0.01)
        }
        let quick = ExportGeometry.extensionOutputSize(for: project, assets: assets)
        XCTAssertEqual(max(quick.width, quick.height), 2048, accuracy: 1)
    }

    @MainActor
    func testMovingOneLayerCrossesNeighbourEvenWithSparseDepths() {
        var project = CollageProject(mode: .freeform)
        project.objects = [0, 100, 200].map { LayerObject(kind: .text, zIndex: $0, text: TextPayload(text: "\($0)")) }
        let first = project.objects[0].id
        let second = project.objects[1].id
        let session = EditorSession(project: project, assets: AssetLibrary(), autosaves: false)
        session.select(first)
        session.setZ(.up)
        XCTAssertEqual(session.project.visibleObjects.map(\.id), [second, first, project.objects[2].id])
        session.undoLast()
        XCTAssertEqual(session.project.objects, project.objects)
    }

    @MainActor
    func testDuplicatePhotoPreservesEditsAndReplacingSecondOccurrenceKeepsFirst() {
        let source = photo()
        let session = EditorSession(project: ProjectFactory.make(mode: .freeform, photos: [source]), assets: AssetLibrary(images: [source.id: source.data]), autosaves: false)
        session.select(session.project.photoLayers[0].id)
        session.updateSelected { $0.photo?.filterID = "mono"; $0.photo?.crop.top = 0.2 }
        session.duplicateSelected()
        XCTAssertEqual(session.project.photoLayers.count, 2)
        XCTAssertEqual(session.selected?.photo?.filterID, "mono")
        XCTAssertEqual(session.selected?.photo?.crop.top, 0.2)
        let replacement = photo(.blue)
        session.replaceSelectedPhoto(replacement)
        XCTAssertEqual(session.project.photoOrder, [source.id, replacement.id])
        XCTAssertEqual(session.project.photoLayers.map { $0.photo!.assetID }, [source.id, replacement.id])
        session.undoLast()
        XCTAssertEqual(session.project.photoOrder, [source.id, source.id])
    }

    @MainActor
    func testTextEditsUndoAndTextDuplicationEnforcesLimit() {
        let session = EditorSession(project: CollageProject(mode: .freeform), assets: AssetLibrary(), autosaves: false)
        session.addText("原文")
        session.updateSelected { $0.text?.text = "新文字" }
        session.undoLast()
        XCTAssertEqual(session.selected?.text?.text, "原文")
        for _ in 1..<20 { session.addText("更多文字") }
        session.duplicateSelected()
        XCTAssertEqual(session.project.textCount, 20)
        XCTAssertNotNil(session.lastError)
    }

    @MainActor
    func testLockedLayerCannotBeEditedButCanBeUnlocked() {
        let session = EditorSession(project: CollageProject(mode: .freeform), assets: AssetLibrary(), autosaves: false)
        session.addText("锁定文字")
        session.toggleLock()
        session.rotateSelected(degrees: 90)
        session.updateSelected { $0.text?.text = "不应写入" }
        XCTAssertEqual(session.selected?.text?.text, "锁定文字")
        XCTAssertEqual(session.selected?.transform.rotation, 0)
        session.toggleLock()
        XCTAssertFalse(session.selected!.isLocked)
    }

    func testModeCopyKeepsImageReferencesAndAllCommonDecorations() {
        let images = [photo(), photo(.blue), photo(.green)]
        var source = ProjectFactory.make(mode: .freeform, photos: images)
        source.objects[0].photo?.filterID = "mono"
        source.objects.append(LayerObject(kind: .text, zIndex: 100, text: TextPayload(text: "保留的标题")))
        source.objects.append(LayerObject(kind: .shape, zIndex: 101, shape: ShapePayload(shapeID: "heart")))
        source.objects.append(LayerObject(kind: .doodle, zIndex: 102, doodle: DoodlePayload()))
        for target in [CollageMode.template, .poster, .longStrip] {
            let copy = ProjectFactory.copy(project: source, to: target, photos: images)
            XCTAssertNotEqual(copy.id, source.id)
            XCTAssertEqual(copy.photoOrder, source.photoOrder)
            XCTAssertEqual(copy.photoLayers.first?.photo?.filterID, "mono")
            XCTAssertTrue(copy.objects.contains { $0.text?.text == "保留的标题" })
            XCTAssertTrue(copy.objects.contains { $0.kind == .shape })
            XCTAssertTrue(copy.objects.contains { $0.kind == .doodle })
        }
    }

    @MainActor
    func testQuickEditingDoesNotAutosaveAndExplicitSaveDoes() async throws {
        let store = DraftStore(overridesContainer: try directory())
        let image = photo()
        let session = EditorSession(project: ProjectFactory.make(mode: .freeform, photos: [image]), assets: AssetLibrary(images: [image.id: image.data]), store: store, autosaves: false)
        session.updateProject { $0.name = "快速编辑" }
        try await Task.sleep(nanoseconds: 650_000_000)
        XCTAssertTrue(store.listDrafts().isEmpty)
        let saved = await session.persistNow()
        XCTAssertTrue(saved)
        XCTAssertEqual(store.listDrafts().count, 1)
    }

    func testShareFilesAreUniqueAndEmptyPayloadCannotReuseAnOldFile() throws {
        let root = try directory()
        let first = try ExportFile.write(data: Data([1, 2]), format: .jpeg, directory: root)
        let second = try ExportFile.write(data: Data([3, 4]), format: .jpeg, directory: root)
        XCTAssertNotEqual(first, second)
        XCTAssertThrowsError(try ExportFile.write(data: Data(), format: .jpeg, directory: root))
        XCTAssertEqual(try Data(contentsOf: first), Data([1, 2]))
    }

    func testCoverBlocksUseTopOriginAndStayOpaqueAfterFlipping() throws {
        let image = photo(.white)
        var project = ProjectFactory.make(mode: .freeform, photos: [image])
        project.objects[0].transform = CanvasTransform(width: 1, height: 1)
        project.objects[0].photo?.coverBlocks = [CoverBlock(rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2), colorHex: "#00000000")]
        let assets = DataAssetLibrary(images: [image.id: image.data])
        let size = CGSize(width: 100, height: 100)
        let normal = try XCTUnwrap(CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: false).cgImage)
        XCTAssertLessThan(rgba(normal, x: 20, y: 20).0, 20)
        XCTAssertGreaterThan(rgba(normal, x: 20, y: 80).0, 240)
        project.objects[0].transform.scaleY = -1
        let flipped = try XCTUnwrap(CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: false).cgImage)
        XCTAssertGreaterThan(rgba(flipped, x: 20, y: 20).0, 240)
        XCTAssertLessThan(rgba(flipped, x: 20, y: 80).0, 20)
    }

    func testRotatingTemplatePhotoDoesNotPaintOverAdjacentCell() throws {
        let photos = [photo(.red), photo(.blue)]
        let layout = try XCTUnwrap(CollageGridLayoutCatalog.all.first { $0.photoCount == 2 && $0.cells[0].width == 0.5 && $0.cells[0].height == 1 })
        var project = ProjectFactory.make(mode: .template, photos: photos, layoutID: layout.id)
        project.spacing = 0
        project.outerMargin = 0
        project.objects[0].transform.rotation = 45
        project.objects[0].zIndex = 200
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let result = try XCTUnwrap(CollageRenderer.shared.render(project: project, assets: assets, canvasSize: CGSize(width: 100, height: 100), preview: false).cgImage)
        let neighbour = rgba(result, x: 55, y: 50)
        XCTAssertLessThan(neighbour.0, 30)
        XCTAssertGreaterThan(neighbour.2, 220)
    }

    func testTextureDoesNotChangeBetweenIdenticalRenders() {
        var project = CollageProject(mode: .freeform)
        project.background = BackgroundCatalog.preset(id: "tex-paper")!.spec
        let assets = DataAssetLibrary(images: [:])
        let first = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: CGSize(width: 240, height: 240), preview: true)
        let second = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: CGSize(width: 240, height: 240), preview: true)
        XCTAssertEqual(first.pngData(), second.pngData())
    }

    @MainActor
    func testDuplicatingPosterPhotoDoesNotCreateAnInvisiblePhoto() {
        let photos = [photo(), photo(.blue), photo(.green)]
        let session = EditorSession(project: ProjectFactory.make(mode: .poster, photos: photos),
                                    assets: AssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })), autosaves: false)
        session.select(session.project.photoLayers[0].id)
        session.duplicateSelected()
        XCTAssertEqual(session.project.photoOrder.count, 4)
        XCTAssertEqual(session.project.photoLayers.count, 4)
        XCTAssertEqual(Set(session.project.photoLayers.map(\.id)).count, 4)
        XCTAssertNil(session.project.photoLayers.last?.photo?.slotID)
    }

    func testQueuedOldSnapshotCannotOverwriteNewerSavedVersion() async throws {
        let store = DraftStore(overridesContainer: try directory())
        let image = photo()
        let older = ProjectFactory.make(mode: .freeform, photos: [image])
        var newer = older
        newer.name = "新的修改"
        newer.updatedAt = older.updatedAt.addingTimeInterval(20)
        let assets = DataAssetLibrary(images: [image.id: image.data])
        try await DraftWriting.shared.save(project: newer, assets: assets, store: store)
        try await DraftWriting.shared.save(project: older, assets: assets, store: store)
        XCTAssertEqual(try store.load(id: older.id).project.name, "新的修改")
    }

    private func rgba(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { storage in
            let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let offset = (y * image.width + x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}

private final class FailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [Error] = []
    func append(_ error: Error) { lock.lock(); defer { lock.unlock() }; failures.append(error) }
    var count: Int { lock.lock(); defer { lock.unlock() }; return failures.count }
}
