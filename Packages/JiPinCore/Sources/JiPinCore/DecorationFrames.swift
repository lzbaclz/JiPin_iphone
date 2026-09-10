import CoreGraphics
import Foundation

public struct CanvasDecoration: Codable, Hashable, Sendable {
    public var frameID: String
    public var width: Double
    public init(frameID: String, width: Double = 0.065) { self.frameID = frameID; self.width = width }
}

public struct DecorationFrame: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let colorHex: String
}

public enum DecorationFrameCatalog {
    public static let all: [DecorationFrame] = [
        .init(id: "cream-lace", name: "奶油花边", subtitle: "像一块甜甜的曲奇", colorHex: "#FFF0D4"),
        .init(id: "berry-wrap", name: "草莓糖纸", subtitle: "粉色格纹与小草莓", colorHex: "#FCE1E8"),
        .init(id: "sakura-letter", name: "樱花信笺", subtitle: "把春天寄给你", colorHex: "#F7E1EB"),
        .init(id: "mint-check", name: "薄荷格纹", subtitle: "清新的野餐日记", colorHex: "#DDEFE3"),
        .init(id: "star-dream", name: "星星梦境", subtitle: "晚安，做个好梦", colorHex: "#E9E2F6"),
        .init(id: "ribbon-gift", name: "蝴蝶结礼物", subtitle: "每个瞬间都值得珍藏", colorHex: "#FBE5EB")
    ]
    public static func frame(id: String) -> DecorationFrame? { all.first { $0.id == id } }
}

public enum DecorationFrameRenderer {
    public static func draw(_ decoration: CanvasDecoration, in rect: CGRect, context cg: CGContext) {
        guard let frame = DecorationFrameCatalog.frame(id: decoration.frameID), rect.width > 0, rect.height > 0 else { return }
        let fraction = decoration.width.isFinite ? min(max(decoration.width, 0.025), 0.12) : 0.065
        let b = min(rect.width, rect.height) * fraction
        let inner = rect.insetBy(dx: b, dy: b)
        let ring = CGMutablePath(); ring.addRect(rect)
        ring.addRoundedRect(in: inner, cornerWidth: b * 0.36, cornerHeight: b * 0.36)
        cg.saveGState(); defer { cg.restoreGState() }
        cg.addPath(ring); cg.setFillColor(OriginalStickerArt.color(frame.colorHex)); cg.fillPath(using: .evenOdd)
        cg.saveGState()
        cg.addPath(ring); cg.clip(using: .evenOdd)
        if frame.id == "berry-wrap" || frame.id == "mint-check" {
            cg.setFillColor(OriginalStickerArt.color(frame.id == "mint-check" ? "#88BDA3" : "#E8A3B7"))
            cg.setAlpha(0.24)
            let step = max(b * 0.72, 1)
            for x in stride(from: rect.minX, through: rect.maxX, by: step) {
                cg.fill(CGRect(x: x, y: rect.minY, width: step * 0.5, height: rect.height))
            }
            for y in stride(from: rect.minY, through: rect.maxY, by: step) {
                cg.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: step * 0.5))
            }
        } else {
            cg.setStrokeColor(OriginalStickerArt.color(frame.id == "star-dream" ? "#BDACD7" : "#D7A8B4"))
            cg.setLineWidth(max(b * 0.035, 0.5)); cg.setLineDash(phase: 0, lengths: [b * 0.14, b * 0.14])
            cg.stroke(rect.insetBy(dx: b * 0.42, dy: b * 0.42)); cg.setLineDash(phase: 0, lengths: [])
        }
        cg.restoreGState()
        func circle(_ center: CGPoint, _ radius: CGFloat, _ color: String) {
            cg.setFillColor(OriginalStickerArt.color(color))
            cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        func stamp(_ name: String, _ center: CGPoint, _ size: CGFloat) {
            OriginalStickerArt.draw(name, in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size), context: cg)
        }
        if frame.id == "cream-lace" {
            let step = b * 0.54
            for x in stride(from: inner.minX, through: inner.maxX, by: step) {
                for y in [inner.minY, inner.maxY] {
                    circle(CGPoint(x: x,y: y), b * 0.29, frame.colorHex)
                    circle(CGPoint(x: x,y: y), b * 0.075, "#DCBD92")
                }
            }
            for y in stride(from: inner.minY, through: inner.maxY, by: step) {
                for x in [inner.minX, inner.maxX] {
                    circle(CGPoint(x: x,y: y), b * 0.29, frame.colorHex)
                    circle(CGPoint(x: x,y: y), b * 0.075, "#DCBD92")
                }
            }
        }
        let topLeft = CGPoint(x: rect.minX + b * 0.85, y: rect.minY + b * 0.85)
        let bottomRight = CGPoint(x: rect.maxX - b * 0.85, y: rect.maxY - b * 0.85)
        switch frame.id {
        case "cream-lace":
            stamp("daisy", topLeft, b * 1.8); stamp("daisy", bottomRight, b * 1.8)
        case "berry-wrap":
            stamp("strawberry", topLeft, b * 2.1); stamp("cherries", bottomRight, b * 2.0)
        case "sakura-letter":
            for center in [topLeft, bottomRight] {
                for i in 0..<5 {
                    cg.saveGState(); cg.translateBy(x: center.x, y: center.y); cg.rotate(by: CGFloat(i) * .pi * 2 / 5)
                    circle(CGPoint(x: 0,y: -b * 0.35), b * 0.29, "#EAA8BF"); cg.restoreGState()
                }
                circle(center, b * 0.15, "#FFF0BC")
            }
            stamp("letter", CGPoint(x: rect.maxX - b, y: rect.minY + b * 0.6), b * 1.5)
        case "mint-check":
            stamp("daisy", topLeft, b * 1.8); stamp("bow", bottomRight, b * 1.9)
        case "star-dream":
            stamp("moon", CGPoint(x: rect.maxX - b, y: rect.minY + b), b * 2)
            stamp("cloud", CGPoint(x: rect.minX + b, y: rect.maxY - b), b * 2)
            for x in stride(from: rect.minX + b * 2, to: rect.maxX - b * 2, by: b * 1.9) {
                for y in [rect.minY + b * 0.45, rect.maxY - b * 0.45] {
                    let r = b * 0.15, star = CGMutablePath()
                    star.addLines(between: [CGPoint(x:x,y:y-r),CGPoint(x:x+r,y:y),CGPoint(x:x,y:y+r),CGPoint(x:x-r,y:y)])
                    star.closeSubpath(); cg.addPath(star); cg.setFillColor(OriginalStickerArt.color("#E6BE73")); cg.fillPath()
                }
            }
        case "ribbon-gift":
            stamp("bow", CGPoint(x: rect.midX, y: rect.minY + b * 0.75), b * 2.5)
            stamp("letter", bottomRight, b * 1.8)
        default: break
        }
    }
}
