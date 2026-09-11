import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

public struct LivePhotoExport: Sendable {
    public let lease: MediaFileLease
    public let imageURL: URL
    public let videoURL: URL
    public let identifier: String
    /// Encoded motion dimensions. The still image can retain more detail than the video.
    public let size: CGSize
    public let photoSize: CGSize
    public let duration: Double
    public let coverTime: Double
    public var byteCount: Int64 {
        [imageURL, videoURL].reduce(0) { total, url in total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}

/// Creates a genuine still + QuickTime resource pair. Native PhotoKit validation is performed by the caller.
public enum LivePhotoWriter {
    public static func write(size: CGSize, duration: Double,
                             progress: (@Sendable (Double) async -> Void)? = nil,
                             draw: (CGContext, Double) throws -> Void) async throws -> LivePhotoExport {
        try Task.checkCancellation()
        guard size.width.isFinite, size.height.isFinite, size.width >= 2, size.height >= 2,
              size.width <= 3840, size.height <= 3840, size.width * size.height <= 4_194_304,
              duration.isFinite, duration >= 0.1, duration <= 3 else {
            throw LivePhotoError.encodingFailed
        }
        let size = CGSize(width: floor(size.width / 2) * 2, height: floor(size.height / 2) * 2)
        let width = Int(size.width), height = Int(size.height)
        let fps = LivePhotoPolicy.frameRate, frameCount = max(Int((duration * Double(fps)).rounded()), 1)
        let coverFrame = frameCount / 2
        let coverTime = CMTime(value: Int64(coverFrame), timescale: fps)
        let finalDuration = CMTime(value: Int64(frameCount), timescale: fps)
        let lease = try MediaFileLease.temporary(prefix: "JiPin-Live-Export")
        let imageURL = lease.directory.appendingPathComponent("still.jpg"), videoURL = lease.directory.appendingPathComponent("motion.mov")
        let identifier = UUID().uuidString
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
        var completed = false
        defer { if !completed { writer.cancelWriting() } }
        writer.metadata = [contentIdentifier(identifier)]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(width * height * 5, 600_000),
                AVVideoMaxKeyFrameIntervalKey: 30, AVVideoAllowFrameReorderingKey: false,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else { throw LivePhotoError.encodingFailed }
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        video.expectsMediaDataInRealTime = false
        let buffers = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        var metadataFormat: CMMetadataFormatDescription?
        let specifications: [[String: Any]] = [[
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "mdta/\(LivePhotoMedia.stillTimeKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataBaseDataType_SInt8 as String
        ]]
        guard CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: specifications as CFArray,
            formatDescriptionOut: &metadataFormat) == noErr else { throw LivePhotoError.encodingFailed }
        let metadata = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: metadataFormat)
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadata)
        guard writer.canAdd(video), writer.canAdd(metadata) else { throw LivePhotoError.encodingFailed }
        writer.add(video); writer.add(metadata)
        guard writer.startWriting() else { throw writer.error ?? LivePhotoError.encodingFailed }
        writer.startSession(atSourceTime: .zero)
        let still = AVMutableMetadataItem()
        still.keySpace = .quickTimeMetadata; still.key = LivePhotoMedia.stillTimeKey as NSString
        still.value = NSNumber(value: Int8(0)); still.dataType = kCMMetadataBaseDataType_SInt8 as String
        guard metadataAdaptor.append(AVTimedMetadataGroup(items: [still], timeRange: CMTimeRange(start: coverTime, duration: CMTime(value: 1, timescale: fps)))) else {
            throw writer.error ?? LivePhotoError.encodingFailed
        }
        metadata.markAsFinished()
        for index in 0..<frameCount {
            try Task.checkCancellation()
            let waitingSince = Date()
            while !video.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing, Date().timeIntervalSince(waitingSince) < 30 else { throw writer.error ?? LivePhotoError.encodingFailed }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            try autoreleasepool {
                guard let pool = buffers.pixelBufferPool else { throw LivePhotoError.encodingFailed }
                var pixelBuffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
                      let pixelBuffer else { throw LivePhotoError.encodingFailed }
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, CGColorSpace(name: CGColorSpace.sRGB)!, .shouldPropagate)
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
                guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { throw LivePhotoError.encodingFailed }
                context.setFillColor(UIColor.white.cgColor); context.fill(CGRect(origin: .zero, size: size))
                context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
                UIGraphicsPushContext(context)
                defer { UIGraphicsPopContext() }
                try draw(context, Double(index) / Double(fps))
                guard buffers.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(index), timescale: fps)) else {
                    throw writer.error ?? LivePhotoError.encodingFailed
                }
            }
            if index.isMultiple(of: 3) { await progress?(Double(index + 1) / Double(frameCount)) }
        }
        video.markAsFinished(); writer.endSession(atSourceTime: finalDuration)
        final class CancellableWriter: @unchecked Sendable {
            let writer: AVAssetWriter
            init(_ writer: AVAssetWriter) { self.writer = writer }
        }
        let cancellation = CancellableWriter(writer)
        await withTaskCancellationHandler { await writer.finishWriting() } onCancel: { cancellation.writer.cancelWriting() }
        try Task.checkCancellation()
        guard writer.status == .completed else { throw writer.error ?? LivePhotoError.encodingFailed }
        // Take the cover from the encoded middle frame. Codec colour conversion then matches playback,
        // including on iOS 17, where the writer cannot declare the newer sRGB transfer function.
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        let cover = try await generator.image(at: coverTime).image
        try Task.checkCancellation()
        try writeStill(cover, identifier: identifier, to: imageURL)
        completed = true
        await progress?(1)
        return LivePhotoExport(lease: lease, imageURL: imageURL, videoURL: videoURL, identifier: identifier,
                               size: size, photoSize: size, duration: finalDuration.seconds, coverTime: coverTime.seconds)
    }

    /// Retain the original photo detail instead of upscaling an encoded video frame.
    static func replacingStill(in export: LivePhotoExport, with image: CGImage) throws -> LivePhotoExport {
        try Task.checkCancellation()
        try writeStill(image, identifier: export.identifier, to: export.imageURL)
        return LivePhotoExport(lease: export.lease, imageURL: export.imageURL, videoURL: export.videoURL,
                               identifier: export.identifier, size: export.size,
                               photoSize: CGSize(width: image.width, height: image.height),
                               duration: export.duration, coverTime: export.coverTime)
    }

    static func contentIdentifier(_ identifier: String) -> AVMetadataItem {
        let metadata = AVMutableMetadataItem()
        metadata.identifier = .quickTimeMetadataContentIdentifier
        metadata.value = identifier as NSString
        metadata.dataType = kCMMetadataBaseDataType_UTF8 as String
        return metadata
    }

    private static func writeStill(_ image: CGImage, identifier: String, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw LivePhotoError.encodingFailed }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.96,
            kCGImagePropertyOrientation: 1,
            kCGImagePropertyMakerAppleDictionary: ["17": identifier]
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw LivePhotoError.encodingFailed }
    }
}
