import ImageIO
import JiPinCore
import UIKit
import XCTest

final class IDPhotoRenderTests: XCTestCase {
    func testAllFiveTemplatesAndCustomExportExactPixels300PPIWithoutSourceGPS() throws {
        let source = try XCTUnwrap(ImageIOHelpers.jpegWithGPS(from: image(size: CGSize(width: 600, height: 900)) { _ in
            UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 600, height: 900))
        }))
        XCTAssertTrue(ImageIOHelpers.containsGPS(source))
        let templates = IDPhotoTemplateCatalog.all + [try IDPhotoTemplate.custom(width: 601, height: 801)]
        for template in templates {
            let project = IDPhotoProject(template: template, keepOriginalBackground: true)
            let jpeg = try IDPhotoRenderer.jpegData(project: project, sourceData: source)
            let decoded = try XCTUnwrap(CGImageSourceCreateWithData(jpeg as CFData, nil))
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as? [CFString: Any])
            XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, template.width)
            XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, template.height)
            XCTAssertEqual((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0, 300, accuracy: 0.1)
            XCTAssertEqual((properties[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue ?? 0, 300, accuracy: 0.1)
            XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
            XCTAssertEqual(properties[kCGImagePropertyOrientation] as? Int ?? 1, 1)
            XCTAssertTrue((properties[kCGImagePropertyProfileName] as? String)?.contains("sRGB") == true)
        }
    }

    func testPreviewUsesRequestedWorkingResolutionButExportKeepsSmallTemplate() throws {
        let data = try sourceData(size: CGSize(width: 900, height: 1260))
        let project = IDPhotoProject(keepOriginalBackground: true)
        let prepared = try IDPhotoPreparedSource(sourceData: data)
        let preview = try IDPhotoRenderer.render(project: project, prepared: prepared, maxSide: 1024)
        XCTAssertEqual(preview.cgImage?.height, 1024)
        XCTAssertEqual(preview.cgImage?.width, 731)
        let output = try IDPhotoRenderer.jpegData(project: project, prepared: prepared)
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: output), CGSize(width: 295, height: 413))
    }

    func testZeroRetouchPreservesOriginalPixelsAndOriginalFallbackNeverAppliesWholeImageBeauty() throws {
        let template = try IDPhotoTemplate.custom(width: 200, height: 200)
        let source = try sourceData(size: template.pixelSize)
        let original = try XCTUnwrap(ImageIOHelpers.fullImage(from: source))
        let defaultProject = IDPhotoProject(template: template, keepOriginalBackground: true)
        let rendered = try XCTUnwrap(IDPhotoRenderer.render(project: defaultProject, sourceData: source).cgImage)
        XCTAssertLessThanOrEqual(maximumDifference(original, rendered), 1)
        var unavailableBeauty = defaultProject
        unavailableBeauty.adjustments = IDPhotoAdjustments(brightness: 20, smoothing: 30, temperature: 10)
        let fallback = try XCTUnwrap(IDPhotoRenderer.render(project: unavailableBeauty, sourceData: source).cgImage)
        XCTAssertEqual(bytes(fallback), bytes(rendered), "Without a person matte the fallback must be crop-only")
    }

    func testReplacementWithoutMatteFailsInsteadOfPretendingToChangeBackground() throws {
        let source = try sourceData(size: CGSize(width: 200, height: 200))
        XCTAssertThrowsError(try IDPhotoRenderer.render(project: IDPhotoProject(), sourceData: source)) { error in
            guard case IDPhotoRenderError.missingMask = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertThrowsError(try IDPhotoPreparedSource(sourceData: source, maskData: Data([1, 2, 3])))
    }

    func testAllSolidBackgroundsStayExactWhenPersonBrightnessAndTemperatureChange() throws {
        let template = try IDPhotoTemplate.custom(width: 200, height: 200)
        let source = try sourceData(size: template.pixelSize)
        let matte = try maskData(size: template.pixelSize, fill: CGRect(x: 60, y: 30, width: 80, height: 150))
        for color in IDPhotoBackground.allCases where color != .blueWhite {
            var project = IDPhotoProject(template: template, background: color)
            let base = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: matte).cgImage)
            project.adjustments = IDPhotoAdjustments(brightness: 20, smoothing: 30, temperature: 10)
            let adjusted = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: matte).cgImage)
            let expected = rgba(HexColor.uiColor(color.topHex))
            assertPixel(pixel(adjusted, x: 5, y: 5), approximately: expected, tolerance: 1)
            XCTAssertEqual(pixel(base, x: 5, y: 5), pixel(adjusted, x: 5, y: 5))
            XCTAssertNotEqual(pixel(base, x: 100, y: 100), pixel(adjusted, x: 100, y: 100))
        }
    }

    func testBlueWhiteGradientIsVerticalAndAnchoredToOutputWhileCropping() throws {
        let template = try IDPhotoTemplate.custom(width: 200, height: 300)
        let source = try sourceData(size: CGSize(width: 400, height: 600))
        let matte = try maskData(size: CGSize(width: 400, height: 600), fill: .zero)
        var project = IDPhotoProject(template: template, background: .blueWhite)
        let before = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: matte).cgImage)
        project.crop = IDPhotoCrop(centerX: 0.3, centerY: 0.65, zoom: 2, rotationDegrees: 20)
        let after = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: matte).cgImage)
        XCTAssertEqual(bytes(before), bytes(after), "Output gradient cannot move with the source photograph")
        assertPixel(pixel(after, x: 100, y: 0), approximately: rgba(HexColor.uiColor("#66A9E6")), tolerance: 2)
        assertPixel(pixel(after, x: 100, y: 299), approximately: [255, 255, 255, 255], tolerance: 2)
    }

    func testSoftBrushEraseAndRestoreUseTopLeftSourceCoordinates() throws {
        let template = try IDPhotoTemplate.custom(width: 200, height: 200)
        let source = try sourceData(size: template.pixelSize)
        let matte = try maskData(size: template.pixelSize, fill: CGRect(origin: .zero, size: template.pixelSize))
        var project = IDPhotoProject(template: template, background: .blue)
        let prepared = try IDPhotoPreparedSource(sourceData: source, maskData: matte)
        let baseline = try XCTUnwrap(IDPhotoRenderer.render(project: project, prepared: prepared).cgImage)
        project.strokes = [IDPhotoBrushStroke(points: [CGPoint(x: 0.25, y: 0.2)], radius: 0.10, restores: false)]
        let erased = try XCTUnwrap(IDPhotoRenderer.render(project: project, prepared: prepared).cgImage)
        assertPixel(pixel(erased, x: 50, y: 40), approximately: rgba(HexColor.uiColor("#438EDB")), tolerance: 1)
        XCTAssertEqual(pixel(erased, x: 50, y: 160), pixel(baseline, x: 50, y: 160), "Brush must not mirror vertically")
        project.strokes.append(IDPhotoBrushStroke(points: [CGPoint(x: 0.25, y: 0.2)], radius: 0.10, restores: true))
        let restored = try XCTUnwrap(IDPhotoRenderer.render(project: project, prepared: prepared).cgImage)
        XCTAssertEqual(pixel(restored, x: 50, y: 40), pixel(baseline, x: 50, y: 40))
    }

    func testBrushStaysAttachedToSourceAfterZoomAndClockwiseRotation() throws {
        let template = try IDPhotoTemplate.custom(width: 200, height: 200)
        let source = try sourceData(size: template.pixelSize)
        let matte = try maskData(size: template.pixelSize, fill: CGRect(origin: .zero, size: template.pixelSize))
        let point = CGPoint(x: 0.4, y: 0.45)
        let crop = IDPhotoCrop(centerX: 0.45, centerY: 0.5, zoom: 1.4, rotationDegrees: 35)
        let project = IDPhotoProject(template: template, crop: crop, background: .red,
                                    strokes: [IDPhotoBrushStroke(points: [point], radius: 0.055, restores: false)])
        let result = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: matte).cgImage)
        let output = IDPhotoGeometry.outputPoint(fromNormalizedSource: point, sourceSize: template.pixelSize,
                                               outputSize: template.pixelSize, crop: crop)
        assertPixel(pixel(result, x: Int(output.x.rounded()), y: Int(output.y.rounded())),
                    approximately: rgba(HexColor.uiColor("#D9363E")), tolerance: 1)
    }

    func testSoftMatteCoverageSurvivesColorManagementAndUnrelatedBrushStroke() throws {
        let size = CGSize(width: 200, height: 200)
        let source = try sourceData(size: size)
        let halfMask = try XCTUnwrap(ImageIOHelpers.pngData(from: image(size: size) { _ in
            UIColor(white: 0.5, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }))
        let template = try IDPhotoTemplate.custom(width: 200, height: 200)
        var project = IDPhotoProject(template: template, background: .white)
        let prepared = try IDPhotoPreparedSource(sourceData: source, maskData: halfMask)
        let before = try XCTUnwrap(IDPhotoRenderer.render(project: project, prepared: prepared).cgImage)
        let raw = pixel(try XCTUnwrap(ImageIOHelpers.fullImage(from: source)), x: 100, y: 100)
        let expected = raw.prefix(3).map { UInt8((Double($0) * 128 / 255 + 127).rounded()) } + [255]
        assertPixel(pixel(before, x: 100, y: 100), approximately: expected, tolerance: 2)
        project.strokes = [IDPhotoBrushStroke(points: [CGPoint(x: 0.1, y: 0.1)], radius: 0.03, restores: false)]
        let after = try XCTUnwrap(IDPhotoRenderer.render(project: project, prepared: prepared).cgImage)
        assertPixel(pixel(after, x: 100, y: 100), approximately: pixel(before, x: 100, y: 100), tolerance: 1)
    }

    func testTransparentSourceRestorationPreservesChosenBackgroundInsteadOfWhiteHoles() throws {
        let size = CGSize(width: 200, height: 200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = false; format.preferredRange = .standard
        let transparent = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.red.setFill()
            UIRectFill(CGRect(x: 70, y: 60, width: 60, height: 100))
        }
        let sourceImage = try XCTUnwrap(transparent.cgImage)
        XCTAssertTrue(ImageIOHelpers.hasAlpha(sourceImage))
        let source = try XCTUnwrap(ImageIOHelpers.pngData(from: sourceImage))
        let fullMask = try maskData(size: size, fill: CGRect(origin: .zero, size: size))
        let project = IDPhotoProject(template: try IDPhotoTemplate.custom(width: 200, height: 200), background: .blue,
            strokes: [IDPhotoBrushStroke(points: [CGPoint(x: 0.1, y: 0.1)], radius: 0.08, restores: true)])
        let output = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: fullMask).cgImage)
        assertPixel(pixel(output, x: 20, y: 20), approximately: rgba(HexColor.uiColor("#438EDB")), tolerance: 1)
        assertPixel(pixel(output, x: 180, y: 180), approximately: rgba(HexColor.uiColor("#438EDB")), tolerance: 1)
        assertPixel(pixel(output, x: 100, y: 100), approximately: [255, 0, 0, 255], tolerance: 1)
    }

    func testMaximumBrightnessKeepsHighlightTextureAndDoesNotCreateClippedPlateaus() throws {
        let size = CGSize(width: 256, height: 100)
        let source = try XCTUnwrap(ImageIOHelpers.pngData(from: image(size: size) { _ in
            for x in 0..<256 {
                UIColor(white: CGFloat(x) / 255, alpha: 1).setFill()
                UIRectFill(CGRect(x: x, y: 0, width: 1, height: 100))
            }
        }))
        let mask = try maskData(size: size, fill: CGRect(origin: .zero, size: size))
        let project = IDPhotoProject(template: try IDPhotoTemplate.custom(width: 256, height: 100),
            keepOriginalBackground: true, adjustments: IDPhotoAdjustments(brightness: 20))
        let result = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: mask).cgImage)
        let data = bytes(result)
        let row = (0..<256).map { Int(data[(50 * 256 + $0) * 4]) }
        XCTAssertEqual(row.first, 0)
        XCTAssertEqual(row.last, 255)
        XCTAssertLessThanOrEqual(row.filter { $0 >= 255 }.count, 2, "Brightening must not turn a broad highlight gradient into pure white")
        XCTAssertGreaterThan(Set(row[200..<254]).count, 25, "Retain distinct highlight values")
        XCTAssertTrue(zip(row, row.dropFirst()).allSatisfy { $0 <= $1 }, "Tone curve must stay monotonic")
        XCTAssertGreaterThan(row[128], 128)
        XCTAssertLessThanOrEqual(row[128], 159, "Midtone lift remains lightweight at the maximum slider value")
        XCTAssertLessThan(row[230], 248)
    }

    func testEXIFRotationAndMirrorAreBakedOnce() throws {
        let raw = image(size: CGSize(width: 200, height: 100)) { _ in
            UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 50))
            UIColor.green.setFill(); UIRectFill(CGRect(x: 100, y: 0, width: 100, height: 50))
            UIColor.blue.setFill(); UIRectFill(CGRect(x: 0, y: 50, width: 100, height: 50))
            UIColor.yellow.setFill(); UIRectFill(CGRect(x: 100, y: 50, width: 100, height: 50))
        }
        let rotated = try XCTUnwrap(ImageIOHelpers.jpegWithOrientation(from: raw, orientation: 6))
        let rotatedProject = IDPhotoProject(template: try IDPhotoTemplate.custom(width: 100, height: 200), keepOriginalBackground: true)
        let output = try XCTUnwrap(IDPhotoRenderer.render(project: rotatedProject, sourceData: rotated).cgImage)
        assertPixel(pixel(output, x: 20, y: 20), approximately: [0, 0, 255, 255], tolerance: 4)
        assertPixel(pixel(output, x: 80, y: 20), approximately: [255, 0, 0, 255], tolerance: 4)
        assertPixel(pixel(output, x: 20, y: 180), approximately: [255, 255, 0, 255], tolerance: 4)
        let mirrored = try XCTUnwrap(ImageIOHelpers.jpegWithOrientation(from: raw, orientation: 2))
        let mirroredProject = IDPhotoProject(template: try IDPhotoTemplate.custom(width: 200, height: 100), keepOriginalBackground: true)
        let mirror = try XCTUnwrap(IDPhotoRenderer.render(project: mirroredProject, sourceData: mirrored).cgImage)
        assertPixel(pixel(mirror, x: 20, y: 20), approximately: [0, 255, 0, 255], tolerance: 4)
        assertPixel(pixel(mirror, x: 180, y: 20), approximately: [255, 0, 0, 255], tolerance: 4)
    }

    func testSmoothingRequiresReliableSkinAndPreservesProtectedEyesAndClothes() throws {
        let size = CGSize(width: 256, height: 256)
        let source = try textureData(size: 256)
        let mask = try maskData(size: size, fill: CGRect(origin: .zero, size: size))
        let template = try IDPhotoTemplate.custom(width: 256, height: 256)
        var project = IDPhotoProject(template: template, keepOriginalBackground: true)
        let baseline = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: mask).cgImage)
        project.adjustments.smoothing = 30
        let noFace = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: mask).cgImage)
        XCTAssertLessThanOrEqual(maximumDifference(baseline, noFace), 1)
        let face = IDPhotoFaceRegion(faceRect: CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.6),
            protectedPolygons: [[CGPoint(x: 0.2, y: 0.25), CGPoint(x: 0.8, y: 0.25), CGPoint(x: 0.8, y: 0.4), CGPoint(x: 0.2, y: 0.4)]],
            skinPolygon: [CGPoint(x: 0.2, y: 0.15), CGPoint(x: 0.8, y: 0.15), CGPoint(x: 0.8, y: 0.65), CGPoint(x: 0.2, y: 0.65)])
        let smoothed = try XCTUnwrap(IDPhotoRenderer.render(project: project, sourceData: source, maskData: mask, faces: [face]).cgImage)
        assertPixel(pixel(smoothed, x: 128, y: 80), approximately: pixel(baseline, x: 128, y: 80), tolerance: 1)
        assertPixel(pixel(smoothed, x: 128, y: 220), approximately: pixel(baseline, x: 128, y: 220), tolerance: 1)
        let beforeBytes = bytes(baseline), afterBytes = bytes(smoothed)
        var changedSkin = 0
        for y in 120..<150 { for x in 80..<170 {
            let start = (y * 256 + x) * 4
            if afterBytes[start..<(start + 4)] != beforeBytes[start..<(start + 4)] { changedSkin += 1 }
        } }
        XCTAssertGreaterThan(changedSkin, 0, "The skin effect must be a real, localized operation")
        XCTAssertLessThanOrEqual(maximumDifference(baseline, smoothed), 15, "Light smoothing must stay subtle")
    }

    func testAlreadyCancelledAnalysisDoesNotReturnSuccess() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await IDPhotoSegmentation.analyze(sourceData: Data())
        }
        do { _ = try await task.value; XCTFail("Cancelled analysis returned success") }
        catch is CancellationError { }
        catch { XCTFail("Cancellation must remain CancellationError, got \(error)") }
    }

    private func image(size: CGSize, draw: (CGContext) -> Void) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true; format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }.cgImage!
    }

    private func sourceData(size: CGSize) throws -> Data {
        try XCTUnwrap(ImageIOHelpers.pngData(from: image(size: size) { _ in
            UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 3))
        }))
    }

    private func maskData(size: CGSize, fill: CGRect) throws -> Data {
        try XCTUnwrap(ImageIOHelpers.pngData(from: image(size: size) { _ in
            UIColor.black.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill(); UIRectFill(fill)
        }))
    }

    private func textureData(size: Int) throws -> Data {
        var data = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size { for x in 0..<size {
            let offset = (y * size + x) * 4
            let noise = ((x * 17 + y * 29) % 11) - 5
            data[offset] = UInt8(170 + noise); data[offset + 1] = UInt8(130 + noise); data[offset + 2] = UInt8(110 + noise)
        } }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(data) as CFData))
        let cg = try XCTUnwrap(CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        return try XCTUnwrap(ImageIOHelpers.pngData(from: cg))
    }

    private func bytes(_ image: CGImage) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &result, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return result
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let data = bytes(image), offset = (y * image.width + x) * 4
        return Array(data[offset..<(offset + 4)])
    }

    private func rgba(_ color: UIColor) -> [UInt8] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { UInt8(($0 * 255).rounded()) }
    }

    private func maximumDifference(_ a: CGImage, _ b: CGImage) -> Int {
        guard a.width == b.width, a.height == b.height else { return 255 }
        return zip(bytes(a), bytes(b)).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }

    private func assertPixel(_ actual: [UInt8], approximately expected: [UInt8], tolerance: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (a, b) in zip(actual, expected) {
            XCTAssertLessThanOrEqual(abs(Int(a) - Int(b)), tolerance, "actual \(actual), expected \(expected)", file: file, line: line)
        }
    }
}
