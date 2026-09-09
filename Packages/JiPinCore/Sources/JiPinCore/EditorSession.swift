import Combine
import Foundation
import UIKit

@MainActor
public final class AssetLibrary: ObservableObject {
    @Published public var images: [UUID: Data] = [:]
    @Published public var pixelSizes: [UUID: CGSize] = [:]

    public init(images: [UUID: Data] = [:]) {
        self.images = images
        for (id, data) in images {
            pixelSizes[id] = ImageIOHelpers.pixelSize(of: data)
        }
    }

    public func ingest(_ photos: [ImportedPhoto]) {
        for photo in photos where !photo.loadFailed {
            images[photo.id] = photo.data
            pixelSizes[photo.id] = photo.pixelSize == .zero ? ImageIOHelpers.pixelSize(of: photo.data) : photo.pixelSize
        }
    }

    public func data(for id: UUID) -> Data? { images[id] }
}

extension AssetLibrary: AssetProviding {
    public func imageData(for id: UUID) -> Data? { images[id] }
}

public enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case adjust, filter, color, text, sticker, background, border, layer, mosaic, doodle, layout, crop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .adjust: return "调整"
        case .filter: return "滤镜"
        case .color: return "调色"
        case .text: return "文字"
        case .sticker: return "贴纸"
        case .background: return "背景"
        case .border: return "边框"
        case .layer: return "图层"
        case .mosaic: return "遮挡"
        case .doodle: return "涂鸦"
        case .layout: return "布局"
        case .crop: return "裁切"
        }
    }

    public var systemImage: String {
        switch self {
        case .adjust: return "crop.rotate"
        case .filter: return "camera.filters"
        case .color: return "slider.horizontal.3"
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .background: return "photo"
        case .border: return "rectangle.inset.filled"
        case .layer: return "square.3.layers.3d"
        case .mosaic: return "checkerboard.rectangle"
        case .doodle: return "pencil.tip"
        case .layout: return "square.grid.2x2"
        case .crop: return "crop"
        }
    }
}

@MainActor
public final class EditorSession: ObservableObject {
    @Published public var project: CollageProject
    @Published public var selectedID: UUID?
    @Published public var guides: [SnapGuide] = []
    @Published public var activeTool: EditorTool = .adjust
    @Published public var isSaving = false
    @Published public var lastError: String?
    @Published public var lowResolutionWarning = false
    @Published public var missingAssetWarning = false
    @Published public var brushMode: BrushMode = .freehand
    @Published public var brushColorHex = "#FF5A36"
    @Published public var brushWidth = 0.012
    @Published public var brushOpacity = 1.0
    @Published public var mosaicRadius = 0.05
    @Published public var livePoints: [CGPoint] = []
    @Published public var compareOriginal = false

    public let assets: AssetLibrary
    public let undo = UndoStack()
    public let store: DraftStore

    private var saveTask: Task<Void, Never>?
    private var gestureSnapshot: CollageProject?

    public init(project: CollageProject, assets: AssetLibrary, store: DraftStore = .shared) {
        self.project = project
        self.assets = assets
        self.store = store
        refreshWarnings()
    }

    public var selected: LayerObject? {
        guard let selectedID else { return nil }
        return project.object(id: selectedID)
    }

    public var canAddText: Bool { project.textCount < JiPin.maxTextObjects }
    public var canAddObject: Bool { project.objects.count < JiPin.maxObjects }
    public var isDrawingTool: Bool { activeTool == .doodle || activeTool == .mosaic }
    public var remainingPhotoSlots: Int {
        max(PhotoLimits.range(for: project.mode).upperBound - project.photoOrder.count, 0)
    }
    public var outputSizeLabel: String {
        ExportGeometry.pixelLabel(for: project, assets: assets)
    }

    public enum BrushMode: String, CaseIterable, Identifiable, Sendable {
        case freehand, line, arrow, eraser, mosaic, cover
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .freehand: return "画笔"
            case .line: return "直线"
            case .arrow: return "箭头"
            case .eraser: return "橡皮"
            case .mosaic: return "马赛克"
            case .cover: return "色块"
            }
        }
    }

    public func checkpoint() {
        undo.checkpoint(project)
    }

    public func beginGesture() {
        if gestureSnapshot == nil {
            gestureSnapshot = project
            undo.checkpoint(project)
        }
    }

    public func endGesture() {
        gestureSnapshot = nil
        guides = []
        scheduleSave()
    }

    public func selectTool(_ tool: EditorTool) {
        guard tool != activeTool else { return }
        livePoints = []
        endGesture()
        activeTool = tool
        if tool != .doodle && tool != .mosaic {
            if brushMode == .mosaic || brushMode == .cover || brushMode == .eraser {
                brushMode = .freehand
            }
        }
    }

    public func undoLast() {
        if let previous = undo.undo(current: project) {
            project = previous
            scheduleSave()
        }
    }

    public func redoLast() {
        if let next = undo.redo(current: project) {
            project = next
            scheduleSave()
        }
    }

    public func select(_ id: UUID?) {
        selectedID = id
        if let object = selected {
            switch object.kind {
            case .text: activeTool = .text
            case .sticker, .shape: activeTool = .sticker
            default: activeTool = .adjust
            }
        }
    }

    public func updateSelected(_ body: (inout LayerObject) -> Void) {
        guard let selectedID else { return }
        project.updateObject(id: selectedID, body)
        scheduleSave()
    }

    public var pansPhotoContent: Bool {
        guard let selected else { return false }
        return usesLayoutPhotoFrame(selected)
    }

    public func usesLayoutPhotoFrame(_ object: LayerObject) -> Bool {
        guard object.kind == .photo else { return false }
        switch project.mode {
        case .template, .longStrip: return true
        case .poster: return object.photo?.slotID != nil
        case .freeform: return false
        }
    }

    public func hitTest(_ point: CGPoint, canvasSize: CGSize) -> UUID? {
        let frames = photoFrames(canvasSize: canvasSize)
        let layoutIDs = Set(project.objects.filter(usesLayoutPhotoFrame).map(\.id))
        return LayoutEngine.hitTest(
            point,
            objects: project.objects,
            canvasSize: canvasSize,
            frames: frames,
            layoutDrivenIDs: layoutIDs
        )
    }

    public func selectionRect(for object: LayerObject, canvasSize: CGSize) -> CGRect {
        if usesLayoutPhotoFrame(object), let frame = photoFrames(canvasSize: canvasSize)[object.id] {
            return frame
        }
        return LayoutEngine.rotatedFrame(object.transform, canvasSize: canvasSize)
    }

    public func moveSelected(centerX: Double, centerY: Double, canvasSize: CGSize) {
        guard let selectedID, var object = project.object(id: selectedID), !object.isLocked else { return }
        object.transform.centerX = centerX
        object.transform.centerY = centerY
        if project.mode == .freeform || object.kind != .photo || project.mode == .poster && object.kind != .photo {
            let others = project.objects.filter { $0.id != selectedID }.map(\.transform)
            let snapped = LayoutEngine.snap(object.transform, canvasSize: canvasSize, others: others, enabled: project.snapEnabled)
            object.transform = snapped.0
            guides = snapped.1
        }
        project.updateObject(id: selectedID) { $0.transform = object.transform }
    }

    public func setPhotoContent(offsetX: Double? = nil, offsetY: Double? = nil, zoom: Double? = nil) {
        updateSelected { object in
            guard var crop = object.photo?.crop else { return }
            if let offsetX { crop.offsetX = min(max(offsetX, -0.45), 0.45) }
            if let offsetY { crop.offsetY = min(max(offsetY, -0.45), 0.45) }
            if let zoom { crop.zoom = min(max(zoom, 1), 4) }
            object.photo?.crop = crop
        }
    }

    public func panPhotoContent(dx: Double, dy: Double) {
        let crop = selected?.photo?.crop
        setPhotoContent(offsetX: (crop?.offsetX ?? 0) + dx, offsetY: (crop?.offsetY ?? 0) + dy)
    }

    public func scaleSelected(_ factor: CGFloat) {
        guard selected?.isLocked != true else { return }
        if pansPhotoContent {
            zoomPhotoContent(factor)
            return
        }
        updateSelected { object in
            object.transform.width *= Double(factor)
            object.transform.height *= Double(factor)
        }
    }

    public func zoomPhotoContent(_ factor: CGFloat) {
        updateSelected { object in
            guard var crop = object.photo?.crop else { return }
            crop.zoom = min(max(crop.zoom * Double(factor), 1), 4)
            object.photo?.crop = crop
        }
    }

    public func rotateSelected(degrees: Double) {
        checkpoint()
        updateSelected { $0.transform.rotation += degrees }
    }

    public func setSelectedRotation(_ degrees: Double) {
        updateSelected { $0.transform.rotation = degrees }
    }

    public func flipSelected(horizontal: Bool) {
        checkpoint()
        updateSelected { object in
            if horizontal { object.transform.scaleX *= -1 } else { object.transform.scaleY *= -1 }
        }
    }

    public func replaceSelectedPhoto(_ photo: ImportedPhoto) {
        checkpoint()
        assets.ingest([photo])
        updateSelected { object in
            guard var payload = object.photo else { return }
            if let old = project.photoOrder.firstIndex(of: payload.assetID) {
                project.photoOrder[old] = photo.id
            }
            payload.assetID = photo.id
            payload.crop = .identity
            payload.filterID = nil
            payload.filterIntensity = 1
            payload.colorAdjust = ColorAdjust()
            payload.mosaics = []
            payload.coverBlocks = []
            object.photo = payload
        }
        refreshWarnings()
    }

    public func swapPhotos(a: UUID, b: UUID) {
        checkpoint()
        guard let first = project.objects.firstIndex(where: { $0.id == a }),
              let second = project.objects.firstIndex(where: { $0.id == b }),
              let assetA = project.objects[first].photo?.assetID,
              let assetB = project.objects[second].photo?.assetID
        else { return }
        project.objects[first].photo?.assetID = assetB
        project.objects[second].photo?.assetID = assetA
        project.objects[first].photo?.crop = .identity
        project.objects[second].photo?.crop = .identity
        if let i = project.photoOrder.firstIndex(of: assetA),
           let j = project.photoOrder.firstIndex(of: assetB) {
            project.photoOrder.swapAt(i, j)
        }
        project.touch()
        scheduleSave()
    }

    public func movePhoto(forward: Bool) {
        guard let selectedID, let payload = project.object(id: selectedID)?.photo else { return }
        guard let index = project.photoOrder.firstIndex(of: payload.assetID) else { return }
        let next = forward ? index + 1 : index - 1
        guard project.photoOrder.indices.contains(next) else { return }
        checkpoint()
        project.photoOrder.swapAt(index, next)
        if project.mode == .template, let layoutID = project.layoutID, let layout = CollageGridLayoutCatalog.layout(id: layoutID) {
            ProjectFactory.applyLayout(layout, to: &project)
        } else if project.mode == .longStrip {
            let photos = project.photoOrder
            project.objects = project.objects.filter { $0.kind != .photo } + photos.enumerated().compactMap { index, assetID in
                var layer = project.photoLayers.first(where: { $0.photo?.assetID == assetID })
                layer?.zIndex = index
                layer?.photo?.slotID = "strip-\(index)"
                return layer
            }
        }
        project.touch()
        scheduleSave()
    }

    public func addPhotos(_ photos: [ImportedPhoto]) {
        let range = PhotoLimits.range(for: project.mode)
        let room = max(range.upperBound - project.photoOrder.count, 0)
        let accepted = Array(photos.prefix(room))
        if accepted.isEmpty {
            lastError = "当前模式最多 \(range.upperBound) 张照片。"
            return
        }
        if accepted.count < photos.count {
            lastError = "当前模式最多 \(range.upperBound) 张，多出的 \(photos.count - accepted.count) 张未添加。"
        }
        checkpoint()
        assets.ingest(accepted)
        project.photoOrder.append(contentsOf: accepted.map(\.id))
        ProjectFactory.syncPhotos(in: &project)
        refreshWarnings()
        scheduleSave()
    }

    public func removeSelectedPhoto() {
        guard let selected, selected.kind == .photo, let assetID = selected.photo?.assetID else { return }
        guard !selected.isLocked else { return }
        let range = PhotoLimits.range(for: project.mode)
        if project.photoOrder.count <= range.lowerBound {
            lastError = "当前模式至少需要 \(range.lowerBound) 张照片，不能再删。"
            return
        }
        checkpoint()
        if let orderIndex = project.photoOrder.firstIndex(of: assetID) {
            project.photoOrder.remove(at: orderIndex)
        }
        project.objects.removeAll { $0.id == selected.id }
        selectedID = nil
        ProjectFactory.syncPhotos(in: &project)
        refreshWarnings()
        scheduleSave()
    }

    public func addText(_ string: String = "双击编辑文字") {
        if !canAddText {
            lastError = "文字最多 \(JiPin.maxTextObjects) 个。"
            return
        }
        if !canAddObject {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        checkpoint()
        let layer = LayerObject(
            kind: .text,
            zIndex: (project.objects.map(\.zIndex).max() ?? 0) + 1,
            transform: CanvasTransform(centerX: 0.5, centerY: 0.18, width: 0.7, height: 0.12),
            text: TextPayload(text: string)
        )
        project.objects.append(layer)
        selectedID = layer.id
        activeTool = .text
        scheduleSave()
    }

    public func addSticker(_ id: String) {
        guard canAddObject else {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        checkpoint()
        let layer = LayerObject(
            kind: .sticker,
            zIndex: (project.objects.map(\.zIndex).max() ?? 0) + 1,
            transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.22, height: 0.22),
            sticker: StickerPayload(stickerID: id)
        )
        project.objects.append(layer)
        selectedID = layer.id
        scheduleSave()
    }

    public func addShape(_ id: String) {
        guard canAddObject else {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        checkpoint()
        let layer = LayerObject(
            kind: .shape,
            zIndex: (project.objects.map(\.zIndex).max() ?? 0) + 1,
            transform: CanvasTransform(width: 0.2, height: 0.2),
            shape: ShapePayload(shapeID: id)
        )
        project.objects.append(layer)
        selectedID = layer.id
        activeTool = .sticker
        scheduleSave()
    }

    public func addImageDecoration(_ photo: ImportedPhoto) {
        guard canAddObject else {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        checkpoint()
        assets.ingest([photo])
        let layer = LayerObject(
            kind: .sticker,
            zIndex: (project.objects.map(\.zIndex).max() ?? 0) + 1,
            transform: CanvasTransform(width: 0.28, height: 0.28),
            sticker: StickerPayload(stickerID: "custom-image", assetID: photo.id)
        )
        project.objects.append(layer)
        selectedID = layer.id
        scheduleSave()
    }

    public func ensureDoodleLayer() -> UUID {
        if let existing = project.objects.first(where: { $0.kind == .doodle }) {
            return existing.id
        }
        let layer = LayerObject(
            kind: .doodle,
            zIndex: 10_000,
            transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 1),
            doodle: DoodlePayload()
        )
        project.objects.append(layer)
        return layer.id
    }

    public func appendDoodle(_ stroke: DoodleStroke) {
        let id = ensureDoodleLayer()
        let count = project.objects.first(where: { $0.id == id })?.doodle?.strokes.count ?? 0
        if count >= JiPin.maxDoodleStrokes {
            lastError = "涂鸦笔画已达上限 \(JiPin.maxDoodleStrokes)，请清除部分笔画后再画。"
            return
        }
        project.updateObject(id: id) { object in
            object.doodle = object.doodle ?? DoodlePayload()
            object.doodle?.strokes.append(stroke)
        }
        scheduleSave()
    }

    public func beginDraw(at canvasPoint: CGPoint, canvasSize: CGSize) {
        checkpoint()
        livePoints = [normalized(canvasPoint, canvasSize: canvasSize)]
    }

    public func continueDraw(at canvasPoint: CGPoint, canvasSize: CGSize) {
        let point = normalized(canvasPoint, canvasSize: canvasSize)
        if brushMode == .line || brushMode == .arrow || brushMode == .cover {
            if livePoints.isEmpty {
                livePoints = [point]
            } else {
                livePoints = [livePoints[0], point]
            }
            return
        }
        if let last = livePoints.last {
            let spacing = hypot(point.x - last.x, point.y - last.y)
            if spacing < JiPin.doodleSampleSpacing { return }
        }
        livePoints.append(point)
    }

    public func endDraw(canvasSize: CGSize) {
        defer { livePoints = [] }
        guard livePoints.count >= 2 || (brushMode == .mosaic && !livePoints.isEmpty) else { return }
        if activeTool == .doodle {
            let kind: DoodleStroke.Kind
            switch brushMode {
            case .line: kind = .line
            case .arrow: kind = .arrow
            default: kind = .freehand
            }
            appendDoodle(
                DoodleStroke(
                    points: livePoints,
                    colorHex: brushColorHex,
                    lineWidth: brushWidth,
                    opacity: brushOpacity,
                    isEraser: brushMode == .eraser,
                    kind: kind
                )
            )
            return
        }
        guard let target = photoHit(from: livePoints[0], canvasSize: canvasSize) else {
            lastError = "请先点选要遮挡的照片，再在该照片上绘制。"
            return
        }
        let photoPoints = livePoints.compactMap { canvasToPhoto($0, photoID: target, canvasSize: canvasSize) }
        if brushMode == .cover, let first = photoPoints.first, let last = photoPoints.last {
            let rect = NormalizedRect(
                x: min(first.x, last.x),
                y: min(first.y, last.y),
                width: max(abs(last.x - first.x), 0.02),
                height: max(abs(last.y - first.y), 0.02)
            )
            project.updateObject(id: target) { object in
                object.photo?.coverBlocks.append(CoverBlock(rect: rect, colorHex: brushColorHex))
            }
        } else {
            project.updateObject(id: target) { object in
                object.photo?.mosaics.append(MosaicStroke(points: photoPoints, radius: mosaicRadius))
            }
        }
        selectedID = target
        scheduleSave()
    }

    public func clearDoodle() {
        checkpoint()
        if let id = project.objects.first(where: { $0.kind == .doodle })?.id {
            project.updateObject(id: id) { $0.doodle = DoodlePayload() }
        }
        scheduleSave()
    }

    public func clearSelectedPhotoMask() {
        checkpoint()
        updateSelected {
            $0.photo?.mosaics = []
            $0.photo?.coverBlocks = []
        }
    }

    public func applyPoster(_ template: PosterTemplate, keeping photos: [UUID]) {
        checkpoint()
        let retained = project.photoOrder
        ProjectFactory.applyPoster(template, photos: photos, to: &project)
        project.photoOrder = retained
        scheduleSave()
    }

    private func normalized(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x / max(canvasSize.width, 1), 0), 1),
            y: min(max(point.y / max(canvasSize.height, 1), 0), 1)
        )
    }

    private func photoFrames(canvasSize: CGSize) -> [UUID: CGRect] {
        CollageRenderer.shared.resolvedFrames(project: project, canvasSize: canvasSize, assets: assets)
    }

    private func photoHit(from normalizedPoint: CGPoint, canvasSize: CGSize) -> UUID? {
        let canvasPoint = CGPoint(x: normalizedPoint.x * canvasSize.width, y: normalizedPoint.y * canvasSize.height)
        if let selectedID, project.object(id: selectedID)?.kind == .photo,
           let frame = photoFrames(canvasSize: canvasSize)[selectedID],
           frame.insetBy(dx: -8, dy: -8).contains(canvasPoint) {
            return selectedID
        }
        let frames = photoFrames(canvasSize: canvasSize)
        return project.photoLayers.reversed().first { object in
            frames[object.id]?.contains(canvasPoint) == true
        }?.id
    }

    private func canvasToPhoto(_ normalizedPoint: CGPoint, photoID: UUID, canvasSize: CGSize) -> CGPoint? {
        guard let object = project.object(id: photoID),
              let payload = object.photo,
              let cell = photoFrames(canvasSize: canvasSize)[photoID],
              cell.width > 1, cell.height > 1
        else { return nil }
        let canvasPoint = CGPoint(x: normalizedPoint.x * canvasSize.width, y: normalizedPoint.y * canvasSize.height)
        let imageSize = assets.pixelSizes[payload.assetID]
            ?? LayoutEngine.croppedSize(CGSize(width: 1000, height: 1000), crop: .identity)
        return LayoutEngine.canvasPointToPhoto(
            canvasPoint,
            payload: payload,
            cell: cell,
            imageSize: imageSize,
            rotation: object.transform.rotation,
            scaleX: object.transform.scaleX,
            scaleY: object.transform.scaleY
        )
    }

    public func setZ(_ action: ZAction) {
        guard let selectedID, let index = project.objects.firstIndex(where: { $0.id == selectedID }) else { return }
        checkpoint()
        switch action {
        case .front: project.objects[index].zIndex = (project.objects.map(\.zIndex).max() ?? 0) + 1
        case .back: project.objects[index].zIndex = (project.objects.map(\.zIndex).min() ?? 0) - 1
        case .up: project.objects[index].zIndex += 1
        case .down: project.objects[index].zIndex -= 1
        }
        project.touch()
        scheduleSave()
    }

    public func toggleLock() {
        checkpoint()
        updateSelected { $0.isLocked.toggle() }
    }

    public func toggleVisible() {
        checkpoint()
        updateSelected { $0.isVisible.toggle() }
    }

    public func duplicateSelected() {
        guard let selected else { return }
        if !canAddObject {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        if selected.kind == .photo, let assetID = selected.photo?.assetID {
            let range = PhotoLimits.range(for: project.mode)
            if project.photoOrder.count >= range.upperBound {
                lastError = "当前模式最多 \(range.upperBound) 张照片。"
                return
            }
            checkpoint()
            project.photoOrder.append(assetID)
            ProjectFactory.syncPhotos(in: &project)
            scheduleSave()
            return
        }
        checkpoint()
        var copy = selected
        copy.id = UUID()
        copy.zIndex += 1
        copy.transform.centerX += 0.04
        copy.transform.centerY += 0.04
        copy.isLocked = false
        project.objects.append(copy)
        selectedID = copy.id
        scheduleSave()
    }

    public func deleteSelected() {
        guard selected?.isLocked != true else { return }
        if selected?.kind == .photo {
            removeSelectedPhoto()
            return
        }
        guard let selectedID else { return }
        checkpoint()
        project.objects.removeAll { $0.id == selectedID }
        self.selectedID = nil
        scheduleSave()
    }

    public func changeLayout(_ layout: CollageGridLayout) {
        checkpoint()
        ProjectFactory.applyLayout(layout, to: &project)
        scheduleSave()
    }

    public func changePoster(_ template: PosterTemplate) {
        checkpoint()
        ProjectFactory.applyPoster(template, photos: project.photoOrder, to: &project)
        scheduleSave()
    }

    public func applyFilterToAll(_ id: String?, intensity: Double) {
        checkpoint()
        for object in project.photoLayers {
            project.updateObject(id: object.id) { layer in
                layer.photo?.filterID = id
                layer.photo?.filterIntensity = intensity
            }
        }
        scheduleSave()
    }

    public func setCanvas(_ spec: CanvasSpec) {
        checkpoint()
        project.canvas = spec
        scheduleSave()
    }

    public func renameProject(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != project.name else { return }
        checkpoint()
        project.name = trimmed
        scheduleSave()
    }

    public func scheduleSave() {
        project.touch()
        isSaving = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: JiPin.autosaveDelayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            await self.persist()
        }
    }

    public func persistNow() async {
        saveTask?.cancel()
        await persist()
    }

    private func persist() async {
        do {
            try store.prepare()
            let preview = previewImage(maxSide: 512)
            let thumb = preview?.jpegData(compressionQuality: 0.8)
            try store.save(project: project, assets: assets.images, thumbnailJPEG: thumb)
            lastError = nil
            isSaving = false
        } catch {
            if isDiskFull(error) {
                lastError = DraftStoreError.diskFull.errorDescription
            } else {
                lastError = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func isDiskFull(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.code == NSFileWriteOutOfSpaceError { return true }
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC) { return true }
        if let store = error as? DraftStoreError, store == .diskFull { return true }
        return false
    }

    public func previewImage(maxSide: CGFloat) -> UIImage? {
        var project = self.project
        if compareOriginal {
            for index in project.objects.indices where project.objects[index].kind == .photo {
                project.objects[index].photo?.filterID = nil
                project.objects[index].photo?.filterIntensity = 1
                project.objects[index].photo?.colorAdjust = ColorAdjust()
            }
        }
        let size: CGSize
        if project.mode == .longStrip {
            switch ExportGeometry.outputSize(for: project, assets: assets) {
            case .ok(let value), .needsChoice(_, let value):
                let scale = maxSide / max(value.width, value.height)
                size = CGSize(width: max(value.width * scale, 1), height: max(value.height * scale, 1))
            }
        } else {
            size = project.canvas.size(fitting: maxSide)
        }
        return CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: true)
    }

    public func refreshWarnings() {
        lowResolutionWarning = assets.pixelSizes.values.contains { min($0.width, $0.height) < 700 }
        let photoMissing = project.photoOrder.contains { assets.data(for: $0) == nil }
        let stickerMissing = project.objects.contains { object in
            guard object.kind == .sticker, let payload = object.sticker else { return false }
            if let assetID = payload.assetID { return assets.data(for: assetID) == nil }
            return StickerCatalog.sticker(id: payload.stickerID) == nil
        }
        missingAssetWarning = photoMissing || stickerMissing
    }

    public enum ZAction { case up, down, front, back }
}

public final class FavoriteStore: ObservableObject {
    @Published public var templates: Set<String>
    @Published public var posters: Set<String>
    @Published public var stickers: Set<String>
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaults(suiteName: JiPin.appGroupID) ?? .standard) {
        self.defaults = defaults
        templates = Set(defaults.stringArray(forKey: "favorite.templates") ?? [])
        posters = Set(defaults.stringArray(forKey: "favorite.posters") ?? [])
        stickers = Set(defaults.stringArray(forKey: "favorite.stickers") ?? [])
    }

    public func toggleTemplate(_ id: String) {
        if templates.contains(id) { templates.remove(id) } else { templates.insert(id) }
        defaults.set(Array(templates), forKey: "favorite.templates")
    }

    public func togglePoster(_ id: String) {
        if posters.contains(id) { posters.remove(id) } else { posters.insert(id) }
        defaults.set(Array(posters), forKey: "favorite.posters")
    }

    public func toggleSticker(_ id: String) {
        if stickers.contains(id) { stickers.remove(id) } else { stickers.insert(id) }
        defaults.set(Array(stickers), forKey: "favorite.stickers")
    }
}
