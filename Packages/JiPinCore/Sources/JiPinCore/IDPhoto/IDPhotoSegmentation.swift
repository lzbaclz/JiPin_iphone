import CoreML
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// All geometry uses the upright photo, normalized from its top-left corner.
/// The PNG is a soft luminance matte (white = person); it is never a fabricated fallback.
public struct IDPhotoAnalysis: Sendable {
    public let maskData: Data?
    public let faces: [IDPhotoFaceRegion]
    public let suggestedCrop: IDPhotoCrop?
    public let warning: String?
    public let algorithmVersion: String
    /// Diagnostic details for local QA; callers should present `warning` to users.
    public let diagnostic: String?
    /// Captured geometry lets the editor reframe for a template changed while
    /// analysis was running, without running Vision a second time.
    public let sourceSize: CGSize?
    public let personBounds: CGRect?
    public let headBounds: CGRect?

    public init(maskData: Data?, faces: [IDPhotoFaceRegion], suggestedCrop: IDPhotoCrop?,
                warning: String?, algorithmVersion: String = IDPhotoSegmentation.algorithmVersion,
                diagnostic: String? = nil, sourceSize: CGSize? = nil,
                personBounds: CGRect? = nil, headBounds: CGRect? = nil) {
        self.maskData = maskData
        self.faces = faces
        self.suggestedCrop = suggestedCrop
        self.warning = warning
        self.algorithmVersion = algorithmVersion
        self.diagnostic = diagnostic
        self.sourceSize = sourceSize
        self.personBounds = personBounds
        self.headBounds = headBounds
    }
}

public enum IDPhotoSegmentation {
    public static let algorithmVersion = "vision-person-accurate-v1-landmarks76-v1"
    private static let queue = DispatchQueue(label: "com.jipin.id-photo.analysis", qos: .userInitiated)

    /// Only one Vision analysis runs at a time. Cancellation resumes the caller immediately
    /// and forwards cancellation to the active Vision request, including when already queued.
    public static func analyze(sourceData: Data, outputSize: CGSize = CGSize(width: 295, height: 413)) async throws -> IDPhotoAnalysis {
        let operation = AnalysisOperation()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                operation.install(continuation)
                queue.async {
                    guard !operation.isCancelled else { return }
                    let result: Result<IDPhotoAnalysis, Error> = Result {
                        try autoreleasepool {
                            try perform(sourceData: sourceData, outputSize: outputSize, operation: operation)
                        }
                    }
                    operation.finish(result)
                }
            }
        } onCancel: {
            operation.cancel()
        }
    }

    private static func perform(sourceData: Data, outputSize: CGSize, operation: AnalysisOperation) throws -> IDPhotoAnalysis {
        guard let image = ImageIOHelpers.thumbnail(from: sourceData, maxLongSide: 1536) else {
            throw IDPhotoRenderError.invalidImage
        }
        let size = CGSize(width: image.width, height: image.height)
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        let request = VNDetectFaceLandmarksRequest()
        request.constellation = .constellation76Points
        configureSimulatorCompute(for: request)
        operation.register(request)
        do {
            try handler.perform([request])
        } catch {
            try operation.checkCancellation()
            return IDPhotoAnalysis(maskData: nil, faces: [], suggestedCrop: nil,
                                   warning: "暂时无法识别人像。可以重试、换一张清晰正面照片，或保留原背景仅调整尺寸。",
                                   diagnostic: diagnostic(error, stage: "face-landmarks"), sourceSize: size)
        }
        try operation.checkCancellation()
        let observations = (request.results ?? []).filter { $0.confidence >= 0.5 }
        let faces = observations.map(faceRegion)
        guard faces.count == 1 else {
            return IDPhotoAnalysis(maskData: nil, faces: faces, suggestedCrop: nil,
                warning: faces.isEmpty ? "没有识别到清晰的人脸。请换用单人正面照，也可以保留原背景仅调整尺寸。"
                : "检测到多张人脸，请换用单人照片。当前可以保留原背景仅调整尺寸。", sourceSize: size)
        }

        let segmentation = VNGeneratePersonSegmentationRequest()
        segmentation.qualityLevel = .accurate
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
        configureSimulatorCompute(for: segmentation)
        operation.register(segmentation)
        let basicCrop = IDPhotoGeometry.autoCrop(face: faces.first, sourceSize: size, outputSize: outputSize)
        do {
            try handler.perform([segmentation])
            try operation.checkCancellation()
            guard let buffer = segmentation.results?.first?.pixelBuffer,
                  let geometry = personGeometry(buffer: buffer, face: faces[0].faceRect),
                  let mask = maskImage(buffer),
                  let data = encodeMask(mask) else {
                return IDPhotoAnalysis(maskData: nil, faces: faces, suggestedCrop: basicCrop,
                                       warning: "没有得到可靠的人像轮廓。请重试或换图，也可以保留原背景继续调整尺寸。", sourceSize: size)
            }
            let crop = IDPhotoGeometry.autoCrop(face: faces[0], sourceSize: size, outputSize: outputSize,
                                                personBounds: geometry.person, headBounds: geometry.head)
            var warnings: [String] = []
            if (geometry.head?.minY ?? geometry.person.minY) < 0.012 { warnings.append("原片头顶接近边缘，请检查头发是否完整。") }
            if faces[0].skinPolygon == nil { warnings.append("面部关键点不够清晰，已停用自动磨皮。") }
            return IDPhotoAnalysis(maskData: data, faces: faces, suggestedCrop: crop,
                                   warning: warnings.isEmpty ? nil : warnings.joined(separator: " "),
                                   sourceSize: size, personBounds: geometry.person, headBounds: geometry.head)
        } catch {
            try operation.checkCancellation()
            return IDPhotoAnalysis(maskData: nil, faces: faces, suggestedCrop: basicCrop,
                                   warning: "当前未能完成人像抠图。可以重试或换图；保留原背景时仍可调整尺寸。",
                                   diagnostic: diagnostic(error, stage: "person-segmentation"), sourceSize: size)
        }
    }

    private static func configureSimulatorCompute(for request: VNRequest) {
        #if targetEnvironment(simulator)
        // The simulator has no Neural Engine. Use only a CPU that Vision itself
        // advertises for each stage; real devices retain Apple's default scheduling.
        if let stages = try? request.supportedComputeStageDevices {
            for (stage, devices) in stages {
                if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        }
        #endif
    }

    private static func diagnostic(_ error: Error, stage: String) -> String {
        let error = error as NSError
        return "\(stage): \(error.domain) (\(error.code)): \(error.localizedDescription)"
    }

    /// Preserve Vision's raw coverage samples, without ICC/gamma transforms. The
    /// request explicitly produces an 8-bit one-component soft matte.
    private static func maskImage(_ buffer: CVPixelBuffer) -> CGImage? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8 else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let address = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        var bytes = Data(count: width * height)
        bytes.withUnsafeMutableBytes { destination in
            guard let base = destination.baseAddress else { return }
            for row in 0..<height {
                base.advanced(by: row * width).copyMemory(from: address.advanced(by: row * stride), byteCount: width)
            }
        }
        guard let provider = CGDataProvider(data: bytes as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func encodeMask(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func faceRegion(_ observation: VNFaceObservation) -> IDPhotoFaceRegion {
        let box = observation.boundingBox
        let rect = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        guard let landmarks = observation.landmarks, landmarks.confidence >= 0.5,
              let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye,
              let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow,
              let lips = landmarks.outerLips, let nose = landmarks.nose,
              [leftEye, rightEye, leftBrow, rightBrow, lips, nose].allSatisfy({ $0.pointCount >= 3 }),
              abs(observation.yaw?.doubleValue ?? 0) < 0.45 else {
            return IDPhotoFaceRegion(faceRect: rect)
        }
        func points(_ region: VNFaceLandmarkRegion2D) -> [CGPoint] {
            region.normalizedPoints.map { point in
                CGPoint(x: box.minX + point.x * box.width, y: 1 - (box.minY + point.y * box.height))
            }
        }
        func rectangle(around points: [CGPoint], margin: CGFloat) -> [CGPoint] {
            guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return [] }
            return corners(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -margin, dy: -margin))
        }
        // Protect a continuous eye/brow band as well as the individual features. This
        // deliberately includes most glasses frames, which Vision does not label as skin.
        let eyePoints = points(leftEye) + points(rightEye) + points(leftBrow) + points(rightBrow)
        let protected = [rectangle(around: eyePoints, margin: rect.height * 0.055),
                         rectangle(around: points(lips), margin: rect.height * 0.06),
                         rectangle(around: points(nose), margin: rect.height * 0.035)]
        // Stay well inside the contour and hairline rather than treating the whole
        // person matte or face rectangle as skin. Preserve uncertain cheeks/forehead.
        let skinRect = rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.09)
        let skin = (0..<48).map { index -> CGPoint in
            let angle = CGFloat(index) * 2 * .pi / 48
            return CGPoint(x: skinRect.midX + cos(angle) * skinRect.width / 2,
                           y: skinRect.midY + sin(angle) * skinRect.height / 2)
        }
        return IDPhotoFaceRegion(faceRect: rect, protectedPolygons: protected, skinPolygon: skin)
    }

    private static func corners(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
            .map { CGPoint(x: min(max($0.x, 0), 1), y: min(max($0.y, 0), 1)) }
    }

    /// Flood-fill the soft matte's opaque core starting within the detected face.
    /// This avoids using an unrelated foreground speck as the top of the person's head.
    private static func personGeometry(buffer: CVPixelBuffer, face: CGRect) -> (person: CGRect, head: CGRect?)? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let address = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = address.assumingMemoryBound(to: UInt8.self)
        let startX = min(max(Int(face.midX * CGFloat(width)), 0), width - 1)
        let startY = min(max(Int(face.midY * CGFloat(height)), 0), height - 1)
        guard pixels[startY * stride + startX] > 100 else { return nil }
        var visited = [Bool](repeating: false, count: width * height)
        var pending = [startY * width + startX]
        visited[pending[0]] = true
        var cursor = 0, minX = startX, maxX = startX, minY = startY, maxY = startY
        while cursor < pending.count {
            let index = pending[cursor]; cursor += 1
            let x = index % width, y = index / width
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let next = ny * width + nx
                if !visited[next] && pixels[ny * stride + nx] > 100 {
                    visited[next] = true; pending.append(next)
                }
            }
        }
        let coverage = Double(pending.count) / Double(width * height)
        guard coverage > 0.015, coverage < 0.995 else { return nil }
        let person = CGRect(x: CGFloat(minX) / CGFloat(width), y: CGFloat(minY) / CGFloat(height),
                            width: CGFloat(maxX - minX + 1) / CGFloat(width), height: CGFloat(maxY - minY + 1) / CGFloat(height))

        // Use head-only scan lines, not the whole person's width (arms, a helmet,
        // or an accidentally connected flag can be much wider than the hair).
        // Each accepted opaque run must cross the face's horizontal band. A flag
        // elsewhere in the same connected component therefore does not widen it.
        let headStart = max(minY, max(0, Int((face.minY - face.height * 0.9) * CGFloat(height))))
        // Stop near eye/nose level. Below this, a forward-leaning person's
        // shoulders or a high collar can already form the row's opaque span.
        let headEnd = min(height - 1, Int((face.minY + face.height * 0.55) * CGFloat(height)))
        let faceLeft = Int(face.minX * CGFloat(width)), faceRight = Int(face.maxX * CGFloat(width))
        let widestRun = max(1, Int(face.width * CGFloat(width) * 2.3))
        var headMinX = width, headMaxX = -1, headMinY = height, headMaxY = -1
        if headStart <= headEnd {
            for y in headStart...headEnd {
                var x = 0
                var best: (left: Int, right: Int, distance: Int)?
                while x < width {
                    guard visited[y * width + x], pixels[y * stride + x] > 100 else { x += 1; continue }
                    let left = x
                    while x < width, visited[y * width + x], pixels[y * stride + x] > 100 { x += 1 }
                    let right = x - 1
                    guard right >= faceLeft, left <= faceRight, right - left + 1 <= widestRun else { continue }
                    let distance = max(left - startX, startX - right, 0)
                    if best == nil || distance < best!.distance { best = (left, right, distance) }
                }
                if let best {
                    headMinX = min(headMinX, best.left); headMaxX = max(headMaxX, best.right)
                    headMinY = min(headMinY, y); headMaxY = max(headMaxY, y)
                }
            }
        }
        let head: CGRect?
        if headMaxX > headMinX, headMaxY > headMinY {
            head = CGRect(x: CGFloat(headMinX) / CGFloat(width), y: CGFloat(headMinY) / CGFloat(height),
                          width: CGFloat(headMaxX - headMinX + 1) / CGFloat(width), height: CGFloat(headMaxY - headMinY + 1) / CGFloat(height))
        } else { head = nil }
        return (person, head)
    }
}

private final class AnalysisOperation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var requests: [VNRequest] = []
    private var continuation: CheckedContinuation<IDPhotoAnalysis, Error>?
    private var finished = false

    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    func checkCancellation() throws { if isCancelled { throw CancellationError() } }

    func install(_ continuation: CheckedContinuation<IDPhotoAnalysis, Error>) {
        lock.lock()
        if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        lock.unlock()
    }

    func register(_ request: VNRequest) {
        lock.lock()
        requests.append(request)
        let cancelNow = cancelled
        lock.unlock()
        if cancelNow { request.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let requests = self.requests
        lock.unlock()
        requests.forEach { $0.cancel() }
        finish(.failure(CancellationError()))
    }

    func finish(_ result: Result<IDPhotoAnalysis, Error>) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        requests.removeAll()
        lock.unlock()
        continuation?.resume(with: result)
    }
}
