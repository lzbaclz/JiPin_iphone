import XCTest
import JiPinCore

final class CatalogTests: XCTestCase {
    func testGridLayoutsCoverTwoToSixteenAndAtLeastThirty() {
        XCTAssertGreaterThanOrEqual(CollageGridLayoutCatalog.all.count, 30)
        XCTAssertEqual(CollageGridLayoutCatalog.coveredCounts, Set(2...16))
        for count in 2...16 {
            XCTAssertFalse(CollageGridLayoutCatalog.layouts(forPhotoCount: count).isEmpty, "missing layout for \(count)")
            for layout in CollageGridLayoutCatalog.layouts(forPhotoCount: count) {
                XCTAssertEqual(layout.cells.count, count)
            }
        }
        for count in 2...16 {
            XCTAssertGreaterThanOrEqual(
                CollageGridLayoutCatalog.layouts(forPhotoCount: count).count,
                2,
                "count \(count) should offer more than one layout"
            )
        }
    }

    func testPosterCountAndThemes() {
        XCTAssertEqual(PosterTemplateCatalog.all.count, 20)
        XCTAssertEqual(Set(PosterTemplateCatalog.all.map(\.id)).count, 20)
        for theme in PosterTheme.allCases {
            XCTAssertFalse(PosterTemplateCatalog.templates(theme: theme).isEmpty, theme.title)
        }
        for poster in PosterTemplateCatalog.all {
            XCTAssertFalse(poster.photoSlots.isEmpty)
            XCTAssertFalse(poster.texts.isEmpty)
            XCTAssertFalse(poster.supportedCanvases.isEmpty)
        }
    }

    func testAssetCatalogCounts() {
        XCTAssertEqual(StickerCatalog.all.count, 60)
        XCTAssertEqual(BackgroundCatalog.all.count, 20)
        XCTAssertEqual(FilterCatalog.all.count, 10)
        XCTAssertEqual(Set(StickerCatalog.all.map(\.id)).count, 60)
        XCTAssertEqual(GeometryShapeCatalog.all.count, 10)
        XCTAssertTrue(GeometryShapeCatalog.all.contains(where: { $0.id == "arrow" }))
    }

    func testPhotoLimits() {
        XCTAssertEqual(PhotoLimits.validate(0, mode: .template), .needPhotos(minimum: 2))
        XCTAssertEqual(PhotoLimits.validate(1, mode: .template), .tooFew(minimum: 2))
        XCTAssertEqual(PhotoLimits.validate(16, mode: .template), .ok)
        XCTAssertEqual(PhotoLimits.validate(17, mode: .template), .tooMany(maximum: 16))
        XCTAssertEqual(PhotoLimits.validate(1, mode: .freeform), .ok)
        XCTAssertEqual(PhotoLimits.validate(2, mode: .template), .ok)
        XCTAssertEqual(PhotoLimits.validate(2, mode: .longStrip), .ok)
        XCTAssertEqual(PhotoLimits.validate(9, mode: .template), .ok)
        XCTAssertEqual(PhotoLimits.validate(9, mode: .poster), .ok)
        XCTAssertEqual(PhotoLimits.validate(9, mode: .freeform), .ok)
        XCTAssertEqual(PhotoLimits.validate(1, mode: .poster), .ok)
        XCTAssertEqual(PhotoLimits.validate(20, mode: .longStrip), .ok)
        XCTAssertEqual(PhotoLimits.validate(21, mode: nil), .tooMany(maximum: 20))
        XCTAssertEqual(PhotoLimits.modes(forPhotoCount: 1), [.freeform, .poster])
        XCTAssertTrue(PhotoLimits.modes(forPhotoCount: 0).isEmpty)
        XCTAssertEqual(PhotoLimits.modes(forPhotoCount: 17), [.longStrip])
        XCTAssertEqual(PhotoLimits.modes(forPhotoCount: 20), [.longStrip])
        XCTAssertTrue(PhotoLimits.modes(forPhotoCount: 21).isEmpty)
        XCTAssertEqual(PhotoLimits.validate(0, mode: nil), .needPhotos(minimum: 1))
        XCTAssertTrue(ExtensionIngest.isLikelyImage(typeIdentifiers: ["public.jpeg"]))
        XCTAssertTrue(ExtensionIngest.isLikelyImage(typeIdentifiers: ["public.heic"]))
        XCTAssertTrue(ExtensionIngest.isLikelyImage(typeIdentifiers: ["public.file-url"]))
        XCTAssertFalse(ExtensionIngest.isLikelyImage(typeIdentifiers: ["com.adobe.pdf"]))
        XCTAssertTrue(PhotoLimits.modes(forPhotoCount: 2).contains(.template))
        XCTAssertTrue(PhotoLimits.modes(forPhotoCount: 2).contains(.longStrip))
        XCTAssertEqual(DraftStoreError.diskFull.errorDescription, "存储空间不足，这次没有写入。已有草稿仍保留。")
    }

    func testSeamlessSpacingLeavesNoGapOnTwoByTwo() {
        let layout = CollageGridLayoutCatalog.layout(id: "g4-grid")!
        let frames = LayoutEngine.frames(
            layout: layout,
            canvasSize: CGSize(width: 1000, height: 1000),
            spacing: 0,
            margin: 0
        )
        XCTAssertEqual(frames.count, 4)
        XCTAssertLessThanOrEqual(frames[1].minX, frames[0].maxX)
        XCTAssertLessThanOrEqual(frames[2].minY, frames[0].maxY)
        XCTAssertLessThan(frames[1].minX - frames[0].maxX, 0.01)
        XCTAssertLessThan(frames[2].minY - frames[0].maxY, 0.01)
    }

    func testCanvasPointToPhotoAccountsForPanAndZoom() {
        var payload = PhotoPayload(assetID: UUID())
        payload.contentMode = .fit
        payload.crop.offsetX = 0.2
        payload.crop.zoom = 2
        let cell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let imageSize = CGSize(width: 200, height: 100)
        let fitted = LayoutEngine.fittedRect(imageSize: imageSize, in: cell, mode: .fit, crop: payload.crop)
        let mapped = LayoutEngine.canvasPointToPhoto(CGPoint(x: fitted.midX, y: fitted.midY), payload: payload, cell: cell, imageSize: imageSize)
        XCTAssertEqual(mapped.x, 0.5, accuracy: 0.02)
        XCTAssertEqual(mapped.y, 0.5, accuracy: 0.02)
        let left = LayoutEngine.canvasPointToPhoto(CGPoint(x: 50, y: 50), payload: payload, cell: cell, imageSize: imageSize)
        XCTAssertLessThan(left.x, 0.5)
    }

    func testCanvasPointToPhotoUsesOriginalCoordinatesAfterInsetCrop() {
        var payload = PhotoPayload(assetID: UUID())
        payload.crop = PhotoCrop(left: 0.25, right: 0.25)
        let cell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let imageSize = CGSize(width: 100, height: 100)
        let center = LayoutEngine.canvasPointToPhoto(
            CGPoint(x: 50, y: 50),
            payload: payload,
            cell: cell,
            imageSize: imageSize
        )
        XCTAssertEqual(center.x, 0.5, accuracy: 0.03)
        XCTAssertEqual(center.y, 0.5, accuracy: 0.03)
        let leftEdge = LayoutEngine.canvasPointToPhoto(
            CGPoint(x: 1, y: 50),
            payload: payload,
            cell: cell,
            imageSize: imageSize
        )
        XCTAssertEqual(leftEdge.x, 0.25, accuracy: 0.04)
        let crop = PhotoCrop(top: 0.1, bottom: 0.1, left: 0.2, right: 0.2)
        let original = CGPoint(x: 0.5, y: 0.4)
        let cropped = LayoutEngine.croppedPointFromPhoto(original, crop: crop)
        XCTAssertEqual(cropped.x, (0.5 - 0.2) / 0.6, accuracy: 0.001)
        XCTAssertEqual(cropped.y, (0.4 - 0.1) / 0.8, accuracy: 0.001)
        let roundTrip = LayoutEngine.photoPointFromCropped(cropped, crop: crop)
        XCTAssertEqual(roundTrip.x, original.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, original.y, accuracy: 0.001)
        let outside = LayoutEngine.unclampedCroppedPointFromPhoto(CGPoint(x: 0.1, y: 0.5), crop: PhotoCrop(left: 0.4))
        XCTAssertLessThan(outside.x, 0)
    }

    @MainActor
    func testSwitchingToolsDiscardsUnconfirmedDoodleStroke() {
        let photos = (0..<2).map { index in
            ImportedPhoto(
                filename: "p\(index).png",
                data: Data(),
                pixelSize: CGSize(width: 100, height: 100),
                utType: "public.png"
            )
        }
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: photos),
            assets: AssetLibrary()
        )
        session.activeTool = .doodle
        session.beginDraw(at: CGPoint(x: 10, y: 10), canvasSize: CGSize(width: 100, height: 100))
        session.continueDraw(at: CGPoint(x: 40, y: 40), canvasSize: CGSize(width: 100, height: 100))
        XCTAssertFalse(session.livePoints.isEmpty)
        session.selectTool(.text)
        XCTAssertTrue(session.livePoints.isEmpty)
        XCTAssertEqual(session.activeTool, .text)
        XCTAssertTrue(session.project.objects.allSatisfy { $0.doodle?.strokes.isEmpty ?? true })
    }

    func testCanvasPointToPhotoInvertsRotationAndFlip() {
        let payload = PhotoPayload(assetID: UUID())
        let cell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let imageSize = CGSize(width: 100, height: 100)
        let rotated = LayoutEngine.canvasPointToPhoto(
            CGPoint(x: 25, y: 25),
            payload: payload,
            cell: cell,
            imageSize: imageSize,
            rotation: 180
        )
        XCTAssertEqual(rotated.x, 0.75, accuracy: 0.02)
        XCTAssertEqual(rotated.y, 0.75, accuracy: 0.02)
        let flipped = LayoutEngine.canvasPointToPhoto(
            CGPoint(x: 25, y: 25),
            payload: payload,
            cell: cell,
            imageSize: imageSize,
            scaleX: -1
        )
        XCTAssertEqual(flipped.x, 0.75, accuracy: 0.02)
        XCTAssertEqual(flipped.y, 0.25, accuracy: 0.02)
    }

    func testUndoLimit() {
        let stack = UndoStack(limit: 50)
        var project = ProjectFactory.make(mode: .freeform, photos: [])
        for i in 0..<60 {
            project.name = "v\(i)"
            stack.checkpoint(project)
        }
        XCTAssertEqual(stack.undoCount, 50)
        XCTAssertTrue(stack.canUndo)
    }

    func testExportClamp() {
        let huge = CGSize(width: 20000, height: 20000)
        if case .needsChoice(let computed, let scaled) = ExportGeometry.clamp(huge) {
            XCTAssertEqual(computed, huge)
            XCTAssertLessThanOrEqual(max(scaled.width, scaled.height), JiPin.Export.maxLongSide)
            XCTAssertLessThanOrEqual(scaled.width * scaled.height, JiPin.Export.maxPixelCount)
        } else {
            XCTFail("expected needsChoice")
        }
        if case .ok(let size) = ExportGeometry.clamp(CGSize(width: 1080, height: 1920)) {
            XCTAssertEqual(size, CGSize(width: 1080, height: 1920))
        } else {
            XCTFail("expected ok")
        }
    }

    @MainActor
    func testRenameProjectUpdatesNameAndUndo() {
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: dummyPhotos(2)),
            assets: AssetLibrary()
        )
        let original = session.project.name
        session.renameProject("旅行拼图")
        XCTAssertEqual(session.project.name, "旅行拼图")
        session.undoLast()
        XCTAssertEqual(session.project.name, original)
        session.renameProject("   ")
        XCTAssertEqual(session.project.name, original)
    }

    @MainActor
    func testSwapPhotosExchangesAssetsAndOrder() {
        let photos = dummyPhotos(3)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: photos),
            assets: AssetLibrary()
        )
        let first = session.project.photoLayers[0]
        let second = session.project.photoLayers[1]
        let assetA = first.photo!.assetID
        let assetB = second.photo!.assetID
        session.swapPhotos(a: first.id, b: second.id)
        XCTAssertEqual(session.project.object(id: first.id)?.photo?.assetID, assetB)
        XCTAssertEqual(session.project.object(id: second.id)?.photo?.assetID, assetA)
        XCTAssertEqual(session.project.photoOrder[0], assetB)
        XCTAssertEqual(session.project.photoOrder[1], assetA)
    }

    func testModeCopyKeepsOriginalIdentitySeparate() {
        let original = ProjectFactory.make(
            mode: .template,
            photos: (0..<4).map { ImportedPhoto(filename: "\($0).jpg", data: Data(), pixelSize: CGSize(width: 100, height: 100), utType: "public.jpeg") }
        )
        let copy = ProjectFactory.copy(project: original, to: .freeform, photos: [])
        XCTAssertNotEqual(original.id, copy.id)
        XCTAssertEqual(original.mode, .template)
        XCTAssertEqual(copy.mode, .freeform)
    }

    func testPosterApplyUsesOnlyExplicitPhotos() {
        let photos = (0..<4).map {
            ImportedPhoto(filename: "\($0).jpg", data: Data(), pixelSize: CGSize(width: 100, height: 100), utType: "public.jpeg")
        }
        var project = ProjectFactory.make(mode: .poster, photos: photos)
        guard let oneSlot = PosterTemplateCatalog.all.first(where: { $0.photoCount == 1 }) else {
            return XCTFail("missing 1-photo poster")
        }
        ProjectFactory.applyPoster(oneSlot, photos: [photos[2].id], to: &project)
        XCTAssertEqual(project.photoLayers.count, 1)
        XCTAssertEqual(project.photoLayers.first?.photo?.assetID, photos[2].id)
        XCTAssertEqual(oneSlot.texts.count, project.objects.filter { $0.kind == .text }.count)
    }

    @MainActor
    func testDoodleStrokeCap() {
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: []),
            assets: AssetLibrary()
        )
        for _ in 0..<JiPin.maxDoodleStrokes {
            session.appendDoodle(DoodleStroke(points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.2, y: 0.2)]))
        }
        session.appendDoodle(DoodleStroke(points: [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.4, y: 0.4)]))
        XCTAssertEqual(session.project.objects.first { $0.kind == .doodle }?.doodle?.strokes.count, JiPin.maxDoodleStrokes)
        XCTAssertNotNil(session.lastError)
    }

    @MainActor
    func testAddAndRemovePhotosRematchTemplateLayouts() {
        let photos = dummyPhotos(4)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: photos),
            assets: AssetLibrary()
        )
        XCTAssertEqual(session.project.photoOrder.count, 4)
        XCTAssertEqual(CollageGridLayoutCatalog.layout(id: session.project.layoutID ?? "")?.photoCount, 4)

        session.addPhotos(dummyPhotos(1))
        XCTAssertEqual(session.project.photoOrder.count, 5)
        XCTAssertEqual(session.project.photoLayers.count, 5)
        XCTAssertEqual(CollageGridLayoutCatalog.layout(id: session.project.layoutID ?? "")?.photoCount, 5)

        session.selectedID = session.project.photoLayers.last?.id
        session.removeSelectedPhoto()
        XCTAssertEqual(session.project.photoOrder.count, 4)
        XCTAssertEqual(session.project.photoLayers.count, 4)
        XCTAssertEqual(CollageGridLayoutCatalog.layout(id: session.project.layoutID ?? "")?.photoCount, 4)
    }

    @MainActor
    func testCannotRemoveBelowModeMinimumOrExceedMaximum() {
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: dummyPhotos(2)),
            assets: AssetLibrary()
        )
        session.selectedID = session.project.photoLayers.first?.id
        session.removeSelectedPhoto()
        XCTAssertEqual(session.project.photoOrder.count, 2)
        XCTAssertNotNil(session.lastError)

        let extras = dummyPhotos(20)
        session.lastError = nil
        session.addPhotos(extras)
        XCTAssertEqual(session.project.photoOrder.count, 16)
        XCTAssertNotNil(session.lastError)
    }

    func testPosterKeepsExtraPhotosInOrder() {
        let photos = dummyPhotos(4)
        var project = ProjectFactory.make(mode: .poster, photos: photos)
        guard let oneSlot = PosterTemplateCatalog.all.first(where: { $0.photoCount == 1 }) else {
            return XCTFail("missing 1-photo poster")
        }
        let retained = project.photoOrder
        ProjectFactory.applyPoster(oneSlot, photos: [photos[2].id], to: &project)
        project.photoOrder = retained
        XCTAssertEqual(project.photoLayers.count, 1)
        XCTAssertEqual(project.photoOrder.count, 4)
        XCTAssertEqual(project.photoLayers.first?.photo?.assetID, photos[2].id)
    }

    func testDraftFromExtensionIsListed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DraftStore(overridesContainer: root)
        try store.prepare()
        var project = ProjectFactory.make(mode: .template, photos: dummyPhotos(2), originatedFromExtension: true)
        project.name = "相册快拼"
        try store.save(project: project, assets: Dictionary(uniqueKeysWithValues: project.photoOrder.map { ($0, Data([1])) }), thumbnailJPEG: nil)
        let listed = store.listDrafts()
        XCTAssertEqual(listed.first?.originatedFromExtension, true)
        XCTAssertTrue(store.isUsingAppGroup)
    }

    func testModeCopyWarnsInsteadOfSilentTruncate() {
        let photos = dummyPhotos(12)
        let original = ProjectFactory.make(mode: .freeform, photos: photos)
        let preview = ProjectFactory.previewCopy(from: original, to: .poster)
        XCTAssertTrue(preview.warnings.contains(where: { $0.contains("最多") }))
        let chosen = Array(photos.prefix(3))
        let copy = ProjectFactory.copy(project: original, to: .poster, photos: chosen)
        XCTAssertEqual(copy.photoOrder.count, 3)
        XCTAssertEqual(original.photoOrder.count, 12)
        XCTAssertNotEqual(original.id, copy.id)
    }

    @MainActor
    func testReplacePhotoResetsOnlyThatPhotoEffects() {
        let photos = dummyPhotos(2)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: photos),
            assets: AssetLibrary()
        )
        session.selectedID = session.project.photoLayers[0].id
        session.updateSelected {
            $0.photo?.filterID = "mono"
            $0.photo?.coverBlocks = [CoverBlock(rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), colorHex: "#000000")]
        }
        let otherID = session.project.photoLayers[1].id
        session.project.updateObject(id: otherID) { $0.photo?.filterID = "warm" }
        let replacement = dummyPhotos(1)[0]
        session.replaceSelectedPhoto(replacement)
        XCTAssertNil(session.project.photoLayers[0].photo?.filterID)
        XCTAssertTrue(session.project.photoLayers[0].photo?.coverBlocks.isEmpty ?? false)
        XCTAssertEqual(session.project.object(id: otherID)?.photo?.filterID, "warm")
    }

    @MainActor
    func testCompareOriginalDoesNotPersistFilterRemoval() {
        let photos = dummyPhotos(2)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: photos),
            assets: AssetLibrary()
        )
        session.selectedID = session.project.photoLayers[0].id
        session.updateSelected { $0.photo?.filterID = "mono" }
        session.compareOriginal = true
        XCTAssertEqual(session.project.photoLayers[0].photo?.filterID, "mono")
        session.compareOriginal = false
        XCTAssertEqual(session.project.photoLayers[0].photo?.filterID, "mono")
    }

    @MainActor
    func testApplyFilterToAllSkipsTextAndStickers() {
        let photos = dummyPhotos(2)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: photos),
            assets: AssetLibrary()
        )
        session.addText("标题")
        session.addSticker(StickerCatalog.all[0].id)
        session.applyFilterToAll("mono", intensity: 0.6)
        XCTAssertTrue(session.project.photoLayers.allSatisfy { $0.photo?.filterID == "mono" && $0.photo?.filterIntensity == 0.6 })
        XCTAssertNil(session.project.objects.first { $0.kind == .text }?.photo)
        XCTAssertNil(session.project.objects.first { $0.kind == .sticker }?.photo?.filterID)
    }

    @MainActor
    func testTextAndObjectCapsSurfaceErrors() {
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: dummyPhotos(1)),
            assets: AssetLibrary()
        )
        for _ in 0..<JiPin.maxTextObjects {
            session.addText("标题")
        }
        session.lastError = nil
        session.addText("超出")
        XCTAssertEqual(session.project.textCount, JiPin.maxTextObjects)
        XCTAssertNotNil(session.lastError)
    }

    @MainActor
    func testObjectCapSurfacesErrorOnStickerAndDuplicate() {
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: dummyPhotos(1)),
            assets: AssetLibrary()
        )
        let stickerID = StickerCatalog.all[0].id
        while session.project.objects.count < JiPin.maxObjects {
            session.addSticker(stickerID)
        }
        XCTAssertEqual(session.project.objects.count, JiPin.maxObjects)
        session.lastError = nil
        session.addSticker(stickerID)
        XCTAssertEqual(session.project.objects.count, JiPin.maxObjects)
        XCTAssertNotNil(session.lastError)
        session.lastError = nil
        session.selectedID = session.project.objects.last?.id
        session.duplicateSelected()
        XCTAssertEqual(session.project.objects.count, JiPin.maxObjects)
        XCTAssertNotNil(session.lastError)
    }

    func testExportJobLockAllowsOnlyOneAtATime() {
        XCTAssertTrue(ExportJobLock.tryBegin())
        XCTAssertFalse(ExportJobLock.tryBegin())
        ExportJobLock.end()
        XCTAssertTrue(ExportJobLock.tryBegin())
        ExportJobLock.end()
    }

    @MainActor
    func testFiftyUndoRedoCommandsStayWithinLimit() {
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: dummyPhotos(1)),
            assets: AssetLibrary()
        )
        session.selectedID = session.project.photoLayers.first?.id
        for i in 0..<50 {
            session.beginGesture()
            session.updateSelected { $0.opacity = 0.2 + Double(i % 5) * 0.1 }
            session.endGesture()
        }
        XCTAssertEqual(session.undo.undoCount, 50)
        for _ in 0..<50 {
            session.undoLast()
        }
        XCTAssertFalse(session.undo.canUndo)
        XCTAssertTrue(session.undo.canRedo)
        for _ in 0..<50 {
            session.redoLast()
        }
        XCTAssertTrue(session.undo.canUndo)
        XCTAssertFalse(session.undo.canRedo)
    }

    func testSnapAlignsToCanvasAndObjectEdges() {
        let canvas = CGSize(width: 1000, height: 1000)
        let nearLeft = CanvasTransform(centerX: 0.204, centerY: 0.5, width: 0.4, height: 0.2)
        let snappedLeft = LayoutEngine.snap(nearLeft, canvasSize: canvas, others: [], enabled: true)
        XCTAssertEqual(snappedLeft.0.centerX, 0.2, accuracy: 0.002)
        XCTAssertTrue(snappedLeft.1.contains(where: { $0.axis == .vertical && abs($0.position) < 0.001 }))

        let nearCenter = CanvasTransform(centerX: 0.504, centerY: 0.5, width: 0.2, height: 0.2)
        let snappedCenter = LayoutEngine.snap(nearCenter, canvasSize: canvas, others: [], enabled: true)
        XCTAssertEqual(snappedCenter.0.centerX, 0.5, accuracy: 0.002)

        let other = CanvasTransform(centerX: 0.3, centerY: 0.5, width: 0.2, height: 0.2)
        let neighbor = CanvasTransform(centerX: 0.503, centerY: 0.5, width: 0.2, height: 0.2)
        let snappedEdge = LayoutEngine.snap(neighbor, canvasSize: canvas, others: [other], enabled: true)
        XCTAssertEqual(snappedEdge.0.centerX, 0.5, accuracy: 0.002)

        let ignored = LayoutEngine.snap(nearLeft, canvasSize: canvas, others: [], enabled: false)
        XCTAssertEqual(ignored.0.centerX, 0.204, accuracy: 0.0001)
        XCTAssertTrue(ignored.1.isEmpty)
    }

    func testFavoriteStoreRemembersPosters() {
        let suite = "com.jipin.test.favorites.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = FavoriteStore(defaults: defaults)
        store.togglePoster("travel-1")
        XCTAssertTrue(store.posters.contains("travel-1"))
        store.togglePoster("travel-1")
        XCTAssertFalse(store.posters.contains("travel-1"))
    }

    func testHitTestUsesActualRotatedBounds() {
        let object = LayerObject(
            kind: .text,
            zIndex: 1,
            transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.4, height: 0.1, rotation: 90),
            text: TextPayload(text: "标题")
        )
        let canvas = CGSize(width: 100, height: 100)
        XCTAssertEqual(
            LayoutEngine.hitTest(CGPoint(x: 50, y: 30), objects: [object], canvasSize: canvas),
            object.id
        )
        XCTAssertNil(LayoutEngine.hitTest(CGPoint(x: 30, y: 50), objects: [object], canvasSize: canvas))
    }

    @MainActor
    func testTemplatePhotoPanUpdatesCropNotLayerTransform() {
        let photos = dummyPhotos(2)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .template, photos: photos),
            assets: AssetLibrary()
        )
        session.selectedID = session.project.photoLayers.first?.id
        XCTAssertTrue(session.pansPhotoContent)
        let transform = session.selected!.transform
        session.panPhotoContent(dx: 0.2, dy: -0.1)
        XCTAssertEqual(session.selected?.transform.centerX ?? 0, transform.centerX, accuracy: 0.0001)
        XCTAssertEqual(session.selected?.transform.centerY ?? 0, transform.centerY, accuracy: 0.0001)
        XCTAssertEqual(session.selected?.photo?.crop.offsetX ?? 0, 0.2, accuracy: 0.0001)
        XCTAssertEqual(session.selected?.photo?.crop.offsetY ?? 0, -0.1, accuracy: 0.0001)
        session.zoomPhotoContent(2)
        XCTAssertEqual(session.selected?.photo?.crop.zoom ?? 0, 2, accuracy: 0.0001)
        session.scaleSelected(1.5)
        XCTAssertEqual(session.selected?.photo?.crop.zoom ?? 0, 3, accuracy: 0.0001)
        XCTAssertEqual(session.selected?.transform.width ?? 0, transform.width, accuracy: 0.0001)
    }

    @MainActor
    func testEditorOpensOnLayoutToolWithFirstPhotoSelected() {
        for mode in CollageMode.allCases {
            let count = PhotoLimits.range(for: mode).lowerBound
            let session = EditorSession(
                project: ProjectFactory.make(mode: mode, photos: dummyPhotos(count)),
                assets: AssetLibrary()
            )
            XCTAssertEqual(session.activeTool, .layout, mode.rawValue)
            XCTAssertEqual(session.selectedID, session.project.photoLayers.first?.id, mode.rawValue)
        }
    }

    @MainActor
    func testSelectingObjectSwitchesToolButKeepsPhotoEditors() {
        let photos = dummyPhotos(2)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .freeform, photos: photos),
            assets: AssetLibrary()
        )
        session.addText("标题")
        let textID = session.project.objects.first(where: { $0.kind == .text })?.id
        let photoID = session.project.photoLayers[0].id
        session.selectTool(.filter)
        session.select(photoID)
        XCTAssertEqual(session.activeTool, .filter)
        session.select(textID)
        XCTAssertEqual(session.activeTool, .text)
        session.select(photoID)
        XCTAssertEqual(session.activeTool, .adjust)
        session.addSticker(StickerCatalog.all[0].id)
        session.select(session.project.objects.first(where: { $0.kind == .sticker })?.id)
        XCTAssertEqual(session.activeTool, .sticker)
    }

    @MainActor
    func testLongStripHitTestUsesResolvedFrames() {
        let photos = dummyPhotos(2)
        let session = EditorSession(
            project: ProjectFactory.make(mode: .longStrip, photos: photos),
            assets: AssetLibrary()
        )
        let canvas = CGSize(width: 100, height: 200)
        let top = session.project.photoLayers[0]
        let bottom = session.project.photoLayers[1]
        XCTAssertEqual(session.hitTest(CGPoint(x: 50, y: 40), canvasSize: canvas), top.id)
        XCTAssertEqual(session.hitTest(CGPoint(x: 50, y: 150), canvasSize: canvas), bottom.id)
    }

    private func dummyPhotos(_ count: Int) -> [ImportedPhoto] {
        (0..<count).map {
            ImportedPhoto(
                filename: "\($0).jpg",
                data: Data(),
                pixelSize: CGSize(width: 100, height: 100),
                utType: "public.jpeg"
            )
        }
    }
}
