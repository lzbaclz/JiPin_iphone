#if canImport(JiPin)
import XCTest
import UIKit
@testable import JiPin
@testable import JiPinCore

@MainActor final class IDPhotoSessionTests: XCTestCase {
    private func fixture() throws -> IDPhotoSession {
        let size = CGSize(width: 240, height: 336)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let source = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.lightGray.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.67, green: 0.4, blue: 0.28, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 65, y: 45, width: 110, height: 190))
        }.pngData()!
        let mask = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill(); ctx.cgContext.fillEllipse(in: CGRect(x: 65, y: 45, width: 110, height: 190))
        }.pngData()!
        let face = IDPhotoFaceRegion(faceRect: CGRect(x: 0.27, y: 0.14, width: 0.46, height: 0.57),
            protectedPolygons: [[CGPoint(x:0.3,y:0.24),CGPoint(x:0.7,y:0.24),CGPoint(x:0.7,y:0.33),CGPoint(x:0.3,y:0.33)]],
            skinPolygon: [CGPoint(x:0.3,y:0.2),CGPoint(x:0.7,y:0.2),CGPoint(x:0.7,y:0.65),CGPoint(x:0.3,y:0.65)])
        return IDPhotoSession(draft: IDPhotoLoadedDraft(project: IDPhotoProject(), sourceData: source,
            maskData: mask, faceRegions: [face], maskIssue: nil, algorithmVersion: "explicit-unit-fixture"))
    }
    private func settled(_ session: IDPhotoSession) async {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if session.preview != nil && !session.isRendering && !session.isAnalyzing { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Preview did not settle: \(session.errorMessage ?? "none")")
    }
    func testReplacingPhotoRetainsWebsiteSpecificationAndOriginalBackgroundChoice() async throws {
        let session = try fixture()
        let oldID = session.project.id
        defer {
            session.stop()
            try? IDPhotoDraftStore.shared.delete(id: oldID)
            try? IDPhotoDraftStore.shared.delete(id: session.project.id)
        }
        session.start(reanalyze: false); await settled(session)
        let template = try IDPhotoTemplate.custom(width: 285, height: 385, title: "报名一寸")
        session.edit {
            $0.template = template; $0.exportByteLimit = 1_000_000
            $0.keepOriginalBackground = true; $0.exportQuality = .compressed
        }
        let changed = await session.replaceSource(session.sourceData)
        XCTAssertTrue(changed)
        XCTAssertNotEqual(session.project.id, oldID)
        XCTAssertEqual(session.project.template, template)
        XCTAssertEqual(session.project.exportByteLimit, 1_000_000)
        XCTAssertEqual(session.project.exportQuality, .compressed)
        XCTAssertTrue(session.project.keepOriginalBackground)
        XCTAssertTrue(session.project.adjustments.isIdentity)
        XCTAssertTrue(session.project.strokes.isEmpty)
        XCTAssertEqual(try IDPhotoDraftStore.shared.load(id: oldID).project.exportByteLimit, 1_000_000)
    }
    func testColorAndLightEditsDuringAnalysisKeepAutomaticFramingAndUndoBaseline() async throws {
        let seed = try fixture()
        let suggested = IDPhotoCrop(centerX: 0.48, centerY: 0.47, zoom: 1.7)
        let result = IDPhotoAnalysis(maskData: seed.maskData, faces: seed.faces, suggestedCrop: suggested,
                                     warning: nil, sourceSize: seed.sourceSize)
        let analyzer = DelayedIDPhotoAnalysis(result: result)
        let session = IDPhotoSession(sourceData: seed.sourceData, template: IDPhotoTemplateCatalog.defaultTemplate,
                                     analysisProvider: { _, size in try await analyzer.analyze(outputSize: size) })
        defer { session.stop(); seed.stop(); try? IDPhotoDraftStore.shared.delete(id: session.project.id) }
        session.start()
        session.edit { $0.background = .blue; $0.adjustments.brightness = 5 }
        await settled(session)
        XCTAssertEqual(session.project.crop, suggested)
        XCTAssertEqual(session.project.background, .blue)
        XCTAssertEqual(session.project.adjustments.brightness, 5)
        XCTAssertEqual(session.undoCount, 1)
        session.undo()
        XCTAssertEqual(session.project.background, .white)
        XCTAssertEqual(session.project.adjustments.brightness, 0)
        XCTAssertEqual(session.project.crop, suggested, "Undoing a color must retain initial automatic framing.")
        let calls = await analyzer.callCount
        XCTAssertEqual(calls, 1, "Changing background and light must reuse a single analysis.")
    }

    func testManualCropAndExplicitResetAreNotOverwrittenByLateAnalysis() async throws {
        let seed = try fixture(); defer { seed.stop() }
        for choice in [IDPhotoCrop(centerX: 0.42, centerY: 0.57, zoom: 1.9, rotationDegrees: 3), IDPhotoCrop()] {
            let result = IDPhotoAnalysis(maskData: seed.maskData, faces: seed.faces,
                                         suggestedCrop: IDPhotoCrop(centerY: 0.4, zoom: 1.5), warning: nil,
                                         sourceSize: seed.sourceSize)
            let analyzer = DelayedIDPhotoAnalysis(result: result)
            let session = IDPhotoSession(sourceData: seed.sourceData, template: IDPhotoTemplateCatalog.defaultTemplate,
                                         analysisProvider: { _, size in try await analyzer.analyze(outputSize: size) })
            defer { session.stop(); try? IDPhotoDraftStore.shared.delete(id: session.project.id) }
            session.start()
            session.editCrop { $0 = choice }
            session.edit { $0.background = .red }
            await settled(session)
            XCTAssertEqual(session.project.crop, choice, "Manual framing, including an explicit default reset, is intentional.")
            XCTAssertEqual(session.project.background, .red)
        }
    }

    func testTemplateChangedDuringAnalysisReframesWithCachedHeadBoundsWithoutAnotherVisionRequest() async throws {
        let seed = try fixture(); defer { seed.stop() }
        let initial = IDPhotoTemplateCatalog.defaultTemplate
        let changed = try IDPhotoTemplate.custom(width: 600, height: 600)
        let head = CGRect(x: 0.20, y: 0.05, width: 0.60, height: 0.68)
        let person = CGRect(x: 0.15, y: 0.05, width: 0.70, height: 0.95)
        let initialCrop = IDPhotoGeometry.autoCrop(face: seed.faces.first, sourceSize: seed.sourceSize,
                                                 outputSize: initial.pixelSize, personBounds: person, headBounds: head)
        let result = IDPhotoAnalysis(maskData: seed.maskData, faces: seed.faces, suggestedCrop: initialCrop,
                                     warning: nil, sourceSize: seed.sourceSize, personBounds: person, headBounds: head)
        let analyzer = DelayedIDPhotoAnalysis(result: result)
        let session = IDPhotoSession(sourceData: seed.sourceData, template: initial,
                                     analysisProvider: { _, size in try await analyzer.analyze(outputSize: size) })
        defer { session.stop(); try? IDPhotoDraftStore.shared.delete(id: session.project.id) }
        session.start()
        session.edit { $0.template = changed; $0.background = .blueWhite }
        await settled(session)
        let expected = IDPhotoGeometry.autoCrop(face: seed.faces.first, sourceSize: seed.sourceSize,
                                               outputSize: changed.pixelSize, personBounds: person, headBounds: head)
        XCTAssertEqual(session.project.template, changed)
        XCTAssertEqual(session.project.crop, expected)
        XCTAssertNotEqual(expected, initialCrop, "Fixture must exercise a different framing after aspect change.")
        XCTAssertEqual(session.project.background, .blueWhite)
        session.undo()
        XCTAssertEqual(session.project.template, initial)
        XCTAssertEqual(session.project.crop, initialCrop, "Each template's undo baseline uses that template's own framing.")
        let calls = await analyzer.callCount
        let requestedSizes = await analyzer.requestedSizes
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(requestedSizes, [initial.pixelSize])
    }

    func testRapidEditsDuringPreparationPreserveMaskAndLatestOutput() async throws {
        let session = try fixture(); defer { session.stop(); try? IDPhotoDraftStore.shared.delete(id: session.project.id) }
        session.start(reanalyze: false)
        session.beginTransaction()
        for n in 0..<30 {
            session.edit { $0.background = n.isMultiple(of:2) ? .red : .blue }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        session.edit { $0.background = .lightGray }
        session.endTransaction()
        await settled(session)
        XCTAssertNil(session.errorMessage)
        XCTAssertTrue(session.hasMask)
        XCTAssertEqual(session.undoCount, 1)
        XCTAssertEqual(session.project.background, .lightGray)
        let actual = try XCTUnwrap(session.preview)
        XCTAssertEqual(Int(actual.size.height),1000)
        let expected = try IDPhotoRenderer.render(project:session.project,sourceData:session.sourceData,
                                                 maskData:session.maskData,faces:session.faces,maxSide:1000)
        XCTAssertEqual(actual.pngData(),expected.pngData(),"An older frame must never remain after edits settle.")
    }
    func testContinuousEditsYieldPreviewBeforeFingerIsLifted() async throws {
        let session = try fixture(); defer { session.stop(); try? IDPhotoDraftStore.shared.delete(id: session.project.id) }
        session.start(reanalyze:false); await settled(session)
        let initial=session.preview?.pngData();var updatedWhileDragging=false
        session.beginTransaction()
        for n in 0..<80 {
            session.edit { $0.adjustments.brightness=Double(n%20) }
            try? await Task.sleep(nanoseconds:16_000_000)
            if session.preview?.pngData() != initial { updatedWhileDragging=true }
        }
        session.endTransaction();await settled(session)
        XCTAssertTrue(updatedWhileDragging,"A trailing debounce must not starve continuous gestures.")
        XCTAssertEqual(session.undoCount,1)
        session.undo();await settled(session)
        XCTAssertEqual(session.project.adjustments.brightness,0)
        XCTAssertEqual(session.redoCount,1)
    }
    func testDraftReopenKeepsEditsAndCloseFreezesTheSnapshot() async throws {
        let session=try fixture();let id=session.project.id
        defer { session.stop();try? IDPhotoDraftStore.shared.delete(id:id) }
        session.start(reanalyze:false);await settled(session)
        session.edit { $0.background = .blueWhite; $0.adjustments = .natural }
        await settled(session)
        let closed=await session.close();XCTAssertTrue(closed)
        session.edit { $0.background = .red };session.undo();session.redo()
        let draft=try IDPhotoDraftStore.shared.load(id:id)
        XCTAssertEqual(draft.project.background,.blueWhite)
        XCTAssertEqual(draft.project.adjustments,.natural)
        let reopened=IDPhotoSession(draft:draft);defer { reopened.stop() }
        reopened.start(reanalyze:false);await settled(reopened)
        reopened.edit { $0.background = .white }
        let saved=await reopened.persistNow();XCTAssertTrue(saved)
        XCTAssertEqual(try IDPhotoDraftStore.shared.load(id:id).project.background,.white)
    }
}

private actor DelayedIDPhotoAnalysis {
    private let result: IDPhotoAnalysis
    private(set) var callCount = 0
    private(set) var requestedSizes: [CGSize] = []
    init(result: IDPhotoAnalysis) { self.result = result }
    func analyze(outputSize: CGSize) async throws -> IDPhotoAnalysis {
        callCount += 1; requestedSizes.append(outputSize)
        try await Task.sleep(nanoseconds: 150_000_000)
        return result
    }
}
#endif
