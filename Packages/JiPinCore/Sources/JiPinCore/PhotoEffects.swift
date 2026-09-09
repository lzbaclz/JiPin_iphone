import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

public final class PhotoEffects {
    public static let shared = PhotoEffects()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    public func apply(
        to cgImage: CGImage,
        payload: PhotoPayload,
        targetSize: CGSize
    ) -> CGImage {
        var image = crop(cgImage, crop: payload.crop)
        image = applyMosaic(image, strokes: payload.mosaics, crop: payload.crop)
        image = adjustAndFilter(image, payload: payload)
        return image
    }

    public func crop(_ image: CGImage, crop: PhotoCrop) -> CGImage {
        if crop == .identity { return image }
        let size = CGSize(width: image.width, height: image.height)
        let cropped = LayoutEngine.croppedSize(size, crop: crop)
        let origin = CGPoint(x: size.width * crop.left, y: size.height * crop.top)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let ui = UIGraphicsImageRenderer(size: cropped, format: format).image { _ in
            UIImage(cgImage: image).draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
        return ui.cgImage ?? image
    }

    private func applyMosaic(_ image: CGImage, strokes: [MosaicStroke], crop: PhotoCrop) -> CGImage {
        let remapped = strokes.compactMap { stroke -> MosaicStroke? in
            let points = stroke.points.compactMap { point -> CGPoint? in
                let raw = LayoutEngine.unclampedCroppedPointFromPhoto(point, crop: crop)
                let margin = stroke.radius * 2
                guard raw.x >= -margin, raw.x <= 1 + margin, raw.y >= -margin, raw.y <= 1 + margin else {
                    return nil
                }
                return CGPoint(x: min(max(raw.x, 0), 1), y: min(max(raw.y, 0), 1))
            }
            guard !points.isEmpty else { return nil }
            return MosaicStroke(id: stroke.id, points: points, radius: stroke.radius)
        }
        guard !remapped.isEmpty else { return image }
        let ciImage = CIImage(cgImage: image)
        guard let pixellate = CIFilter(name: "CIPixellate") else { return image }
        pixellate.setValue(ciImage, forKey: kCIInputImageKey)
        pixellate.setValue(max(ciImage.extent.width / 28, 8), forKey: kCIInputScaleKey)
        guard let pixelImage = pixellate.outputImage else { return image }

        let size = CGSize(width: image.width, height: image.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let masked = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(image, in: CGRect(origin: .zero, size: size))
            cg.saveGState()
            let path = CGMutablePath()
            for stroke in remapped {
                for point in stroke.points {
                    let p = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    let r = stroke.radius * min(size.width, size.height)
                    path.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                }
            }
            cg.addPath(path)
            cg.clip()
            if let pixelCG = context.createCGImage(pixelImage, from: ciImage.extent) {
                cg.draw(pixelCG, in: CGRect(origin: .zero, size: size))
            }
            cg.restoreGState()
        }
        return masked.cgImage ?? image
    }

    private func adjustAndFilter(_ image: CGImage, payload: PhotoPayload) -> CGImage {
        var ciImage = CIImage(cgImage: image)
        let controls = CIFilter.colorControls()
        controls.inputImage = ciImage
        var brightness = payload.colorAdjust.brightness
        var contrast = payload.colorAdjust.contrast
        var saturation = payload.colorAdjust.saturation
        var temperature = payload.colorAdjust.temperature
        if let filterID = payload.filterID, let preset = FilterCatalog.preset(id: filterID) {
            let intensity = payload.filterIntensity
            brightness += 0
            contrast = mix(contrast, contrast * preset.extraContrast, intensity)
            saturation = mix(saturation, saturation * preset.extraSaturation, intensity)
            temperature = mix(temperature, temperature + preset.extraTemperature, intensity)
            if let name = preset.ciName, let effect = CIFilter(name: name) {
                effect.setValue(ciImage, forKey: kCIInputImageKey)
                if let output = effect.outputImage, intensity > 0.01, let mixed = mix(ciImage, output, intensity) {
                    ciImage = mixed
                }
            }
        }
        controls.inputImage = ciImage
        controls.brightness = Float(brightness)
        controls.contrast = Float(contrast)
        controls.saturation = Float(saturation)
        ciImage = controls.outputImage ?? ciImage
        if abs(temperature) > 0.01 {
            let temp = CIFilter.temperatureAndTint()
            temp.inputImage = ciImage
            temp.neutral = CIVector(x: 6500, y: 0)
            temp.targetNeutral = CIVector(x: 6500 + CGFloat(temperature) * 1800, y: 0)
            ciImage = temp.outputImage ?? ciImage
        }
        let extent = ciImage.extent.integral
        return context.createCGImage(ciImage, from: extent) ?? image
    }

    private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func mix(_ base: CIImage, _ overlay: CIImage, _ t: Double) -> CIImage? {
        guard let filter = CIFilter(name: "CIDissolveTransition") else { return overlay }
        filter.setValue(base, forKey: kCIInputImageKey)
        filter.setValue(overlay, forKey: kCIInputTargetImageKey)
        filter.setValue(Float(t), forKey: kCIInputTimeKey)
        return filter.outputImage
    }
}
