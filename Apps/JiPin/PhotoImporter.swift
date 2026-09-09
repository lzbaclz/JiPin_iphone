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

    static func load(_ items: [PhotosPickerItem]) async -> (ok: [ImportedPhoto], failed: [ImportedPhoto]) {
        var ok: [ImportedPhoto] = []
        var failed: [ImportedPhoto] = []
        for (index, item) in items.enumerated() {
            switch await loadOne(item, index: index) {
            case .ok(let photo):
                ok.append(photo)
            case .failed(let photo):
                failed.append(photo)
            }
        }
        return (ok, failed)
    }

    private enum LoadOutcome {
        case ok(ImportedPhoto)
        case failed(ImportedPhoto)
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
                guard let stripped = ImageIOHelpers.strippedJPEG(from: data, quality: 0.95) else {
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
                        utType: UTType.jpeg.identifier
                    )
                )
            } catch {
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
            guard let cgImage = image.cgImage,
                  let data = ImageIOHelpers.jpegData(from: cgImage, quality: 0.95)
            else { return nil }
            return ImportedPhoto(
                filename: "照片 \(index + 1)",
                data: data,
                pixelSize: ImageIOHelpers.pixelSize(of: data),
                utType: UTType.jpeg.identifier
            )
        }
    }
}

enum SamplePhotos {
    static func make(_ count: Int) -> [ImportedPhoto] {
        let colors: [(UIColor, String)] = [
            (UIColor(red: 0.98, green: 0.45, blue: 0.32, alpha: 1), "旅行"),
            (UIColor(red: 0.95, green: 0.78, blue: 0.42, alpha: 1), "日常"),
            (UIColor(red: 0.45, green: 0.67, blue: 0.86, alpha: 1), "海边"),
            (UIColor(red: 0.62, green: 0.80, blue: 0.50, alpha: 1), "公园"),
            (UIColor(red: 0.76, green: 0.58, blue: 0.85, alpha: 1), "城市"),
            (UIColor(red: 0.95, green: 0.62, blue: 0.70, alpha: 1), "节日")
        ]
        return (0..<count).compactMap { index in
            let item = colors[index % colors.count]
            let image = render(color: item.0, title: item.1, number: index + 1)
            guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
            return ImportedPhoto(
                filename: "示例 \(index + 1).jpg",
                data: data,
                pixelSize: image.size,
                utType: UTType.jpeg.identifier
            )
        }
    }

    private static func render(color: UIColor, title: String, number: Int) -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.18).setFill()
            UIBezierPath(ovalIn: CGRect(x: 200, y: 240, width: 800, height: 800)).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let text = "\(title)\n\(number)" as NSString
            let textSize = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attrs
            )
        }
    }
}
