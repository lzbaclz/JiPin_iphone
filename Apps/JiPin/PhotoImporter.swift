import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import JiPinCore
import ImageIO

enum PhotoImporter {
    static var stillImages: PHPickerFilter {
        .any(of: [.images, .livePhotos])
    }

    static func load(_ items: [PhotosPickerItem], progress: (@MainActor (Int, Int) -> Void)? = nil) async -> (ok: [ImportedPhoto], failed: [ImportedPhoto]) {
        var ok: [ImportedPhoto] = []
        var failed: [ImportedPhoto] = []
        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            await progress?(index, items.count)
            switch await loadOne(item, index: index) {
            case .ok(let photo):
                ok.append(photo)
            case .failed(let photo):
                failed.append(photo)
            case .cancelled:
                return (ok, failed)
            }
            await progress?(index + 1, items.count)
        }
        return (ok, failed)
    }

    private enum LoadOutcome {
        case ok(ImportedPhoto)
        case failed(ImportedPhoto)
        case cancelled
    }

    private static func loadOne(_ item: PhotosPickerItem, index: Int) async -> LoadOutcome {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    if attempt < 2 {
                        try await Task.sleep(nanoseconds: 1_200_000_000)
                        continue
                    }
                    return .failed(ImportedPhoto(
                        filename: "照片 \(index + 1)",
                        data: Data(),
                        pixelSize: .zero,
                        utType: "public.image",
                        loadFailed: true,
                        failureReason: "无法读取所选照片。如果原图还在 iCloud，请联网后重试。"
                    ))
                }
                let size = ImageIOHelpers.pixelSize(of: data)
                if size == .zero {
                    return .failed(ImportedPhoto(
                        filename: "照片 \(index + 1)",
                        data: Data(),
                        pixelSize: .zero,
                        utType: "public.image",
                        loadFailed: true,
                        failureReason: "照片文件损坏或格式无法识别。"
                    ))
                }
                if Task.isCancelled { return .cancelled }
                guard let stripped = ImageIOHelpers.sanitizedImageData(from: data) else {
                    return .failed(ImportedPhoto(
                        filename: "照片 \(index + 1)",
                        data: Data(),
                        pixelSize: .zero,
                        utType: "public.image",
                        loadFailed: true,
                        failureReason: "照片无法解码，未导入原文件以免带上位置信息。"
                    ))
                }
                return .ok(
                    ImportedPhoto(
                        filename: "照片 \(index + 1)",
                        data: stripped,
                        pixelSize: ImageIOHelpers.pixelSize(of: stripped),
                        utType: ImageIOHelpers.typeIdentifier(of: stripped)
                    )
                )
            } catch {
                if Task.isCancelled || error is CancellationError { return .cancelled }
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    continue
                }
                return .failed(ImportedPhoto(
                    filename: "照片 \(index + 1)",
                    data: Data(),
                    pixelSize: .zero,
                    utType: "public.image",
                    loadFailed: true,
                    failureReason: Self.importFailureReason(error)
                ))
            }
        }
        return .failed(ImportedPhoto(
            filename: "照片 \(index + 1)",
            data: Data(),
            pixelSize: .zero,
            utType: "public.image",
            loadFailed: true,
            failureReason: lastError.map(Self.importFailureReason) ?? "无法读取所选照片。如果原图还在 iCloud，请联网后重试。"
        ))
    }

    public static func importFailureReason(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return "这张照片可能还在 iCloud。当前网络不可用，请联网后重试；断网时无法获取仅在云端的原图。"
        }
        let text = ns.localizedDescription.lowercased()
        if text.contains("icloud") || text.contains("cloud") || text.contains("ckerror") {
            return "这张照片尚未下载到本机。请等待系统下载完成后重试。"
        }
        return ns.localizedDescription
    }

    static func loadImages(_ images: [UIImage]) -> [ImportedPhoto] {
        images.enumerated().compactMap { index, image in
            guard let data = ImageIOHelpers.sanitizedImageData(from: image, maxLongSide: 8192, maxPixelCount: 16_777_216)
            else { return nil }
            return ImportedPhoto(
                filename: "照片 \(index + 1)",
                data: data,
                pixelSize: ImageIOHelpers.pixelSize(of: data),
                utType: ImageIOHelpers.typeIdentifier(of: data)
            )
        }
    }
}

enum SamplePhotos {
    private static let examples: [Data] = (0..<6).compactMap { index in
        autoreleasepool {
            StudioArtwork.image(index: index, size: CGSize(width: 1200, height: 1600)).jpegData(compressionQuality: 0.95)
        }
    }

    static func make(_ count: Int) -> [ImportedPhoto] {
        guard count > 0, !examples.isEmpty else { return [] }
        return (0..<count).map { index in
            ImportedPhoto(filename: "示例插画 \(index + 1)", data: examples[index % examples.count],
                          pixelSize: CGSize(width: 1200, height: 1600), utType: UTType.jpeg.identifier)
        }
    }
}
