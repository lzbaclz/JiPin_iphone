import Combine
import Foundation
import UIKit

@MainActor
public final class AssetLibrary: ObservableObject {
    @Published public var images: [UUID: Data] = [:] {
        didSet { revision &+= 1 }
    }
    @Published public private(set) var revision: UInt64 = 0
    @Published public var pixelSizes: [UUID: CGSize] = [:]
    @Published public var motions: [UUID: LivePhotoClip] = [:] {
        didSet { revision &+= 1 }
    }

    public init(images: [UUID: Data] = [:], motions: [UUID: LivePhotoClip] = [:]) {
        self.images = images
        self.motions = motions
        for (id, data) in images {
            pixelSizes[id] = ImageIOHelpers.pixelSize(of: data)
        }
    }

    public convenience init(photos: [ImportedPhoto]) {
        self.init()
        ingest(photos)
    }

    public func ingest(_ photos: [ImportedPhoto]) {
        for photo in photos where !photo.loadFailed {
            images[photo.id] = photo.data
            pixelSizes[photo.id] = photo.pixelSize == .zero ? ImageIOHelpers.pixelSize(of: photo.data) : photo.pixelSize
            if var clip = photo.liveClip { clip.source.id = photo.id; motions[photo.id] = clip }
        }
    }

    public func data(for id: UUID) -> Data? { images[id] }
    public var snapshot: DataAssetLibrary { DataAssetLibrary(images: images, motions: motions) }
}

public enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case adjust, filter, color, text, sticker, background, border, layer, mosaic, doodle, layout, crop, style, livePhoto

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
        case .style: return "风格"
        case .livePhoto: return "Live"
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
        case .style: return "sparkles.rectangle.stack"
        case .livePhoto: return "livephoto"
        }
    }
}

@MainActor
public final class EditorSession: ObservableObject {
    @Published public var project: CollageProject
    @Published public var selectedID: UUID?
    @Published public var guides: [SnapGuide] = []
    @Published public var activeTool: EditorTool = .layout
    @Published public var isSaving = false
    @Published public var lastError: String?
    @Published public var lowResolutionWarning = false
    @Published public var missingAssetWarning = false
    @Published public var missingLiveAssetWarning = false
    @Published public var brushMode: BrushMode = .freehand
    @Published public var brushColorHex = "#FF5A36"
    @Published public var brushWidth = 0.012
    @Published public var brushOpacity = 1.0
    @Published public var mosaicRadius = 0.05
    @Published public var livePoints: [CGPoint] = []
    @Published public var compareOriginal = false
    @Published public var wantsTextFocus = false
    @Published public var wantsLivePreview = false

    public let assets: AssetLibrary
    public let undo = UndoStack()
    public let store: DraftStore

    private var saveTask: Task<Void, Never>?
    private var gestureSnapshot: CollageProject?
    private var checkpointPending = false
    private var checkpointProject: CollageProject?
    public let autosaves: Bool

    public init(project: CollageProject, assets: AssetLibrary, store: DraftStore = .shared, autosaves: Bool = true) {
        self.project = project
        self.assets = assets
        self.store = store
        self.autosaves = autosaves
        self.activeTool = Self.defaultTool(for: project.mode)
        self.selectedID = project.photoLayers.first?.id
        syncLiveSources()
        refreshWarnings()
    }

    public static func defaultTool(for mode: CollageMode) -> EditorTool {
        switch mode {
        case .template, .poster, .longStrip, .freeform:
            return .layout
        }
    }

    public var selected: LayerObject? {
        guard let selectedID else { return nil }
        return project.object(id: selectedID)
    }

    public var canAddText: Bool { project.textCount < JiPin.maxTextObjects }
    public var canAddObject: Bool { project.objects.count < JiPin.maxObjects }
    public var isDrawingTool: Bool { activeTool == .doodle || activeTool == .mosaic }
    public var remainingPhotoSlots: Int {
        max(min(PhotoLimits.range(for: project.mode).upperBound - project.photoOrder.count, JiPin.maxObjects - project.objects.count), 0)
    }
    public var outputSizeLabel: String {
        ExportGeometry.pixelLabel(for: project, assets: assets.snapshot)
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
        guard gestureSnapshot == nil else { return }
        if checkpointPending && checkpointProject == project { return }
        undo.checkpoint(project)
        checkpointPending = true
        checkpointProject = project
    }

    public func beginGesture() {
        if gestureSnapshot == nil {
            checkpointPending = false
            checkpoint()
            gestureSnapshot = project
        }
    }

    public func endGesture() {
        let hadGesture = gestureSnapshot != nil
        gestureSnapshot = nil
        guides = []
        if hadGesture { scheduleSave() }
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
        checkpointPending = false
        gestureSnapshot = nil
        if let previous = undo.undo(current: project) {
            project = previous
            scheduleSave()
        }
    }

    public func redoLast() {
        checkpointPending = false
        gestureSnapshot = nil
        if let next = undo.redo(current: project) {
            project = next
            scheduleSave()
        }
    }

    public func select(_ id: UUID?) {
        selectedID = id
        guard let object = selected else { return }
        switch object.kind {
        case .text:
            activeTool = .text
        case .sticker, .shape:
            activeTool = .sticker
        case .doodle:
            activeTool = .doodle
        case .photo:
            let photoTools: Set<EditorTool> = [.adjust, .crop, .filter, .color, .border, .mosaic, .layout]
            if !photoTools.contains(activeTool) {
                activeTool = .adjust
            }
        }
    }

    public func updateSelected(allowLocked: Bool = false, _ body: (inout LayerObject) -> Void) {
        guard let selectedID, var object = project.object(id: selectedID), allowLocked || !object.isLocked else { return }
        let before = object
        body(&object)
        guard object != before else { return }
        if !checkpointPending { checkpoint() }
        project.updateObject(id: selectedID) { $0 = object }
        scheduleSave()
    }

    public func updateProject(_ body: (inout CollageProject) -> Void) {
        var next = project
        body(&next)
        guard next != project else { return }
        if !checkpointPending { checkpoint() }
        project = next
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

    public func photoPanTranslation(_ delta: CGSize, canvasSize: CGSize) -> CGSize {
        guard let selected, let payload = selected.photo,
              let cell = photoFrames(canvasSize: canvasSize)[selected.id] else { return .zero }
        let frame = LayoutEngine.photoDrawFrame(payload, cell: cell)
        let angle = selected.transform.rotation * .pi / 180
        let c: Double = cos(angle)
        let s: Double = sin(angle)
        let x = CGFloat(c) * delta.width + CGFloat(s) * delta.height
        let y = -CGFloat(s) * delta.width + CGFloat(c) * delta.height
        return CGSize(width: x * (selected.transform.scaleX < 0 ? -1 : 1) / max(frame.width, 1),
                      height: y / max(frame.height, 1))
    }

    public func scaleSelected(_ factor: CGFloat) {
        guard selected?.isLocked != true else { return }
        if pansPhotoContent {
            zoomPhotoContent(factor)
            return
        }
        updateSelected { object in
            object.transform.width = min(max(object.transform.width * Double(factor), 0.02), 4)
            object.transform.height = min(max(object.transform.height * Double(factor), 0.02), 4)
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
        guard selected != nil, selected?.isLocked != true else { return }
        checkpoint()
        updateSelected { $0.transform.rotation += degrees }
    }

    public func setSelectedRotation(_ degrees: Double) {
        updateSelected { $0.transform.rotation = degrees }
    }

    public func flipSelected(horizontal: Bool) {
        guard selected != nil, selected?.isLocked != true else { return }
        checkpoint()
        updateSelected { object in
            if horizontal { object.transform.scaleX *= -1 } else { object.transform.scaleY *= -1 }
        }
    }

    public func replaceSelectedPhoto(_ photo: ImportedPhoto) {
        guard let selected, !selected.isLocked, selected.kind == .photo,
              let orderIndex = project.photoLayers.firstIndex(where: { $0.id == selected.id }) else { return }
        let remaining = Set(project.photoLayers.filter { $0.id != selected.id }.compactMap { $0.photo?.assetID })
        let liveIDs = Set(project.resolvedLiveSources.map(\.id)).intersection(remaining)
        if photo.liveClip != nil && !liveIDs.contains(photo.id) && liveIDs.count >= LivePhotoPolicy.maxSources {
            lastError = LivePhotoError.tooManySources.localizedDescription
            return
        }
        checkpoint()
        assets.ingest([photo])
        project.photoOrder[orderIndex] = photo.id
        updateSelected { object in
            guard var payload = object.photo else { return }
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
        guard let first = project.objects.firstIndex(where: { $0.id == a }),
              let second = project.objects.firstIndex(where: { $0.id == b }),
              first != second, !project.objects[first].isLocked, !project.objects[second].isLocked,
              var payloadA = project.objects[first].photo,
              var payloadB = project.objects[second].photo,
              let orderA = project.photoLayers.firstIndex(where: { $0.id == a }),
              let orderB = project.photoLayers.firstIndex(where: { $0.id == b })
        else { return }
        checkpoint()
        let slotA = payloadA.slotID
        payloadA.slotID = payloadB.slotID
        payloadB.slotID = slotA
        project.objects[first].photo = payloadB
        project.objects[second].photo = payloadA
        project.photoOrder.swapAt(orderA, orderB)
        project.touch()
        scheduleSave()
    }

    public func movePhoto(forward: Bool) {
        guard let selectedID, selected?.isLocked != true,
              let index = project.photoLayers.firstIndex(where: { $0.id == selectedID }) else { return }
        let next = forward ? index + 1 : index - 1
        guard project.photoOrder.indices.contains(next) else { return }
        checkpoint()
        project.photoOrder.swapAt(index, next)
        ProjectFactory.syncPhotos(in: &project)
        project.touch()
        scheduleSave()
    }

    public func addPhotos(_ photos: [ImportedPhoto]) {
        let range = PhotoLimits.range(for: project.mode)
        let room = max(min(range.upperBound - project.photoOrder.count, JiPin.maxObjects - project.objects.count), 0)
        let accepted = Array(photos.prefix(room))
        if accepted.isEmpty {
            lastError = "当前模式最多 \(range.upperBound) 张照片。"
            return
        }
        if accepted.count < photos.count {
            lastError = "当前模式最多 \(range.upperBound) 张，多出的 \(photos.count - accepted.count) 张未添加。"
        }
        let liveIDs = Set(project.resolvedLiveSources.map(\.id)).union(accepted.filter { $0.liveClip != nil }.map(\.id))
        guard liveIDs.count <= LivePhotoPolicy.maxSources else {
            lastError = LivePhotoError.tooManySources.localizedDescription
            return
        }
        checkpoint()
        assets.ingest(accepted)
        project.photoOrder.append(contentsOf: accepted.map(\.id))
        ProjectFactory.syncPhotos(in: &project)
        if project.mode == .freeform {
            let canvasRatio = project.canvas.ratio
            for photo in accepted {
                if let id = project.photoLayers.first(where: { $0.photo?.assetID == photo.id })?.id {
                    let ratio = max(photo.pixelSize.width, 1) / max(photo.pixelSize.height, 1)
                    project.updateObject(id: id) {
                        $0.transform.height = $0.transform.width * canvasRatio / ratio
                    }
                }
            }
        }
        refreshWarnings()
        scheduleSave()
    }

    public func removeSelectedPhoto() {
        guard let selected, selected.kind == .photo,
              let orderIndex = project.photoLayers.firstIndex(where: { $0.id == selected.id }) else { return }
        guard !selected.isLocked else { return }
        let range = PhotoLimits.range(for: project.mode)
        if project.photoOrder.count <= range.lowerBound {
            lastError = "当前模式至少需要 \(range.lowerBound) 张照片，不能再删。"
            return
        }
        checkpoint()
        project.photoOrder.remove(at: orderIndex)
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
        wantsTextFocus = true
        scheduleSave()
    }

    public func addSticker(_ id: String) {
        guard canAddObject else {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        checkpoint()
        project.schemaVersion = JiPin.schemaVersion
        let canvas = project.mode == .longStrip
            ? Self.previewCanvasSize(project: project, assets: assets.snapshot) : project.canvas.size(maxLongSide: 1000)
        let unit = min(canvas.width, canvas.height)
        let layer = LayerObject(
            kind: .sticker,
            zIndex: (project.objects.map(\.zIndex).max() ?? 0) + 1,
            transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.25 * unit / canvas.width, height: 0.25 * unit / canvas.height),
            sticker: StickerPayload(stickerID: id)
        )
        project.objects.append(layer)
        selectedID = layer.id
        scheduleSave()
    }

    private static func previewCanvasSize(project: CollageProject, assets: AssetProviding) -> CGSize {
        switch ExportGeometry.outputSize(for: project, assets: assets) {
        case .ok(let size), .needsChoice(_, let size): return size
        }
    }

    public func setDecorationFrame(_ frame: DecorationFrame?) {
        updateProject { project in
            project.decorationFrame = frame.map { CanvasDecoration(frameID: $0.id, width: project.decorationFrame?.width ?? 0.065) }
            if project.schemaVersion != JiPin.schemaVersion { project.schemaVersion = JiPin.schemaVersion }
        }
        refreshWarnings()
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
        let ratio = max(photo.pixelSize.width, 1) / max(photo.pixelSize.height, 1)
        let width = min(0.28, 0.7 * ratio / project.canvas.ratio)
        let height = width * project.canvas.ratio / ratio
        let layer = LayerObject(
            kind: .sticker,
            zIndex: (project.objects.map(\.zIndex).max() ?? 0) + 1,
            transform: CanvasTransform(width: width, height: height),
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
        if let ink = project.objects.first(where: { $0.kind == .doodle }), ink.isLocked {
            lastError = "涂鸦图层已锁定，请先在图层面板解锁。"
            return
        }
        guard project.objects.contains(where: { $0.kind == .doodle }) || canAddObject else {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
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
        if livePoints.count >= 2048 {
            livePoints = stride(from: 0, to: livePoints.count, by: 2).map { livePoints[$0] }
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
            guard (project.object(id: target)?.photo?.coverBlocks.count ?? 0) < JiPin.maxDoodleStrokes else {
                lastError = "这张照片的遮挡已达上限，请清除部分遮挡后继续。"; return
            }
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
            guard (project.object(id: target)?.photo?.mosaics.count ?? 0) < JiPin.maxDoodleStrokes else {
                lastError = "这张照片的马赛克笔画已达上限，请清除后继续。"; return
            }
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
        guard photos.count == template.photoCount else {
            lastError = "这个海报需要 \(template.photoCount) 张照片，请先完成照片选择。"
            return
        }
        checkpoint()
        ProjectFactory.applyPoster(template, photos: photos, to: &project)
        project.photoOrder = photos
        refreshWarnings()
        scheduleSave()
    }

    public func applyPoster(_ template: PosterTemplate, importing photos: [ImportedPhoto]) {
        guard photos.count == template.photoCount else { lastError = "照片数量与海报不匹配。"; return }
        checkpoint()
        assets.ingest(photos)
        ProjectFactory.applyPoster(template, photos: photos.map(\.id), to: &project)
        project.photoOrder = photos.map(\.id)
        selectedID = project.photoLayers.first?.id
        refreshWarnings()
        scheduleSave()
    }

    private func normalized(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x / max(canvasSize.width, 1), 0), 1),
            y: min(max(point.y / max(canvasSize.height, 1), 0), 1)
        )
    }

    private func photoFrames(canvasSize: CGSize) -> [UUID: CGRect] {
        CollageRenderer.shared.resolvedFrames(project: project, canvasSize: canvasSize, assets: assets.snapshot)
    }

    private func photoHit(from normalizedPoint: CGPoint, canvasSize: CGSize) -> UUID? {
        let canvasPoint = CGPoint(x: normalizedPoint.x * canvasSize.width, y: normalizedPoint.y * canvasSize.height)
        let photos = project.photoLayers.filter { !$0.isLocked && $0.isVisible }
        return LayoutEngine.hitTest(canvasPoint, objects: photos, canvasSize: canvasSize,
                                    frames: photoFrames(canvasSize: canvasSize),
                                    layoutDrivenIDs: Set(photos.filter(usesLayoutPhotoFrame).map(\.id)))
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
        guard let selectedID, selected?.isLocked != true else { return }
        var ordered = project.objects.sorted { $0.zIndex < $1.zIndex }
        guard let index = ordered.firstIndex(where: { $0.id == selectedID }) else { return }
        let destination: Int
        switch action {
        case .front: destination = ordered.count - 1
        case .back: destination = 0
        case .up: destination = min(index + 1, ordered.count - 1)
        case .down: destination = max(index - 1, 0)
        }
        guard destination != index else { return }
        checkpoint()
        ordered.insert(ordered.remove(at: index), at: destination)
        for i in ordered.indices { ordered[i].zIndex = i }
        project.objects = ordered
        project.touch()
        scheduleSave()
    }

    public func toggleLock() {
        guard selected != nil else { return }
        checkpoint()
        updateSelected(allowLocked: true) { $0.isLocked.toggle() }
    }

    public func toggleVisible() {
        guard selected != nil else { return }
        checkpoint()
        updateSelected(allowLocked: true) { $0.isVisible.toggle() }
    }

    public func duplicateSelected() {
        guard let selected else { return }
        if !canAddObject {
            lastError = "画布最多 \(JiPin.maxObjects) 个对象。"
            return
        }
        if selected.kind == .text && !canAddText {
            lastError = "文字最多 \(JiPin.maxTextObjects) 个。"
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
            var copy = selected
            copy.id = UUID()
            copy.isLocked = false
            copy.zIndex = (project.objects.map(\.zIndex).max() ?? 0) + 1
            copy.transform.centerX += 0.04
            copy.transform.centerY += 0.04
            project.objects.append(copy)
            if project.mode != .freeform { ProjectFactory.syncPhotos(in: &project) }
            selectedID = copy.id
            scheduleSave()
            return
        }
        checkpoint()
        var copy = selected
        copy.id = UUID()
        copy.zIndex = (project.objects.map(\.zIndex).max() ?? 0) + 1
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
        guard project.mode == .template, layout.photoCount == project.photoLayers.count else { return }
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
        for object in project.photoLayers where !object.isLocked {
            project.updateObject(id: object.id) { layer in
                layer.photo?.filterID = id
                layer.photo?.filterIntensity = intensity
            }
        }
        scheduleSave()
    }

    public func applyStyle(_ recipe: StyleRecipe) {
        updateProject { $0 = recipe.applying(to: $0) }
    }

    public func syncSelectedPhotoEffects() {
        guard let photo = selected?.photo else { return }
        let style = PhotoStyle(photo: photo)
        updateProject { project in
            for i in project.objects.indices where project.objects[i].kind == .photo && !project.objects[i].isLocked {
                if var target = project.objects[i].photo {
                    style.apply(to: &target, effectsOnly: true)
                    project.objects[i].photo = target
                }
            }
        }
    }

    public func moveDivider(_ divider: LayoutDivider, to position: Double) {
        guard project.mode == .template, let cells = project.resolvedGridLayout?.cells else { return }
        let moved = LayoutDividerEngine.moving(divider, to: position, in: cells)
        guard cells != moved else { return }
        updateProject { $0.customLayoutCells = moved; $0.schemaVersion = JiPin.schemaVersion }
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
        if gestureSnapshot == nil { checkpointPending = false }
        syncLiveSources()
        project.touch()
        guard autosaves else { return }
        isSaving = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: JiPin.autosaveDelayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            await self.persist()
        }
    }

    @discardableResult
    public func persistNow() async -> Bool {
        saveTask?.cancel()
        syncLiveSources()
        while true {
            let revision = project.updatedAt
            guard await persist() else { return false }
            if project.updatedAt == revision { return true }
            saveTask?.cancel()
        }
    }

    @discardableResult
    private func persist() async -> Bool {
        let snapshot = project
        isSaving = true
        do {
            try await DraftWriting.shared.save(project: snapshot, assets: assets.snapshot, store: store)
            if project.updatedAt == snapshot.updatedAt {
                lastError = nil
                isSaving = false
            }
            return true
        } catch {
            guard project.updatedAt == snapshot.updatedAt else { return false }
            if isDiskFull(error) {
                lastError = DraftStoreError.diskFull.errorDescription
            } else {
                lastError = error.localizedDescription
            }
            isSaving = false
            return false
        }
    }

    private func isDiskFull(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.code == NSFileWriteOutOfSpaceError { return true }
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC) { return true }
        if let store = error as? DraftStoreError, store == .diskFull { return true }
        return false
    }

    public var previewProject: CollageProject {
        var project = self.project
        if compareOriginal {
            for index in project.objects.indices where project.objects[index].kind == .photo {
                project.objects[index].photo?.filterID = nil
                project.objects[index].photo?.filterIntensity = 1
                project.objects[index].photo?.colorAdjust = ColorAdjust()
            }
        }
        return project
    }

    public func previewImage(maxSide: CGFloat) -> UIImage? {
        let project = previewProject
        let size: CGSize
        if project.mode == .longStrip {
            switch ExportGeometry.outputSize(for: project, assets: assets.snapshot) {
            case .ok(let value), .needsChoice(_, let value):
                let scale = maxSide / max(value.width, value.height)
                size = CGSize(width: max(value.width * scale, 1), height: max(value.height * scale, 1))
            }
        } else {
            size = project.canvas.size(maxLongSide: maxSide)
        }
        return CollageRenderer.shared.render(project: project, assets: assets.snapshot, canvasSize: size, preview: true)
    }

    public func refreshWarnings() {
        syncLiveSources()
        lowResolutionWarning = assets.pixelSizes.values.contains { min($0.width, $0.height) < 700 }
        func missing(_ id: UUID) -> Bool { assets.data(for: id) == nil || assets.pixelSizes[id] == .zero }
        let photoMissing = project.photoOrder.contains(where: missing)
        let stickerMissing = project.objects.contains { object in
            guard object.kind == .sticker, let payload = object.sticker else { return false }
            if let assetID = payload.assetID { return missing(assetID) }
            return StickerCatalog.sticker(id: payload.stickerID) == nil
        }
        let backgroundMissing = project.background.kind == .image && (project.background.imageAssetID.map(missing) ?? true)
        let frameMissing = project.decorationFrame.map { DecorationFrameCatalog.frame(id: $0.frameID) == nil } ?? false
        let liveMissing = project.resolvedLiveSources.contains { source in
            guard let clip = assets.motions[source.id] else { return true }
            return !FileManager.default.fileExists(atPath: clip.url.path)
        }
        missingAssetWarning = photoMissing || stickerMissing || backgroundMissing || frameMissing
        missingLiveAssetWarning = liveMissing
    }

    private func syncLiveSources() {
        var seen = Set<UUID>()
        let ids = project.photoLayers.compactMap { $0.photo?.assetID }.filter { seen.insert($0).inserted }
        let sources = ids.compactMap { id in assets.motions[id]?.source ?? project.liveSources?.first { $0.id == id } }
        let next: [LivePhotoSource]? = sources.isEmpty ? nil : sources
        if project.liveSources != next { project.liveSources = next }
        if !sources.isEmpty {
            if project.livePhotoSettings == nil { project.livePhotoSettings = LivePhotoSettings() }
            if project.schemaVersion != JiPin.schemaVersion { project.schemaVersion = JiPin.schemaVersion }
        }
        if let audio = project.livePhotoSettings?.audioSourceID, !sources.contains(where: { $0.id == audio && $0.hasAudio }) {
            project.livePhotoSettings?.audioSourceID = nil
        }
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
