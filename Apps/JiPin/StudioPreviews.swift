import SwiftUI
import UIKit
import JiPinCore

/// Original, deterministic illustrations for trying the editor without a photo-library grant.
enum StudioArtwork {
    static func image(index: Int, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.scaleBy(x: size.width / 600, y: size.height / 800)
            func fill(_ hex: String, _ rect: CGRect) {
                cg.setFillColor(UIColor(hex: hex).cgColor)
                cg.fill(rect)
            }
            func circle(_ hex: String, x: CGFloat, y: CGFloat, diameter: CGFloat) {
                cg.setFillColor(UIColor(hex: hex).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
            }
            func hill(_ hex: String, y: CGFloat, rise: CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: -30, y: y))
                path.addCurve(to: CGPoint(x: 640, y: y + 20), controlPoint1: CGPoint(x: 130, y: y - rise), controlPoint2: CGPoint(x: 370, y: y + rise))
                path.addLine(to: CGPoint(x: 640, y: 840))
                path.addLine(to: CGPoint(x: -30, y: 840))
                path.close()
                UIColor(hex: hex).setFill()
                path.fill()
            }
            switch index % 6 {
            case 0:
                fill("#F2DFBC", CGRect(x: 0, y: 0, width: 600, height: 800))
                circle("#E5864D", x: 365, y: 122, diameter: 136)
                hill("#D29574", y: 360, rise: 180)
                hill("#547F80", y: 470, rise: 150)
                hill("#2D6068", y: 575, rise: 90)
                for row in 0..<5 {
                    cg.setStrokeColor(UIColor(hex: "#B7D3CB").withAlphaComponent(0.55).cgColor)
                    cg.setLineWidth(2)
                    cg.move(to: CGPoint(x: 54, y: 626 + row * 30))
                    cg.addLine(to: CGPoint(x: 360 - row * 32, y: 626 + row * 30))
                    cg.strokePath()
                }
            case 1:
                fill("#E6E8C7", CGRect(x: 0, y: 0, width: 600, height: 800))
                circle("#F8D98A", x: 60, y: 90, diameter: 145)
                hill("#A9B584", y: 400, rise: 110)
                for (x, h) in [(100, 420), (305, 500), (482, 365)] {
                    fill("#6C7052", CGRect(x: x - 8, y: 730 - h, width: 16, height: h))
                    circle("#426956", x: CGFloat(x - 90), y: CGFloat(650 - h), diameter: 180)
                    circle("#658C68", x: CGFloat(x - 76), y: CGFloat(592 - h), diameter: 145)
                }
                hill("#F3E8C6", y: 720, rise: 92)
            case 2:
                fill("#EADBD2", CGRect(x: 0, y: 0, width: 600, height: 800))
                circle("#D77D63", x: 362, y: 80, diameter: 110)
                fill("#79A5A5", CGRect(x: 64, y: 232, width: 268, height: 568))
                fill("#E8B181", CGRect(x: 346, y: 354, width: 190, height: 446))
                for row in 0..<4 {
                    for column in 0..<3 {
                        fill("#F9EDCE", CGRect(x: 94 + column * 76, y: 276 + row * 112, width: 40, height: 74))
                    }
                }
                for row in 0..<3 {
                    fill("#9E5B4C", CGRect(x: 383, y: 398 + row * 114, width: 112, height: 74))
                }
                fill("#294D54", CGRect(x: 0, y: 744, width: 600, height: 56))
            case 3:
                fill("#F5D09C", CGRect(x: 0, y: 0, width: 600, height: 800))
                circle("#FFF0C7", x: 210, y: 144, diameter: 180)
                hill("#E9A16D", y: 400, rise: 240)
                hill("#CB7157", y: 495, rise: 150)
                hill("#A64D42", y: 625, rise: 150)
            case 4:
                fill("#EDE1C9", CGRect(x: 0, y: 0, width: 600, height: 800))
                fill("#BD7364", CGRect(x: 0, y: 520, width: 600, height: 280))
                circle("#D4B287", x: 70, y: 350, diameter: 220)
                circle("#FDF3D9", x: 82, y: 322, diameter: 220)
                circle("#815244", x: 110, y: 350, diameter: 164)
                circle("#D8AD81", x: 126, y: 366, diameter: 132)
                cg.setStrokeColor(UIColor(hex: "#F8EFD7").cgColor)
                cg.setLineWidth(12)
                cg.strokeEllipse(in: CGRect(x: 278, y: 362, width: 70, height: 110))
                fill("#F9EBC9", CGRect(x: 372, y: 205, width: 18, height: 355))
                for y in stride(from: 172, through: 386, by: 62) {
                    circle("#69816C", x: 343, y: CGFloat(y), diameter: 64)
                    circle("#889B78", x: 380, y: CGFloat(y + 26), diameter: 66)
                }
            default:
                fill("#DCE3D5", CGRect(x: 0, y: 0, width: 600, height: 800))
                circle("#F5D3A0", x: 358, y: 110, diameter: 154)
                hill("#9AB9B0", y: 353, rise: 145)
                hill("#679594", y: 458, rise: 185)
                hill("#37686F", y: 607, rise: 100)
                fill("#EDD3A9", CGRect(x: 0, y: 726, width: 600, height: 74))
            }
        }
    }
}

enum StudioPreviewCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 20 * 1024 * 1024
        cache.countLimit = 100
        return cache
    }()

    static func poster(_ poster: PosterTemplate) -> UIImage {
        cached("poster-\(poster.id)") {
            let photos = SamplePhotos.make(poster.photoCount)
            let project = ProjectFactory.make(mode: .poster, photos: photos, posterID: poster.id)
            return CollageRenderer.shared.render(project: project, assets: DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })), canvasSize: poster.canvas.size(maxLongSide: 360), preview: true)
        }
    }

    static func sticker(_ sticker: StickerDefinition) -> UIImage {
        cached("sticker-\(sticker.id)") {
            var project = CollageProject(mode: .freeform)
            project.background.isHidden = true
            project.exportPreference = ExportPreference(format: .png, transparentBackground: true)
            project.objects = [LayerObject(kind: .sticker, zIndex: 0,
                transform: CanvasTransform(width: 0.82, height: sticker.category == .label ? 0.4 : 0.82),
                sticker: StickerPayload(stickerID: sticker.id))]
            return CollageRenderer.shared.render(project: project, assets: DataAssetLibrary(images: [:]), canvasSize: CGSize(width: 180, height: 180), preview: true)
        }
    }

    private static func cached(_ key: String, create: () -> UIImage) -> UIImage {
        if let image = images.object(forKey: key as NSString) { return image }
        let image = create()
        images.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4))
        return image
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let rgb = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}
