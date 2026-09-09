import CoreGraphics
import Foundation

public enum ProjectFactory {
    public static func make(
        mode: CollageMode,
        photos: [ImportedPhoto],
        layoutID: String? = nil,
        posterID: String? = nil,
        originatedFromExtension: Bool = false
    ) -> CollageProject {
        let ids = photos.map(\.id)
        var project = CollageProject(
            name: defaultName(mode: mode),
            mode: mode,
            photoOrder: ids,
            originatedFromExtension: originatedFromExtension
        )
        switch mode {
        case .template:
            let layout = layoutID.flatMap(CollageGridLayoutCatalog.layout(id:))
                ?? LayoutRecommender.ranked(photoSizes: photos.map(\.pixelSize), canvas: .square).first?.layout
                ?? CollageGridLayoutCatalog.defaultLayout(forPhotoCount: photos.count)
                ?? CollageGridLayoutCatalog.all.first { $0.photoCount == max(photos.count, 2) }
            project.layoutID = layout?.id
            project.canvas = .square
            project.objects = makePhotoObjects(ids: ids, layout: layout)
        case .freeform:
            project.canvas = .square
            project.objects = makeFreeformPhotos(photos: photos)
        case .poster:
            let poster = posterID.flatMap(PosterTemplateCatalog.template(id:))
                ?? PosterTemplateCatalog.matching(photoCount: photos.count).first
                ?? PosterTemplateCatalog.all.first
            if let poster {
                applyPoster(poster, photos: ids, to: &project)
            }
        case .longStrip:
            project.longStrip = LongStripSpec(direction: .vertical, spacing: 0)
            project.canvas = CanvasSpec(aspectWidth: 9, aspectHeight: 16)
            project.spacing = 0
            project.outerMargin = 0
            project.objects = ids.enumerated().map { index, id in
                LayerObject.photo(
                    assetID: id,
                    slotID: "strip-\(index)",
                    zIndex: index,
                    transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 0.2)
                )
            }
        }
        return project
    }

    public static func applyLayout(_ layout: CollageGridLayout, to project: inout CollageProject) {
        project.layoutID = layout.id
        project.customLayoutCells = nil
        let existing = project.photoLayers
        var objects = project.objects.filter { $0.kind != .photo }
        for (index, cell) in layout.cells.enumerated() {
            if index < existing.count {
                var photo = existing[index]
                photo.photo?.slotID = "c\(index)"
                photo.transform = transform(from: cell)
                objects.append(photo)
            }
        }
        project.objects = objects
        project.touch()
    }

    public static func syncPhotos(in project: inout CollageProject) {
        let extras = project.objects.filter { $0.kind != .photo }
        var unused = project.photoLayers
        func takeLayer(assetID: UUID, index: Int, slotPrefix: String) -> LayerObject {
            if let match = unused.firstIndex(where: { $0.photo?.assetID == assetID }) {
                return unused.remove(at: match)
            }
            return LayerObject.photo(
                assetID: assetID,
                slotID: "\(slotPrefix)\(index)",
                zIndex: index,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.36, height: 0.36)
            )
        }
        switch project.mode {
        case .template:
            let count = project.photoOrder.count
            let photos = project.photoOrder.enumerated().map { index, id in
                takeLayer(assetID: id, index: index, slotPrefix: "c")
            }
            project.objects = extras + photos
            if let current = project.layoutID.flatMap(CollageGridLayoutCatalog.layout(id:)),
               current.photoCount == count {
                let customCells = project.customLayoutCells
                applyLayout(current, to: &project)
                project.customLayoutCells = customCells
            } else if let layout = CollageGridLayoutCatalog.defaultLayout(forPhotoCount: count) {
                applyLayout(layout, to: &project)
            }
        case .longStrip:
            let photos = project.photoOrder.enumerated().map { index, id -> LayerObject in
                var layer = takeLayer(assetID: id, index: index, slotPrefix: "strip-")
                layer.photo?.slotID = "strip-\(index)"
                return layer
            }
            project.objects = extras + photos
        case .poster:
            if let poster = project.posterID.flatMap(PosterTemplateCatalog.template(id:)) {
                var photos: [LayerObject] = []
                for (index, id) in project.photoOrder.enumerated() {
                    var layer = takeLayer(assetID: id, index: index, slotPrefix: "p")
                    if index < poster.photoSlots.count {
                        let slot = poster.photoSlots[index]
                        layer.photo?.slotID = slot.id
                        layer.photo?.cornerRadius = slot.cornerRadius
                        layer.transform = transform(from: slot.frame)
                    } else {
                        layer.photo?.slotID = nil
                    }
                    photos.append(layer)
                }
                project.objects = extras + photos
            } else {
                project.objects = extras + project.photoOrder.enumerated().map { index, id in
                    takeLayer(assetID: id, index: index, slotPrefix: "p")
                }
            }
        case .freeform:
            project.objects = extras + project.photoOrder.enumerated().map { index, id in
                takeLayer(assetID: id, index: index, slotPrefix: "c")
            }
        }
        project.touch()
    }

    public static func applyPoster(_ template: PosterTemplate, photos: [UUID], to project: inout CollageProject) {
        project.posterID = template.id
        project.mode = .poster
        project.canvas = template.canvas
        project.background = template.background
        var objects: [LayerObject] = []
        for (index, slot) in template.photoSlots.enumerated() {
            guard index < photos.count else { break }
            var layer = LayerObject.photo(
                assetID: photos[index],
                slotID: slot.id,
                zIndex: index,
                transform: transform(from: slot.frame)
            )
            layer.photo?.cornerRadius = slot.cornerRadius
            objects.append(layer)
        }
        for (index, text) in template.texts.enumerated() {
            objects.append(
                LayerObject(
                    kind: .text,
                    zIndex: 100 + index,
                    transform: transform(from: text.frame),
                    text: text.style
                )
            )
        }
        for (index, deco) in template.decorations.enumerated() {
            objects.append(
                LayerObject(
                    kind: .sticker,
                    zIndex: 200 + index,
                    transform: {
                        var t = transform(from: deco.frame)
                        t.rotation = deco.rotation
                        return t
                    }(),
                    sticker: StickerPayload(stickerID: deco.stickerID)
                )
            )
        }
        project.objects = objects
        if project.photoOrder.isEmpty {
            project.photoOrder = photos
        }
        project.touch()
    }

    public static func previewCopy(from project: CollageProject, to mode: CollageMode) -> ModeCopyPreview {
        let range = PhotoLimits.range(for: mode)
        var warnings: [String] = []
        var dropped: [String] = []
        let kept = min(project.photoOrder.count, range.upperBound)
        if project.photoOrder.count > range.upperBound {
            warnings.append("目标模式最多 \(range.upperBound) 张照片，请先勾选要带走的照片，不会自动截掉后面的照片。")
        }
        if project.photoOrder.count < range.lowerBound {
            warnings.append("目标模式至少需要 \(range.lowerBound) 张照片。")
        }
        if mode != project.mode { dropped.append("照片将按目标模式重新排列，文字和装饰会保留") }
        return ModeCopyPreview(target: mode, keptPhotos: kept, droppedKinds: dropped, warnings: warnings)
    }

    public static func copy(project: CollageProject, to mode: CollageMode, photos: [ImportedPhoto], posterID: String? = nil) -> CollageProject {
        var copy = make(mode: mode, photos: photos, posterID: posterID)
        copy.name = project.name + " · \(mode.title)"
        copy.background = project.background
        var sourcePhotos = project.photoLayers
        for index in copy.objects.indices where copy.objects[index].kind == .photo {
            guard let assetID = copy.objects[index].photo?.assetID,
                  let match = sourcePhotos.firstIndex(where: { $0.photo?.assetID == assetID }) else { continue }
            let original = sourcePhotos.remove(at: match)
            var payload = original.photo
            payload?.slotID = copy.objects[index].photo?.slotID
            copy.objects[index].photo = payload
            copy.objects[index].transform.rotation = original.transform.rotation
            copy.objects[index].transform.scaleX = original.transform.scaleX
            copy.objects[index].transform.scaleY = original.transform.scaleY
        }
        let extras = project.objects.filter { $0.kind != .photo }.sorted { $0.zIndex < $1.zIndex }
        if !extras.isEmpty {
            let photoLayers = copy.photoLayers
            copy.objects = photoLayers + extras.enumerated().map { index, object in
                var item = object
                item.id = UUID()
                item.zIndex = photoLayers.count + index
                return item
            }
        }
        return copy
    }

    private static func makePhotoObjects(ids: [UUID], layout: CollageGridLayout?) -> [LayerObject] {
        let cells = layout?.cells ?? []
        return ids.enumerated().map { index, id in
            let cell = index < cells.count ? cells[index] : NormalizedRect(x: 0, y: 0, width: 1, height: 1)
            return LayerObject.photo(assetID: id, slotID: "c\(index)", zIndex: index, transform: transform(from: cell))
        }
    }

    private static func makeFreeformPhotos(photos: [ImportedPhoto]) -> [LayerObject] {
        let count = max(photos.count, 1)
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cellW = 0.78 / Double(cols)
        let cellH = 0.78 / Double(rows)
        return photos.enumerated().map { index, photo in
            let c = index % cols
            let r = index / cols
            let ratio = max(photo.pixelSize.width, 1) / max(photo.pixelSize.height, 1)
            let width = min(cellW * 0.9, cellH * 0.9 * ratio)
            let height = width / ratio
            return LayerObject.photo(
                assetID: photo.id,
                slotID: nil,
                zIndex: index,
                transform: CanvasTransform(
                    centerX: 0.14 + cellW * (Double(c) + 0.5),
                    centerY: 0.14 + cellH * (Double(r) + 0.5),
                    width: width,
                    height: height,
                    rotation: Double(index % 3 - 1) * 3
                )
            )
        }
    }

    private static func transform(from rect: NormalizedRect) -> CanvasTransform {
        CanvasTransform(
            centerX: rect.x + rect.width / 2,
            centerY: rect.y + rect.height / 2,
            width: rect.width,
            height: rect.height
        )
    }

    private static func defaultName(mode: CollageMode) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return "\(mode.title) \(formatter.string(from: Date()))"
    }
}

public enum ExportGeometry {
    public static func outputSize(for project: CollageProject, assets: AssetProviding) -> ExportLimitDecision {
        switch project.mode {
        case .longStrip:
            return longStripSize(project, assets: assets)
        case .template, .freeform, .poster:
            let long = project.exportPreference.quality == .hd ? JiPin.Export.hdLongSide : JiPin.Export.standardLongSide
            let size = project.canvas.size(maxLongSide: long)
            return clamp(size)
        }
    }

    public static func extensionOutputSize(for project: CollageProject, assets: AssetProviding) -> CGSize {
        switch project.mode {
        case .longStrip:
            let dimensions: CGSize
            switch longStripSize(project, assets: assets) {
            case .ok(let size), .needsChoice(_, let size): dimensions = size
            }
            let factor = JiPin.Export.extensionLongSide / max(dimensions.width, dimensions.height, 1)
            return CGSize(width: max(1, floor(dimensions.width * factor)), height: max(1, floor(dimensions.height * factor)))
        default:
            return project.canvas.size(maxLongSide: JiPin.Export.extensionLongSide)
        }
    }

    private static func longStripSize(_ project: CollageProject, assets: AssetProviding, long: CGFloat? = nil) -> ExportLimitDecision {
        let qualityLong = project.exportPreference.quality == .hd ? JiPin.Export.longStripHD : JiPin.Export.longStripStandard
        let base = long ?? qualityLong
        let photos = project.photoLayers.compactMap { object -> (id: UUID, pixelSize: CGSize, crop: PhotoCrop)? in
            guard let payload = object.photo else { return nil }
            let size = assets.imageData(for: payload.assetID).map(ImageIOHelpers.pixelSize(of:)) ?? CGSize(width: 1200, height: 1600)
            return (object.id, size, payload.crop)
        }
        let spacing = CGFloat(project.spacing) * base
        let margin = CGFloat(project.outerMargin) * base
        let result = LayoutEngine.longStripFrames(
            photos: photos,
            direction: project.longStrip?.direction ?? .vertical,
            canvasLong: base,
            spacing: spacing,
            margin: margin
        )
        return clamp(result.canvas)
    }

    public static func clamp(_ size: CGSize) -> ExportLimitDecision {
        let long = max(size.width, size.height)
        let pixels = size.width * size.height
        if long <= JiPin.Export.maxLongSide && pixels <= JiPin.Export.maxPixelCount {
            return .ok(size)
        }
        let scaleLong = JiPin.Export.maxLongSide / max(long, 1)
        let scalePixels = sqrt(JiPin.Export.maxPixelCount / max(pixels, 1))
        let scale = min(scaleLong, scalePixels, 1)
        let scaled = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        return .needsChoice(computed: size, scaled: scaled)
    }

    public static func pixelLabel(for project: CollageProject, assets: AssetProviding) -> String {
        let quality = project.exportPreference.quality.title
        switch outputSize(for: project, assets: assets) {
        case .ok(let size):
            return "\(quality) \(Int(size.width.rounded()))×\(Int(size.height.rounded())) 像素"
        case .needsChoice(let computed, let scaled):
            return "完整 \(Int(computed.width.rounded()))×\(Int(computed.height.rounded())) 超限，可缩至 \(quality) \(Int(scaled.width.rounded()))×\(Int(scaled.height.rounded()))"
        }
    }

    public static func estimatedByteCount(size: CGSize, format: ExportFormat) -> Int64 {
        let pixels = Double(max(size.width, 1) * max(size.height, 1))
        switch format {
        case .jpeg:
            return Int64((pixels * 0.28).rounded())
        case .png:
            return Int64((pixels * 0.9).rounded())
        }
    }

    public static func estimatedSizeLabel(size: CGSize, format: ExportFormat) -> String {
        let formatted = ByteCountFormatter.string(fromByteCount: estimatedByteCount(size: size, format: format), countStyle: .file)
        return "约 \(formatted)（预估）"
    }
}
