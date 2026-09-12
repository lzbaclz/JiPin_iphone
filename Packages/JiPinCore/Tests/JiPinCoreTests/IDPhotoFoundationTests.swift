import XCTest
import UIKit
@testable import JiPinCore

final class IDPhotoFoundationTests: XCTestCase {
    func testLegacyDraftDefaultsToHDAndExplicitCompressionSurvivesReopen() throws {
        let project = IDPhotoProject()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        json.removeValue(forKey: "exportQuality")
        let legacy = try JSONDecoder().decode(IDPhotoProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.exportQuality, .highDefinition)
        XCTAssertEqual(legacy.id, project.id)
        var compact = legacy
        compact.exportQuality = .compressed
        let store = IDPhotoDraftStore(containerURL: try root())
        try store.save(project: compact, sourceData: image(), maskData: nil, faceRegions: [])
        XCTAssertEqual(try store.load(id: compact.id).project.exportQuality, .compressed)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("IDPhotoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func image(_ color: UIColor = .orange, size: CGSize = CGSize(width: 80, height: 120)) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true; format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill(); context.fill(CGRect(origin: .zero, size: size))
        }.pngData()!
    }

    private func face() -> IDPhotoFaceRegion {
        IDPhotoFaceRegion(faceRect: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.4),
                          protectedPolygons: [[CGPoint(x: 0.35, y: 0.35), CGPoint(x: 0.45, y: 0.35), CGPoint(x: 0.4, y: 0.4)]],
                          skinPolygon: [CGPoint(x: 0.3, y: 0.2), CGPoint(x: 0.7, y: 0.2), CGPoint(x: 0.5, y: 0.6)])
    }

    func testFiveTemplatesKeepExactRoundedPixelsAndPrintDimensions() throws {
        let expected = [(25, 35, 295, 413), (35, 49, 413, 579), (22, 32, 260, 378), (35, 45, 413, 531), (33, 48, 390, 567)]
        XCTAssertEqual(IDPhotoTemplateCatalog.all.count, 5)
        XCTAssertEqual(Set(IDPhotoTemplateCatalog.all.map(\.id)).count, 5)
        XCTAssertEqual(IDPhotoTemplateCatalog.defaultTemplate.id, "id-25x35")
        for (template, size) in zip(IDPhotoTemplateCatalog.all, expected) {
            try template.validate()
            XCTAssertEqual(template.widthMM, Double(size.0)); XCTAssertEqual(template.heightMM, Double(size.1))
            XCTAssertEqual(template.width, size.2); XCTAssertEqual(template.height, size.3)
            XCTAssertEqual(template.ppi, 300)
            XCTAssertEqual(template.width, IDPhotoTemplate.pixels(millimeters: template.widthMM))
            XCTAssertEqual(template.height, IDPhotoTemplate.pixels(millimeters: template.heightMM))
            XCTAssertEqual(template.pixelSize, CGSize(width: size.2, height: size.3))
        }
        XCTAssertEqual(IDPhotoTemplate.pixels(millimeters: 25, ppi: 600), 591)
        XCTAssertEqual(IDPhotoTemplate.pixels(millimeters: 35, ppi: 600), 827)
        XCTAssertNotEqual(IDPhotoTemplate.pixels(millimeters: 25, ppi: 600), IDPhotoTemplateCatalog.defaultTemplate.width * 2)
        XCTAssertNil(IDPhotoTemplate.pixels(millimeters: .infinity))
    }

    func testCustomPixelsStayExactAndRejectAllocationExtremes() throws {
        let template = try IDPhotoTemplate.custom(width: 777, height: 1_111)
        XCTAssertEqual(template.pixelSize, CGSize(width: 777, height: 1_111))
        XCTAssertEqual(template.widthMM, 777.0 / 300 * 25.4, accuracy: 0.00001)
        XCTAssertEqual(try IDPhotoTemplate.custom(width: 2_000, height: 2_000).width, 2_000)
        for pair in [(99, 300), (300, 99), (2_049, 300), (0, 0), (-1, 300), (2_048, 2_048), (Int.max, Int.max)] {
            XCTAssertThrowsError(try IDPhotoTemplate.custom(width: pair.0, height: pair.1))
        }
        XCTAssertThrowsError(try IDPhotoTemplate.custom(width: 300, height: 400, ppi: 0))
    }

    func testFiveBackgroundsAndNaturalAdjustmentsHaveExactPresets() {
        XCTAssertEqual(IDPhotoBackground.allCases.count, 5)
        XCTAssertEqual(IDPhotoBackground.allCases.map(\.topHex), ["#FFFFFF", "#D9363E", "#438EDB", "#66A9E6", "#E6E8EB"])
        XCTAssertEqual(IDPhotoBackground.allCases.compactMap(\.bottomHex), ["#FFFFFF"])
        XCTAssertEqual(IDPhotoAdjustments.natural, IDPhotoAdjustments(brightness: 5, smoothing: 6, temperature: 0))
        XCTAssertTrue(IDPhotoAdjustments().isIdentity)
        XCTAssertEqual(IDPhotoAdjustments(brightness: 90, smoothing: -10, temperature: -100),
                       IDPhotoAdjustments(brightness: 20, smoothing: 0, temperature: -10))
        XCTAssertTrue(IDPhotoAdjustments(brightness: .nan, smoothing: .infinity).isIdentity)
    }

    func testCropUsesSourceCenterAndUniformScaleForEveryAspect() {
        for source in [CGSize(width: 400, height: 600), CGSize(width: 600, height: 400), CGSize(width: 300, height: 300)] {
            let output = CGSize(width: 295, height: 413)
            let crop = IDPhotoCrop(centerX: 0.35, centerY: 0.4, zoom: 1.8, rotationDegrees: 23)
            let t = IDPhotoGeometry.transform(sourceSize: source, outputSize: output, crop: crop)
            let center = CGPoint(x: source.width * 0.35, y: source.height * 0.4).applying(t)
            XCTAssertEqual(center.x, output.width / 2, accuracy: 0.00001)
            XCTAssertEqual(center.y, output.height / 2, accuracy: 0.00001)
            XCTAssertEqual(hypot(t.a, t.b), hypot(t.c, t.d), accuracy: 0.00001)
            XCTAssertEqual(t.a * t.c + t.b * t.d, 0, accuracy: 0.00001)
            XCTAssertEqual(hypot(t.a, t.b), max(output.width / source.width, output.height / source.height) * 1.8, accuracy: 0.00001)
        }
    }

    func testBrushMappingRoundTripsAfterZoomCropAndRotation() {
        let source = CGSize(width: 1_200, height: 800)
        let crop = IDPhotoCrop(centerX: 0.6, centerY: 0.35, zoom: 2.1, rotationDegrees: -37)
        for output in [CGSize(width: 295, height: 413), CGSize(width: 590, height: 826), CGSize(width: 222, height: 310.8)] {
            for sourcePoint in [CGPoint(x: 0.12, y: 0.34), CGPoint(x: 0.8, y: 0.6), CGPoint.zero, CGPoint(x: 1, y: 1)] {
                let point = IDPhotoGeometry.outputPoint(fromNormalizedSource: sourcePoint, sourceSize: source, outputSize: output, crop: crop)
                let recovered = IDPhotoGeometry.normalizedSourcePoint(fromOutput: point, sourceSize: source, outputSize: output, crop: crop)
                XCTAssertEqual(recovered.x, sourcePoint.x, accuracy: 0.000001)
                XCTAssertEqual(recovered.y, sourcePoint.y, accuracy: 0.000001)
            }
        }
    }

    func testAutomaticCropLeavesHeadSpaceAndDoesNotTreatFaceBoxAsHair() throws {
        let region = IDPhotoFaceRegion(faceRect: CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.22))
        let source = CGSize(width: 1_000, height: 1_500), output = CGSize(width: 295, height: 413)
        let crop = IDPhotoGeometry.autoCrop(face: region, sourceSize: source, outputSize: output)
        try crop.validate()
        let hairTop = CGPoint(x: 0.5, y: 0.3 - 0.22 * 0.3)
        let top = IDPhotoGeometry.outputPoint(fromNormalizedSource: hairTop, sourceSize: source, outputSize: output, crop: crop)
        XCTAssertEqual(top.y / output.height, 0.08, accuracy: 0.0001)
        XCTAssertEqual(IDPhotoGeometry.autoCrop(face: nil, sourceSize: source, outputSize: output), IDPhotoCrop())
    }

    func testAutomaticCropFitsAsymmetricCurlyHairWithoutIncludingShoulders() {
        let face = IDPhotoFaceRegion(faceRect: CGRect(x: 0.47, y: 0.24, width: 0.16, height: 0.20))
        let head = CGRect(x: 0.25, y: 0.09, width: 0.57, height: 0.36)
        let person = CGRect(x: 0.01, y: 0.09, width: 0.98, height: 0.9)
        let source = CGSize(width: 1_000, height: 1_280), output = CGSize(width: 295, height: 413)
        let crop = IDPhotoGeometry.autoCrop(face: face, sourceSize: source, outputSize: output,
                                            personBounds: person, headBounds: head)
        let t = IDPhotoGeometry.transform(sourceSize: source, outputSize: output, crop: crop)
        let left = CGPoint(x: head.minX * source.width, y: head.minY * source.height).applying(t)
        let right = CGPoint(x: head.maxX * source.width, y: head.minY * source.height).applying(t)
        XCTAssertGreaterThanOrEqual(left.x, output.width * 0.04 - 0.001)
        XCTAssertLessThanOrEqual(right.x, output.width * 0.96 + 0.001)
        XCTAssertEqual(left.y / output.height, 0.08, accuracy: 0.0001)
        // Widening the body further cannot shrink the portrait: only the head band sets this cap.
        let narrowBody = CGRect(x: 0.2, y: 0.09, width: 0.6, height: 0.9)
        XCTAssertEqual(crop, IDPhotoGeometry.autoCrop(face: face, sourceSize: source, outputSize: output,
                                                      personBounds: narrowBody, headBounds: head))
        let heightOnly = IDPhotoGeometry.autoCrop(face: face, sourceSize: source, outputSize: output, personBounds: person)
        XCTAssertLessThan(crop.zoom, heightOnly.zoom)
    }

    func testProjectRejectsFutureSchemaOutOfBoundsAndDuplicatedStrokes() throws {
        let project = IDPhotoProject()
        let encoded = try JSONEncoder().encode(project)
        XCTAssertEqual(try JSONDecoder().decode(IDPhotoProject.self, from: encoded), project)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["schemaVersion"] = 2
        XCTAssertThrowsError(try JSONDecoder().decode(IDPhotoProject.self, from: JSONSerialization.data(withJSONObject: json))) {
            XCTAssertEqual($0 as? IDPhotoValidationError, .unsupportedVersion)
        }
        json["schemaVersion"] = 1
        json["crop"] = ["centerX": 0.5, "centerY": 0.5, "zoom": 100_000, "rotationDegrees": 0]
        XCTAssertThrowsError(try JSONDecoder().decode(IDPhotoProject.self, from: JSONSerialization.data(withJSONObject: json)))
        var bad = project
        let stroke = IDPhotoBrushStroke(points: [.zero], radius: 0.01, restores: true)
        bad.strokes = [stroke, stroke]
        XCTAssertThrowsError(try bad.validate())
        bad.strokes = [IDPhotoBrushStroke(points: [CGPoint(x: -1, y: 0)], radius: 0.01, restores: false)]
        XCTAssertThrowsError(try bad.validate())
    }

    func testDraftRoundTripKeepsMaskLandmarksAndManualEdits() throws {
        let store = IDPhotoDraftStore(containerURL: try root())
        let source = image(), mask = image(.gray, size: CGSize(width: 20, height: 30))
        let now = Date(timeIntervalSince1970: 1_789_200_000.125)
        let project = IDPhotoProject(name: "简历照片", crop: .init(centerX: 0.4, centerY: 0.4, zoom: 1.5, rotationDegrees: 3),
                                     background: .blueWhite, adjustments: .natural,
                                     strokes: [.init(points: [CGPoint(x: 0.4, y: 0.3), CGPoint(x: 0.42, y: 0.33)], radius: 0.005, restores: true)], createdAt: now)
        try store.save(project: project, sourceData: source, maskData: mask, faceRegions: [face()], thumbnailJPEG: source,
                       algorithmVersion: "vision-person-quality-v1")
        let freshStore = IDPhotoDraftStore(containerURL: store.containerURL)
        let loaded = try freshStore.load(id: project.id)
        XCTAssertEqual(loaded.project, project); XCTAssertEqual(loaded.sourceData, source); XCTAssertEqual(loaded.maskData, mask)
        XCTAssertEqual(loaded.faceRegions, [face()]); XCTAssertNil(loaded.maskIssue)
        XCTAssertEqual(loaded.algorithmVersion, "vision-person-quality-v1")
        XCTAssertEqual(freshStore.listDrafts().map(\.id), [project.id])
        XCTAssertEqual(freshStore.thumbnailData(id: project.id), source)
        XCTAssertEqual(try store.draftsRoot.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testDraftAtomicReplacementChangesOnlyCompletedRevision() throws {
        let store = IDPhotoDraftStore(containerURL: try root()), source = image()
        var project = IDPhotoProject()
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        project.background = .red; project.crop.zoom = 1.5
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        XCTAssertEqual(try store.load(id: project.id).project, project)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: store.draftsRoot, includingPropertiesForKeys: nil).count, 1)
    }

    func testDiskFullAtCommitPreservesPreviousDraftAndCleansStaging() throws {
        let url = try root(), source = image()
        let store = IDPhotoDraftStore(containerURL: url)
        let project = IDPhotoProject()
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        let failing = IDPhotoDraftStore(containerURL: url, commit: { _, _ in
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        })
        var changed = project; changed.background = .blue; changed.adjustments = .natural
        XCTAssertThrowsError(try failing.save(project: changed, sourceData: source, maskData: nil, faceRegions: [])) {
            XCTAssertEqual($0 as? IDPhotoDraftStoreError, .diskFull)
        }
        XCTAssertEqual(try store.load(id: project.id).project, project)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: store.draftsRoot, includingPropertiesForKeys: nil).count, 1)
    }

    func testChangingSourceOrMalformedMaskCannotOverwriteGoodDraft() throws {
        let store = IDPhotoDraftStore(containerURL: try root()), source = image()
        let project = IDPhotoProject()
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        XCTAssertThrowsError(try store.save(project: project, sourceData: image(.blue), maskData: nil, faceRegions: [])) {
            XCTAssertEqual($0 as? IDPhotoDraftStoreError, .sourceChanged)
        }
        XCTAssertThrowsError(try store.save(project: project, sourceData: source, maskData: Data([1, 2, 3]), faceRegions: []))
        XCTAssertEqual(try store.load(id: project.id).sourceData, source)
    }

    func testVisionMatteGridMayDifferFromPortraitAspect() throws {
        let store = IDPhotoDraftStore(containerURL: try root()), source = image()
        let squareMask = image(.gray, size: CGSize(width: 64, height: 64)), project = IDPhotoProject()
        // Vision's normalized matte covers the full source despite independent grid dimensions.
        try store.save(project: project, sourceData: source, maskData: squareMask, faceRegions: [face()])
        let loaded = try store.load(id: project.id)
        XCTAssertEqual(loaded.maskData, squareMask); XCTAssertNil(loaded.maskIssue)
    }

    func testSourceCorruptionIsNotSilentlyLoaded() throws {
        let store = IDPhotoDraftStore(containerURL: try root()), source = image(), project = IDPhotoProject()
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        let path = store.draftsRoot.appendingPathComponent(project.id.uuidString).appendingPathComponent("source.image")
        try image(.blue).write(to: path)
        XCTAssertThrowsError(try store.load(id: project.id)) {
            XCTAssertEqual($0 as? IDPhotoDraftStoreError, .missingSource)
        }
    }

    func testDamagedMaskRecoversSourceAndWarnsRatherThanPretendingSuccess() throws {
        let store = IDPhotoDraftStore(containerURL: try root()), source = image()
        let project = IDPhotoProject()
        try store.save(project: project, sourceData: source, maskData: image(.gray), faceRegions: [face()])
        let path = store.draftsRoot.appendingPathComponent(project.id.uuidString).appendingPathComponent("mask.png")
        try Data([1, 2, 3]).write(to: path)
        let loaded = try store.load(id: project.id)
        XCTAssertEqual(loaded.sourceData, source); XCTAssertEqual(loaded.project, project)
        XCTAssertNil(loaded.maskData); XCTAssertNotNil(loaded.maskIssue)
        XCTAssertEqual(store.listDrafts().count, 1)
    }

    func testUnknownDraftSchemaCannotBeLoadedOrOverwritten() throws {
        let store = IDPhotoDraftStore(containerURL: try root()), source = image()
        let project = IDPhotoProject()
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        let path = store.draftsRoot.appendingPathComponent(project.id.uuidString).appendingPathComponent("project.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        json["schemaVersion"] = 10
        let future = try JSONSerialization.data(withJSONObject: json)
        try future.write(to: path)
        XCTAssertThrowsError(try store.load(id: project.id))
        XCTAssertThrowsError(try store.save(project: project, sourceData: source, maskData: nil, faceRegions: []))
        XCTAssertEqual(try Data(contentsOf: path), future)
    }

    func testCollageCacheCleanupAndStagingRecoveryLeaveIDPhotoSourceIntact() throws {
        let url = try root(), source = image(), project = IDPhotoProject()
        let store = IDPhotoDraftStore(containerURL: url)
        try store.save(project: project, sourceData: source, maskData: nil, faceRegions: [])
        let staged = store.draftsRoot.appendingPathComponent(".abandoned.tmp")
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        let collageStore = DraftStore(overridesContainer: url)
        try collageStore.prepare(); try collageStore.clearExportCache(); try store.prepare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(try store.load(id: project.id).sourceData, source)
        try store.delete(id: project.id)
        XCTAssertEqual(store.listDrafts().count, 0)
    }
}
