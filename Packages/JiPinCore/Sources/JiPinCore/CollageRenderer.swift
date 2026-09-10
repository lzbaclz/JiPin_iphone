import CoreGraphics
import Foundation
import UIKit

public protocol AssetProviding {
    func imageData(for id: UUID) -> Data?
    func decodedImage(for id: UUID, maxLongSide: CGFloat) -> CGImage?
    func processedPhoto(_ payload: PhotoPayload, maxLongSide: CGFloat, targetSize: CGSize) -> CGImage?
}

public extension AssetProviding {
    func decodedImage(for id: UUID, maxLongSide: CGFloat) -> CGImage? {
        imageData(for: id).flatMap { ImageIOHelpers.thumbnail(from: $0, maxLongSide: maxLongSide) }
    }
    func processedPhoto(_ payload: PhotoPayload, maxLongSide: CGFloat, targetSize: CGSize) -> CGImage? {
        decodedImage(for: payload.assetID, maxLongSide: maxLongSide).map {
            PhotoEffects.shared.apply(to: $0, payload: payload, targetSize: targetSize)
        }
    }
}

public struct DataAssetLibrary: AssetProviding, Sendable {
    public var images: [UUID: Data]
    public var motions: [UUID: LivePhotoClip]
    public init(images: [UUID: Data] = [:], motions: [UUID: LivePhotoClip] = [:]) {
        self.images = images
        self.motions = motions
    }
    public func imageData(for id: UUID) -> Data? { images[id] }
}

public final class CollageRenderer {
    public static let shared = CollageRenderer()

    public func render(
        project: CollageProject,
        assets: AssetProviding,
        canvasSize: CGSize,
        preview: Bool
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = !Self.allowsTransparent(project)
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            draw(project: project, assets: assets, canvasSize: canvasSize, preview: preview, in: ctx.cgContext)
        }
    }

    public func jpegData(project: CollageProject, assets: AssetProviding, canvasSize: CGSize) -> Data? {
        var project = project
        project.exportPreference.format = .jpeg
        project.exportPreference.transparentBackground = false
        let image = render(project: project, assets: assets, canvasSize: canvasSize, preview: false)
        guard let cgImage = image.cgImage else { return nil }
        return ImageIOHelpers.jpegData(from: cgImage, quality: JiPin.jpegQuality)
    }

    public func pngData(project: CollageProject, assets: AssetProviding, canvasSize: CGSize) -> Data? {
        var project = project
        project.exportPreference.format = .png
        let image = render(project: project, assets: assets, canvasSize: canvasSize, preview: false)
        guard let cgImage = image.cgImage else { return image.pngData() }
        return ImageIOHelpers.pngData(from: cgImage)
    }

    public static func allowsTransparent(_ project: CollageProject) -> Bool {
        project.exportPreference.format == .png
            && project.exportPreference.transparentBackground
            && project.background.isHidden
    }

    public func draw(
        project: CollageProject,
        assets: AssetProviding,
        canvasSize: CGSize,
        preview: Bool,
        visibleRect: CGRect? = nil,
        in cg: CGContext
    ) {
        cg.saveGState()
        if !Self.allowsTransparent(project) {
            drawBackground(project.background, in: CGRect(origin: .zero, size: canvasSize), context: cg, assets: assets)
        }
        let frames = resolvedFrames(project: project, canvasSize: canvasSize, assets: assets)
        for object in project.visibleObjects {
            if Task.isCancelled { break }
            if project.mode == .longStrip, object.kind == .photo, let clip = visibleRect, let frame = frames[object.id] {
                let unit = min(canvasSize.width, canvasSize.height) / 1000
                let expansion = CGFloat((object.photo?.shadow.radius ?? 0) * 4 + abs(object.photo?.shadow.offsetY ?? 0)) * unit
                    + CGFloat(object.photo?.stroke.width ?? 0) * min(frame.width, frame.height) + 2
                if !frame.insetBy(dx: -expansion, dy: -expansion).intersects(clip) { continue }
            }
            autoreleasepool {
            cg.saveGState()
            cg.setAlpha(object.opacity)
            // Composite a multi-path illustration as one layer, so overlapping strokes do not accumulate opacity.
            let groupedOpacity = object.opacity < 1
            if groupedOpacity { cg.beginTransparencyLayer(auxiliaryInfo: nil) }
            switch object.kind {
            case .photo:
                if let payload = object.photo, let frame = frames[object.id] ?? optionalFrame(object, canvasSize) {
                    drawPhoto(
                        payload,
                        frame: frame,
                        rotation: object.transform.rotation,
                        scaleX: object.transform.scaleX,
                        scaleY: object.transform.scaleY,
                        assets: assets,
                        preview: preview,
                        layoutDriven: project.mode != .freeform && (project.mode != .poster || payload.slotID != nil),
                        canvasUnit: min(canvasSize.width, canvasSize.height) / 1000,
                        in: cg
                    )
                }
            case .text:
                if let text = object.text {
                    drawText(text, transform: object.transform, canvasSize: canvasSize, in: cg)
                }
            case .sticker:
                if let sticker = object.sticker {
                    drawSticker(sticker, transform: object.transform, canvasSize: canvasSize, assets: assets, in: cg)
                }
            case .shape:
                if let shape = object.shape {
                    drawShape(shape, transform: object.transform, canvasSize: canvasSize, in: cg)
                }
            case .doodle:
                if let doodle = object.doodle {
                    drawDoodle(doodle, canvasSize: canvasSize, in: cg)
                }
            }
            if groupedOpacity { cg.endTransparencyLayer() }
            cg.restoreGState()
            }
        }
        if let decoration = project.decorationFrame {
            DecorationFrameRenderer.draw(decoration, in: CGRect(origin: .zero, size: canvasSize), context: cg)
        }
        cg.restoreGState()
    }

    public func resolvedFrames(
        project: CollageProject,
        canvasSize: CGSize,
        assets: AssetProviding
    ) -> [UUID: CGRect] {
        switch project.mode {
        case .template:
            guard let layout = project.resolvedGridLayout else { return [:] }
            let spacing = CGFloat(project.spacing) * min(canvasSize.width, canvasSize.height)
            let margin = CGFloat(project.outerMargin) * min(canvasSize.width, canvasSize.height)
            let rects = LayoutEngine.frames(layout: layout, canvasSize: canvasSize, spacing: spacing, margin: margin)
            var map: [UUID: CGRect] = [:]
            let photos = project.photoLayers
            for (index, object) in photos.enumerated() where index < rects.count {
                map[object.id] = rects[index]
            }
            return map
        case .poster:
            var map: [UUID: CGRect] = [:]
            for object in project.objects {
                if object.kind == .photo, let slot = object.photo?.slotID,
                   let template = project.posterID.flatMap(PosterTemplateCatalog.template(id:)),
                   let photoSlot = template.photoSlots.first(where: { $0.id == slot }) {
                    map[object.id] = photoSlot.frame.cgRect(in: canvasSize)
                } else {
                    map[object.id] = object.transform.cgRect(in: canvasSize)
                }
            }
            return map
        case .longStrip:
            let photos = project.photoLayers.compactMap { object -> (id: UUID, pixelSize: CGSize, crop: PhotoCrop)? in
                guard let payload = object.photo, let data = assets.imageData(for: payload.assetID) else {
                    return (object.id, CGSize(width: 1000, height: 1000), object.photo?.crop ?? .identity)
                }
                return (object.id, ImageIOHelpers.pixelSize(of: data), payload.crop)
            }
            let long = project.longStrip?.direction == .horizontal ? canvasSize.height : canvasSize.width
            let spacing = CGFloat(project.spacing) * long
            let margin = CGFloat(project.outerMargin) * long
            let result = LayoutEngine.longStripFrames(
                photos: photos.map { (id: $0.id, pixelSize: $0.pixelSize, crop: $0.crop) },
                direction: project.longStrip?.direction ?? .vertical,
                canvasLong: long,
                spacing: spacing,
                margin: margin
            )
            return result.frames
        case .freeform:
            var map: [UUID: CGRect] = [:]
            for object in project.objects {
                map[object.id] = object.transform.cgRect(in: canvasSize)
            }
            return map
        }
    }

    private func optionalFrame(_ object: LayerObject, _ canvasSize: CGSize) -> CGRect? {
        object.transform.cgRect(in: canvasSize)
    }

    private func drawBackground(_ spec: BackgroundSpec, in rect: CGRect, context cg: CGContext, assets: AssetProviding) {
        if spec.kind == .image, let id = spec.imageAssetID, let data = assets.imageData(for: id),
           let image = ImageIOHelpers.thumbnail(from: data, maxLongSide: max(rect.width, rect.height) * 2) {
            cg.saveGState()
            cg.translateBy(x: 0, y: rect.height)
            cg.scaleBy(x: 1, y: -1)
            let fitted = LayoutEngine.fittedRect(imageSize: CGSize(width: image.width, height: image.height), in: rect, mode: .fill, crop: .identity)
            cg.draw(image, in: fitted)
            cg.restoreGState()
            return
        }
        if spec.kind == .gradient, let second = spec.secondaryHex {
            let colors = [HexColor.cgColor(spec.colorHex), HexColor.cgColor(second)] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: rect.origin, end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
            }
        } else {
            cg.setFillColor(HexColor.cgColor(spec.colorHex))
            cg.fill(rect)
        }
        if spec.kind == .texture {
            drawTexture(BackgroundCatalog.preset(id: spec.presetID ?? "")?.texture ?? .paper, in: rect, context: cg)
        }
    }

    private func drawTexture(_ texture: BackgroundTexture, in rect: CGRect, context cg: CGContext) {
        cg.saveGState()
        let unit = max(min(rect.width, rect.height) / 1000, 0.001)
        cg.setStrokeColor(UIColor.black.withAlphaComponent(0.06).cgColor)
        cg.setFillColor(UIColor.black.withAlphaComponent(0.05).cgColor)
        switch texture {
        case .dots:
            let step: CGFloat = 18 * unit
            var y = rect.minY
            while y < rect.maxY {
                var x = rect.minX
                while x < rect.maxX {
                    cg.fillEllipse(in: CGRect(x: x, y: y, width: 2 * unit, height: 2 * unit))
                    x += step
                }
                y += step
            }
        case .grid:
            let step: CGFloat = 24 * unit
            var x = rect.minX
            while x < rect.maxX {
                cg.move(to: CGPoint(x: x, y: rect.minY))
                cg.addLine(to: CGPoint(x: x, y: rect.maxY))
                x += step
            }
            var y = rect.minY
            while y < rect.maxY {
                cg.move(to: CGPoint(x: rect.minX, y: y))
                cg.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += step
            }
            cg.setLineWidth(0.6 * unit)
            cg.strokePath()
        case .noise, .paper:
            var seed: UInt64 = 0x4A6950696E
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 32) / CGFloat(UInt32.max)
            }
            for _ in 0..<min(Int(rect.width / unit * rect.height / unit / 140), 16000) {
                let x = rect.minX + next() * rect.width
                let y = rect.minY + next() * rect.height
                cg.setFillColor(UIColor.black.withAlphaComponent(texture == .paper ? 0.03 : 0.07).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 1.2 * unit, height: 1.2 * unit))
            }
        }
        cg.restoreGState()
    }

    private func drawPhoto(
        _ payload: PhotoPayload,
        frame: CGRect,
        rotation: Double,
        scaleX: Double,
        scaleY: Double,
        assets: AssetProviding,
        preview: Bool,
        layoutDriven: Bool,
        canvasUnit: CGFloat,
        in cg: CGContext
    ) {
        let drawFrame = LayoutEngine.photoDrawFrame(payload, cell: frame)
        cg.saveGState()
        defer { cg.restoreGState() }
        if !layoutDriven {
            cg.translateBy(x: frame.midX, y: frame.midY)
            cg.rotate(by: CGFloat(rotation * .pi / 180))
            cg.translateBy(x: -frame.midX, y: -frame.midY)
        }
        if payload.polaroid {
            cg.setFillColor(UIColor.white.cgColor)
            cg.setShadow(offset: CGSize(width: 0, height: 3 * canvasUnit), blur: 8 * canvasUnit, color: UIColor.black.withAlphaComponent(0.18).cgColor)
            cg.fill(frame)
            cg.setShadow(offset: .zero, blur: 0, color: nil)
        }
        if payload.shadow.radius > 0 {
            cg.setShadow(
                offset: CGSize(width: 0, height: payload.shadow.offsetY * canvasUnit),
                blur: payload.shadow.radius * canvasUnit,
                color: HexColor.uiColor(payload.shadow.colorHex).cgColor
            )
        }
        cg.saveGState()
        let path = UIBezierPath(roundedRect: drawFrame, cornerRadius: payload.cornerRadius * min(drawFrame.width, drawFrame.height)).cgPath
        cg.addPath(path)
        cg.clip()
        let center = CGPoint(x: drawFrame.midX, y: drawFrame.midY)
        cg.translateBy(x: center.x, y: center.y)
        if layoutDriven { cg.rotate(by: CGFloat(rotation * .pi / 180)) }
        cg.scaleBy(x: scaleX < 0 ? -1 : 1, y: 1)
        cg.translateBy(x: -center.x, y: -center.y)
        if let data = assets.imageData(for: payload.assetID) {
            let original = ImageIOHelpers.pixelSize(of: data)
            let cropped = LayoutEngine.croppedSize(original, crop: payload.crop)
            let desired = LayoutEngine.fittedRect(imageSize: cropped, in: drawFrame, mode: payload.contentMode,
                                                 crop: payload.crop, rotation: rotation, fixedFrame: layoutDriven)
            let ratio = max(desired.width / max(cropped.width, 1), desired.height / max(cropped.height, 1))
            let decodeSide = max(max(original.width, original.height) * min(ratio, 1), 1)
            guard let processed = assets.processedPhoto(payload, maxLongSide: decodeSide, targetSize: drawFrame.size) else { cg.restoreGState(); return }
            let fitted = LayoutEngine.fittedRect(
                imageSize: CGSize(width: processed.width, height: processed.height),
                in: drawFrame,
                mode: payload.contentMode,
                crop: payload.crop,
                rotation: rotation,
                fixedFrame: layoutDriven
            )
            cg.saveGState()
            cg.translateBy(x: 0, y: drawFrame.maxY + drawFrame.minY)
            cg.scaleBy(x: 1, y: -1)
            var dest = CGRect(
                x: fitted.minX,
                y: drawFrame.maxY + drawFrame.minY - fitted.maxY,
                width: fitted.width,
                height: fitted.height
            )
            if scaleY < 0 {
                dest = CGRect(x: dest.minX, y: dest.maxY, width: dest.width, height: -dest.height)
            }
            cg.draw(processed, in: dest)
            cg.restoreGState()
            for block in payload.coverBlocks {
                guard let mapped = LayoutEngine.croppedRectFromPhoto(block.rect, crop: payload.crop) else { continue }
                let rect = CGRect(
                    x: fitted.minX + CGFloat(mapped.x) * fitted.width,
                    y: fitted.minY + CGFloat(scaleY < 0 ? 1 - mapped.y - mapped.height : mapped.y) * fitted.height,
                    width: CGFloat(mapped.width) * fitted.width,
                    height: CGFloat(mapped.height) * fitted.height
                )
                cg.setFillColor(HexColor.uiColor(block.colorHex).withAlphaComponent(1).cgColor)
                cg.fill(rect)
            }
        } else {
            cg.setFillColor(UIColor.systemGray5.cgColor)
            cg.fill(drawFrame)
        }
        cg.restoreGState()
        if payload.stroke.width > 0 {
            cg.setStrokeColor(HexColor.cgColor(payload.stroke.colorHex))
            cg.setLineWidth(payload.stroke.width * min(frame.width, frame.height))
            cg.addPath(UIBezierPath(roundedRect: frame, cornerRadius: payload.cornerRadius * min(frame.width, frame.height)).cgPath)
            cg.strokePath()
        }
    }

    private func drawText(_ text: TextPayload, transform: CanvasTransform, canvasSize: CGSize, in cg: CGContext) {
        let rect = transform.cgRect(in: canvasSize)
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: CGFloat(transform.rotation * .pi / 180))
        cg.scaleBy(x: transform.scaleX < 0 ? -1 : 1, y: transform.scaleY < 0 ? -1 : 1)
        let drawRect = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        if let bg = text.backgroundHex {
            cg.setFillColor(HexColor.cgColor(bg))
            cg.fill(drawRect.insetBy(dx: -6, dy: -4))
        }
        let unit = min(canvasSize.width, canvasSize.height) / 1000
        let fontSize = max(text.fontSize * min(canvasSize.width, canvasSize.height), 0.5)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = {
            switch text.alignment {
            case .leading: return .left
            case .center: return .center
            case .trailing: return .right
            }
        }()
        paragraph.lineHeightMultiple = text.lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont(text.fontName, size: fontSize),
            .foregroundColor: HexColor.uiColor(text.colorHex),
            .paragraphStyle: paragraph
        ]
        if text.shadow.radius > 0 {
            attributes[.shadow] = {
                let shadow = NSShadow()
                shadow.shadowBlurRadius = text.shadow.radius * unit
                shadow.shadowOffset = CGSize(width: 0, height: text.shadow.offsetY * unit)
                shadow.shadowColor = HexColor.uiColor(text.shadow.colorHex)
                return shadow
            }()
        }
        if text.stroke.width > 0 {
            attributes[.strokeColor] = HexColor.uiColor(text.stroke.colorHex)
            attributes[.strokeWidth] = -text.stroke.width * 8
        }
        let wrapWidth = max(drawRect.width, 0.5)
        let paragraphs = text.text.components(separatedBy: "\n")
        var blocks: [(NSAttributedString, CGFloat)] = []
        for raw in paragraphs {
            let lineAttr = NSAttributedString(string: raw.isEmpty ? " " : raw, attributes: attributes)
            let bound = lineAttr.boundingRect(
                with: CGSize(width: wrapWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let height = max(bound.height, fontSize * CGFloat(max(text.lineSpacing, 1.05)))
            blocks.append((lineAttr, height))
        }
        // Draw directly into the destination context. Long text must not allocate an unbounded offscreen bitmap.
        UIGraphicsPushContext(cg)
        var y = -drawRect.height / 2
        for (lineAttr, height) in blocks {
            lineAttr.draw(with: CGRect(x: -wrapWidth / 2, y: y, width: wrapWidth, height: height),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += height
        }
        UIGraphicsPopContext()
        cg.restoreGState()
    }

    private func resolvedFont(_ name: String, size: CGFloat) -> UIFont {
        let base: UIFont
        switch name {
        case SystemFontOption.rounded.fontName:
            base = UIFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor.withDesign(.rounded).flatMap { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
        case SystemFontOption.serif.fontName:
            base = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif).flatMap { UIFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
        case SystemFontOption.monospaced.fontName:
            base = .monospacedSystemFont(ofSize: size, weight: .regular)
        default:
            base = .systemFont(ofSize: size, weight: .semibold)
        }
        guard let emoji = UIFont(name: "AppleColorEmoji", size: size) else { return base }
        let cascaded = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName.cascadeList: [emoji.fontDescriptor]
        ])
        return UIFont(descriptor: cascaded, size: size)
    }

    private func drawSticker(_ payload: StickerPayload, transform: CanvasTransform, canvasSize: CGSize, assets: AssetProviding, in cg: CGContext) {
        let rect = transform.cgRect(in: canvasSize)
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: CGFloat(transform.rotation * .pi / 180))
        cg.scaleBy(x: transform.scaleX < 0 ? -1 : 1, y: transform.scaleY < 0 ? -1 : 1)
        let local = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        if let assetID = payload.assetID, let data = assets.imageData(for: assetID),
           let image = ImageIOHelpers.thumbnail(from: data, maxLongSide: max(rect.width, rect.height) * 2) {
            cg.translateBy(x: 0, y: 0)
            UIImage(cgImage: image).draw(in: local)
            cg.restoreGState()
            return
        }
        let sticker = StickerCatalog.sticker(id: payload.stickerID)
        let tint = HexColor.uiColor(payload.tintHex ?? sticker?.defaultTint ?? "#1C1A17")
        switch sticker?.render {
        case .illustration(let name):
            OriginalStickerArt.draw(name, in: local, context: cg)
        case .symbol(let name):
            let config = UIImage.SymbolConfiguration(pointSize: min(local.width, local.height) * 0.7, weight: .medium)
            if let image = UIImage(systemName: name, withConfiguration: config)?.withTintColor(tint, renderingMode: .alwaysOriginal) {
                image.draw(in: local)
            }
        case .badge:
            let path = UIBezierPath(roundedRect: local, cornerRadius: min(local.height * 0.25, local.width * 0.12))
            tint.setFill()
            path.fill()
            let title = sticker?.name ?? payload.stickerID
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(local.height * 0.38, 0.5), weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let size = (title as NSString).size(withAttributes: attrs)
            (title as NSString).draw(
                at: CGPoint(x: -size.width / 2, y: -size.height / 2),
                withAttributes: attrs
            )
        case .shape(let name):
            drawNamedShape(name, in: local, fill: tint, stroke: UIColor.clear, width: 0, in: cg)
        case .none:
            UIColor.orange.setFill()
            UIBezierPath(ovalIn: local).fill()
        }
        cg.restoreGState()
    }

    private func drawShape(_ payload: ShapePayload, transform: CanvasTransform, canvasSize: CGSize, in cg: CGContext) {
        let rect = transform.cgRect(in: canvasSize)
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: CGFloat(transform.rotation * .pi / 180))
        cg.scaleBy(x: transform.scaleX < 0 ? -1 : 1, y: transform.scaleY < 0 ? -1 : 1)
        let local = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        drawNamedShape(
            payload.shapeID,
            in: local,
            fill: HexColor.uiColor(payload.fillHex),
            stroke: HexColor.uiColor(payload.stroke.colorHex),
            width: payload.stroke.width * min(rect.width, rect.height),
            in: cg
        )
        cg.restoreGState()
    }

    private func drawNamedShape(_ name: String, in rect: CGRect, fill: UIColor, stroke: UIColor, width: CGFloat, in cg: CGContext) {
        let path: UIBezierPath
        switch name {
        case "circle", "oval":
            path = UIBezierPath(ovalIn: rect)
        case "square", "roundrect":
            path = UIBezierPath(roundedRect: rect, cornerRadius: name == "roundrect" ? min(rect.width, rect.height) * 0.18 : 0)
        case "arrow":
            path = arrowPath(in: rect)
        case "triangle":
            path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
        case "heart":
            path = heartPath(in: rect)
        case "star":
            path = starPath(in: rect)
        case "diamond":
            path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.close()
        case "hexagon":
            path = hexPath(in: rect)
        case "plus":
            let t = min(rect.width, rect.height) * 0.28
            path = UIBezierPath(rect: CGRect(x: rect.midX - t / 2, y: rect.minY, width: t, height: rect.height))
            path.append(UIBezierPath(rect: CGRect(x: rect.minX, y: rect.midY - t / 2, width: rect.width, height: t)))
        case "ring":
            path = UIBezierPath(ovalIn: rect)
            path.append(UIBezierPath(ovalIn: rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.22)).reversing())
        case "line":
            path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        default:
            path = UIBezierPath(rect: rect)
        }
        fill.setFill()
        path.fill()
        if width > 0 {
            stroke.setStroke()
            path.lineWidth = width
            path.stroke()
        }
    }

    private func arrowPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let head = rect.width * 0.42
        let shaft = rect.height * 0.34
        path.move(to: CGPoint(x: rect.minX, y: rect.midY - shaft / 2))
        path.addLine(to: CGPoint(x: rect.maxX - head, y: rect.midY - shaft / 2))
        path.addLine(to: CGPoint(x: rect.maxX - head, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - head, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - head, y: rect.midY + shaft / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + shaft / 2))
        path.close()
        return path
    }

    private func heartPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX + w / 2, y: rect.minY + h * 0.85))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.3),
            controlPoint1: CGPoint(x: rect.minX + w * 0.1, y: rect.minY + h * 0.6),
            controlPoint2: CGPoint(x: rect.minX, y: rect.minY + h * 0.45)
        )
        path.addArc(
            withCenter: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.28),
            radius: w * 0.25,
            startAngle: .pi,
            endAngle: 0,
            clockwise: true
        )
        path.addArc(
            withCenter: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.28),
            radius: w * 0.25,
            startAngle: .pi,
            endAngle: 0,
            clockwise: true
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w / 2, y: rect.minY + h * 0.85),
            controlPoint1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.45),
            controlPoint2: CGPoint(x: rect.minX + w * 0.9, y: rect.minY + h * 0.6)
        )
        return path
    }

    private func starPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : r * 0.4
            let point = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.close()
        return path
    }

    private func hexPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let point = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.close()
        return path
    }

    /// Rasterize ink (including eraser `.clear`) onto a transparent bitmap, then composite it so eraser never punches photos.
    private func drawDoodle(_ payload: DoodlePayload, canvasSize: CGSize, in cg: CGContext) {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let ink = UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            let doodleCG = ctx.cgContext
            doodleCG.clear(CGRect(origin: .zero, size: canvasSize))
            for stroke in payload.strokes {
                guard stroke.points.count >= 2 else { continue }
                doodleCG.saveGState()
                doodleCG.setBlendMode(stroke.isEraser ? .clear : .normal)
                doodleCG.setStrokeColor(HexColor.cgColor(stroke.colorHex, alpha: stroke.opacity))
                doodleCG.setLineWidth(stroke.lineWidth * min(canvasSize.width, canvasSize.height))
                doodleCG.setLineCap(.round)
                doodleCG.setLineJoin(.round)
                let mapped = stroke.points.map { CGPoint(x: $0.x * canvasSize.width, y: $0.y * canvasSize.height) }
                doodleCG.beginPath()
                doodleCG.move(to: mapped[0])
                if stroke.kind == .line || stroke.kind == .arrow {
                    doodleCG.addLine(to: mapped.last ?? mapped[0])
                } else {
                    for point in mapped.dropFirst() {
                        doodleCG.addLine(to: point)
                    }
                }
                doodleCG.strokePath()
                if stroke.kind == .arrow, let first = mapped.first, let last = mapped.last {
                    drawArrowHead(from: first, to: last, in: doodleCG)
                }
                doodleCG.restoreGState()
            }
        }
        cg.saveGState()
        UIGraphicsPushContext(cg)
        ink.draw(in: CGRect(origin: .zero, size: canvasSize))
        UIGraphicsPopContext()
        cg.restoreGState()
    }

    private func drawArrowHead(from: CGPoint, to: CGPoint, in cg: CGContext) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let length: CGFloat = 16
        let left = CGPoint(x: to.x - length * cos(angle - .pi / 6), y: to.y - length * sin(angle - .pi / 6))
        let right = CGPoint(x: to.x - length * cos(angle + .pi / 6), y: to.y - length * sin(angle + .pi / 6))
        cg.beginPath()
        cg.move(to: to)
        cg.addLine(to: left)
        cg.move(to: to)
        cg.addLine(to: right)
        cg.strokePath()
    }
}
