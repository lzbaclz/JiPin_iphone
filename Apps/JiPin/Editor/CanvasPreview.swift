import JiPinCore
import SwiftUI

/// Finishes and displays each frame, then takes the newest request. Finger movement never cancels
/// every in-flight frame, and canvas rendering doesn't queue behind gallery thumbnails.
@MainActor final class CanvasPreview: ObservableObject {
    @Published private(set) var image: UIImage?
    private(set) var displayedFrames = 0
    private let renderer = PreviewRendering()
    private var pending: (PreviewRequest, DataAssetLibrary)?
    private var worker: Task<Void, Never>?
    private var generation = UUID()
    func submit(_ request: PreviewRequest, assets: DataAssetLibrary) {
        guard request.pixelSize.width >= 24, request.pixelSize.height >= 24 else { return }
        pending = (request, assets)
        guard worker == nil else { return }
        let token = UUID(); generation = token
        worker = Task { [weak self] in
            guard let self else { return }
            defer { if generation == token { worker = nil } }
            while let (request, assets) = pending, !Task.isCancelled, generation == token {
                pending = nil
                let started = CACurrentMediaTime()
                let frame = await renderer.render(request, assets: assets)
                guard !Task.isCancelled, generation == token else { return }
                if pending?.0.project.id == nil || pending?.0.project.id == request.project.id { image = frame; displayedFrames += 1 }
                let rest = max(1 / 60 - (CACurrentMediaTime() - started), 0)
                if rest > 0 { try? await Task.sleep(nanoseconds: UInt64(rest * 1_000_000_000)) }
            }
        }
    }
    func stop() { generation = UUID(); worker?.cancel(); worker = nil; pending = nil }
}
