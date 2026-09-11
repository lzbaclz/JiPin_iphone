import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main
struct ExportOriginalArt {
    static func bitmap(_ size: CGSize, drawing: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                bytesPerRow: Int(size.width) * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        drawing(context)
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "JiPinArt", code: 1)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "JiPinArt", code: 2) }
    }

    static func label(_ text: String, _ rect: CGRect, size: CGFloat, color: NSColor = .darkGray, bold: Bool = false) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        (text as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
                                                         .foregroundColor: color, .paragraphStyle: paragraph])
    }

    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let stickers = destination.appendingPathComponent("stickers", isDirectory: true)
        let frames = destination.appendingPathComponent("frames", isDirectory: true)
        for folder in [destination, stickers, frames] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let originals = StickerCatalog.all.filter { $0.category == .cute || $0.category == .cool }
        for item in originals {
            guard case .illustration(let key) = item.render else { continue }
            try write(bitmap(CGSize(width: 768, height: 768)) { context in
                OriginalStickerArt.draw(key, in: CGRect(x: 0, y: 0, width: 768, height: 768), context: context)
            }, to: stickers.appendingPathComponent("\(item.id).png"))
        }
        let boardHeight = CGFloat((originals.count + 5) / 6) * 286 + 192
        try write(bitmap(CGSize(width: 1440, height: boardHeight)) { context in
            context.setFillColor(OriginalStickerArt.color("#FAF6F0")); context.fill(CGRect(x: 0,y: 0,width: 1440,height: boardHeight))
            label("极拼 · 日常贴纸册", CGRect(x: 0,y: 36,width: 1440,height: 58), size: 40, bold: true)
            label("\(StickerCatalog.stickers(in: .cute).count) 个可爱贴图  /  \(StickerCatalog.stickers(in: .cool).count) 个酷感点缀", CGRect(x: 0,y: 105,width: 1440,height: 34), size: 23)
            for (index, item) in originals.enumerated() {
                guard case .illustration(let key) = item.render else { continue }
                let x = CGFloat(index % 6) * 226 + 42, y = CGFloat(index / 6) * 286 + 168
                context.setFillColor(OriginalStickerArt.color("#FFFFFF"))
                context.addPath(CGPath(roundedRect: CGRect(x: x,y: y,width: 210,height: 265), cornerWidth: 22, cornerHeight: 22, transform: nil)); context.fillPath()
                OriginalStickerArt.draw(key, in: CGRect(x: x + 10,y: y + 4,width: 190,height: 190), context: context)
                label(item.name, CGRect(x: x,y: y + 198,width: 210,height: 31), size: 21, bold: true)
                label(item.category.title, CGRect(x: x,y: y + 234,width: 210,height: 23), size: 14)
            }
        }, to: destination.appendingPathComponent("v3-sticker-board.png"))
        for frame in DecorationFrameCatalog.all {
            try write(bitmap(CGSize(width: 768,height: 1024)) { context in
                DecorationFrameRenderer.draw(CanvasDecoration(frameID: frame.id), in: CGRect(x: 0,y: 0,width: 768,height: 1024), context: context)
            }, to: frames.appendingPathComponent("\(frame.id).png"))
        }
        try write(bitmap(CGSize(width: 1440,height: 1320)) { context in
            context.setFillColor(OriginalStickerArt.color("#FAF6F0")); context.fill(CGRect(x: 0,y: 0,width: 1440,height: 1320))
            label("极拼 · 可爱边框", CGRect(x: 0,y: 30,width: 1440,height: 58), size: 40, bold: true)
            label("留一圈温柔，把回忆放在中间", CGRect(x: 0,y: 98,width: 1440,height: 36), size: 23)
            for (index, frame) in DecorationFrameCatalog.all.enumerated() {
                let x = CGFloat(index % 3) * 466 + 35, y = CGFloat(index / 3) * 580 + 158
                let rect = CGRect(x: x,y: y,width: 436,height: 510)
                context.setFillColor(OriginalStickerArt.color("#DFEBDD")); context.fill(rect)
                context.setFillColor(OriginalStickerArt.color("#F4CF97")); context.fillEllipse(in: CGRect(x: x + 270,y: y + 90,width: 90,height: 90))
                let hill = CGMutablePath(); hill.move(to: CGPoint(x: x,y: y + 310))
                hill.addCurve(to: CGPoint(x: x + 436,y: y + 340), control1: CGPoint(x: x + 150,y: y + 200), control2: CGPoint(x: x + 250,y: y + 470))
                hill.addLine(to: CGPoint(x: x + 436,y: y + 510)); hill.addLine(to: CGPoint(x: x,y: y + 510)); hill.closeSubpath()
                context.addPath(hill); context.setFillColor(OriginalStickerArt.color("#9BBDAD")); context.fillPath()
                DecorationFrameRenderer.draw(CanvasDecoration(frameID: frame.id), in: rect, context: context)
                label(frame.name, CGRect(x: x,y: y + 520,width: 436,height: 32), size: 23, bold: true)
            }
        }, to: destination.appendingPathComponent("v3-frame-board.png"))
        print("Exported \(originals.count) original transparent stickers, \(DecorationFrameCatalog.all.count) frames and two proof boards.")
    }
}
