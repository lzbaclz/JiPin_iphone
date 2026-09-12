import SwiftUI
import PhotosUI
import JiPinCore

/// Disk writes are serialized independently from rendering, so an older autosave
/// cannot replace the snapshot saved by the close button.
private actor IDPhotoPersistenceLane {
    private var revisions: [UUID: Int] = [:]
    func save(project: IDPhotoProject, source: Data, mask: Data?, faces: [IDPhotoFaceRegion],
              thumbnail: Data?, algorithm: String, revision: Int) throws {
        guard revision >= (revisions[project.id] ?? -1) else { return }
        try IDPhotoDraftStore.shared.save(project: project, sourceData: source, maskData: mask,
                                         faceRegions: faces, thumbnailJPEG: thumbnail,
                                         algorithmVersion: algorithm)
        revisions[project.id] = revision
    }
}

private actor IDPhotoPreparationLane {
    static let shared = IDPhotoPreparationLane()
    func prepare(source: Data, mask: Data?) throws -> IDPhotoPreparedSource {
        try Task.checkCancellation()
        let prepared = try IDPhotoPreparedSource(sourceData: source, maskData: mask)
        try Task.checkCancellation()
        return prepared
    }
}

private actor IDPhotoPreviewLane {
    private var comparisonCache: (source: ObjectIdentifier, crop: IDPhotoCrop, size: CGSize, image: UIImage)?
    func render(project: IDPhotoProject, prepared: IDPhotoPreparedSource,
                faces: [IDPhotoFaceRegion]) throws -> (UIImage, UIImage) {
        try Task.checkCancellation()
        let result = try IDPhotoRenderer.render(project: project, prepared: prepared, faces: faces, maxSide: 1000)
        try Task.checkCancellation()
        var original = project
        original.keepOriginalBackground = true
        original.adjustments = .init()
        original.strokes = []
        let comparison: UIImage
        if let cached = comparisonCache, cached.source == ObjectIdentifier(prepared), cached.crop == project.crop,
           cached.size == project.template.pixelSize {
            comparison = cached.image
        } else {
            comparison = try IDPhotoRenderer.render(project: original, prepared: prepared, faces: faces, maxSide: 1000)
            comparisonCache = (ObjectIdentifier(prepared), project.crop, project.template.pixelSize, comparison)
        }
        return (result, comparison)
    }
}

@MainActor
final class IDPhotoSession: ObservableObject, Identifiable {
    typealias AnalysisProvider = @Sendable (Data, CGSize) async throws -> IDPhotoAnalysis
    private let analysisProvider: AnalysisProvider
    private var hasManuallyAdjustedCrop = false
    let id = UUID()
    @Published private(set) var project: IDPhotoProject
    @Published private(set) var preview: UIImage?
    @Published private(set) var originalPreview: UIImage?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isRendering = false
    @Published private(set) var isClosing = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published private(set) var analysisWarning: String?
    @Published private(set) var hasMask = false
    @Published private(set) var canSmooth = false
    @Published private(set) var undoCount = 0
    @Published private(set) var redoCount = 0
    private(set) var sourceData: Data
    private(set) var sourceSize: CGSize
    private(set) var maskData: Data?
    private(set) var faces: [IDPhotoFaceRegion] = []
    private(set) var algorithmVersion = "vision-person-v1"
    private var prepared: IDPhotoPreparedSource?
    private let previewLane = IDPhotoPreviewLane()
    private let persistenceLane = IDPhotoPersistenceLane()
    private var analyzeTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var prepareTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var analysisID = UUID()
    private var revision = 0
    private var previewWorkerID = UUID()
    private var isActive = true
    private var undoProjects: [IDPhotoProject] = []
    private var redoProjects: [IDPhotoProject] = []
    private var transaction: IDPhotoProject?

    init(sourceData: Data, template: IDPhotoTemplate,
         analysisProvider: @escaping AnalysisProvider = { data, size in
             try await IDPhotoSegmentation.analyze(sourceData: data, outputSize: size)
         }) {
        self.analysisProvider = analysisProvider
        self.sourceData = sourceData
        sourceSize = ImageIOHelpers.pixelSize(of: sourceData)
        project = IDPhotoProject(template: template)
    }

    init(draft: IDPhotoLoadedDraft,
         analysisProvider: @escaping AnalysisProvider = { data, size in
             try await IDPhotoSegmentation.analyze(sourceData: data, outputSize: size)
         }) {
        self.analysisProvider = analysisProvider
        // A reopened draft's saved composition is intentional, even if its original
        // analysis was interrupted. Retrying must not reposition an existing draft.
        hasManuallyAdjustedCrop = true
        project = draft.project
        sourceData = draft.sourceData
        sourceSize = ImageIOHelpers.pixelSize(of: draft.sourceData)
        maskData = draft.maskData
        faces = draft.faceRegions
        hasMask = draft.maskData != nil
        canSmooth = faces.count == 1 && hasMask && (faces.first?.skinPolygon?.count ?? 0) >= 3 && !(faces.first?.protectedPolygons.isEmpty ?? true)
        algorithmVersion = draft.algorithmVersion
        analysisWarning = draft.maskIssue
        if !hasMask {
            project.keepOriginalBackground = true
            if analysisWarning == nil { analysisWarning = "此草稿尚无可用的人像轮廓，目前保留原背景。可重试识别后换底。" }
        }
        if !canSmooth { project.adjustments.smoothing = 0 }
    }

    func start(reanalyze: Bool = true) {
        guard isActive else { return }
        if reanalyze { analyze() } else { prepareAndPreview() }
    }

    func beginTransaction() {
        guard isActive, !isClosing else { return }
        if transaction == nil { transaction = project }
    }

    func edit(_ change: (inout IDPhotoProject) -> Void) {
        guard isActive, !isClosing else { return }
        let standalone = transaction == nil
        if standalone { beginTransaction() }
        let priorCrop = project.crop
        change(&project)
        if project.crop != priorCrop { hasManuallyAdjustedCrop = true }
        revision += 1
        schedulePreview()
        if standalone { endTransaction() }
    }

    func editCrop(_ change: (inout IDPhotoCrop) -> Void) {
        guard isActive, !isClosing else { return }
        // Also respects an explicit reset/edge drag that leaves the numeric crop
        // unchanged; that is still an intentional composition choice.
        hasManuallyAdjustedCrop = true
        edit { change(&$0.crop) }
    }

    func endTransaction() {
        guard let before = transaction else { return }
        transaction = nil
        guard before != project else { return }
        undoProjects.append(before)
        if undoProjects.count > 50 { undoProjects.removeFirst(undoProjects.count - 50) }
        redoProjects.removeAll()
        project.updatedAt = Date()
        updateHistoryCounts()
        scheduleSave()
    }

    func undo() {
        guard isActive, !isClosing else { return }
        endTransaction()
        guard let before = undoProjects.popLast() else { return }
        redoProjects.append(project)
        project = before
        didRestoreHistory()
    }

    func redo() {
        guard isActive, !isClosing else { return }
        guard let after = redoProjects.popLast() else { return }
        undoProjects.append(project)
        project = after
        didRestoreHistory()
    }

    private func didRestoreHistory() {
        if !hasMask { project.keepOriginalBackground = true }
        if !canSmooth { project.adjustments.smoothing = 0 }
        project.updatedAt = Date()
        revision += 1
        updateHistoryCounts()
        schedulePreview()
        scheduleSave()
    }

    private func updateHistoryCounts() {
        undoCount = undoProjects.count
        redoCount = redoProjects.count
    }

    func analyze() {
        guard isActive, !isClosing else { return }
        analyzeTask?.cancel()
        let token = UUID()
        analysisID = token
        let data = sourceData
        let analyzedOutputSize = project.template.pixelSize
        let analyze = analysisProvider
        isAnalyzing = true
        analysisWarning = nil
        if prepared == nil { prepareAndPreview() }
        analyzeTask = Task {
            do {
                let result = try await analyze(data, analyzedOutputSize)
                try Task.checkCancellation()
                guard isActive, analysisID == token else { return }
                maskData = result.maskData
                hasMask = result.maskData != nil
                faces = result.faces
                canSmooth = faces.count == 1 && hasMask && (faces.first?.skinPolygon?.count ?? 0) >= 3 && !(faces.first?.protectedPolygons.isEmpty ?? true)
                algorithmVersion = result.algorithmVersion
                analysisWarning = result.warning
                applyAutomaticFraming(result, analyzedOutputSize: analyzedOutputSize)
                if !hasMask { project.keepOriginalBackground = true }
                if !canSmooth { project.adjustments.smoothing = 0 }
                isAnalyzing = false
                revision += 1
                prepareAndPreview()
                scheduleSave()
            } catch is CancellationError {
                if analysisID == token { isAnalyzing = false }
            } catch {
                guard isActive, analysisID == token else { return }
                isAnalyzing = false
                analysisWarning = "人物识别暂时不可用，可保留原背景调整尺寸，或重试。\(error.localizedDescription)"
                project.keepOriginalBackground = true
                revision += 1
                prepareAndPreview()
                scheduleSave()
            }
        }
    }

    private func applyAutomaticFraming(_ result: IDPhotoAnalysis, analyzedOutputSize: CGSize) {
        guard !hasManuallyAdjustedCrop, let suggested = result.suggestedCrop else { return }
        let uprightSize = result.sourceSize ?? sourceSize
        func crop(for template: IDPhotoTemplate) -> IDPhotoCrop {
            guard template.pixelSize != analyzedOutputSize, let face = result.faces.first else { return suggested }
            return IDPhotoGeometry.autoCrop(face: face, sourceSize: uprightSize, outputSize: template.pixelSize,
                                           personBounds: result.personBounds, headBounds: result.headBounds)
        }
        project.crop = crop(for: project.template)
        // Analysis is the initial framing baseline, not a color/brightness edit.
        // Rebase pending non-crop history so undoing a color cannot undo framing.
        for index in undoProjects.indices { undoProjects[index].crop = crop(for: undoProjects[index].template) }
        for index in redoProjects.indices { redoProjects[index].crop = crop(for: redoProjects[index].template) }
        if var pending = transaction {
            pending.crop = crop(for: pending.template)
            transaction = pending
        }
    }

    private func prepareAndPreview() {
        prepareTask?.cancel()
        previewTask?.cancel()
        previewTask = nil
        previewWorkerID = UUID()
        prepared = nil
        let data = sourceData, mask = maskData, token = analysisID
        isRendering = true
        prepareTask = Task {
            do {
                let cached = try await IDPhotoPreparationLane.shared.prepare(source: data, mask: mask)
                try Task.checkCancellation()
                guard isActive, token == analysisID else { return }
                prepared = cached
                sourceSize = cached.sourceSize
                schedulePreview()
            } catch is CancellationError { } catch {
                guard isActive, token == analysisID else { return }
                isRendering = false
                errorMessage = "照片预览失败：\(error.localizedDescription)"
            }
        }
    }

    private func schedulePreview() {
        guard let prepared, isActive else { return }
        isRendering = true
        // One in-flight frame, followed by the latest parameters. A trailing-edge
        // debounce would starve 60 Hz drags and leave the photograph frozen.
        guard previewTask == nil else { return }
        let worker = UUID()
        previewWorkerID = worker
        previewTask = Task {
            while isActive, previewWorkerID == worker, !Task.isCancelled {
                var snapshot = project
                if !hasMask { snapshot.keepOriginalBackground = true }
                let expected = revision, snapshotFaces = faces
                do {
                    let images = try await previewLane.render(project: snapshot, prepared: prepared, faces: snapshotFaces)
                    try Task.checkCancellation()
                    guard isActive, previewWorkerID == worker else { return }
                    // This serialized worker publishes frames in increasing order.
                    // Newer input is picked up immediately on the next iteration.
                    preview = images.0
                    originalPreview = images.1
                    if revision == expected {
                        isRendering = false
                        previewTask = nil
                        return
                    }
                    try await Task.sleep(nanoseconds: 16_000_000)
                } catch is CancellationError { return } catch {
                    guard isActive, previewWorkerID == worker else { return }
                    isRendering = false
                    previewTask = nil
                    errorMessage = "预览失败：\(error.localizedDescription)"
                    return
                }
            }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
                _ = await persistNow()
            } catch { }
        }
    }

    @discardableResult
    func persistNow() async -> Bool {
        let snapshot = project, data = sourceData, mask = maskData, regions = faces
        let version = algorithmVersion, expected = revision
        let image = preview
        do {
            let thumbnail = await Task.detached(priority: .utility) { () -> Data? in
                guard let image else { return nil }
                let size = image.size
                let scale = min(1, 240 / max(size.width, size.height))
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                return UIGraphicsImageRenderer(size: CGSize(width: size.width * scale, height: size.height * scale), format: format)
                    .jpegData(withCompressionQuality: 0.8) { _ in image.draw(in: CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale))) }
            }.value
            try await persistenceLane.save(project: snapshot, source: data, mask: mask,
                                                        faces: regions, thumbnail: thumbnail,
                                                        algorithm: version, revision: expected)
            return true
        } catch {
            errorMessage = "草稿未能保存，请保留此页面后重试。\(error.localizedDescription)"
            return false
        }
    }

    func close() async -> Bool {
        guard !isClosing else { return false }
        endTransaction()
        isClosing = true
        saveTask?.cancel()
        // Stop an in-flight analysis before freezing the final draft snapshot.
        analysisID = UUID()
        analyzeTask?.cancel()
        isAnalyzing = false
        if !hasMask {
            project.keepOriginalBackground = true; revision += 1
            analysisWarning = "人物识别已暂停，目前保留原背景。可重试识别后换底。"
        }
        guard await persistNow() else {
            isClosing = false
            prepareAndPreview()
            return false
        }
        stop()
        return true
    }

    func replaceSource(_ data: Data) async -> Bool {
        guard isActive, !isClosing, !Task.isCancelled else { return false }
        endTransaction()
        analysisID = UUID()
        analyzeTask?.cancel(); prepareTask?.cancel(); previewTask?.cancel(); saveTask?.cancel()
        isAnalyzing = false
        if !hasMask {
            project.keepOriginalBackground = true; revision += 1
            analysisWarning = "人物识别已暂停，目前保留原背景。可重试识别后换底。"
        }
        guard await persistNow(), !Task.isCancelled else {
            prepareAndPreview()
            return false
        }
        let template = project.template
        project = IDPhotoProject(template: template)
        sourceData = data; sourceSize = ImageIOHelpers.pixelSize(of: data)
        maskData = nil; faces = []; prepared = nil; preview = nil; originalPreview = nil
        hasMask = false; canSmooth = false; analysisWarning = nil; notice = nil
        revision = 0; hasManuallyAdjustedCrop = false
        undoProjects = []; redoProjects = []; transaction = nil
        updateHistoryCounts()
        analyze()
        return true
    }

    func stop() {
        isActive = false
        previewWorkerID = UUID()
        analysisID = UUID()
        analyzeTask?.cancel()
        prepareTask?.cancel()
        previewTask?.cancel()
        saveTask?.cancel()
    }

    private var outputConfiguration: IDPhotoExportConfiguration? {
        try? IDPhotoExportConfiguration(template: project.template, quality: project.exportQuality)
    }
    var outputSummary: String { outputConfiguration?.summary ?? "请检查输出尺寸" }
    var isLowResolution: Bool {
        outputConfiguration?.requiresUpscaling(sourceSize: sourceSize, crop: project.crop) ?? false
    }

    func exportSnapshot() -> IDPhotoExportSnapshot {
        endTransaction()
        if !hasMask { project.keepOriginalBackground = true }
        if !canSmooth { project.adjustments.smoothing = 0 }
        return IDPhotoExportSnapshot(project: project, sourceData: sourceData, maskData: maskData, faces: faces, sourceSize: sourceSize)
    }
}

struct IDPhotoExportSnapshot: Identifiable {
    let id = UUID()
    let project: IDPhotoProject
    let sourceData: Data
    let maskData: Data?
    let faces: [IDPhotoFaceRegion]
    let sourceSize: CGSize
}
