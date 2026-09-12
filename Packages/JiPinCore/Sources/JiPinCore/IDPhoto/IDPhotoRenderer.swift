import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

public enum IDPhotoRenderError: LocalizedError {
    case invalidImage
    case invalidMask
    case missingMask
    case invalidOutputSize
    case renderingFailed
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法读取这张照片，请换一张照片重试。"
        case .invalidMask: return "人像轮廓数据无法读取，请重新识别照片。"
        case .missingMask: return "尚未得到人像轮廓。请重试识别，或打开“保留原背景”仅调整尺寸。"
        case .invalidOutputSize: return "照片尺寸无效。自定义每边需为 100–2048 像素，总像素不超过 400 万。"
        case .renderingFailed: return "照片处理未完成，请重试。"
        case .encodingFailed: return "照片文件生成失败，请重试。"
        }
    }
}

/// An immutable upright sRGB working copy, reusable for previews and export. Cache
/// mutations are locked; Core Image graphs and CGImages are immutable. The caller
/// should serialize preview work and discard old revisions before displaying them.
public final class IDPhotoPreparedSource: @unchecked Sendable {
    public let sourceSize: CGSize
    fileprivate let source: CIImage
    fileprivate let mask: CIImage?
    private let cacheLock = NSLock()
    private var editedMaskCache: (Data, CIImage)?
    private var retouchCache: (RetouchKey, CIImage)?

    public init(sourceData: Data, maskData: Data? = nil) throws {
        let size = ImageIOHelpers.pixelSize(of: sourceData)
        guard size.width > 0, size.height > 0 else { throw IDPhotoRenderError.invalidImage }
        let sourceLongSide = max(size.width, size.height)
        let factor = min(1, 4096 / sourceLongSide, sqrt(8_388_608 / (size.width * size.height)))
        guard let image = ImageIOHelpers.thumbnail(from: sourceData, maxLongSide: max(1, floor(sourceLongSide * factor))) else {
            throw IDPhotoRenderError.invalidImage
        }
        let srgb = ImageIOHelpers.sRGBImage(from: image)
        sourceSize = CGSize(width: srgb.width, height: srgb.height)
        source = CIImage(cgImage: srgb)
        if let maskData {
            let maskSize = ImageIOHelpers.pixelSize(of: maskData)
            guard maskSize.width >= 1, maskSize.height >= 1,
                  max(maskSize.width, maskSize.height) <= 4096,
                  maskSize.width * maskSize.height <= 8_388_608 else { throw IDPhotoRenderError.invalidMask }
            guard let decoded = ImageIOHelpers.fullImage(from: maskData) else { throw IDPhotoRenderError.invalidMask }
            // Vision's matte grid need not have the source photo's aspect ratio.
            // Its normalized coordinates map to the entire upright source image.
            // A matte contains coverage, not display colors. Do not apply an ICC
            // gamma conversion to its soft alpha values.
            mask = CIImage(cgImage: decoded, options: [.colorSpace: NSNull()]).transformed(by: CGAffineTransform(
                scaleX: sourceSize.width / CGFloat(decoded.width), y: sourceSize.height / CGFloat(decoded.height)))
                .cropped(to: source.extent)
        } else {
            mask = nil
        }
    }

    fileprivate func editedMask(strokes: [IDPhotoBrushStroke]) throws -> CIImage? {
        guard let mask else { return nil }
        guard !strokes.isEmpty else { return mask }
        let key = try JSONEncoder().encode(strokes)
        cacheLock.lock()
        let cached = editedMaskCache
        cacheLock.unlock()
        if let cached, cached.0 == key { return cached.1 }

        // The soft matte remains bounded while normalized brush positions preserve
        // their meaning across previews, template changes and exact-size exports.
        let factor = min(1, 2048 / max(sourceSize.width, sourceSize.height))
        let size = CGSize(width: max(1, floor(sourceSize.width * factor)), height: max(1, floor(sourceSize.height * factor)))
        let extent = CGRect(origin: .zero, size: size)
        let smallMask = mask.transformed(by: CGAffineTransform(scaleX: size.width / sourceSize.width, y: size.height / sourceSize.height))
        guard let base = IDPhotoRenderer.context.createCGImage(smallMask, from: extent, format: .L8,
                                                              colorSpace: CGColorSpaceCreateDeviceGray()) else {
            throw IDPhotoRenderError.renderingFailed
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let edited = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIImage(cgImage: base).draw(in: extent)
            let cg = renderer.cgContext
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes {
                guard !stroke.points.isEmpty else { continue }
                let points = stroke.points.filter { $0.x.isFinite && $0.y.isFinite }
                    .map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                guard let first = points.first else { continue }
                let radius = max(0.5, min(max(stroke.radius, 0.0001), 0.5) * min(size.width, size.height))
                let shade: CGFloat = stroke.restores ? 1 : 0
                let path = CGMutablePath()
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                // A narrow soft rim around an opaque core keeps restore/erase
                // predictable without converting the original matte to a hard cutout.
                for ring in stride(from: 5, through: 0, by: -1) {
                    let width = radius * 2 * (0.74 + CGFloat(ring) * 0.052)
                    cg.setStrokeColor(UIColor(white: shade, alpha: ring == 0 ? 1 : 0.16).cgColor)
                    cg.setFillColor(UIColor(white: shade, alpha: ring == 0 ? 1 : 0.16).cgColor)
                    if points.count == 1 {
                        cg.fillEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
                    } else {
                        cg.setLineWidth(width)
                        cg.addPath(path)
                        cg.strokePath()
                    }
                }
            }
        }
        guard let image = edited.cgImage else { throw IDPhotoRenderError.renderingFailed }
        let result = CIImage(cgImage: image, options: [.colorSpace: NSNull()]).transformed(by: CGAffineTransform(
            scaleX: sourceSize.width / size.width, y: sourceSize.height / size.height)).cropped(to: source.extent)
        cacheLock.lock()
        editedMaskCache = (key, result)
        cacheLock.unlock()
        return result
    }

    fileprivate func retouched(brightness: Double, smoothing: Double, temperature: Double,
                               faces: [IDPhotoFaceRegion]) throws -> CIImage {
        guard brightness != 0 || smoothing != 0 || temperature != 0 else { return source }
        let key = RetouchKey(brightness: brightness, smoothing: smoothing, temperature: temperature,
                            faces: try JSONEncoder().encode(faces))
        cacheLock.lock()
        let cached = retouchCache
        cacheLock.unlock()
        if let cached, cached.0 == key { return cached.1 }
        let graph = IDPhotoRenderer.retouch(source, brightness: brightness, smoothing: smoothing,
                                            temperature: temperature, faces: faces)
        guard let pixels = IDPhotoRenderer.context.createCGImage(graph, from: source.extent,
                                format: .RGBA8, colorSpace: IDPhotoRenderer.sRGB) else {
            throw IDPhotoRenderError.renderingFailed
        }
        let result = CIImage(cgImage: pixels)
        cacheLock.lock()
        retouchCache = (key, result)
        cacheLock.unlock()
        return result
    }
}

private struct RetouchKey: Equatable {
    let brightness: Double
    let smoothing: Double
    let temperature: Double
    let faces: Data
}

public enum IDPhotoRenderer {
    fileprivate static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    fileprivate static let context = CIContext(options: [.cacheIntermediates: false,
                                                        .workingColorSpace: sRGB, .outputColorSpace: sRGB])

    public static func render(project: IDPhotoProject, sourceData: Data, maskData: Data? = nil,
                              faces: [IDPhotoFaceRegion] = [], maxSide: CGFloat? = nil) throws -> UIImage {
        try render(project: project, prepared: IDPhotoPreparedSource(sourceData: sourceData, maskData: maskData),
                   faces: faces, maxSide: maxSide)
    }

    /// `maxSide` requests a preview working resolution, including larger than a
    /// small document's pixel template. With nil, pixels equal the template exactly.
    /// Both rendering paths use the same upright source, crop transform and effects.
    public static func render(project: IDPhotoProject, prepared: IDPhotoPreparedSource,
                              faces: [IDPhotoFaceRegion] = [], maxSide: CGFloat? = nil) throws -> UIImage {
        try autoreleasepool {
            try project.validate()
            let width = project.template.width, height = project.template.height
            guard (100...2048).contains(width), (100...2048).contains(height), width * height <= 4_000_000 else {
                throw IDPhotoRenderError.invalidOutputSize
            }
            let factor: CGFloat
            if let maxSide {
                guard maxSide.isFinite, maxSide > 0, maxSide <= 2048 else { throw IDPhotoRenderError.invalidOutputSize }
                factor = maxSide / CGFloat(max(width, height))
            } else { factor = 1 }
            let size = CGSize(width: max(1, (CGFloat(width) * factor).rounded()),
                              height: max(1, (CGFloat(height) * factor).rounded()))
            let rect = CGRect(origin: .zero, size: size)
            let personMask = try prepared.editedMask(strokes: project.strokes)
            if !project.keepOriginalBackground && personMask == nil { throw IDPhotoRenderError.missingMask }
            // Without reliable segmentation, original-background mode is deliberately
            // crop-only. It must not run a whole-image beauty filter as a fallback.
            let adjusted: CIImage
            if personMask != nil {
                adjusted = try prepared.retouched(brightness: finite(project.adjustments.brightness, range: -20...20),
                    smoothing: finite(project.adjustments.smoothing, range: 0...30),
                    temperature: finite(project.adjustments.temperature, range: -10...10), faces: faces)
            } else { adjusted = prepared.source }
            let topLeft = IDPhotoGeometry.transform(sourceSize: prepared.sourceSize, outputSize: size, crop: project.crop)
            let transform = ciTransform(fromTopLeft: topLeft, sourceHeight: prepared.sourceSize.height, outputHeight: size.height)
            let output: CIImage
            if project.keepOriginalBackground {
                let original = prepared.source.clampedToExtent()
                let retouched = personMask.map { blend(adjusted, over: prepared.source, mask: $0) } ?? original
                output = retouched.clampedToExtent().transformed(by: transform).cropped(to: rect)
            } else {
                let foreground = adjusted.transformed(by: transform)
                let outputMask = personMask!.transformed(by: transform)
                // Multiply the source's existing alpha by person coverage first,
                // then source-over the selected background. Interpolating RGBA
                // straight into the background would turn restored transparent
                // PNG pixels into transparent holes (later flattened to white).
                let cutout = blend(foreground, over: CIImage(color: .clear).cropped(to: rect), mask: outputMask)
                output = cutout.composited(over: background(project.background, size: size)).cropped(to: rect)
            }
            let opaqueOutput = output.composited(over: CIImage(color: .white).cropped(to: rect))
            guard let cgImage = context.createCGImage(opaqueOutput, from: rect, format: .RGBA8, colorSpace: sRGB) else {
                throw IDPhotoRenderError.renderingFailed
            }
            return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        }
    }

    public static func jpegData(project: IDPhotoProject, sourceData: Data, maskData: Data? = nil,
                                faces: [IDPhotoFaceRegion] = []) throws -> Data {
        try jpegData(project: project, prepared: IDPhotoPreparedSource(sourceData: sourceData, maskData: maskData), faces: faces)
    }

    public static func jpegData(project: IDPhotoProject, prepared: IDPhotoPreparedSource,
                                faces: [IDPhotoFaceRegion] = []) throws -> Data {
        guard let image = try render(project: project, prepared: prepared, faces: faces).cgImage else {
            throw IDPhotoRenderError.renderingFailed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw IDPhotoRenderError.encodingFailed
        }
        let ppi = project.template.ppi
        // Encode from rendered pixels and an explicit metadata allowlist. Never copy
        // source GPS, EXIF device identifiers, dates or orientation into the new file.
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.96,
            kCGImagePropertyDPIWidth: ppi,
            kCGImagePropertyDPIHeight: ppi,
            kCGImagePropertyOrientation: 1,
            kCGImagePropertyJFIFDictionary: [kCGImagePropertyJFIFXDensity: ppi,
                                           kCGImagePropertyJFIFYDensity: ppi,
                                           kCGImagePropertyJFIFDensityUnit: 1]
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw IDPhotoRenderError.encodingFailed }
        return data as Data
    }

    private static func finite(_ value: Double, range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : 0
    }

    private static func ciTransform(fromTopLeft t: CGAffineTransform, sourceHeight: CGFloat, outputHeight: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: t.a, b: -t.b, c: -t.c, d: t.d,
                          tx: t.c * sourceHeight + t.tx, ty: outputHeight - t.d * sourceHeight - t.ty)
    }

    private static func background(_ color: IDPhotoBackground, size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        let top = CIColor(color: HexColor.uiColor(color.topHex))
        guard let bottomHex = color.bottomHex else { return CIImage(color: top).cropped(to: rect) }
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: 0, y: size.height)
        gradient.point1 = .zero
        gradient.color0 = top
        gradient.color1 = CIColor(color: HexColor.uiColor(bottomHex))
        return (gradient.outputImage ?? CIImage(color: top)).cropped(to: rect)
    }

    fileprivate static func retouch(_ input: CIImage, brightness: Double, smoothing: Double, temperature: Double,
                                     faces: [IDPhotoFaceRegion]) -> CIImage {
        if brightness == 0 && smoothing == 0 && temperature == 0 { return input }
        var result = input
        if brightness != 0 {
            // Bounded midtone lift C' = C + a*C*(1-C), a in [-0.45,0.45].
            // This replaces the prototype EV gain: native-photo QA showed that
            // even +0.5 EV clipped already bright foreheads. The curve is strictly
            // monotonic, keeps black/white endpoints and never flattens highlights.
            let amount = brightness / 20 * 0.45
            let curve = CIFilter.colorPolynomial()
            curve.inputImage = result
            let coefficients = CIVector(x: 0, y: 1 + amount, z: -amount, w: 0)
            curve.redCoefficients = coefficients
            curve.greenCoefficients = coefficients
            curve.blueCoefficients = coefficients
            curve.alphaCoefficients = CIVector(x: 0, y: 1, z: 0, w: 0)
            result = curve.outputImage ?? result
        }
        if temperature != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = result
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 6500 + temperature * 30, y: 0)
            result = filter.outputImage ?? result
        }
        if smoothing > 0, faces.count == 1, let skin = skinMask(face: faces[0], size: input.extent.size) {
            // Edge-preserving noise reduction, blended at <= 25% only in reliable
            // face skin. There is no Gaussian smoothing of the portrait itself.
            let noise = CIFilter.noiseReduction()
            noise.inputImage = result.clampedToExtent()
            noise.noiseLevel = 0.06
            noise.sharpness = 0.15
            if let softened = noise.outputImage?.cropped(to: input.extent) {
                let edges = CIFilter.edges()
                edges.inputImage = input.clampedToExtent()
                edges.intensity = 3
                let inverted = (edges.outputImage ?? CIImage(color: .black))
                    .applyingFilter("CIColorInvert").cropped(to: input.extent)
                let protectedSkin = blend(skin, over: CIImage(color: .black).cropped(to: input.extent), mask: inverted)
                let strength = smoothing / 30 * 0.25
                let scaled = protectedSkin.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: strength, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: strength, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: strength, w: 0)
                ])
                result = blend(softened, over: result, mask: scaled)
            }
        }
        return result.cropped(to: input.extent)
    }

    private static func skinMask(face: IDPhotoFaceRegion, size: CGSize) -> CIImage? {
        guard let polygon = face.skinPolygon, polygon.count >= 3,
              !face.protectedPolygons.isEmpty else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        // Draw the geometric mask at a bounded size; blur only this mask's boundary.
        let factor = min(1, 1536 / max(size.width, size.height))
        let working = CGSize(width: max(1, (size.width * factor).rounded()), height: max(1, (size.height * factor).rounded()))
        let image = UIGraphicsImageRenderer(size: working, format: format).image { renderer in
            let cg = renderer.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: working))
            func draw(_ points: [CGPoint], color: UIColor) {
                guard let first = points.first, points.count >= 3 else { return }
                cg.beginPath()
                cg.move(to: CGPoint(x: first.x * working.width, y: first.y * working.height))
                points.dropFirst().forEach { cg.addLine(to: CGPoint(x: $0.x * working.width, y: $0.y * working.height)) }
                cg.closePath()
                cg.setFillColor(color.cgColor)
                cg.fillPath()
            }
            draw(polygon, color: .white)
            face.protectedPolygons.forEach { draw($0, color: .black) }
        }
        guard let cgImage = image.cgImage else { return nil }
        let mask = CIImage(cgImage: cgImage, options: [.colorSpace: NSNull()]).clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(0.5, face.faceRect.width * working.width * 0.012)])
            .cropped(to: CGRect(origin: .zero, size: working))
        return mask.transformed(by: CGAffineTransform(scaleX: size.width / working.width, y: size.height / working.height))
    }

    private static func blend(_ foreground: CIImage, over background: CIImage, mask: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = foreground
        filter.backgroundImage = background
        filter.maskImage = mask
        return filter.outputImage ?? background
    }
}
