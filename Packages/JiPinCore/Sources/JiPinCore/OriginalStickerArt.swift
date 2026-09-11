import CoreGraphics
import Foundation

/// Original vector artwork, shared by iOS rendering and the macOS asset proof exporter.
/// All geometry uses a 100 × 100 design space; no emoji, raster or external font dependency.
public enum OriginalStickerArt {
    public static let names = ["bunny", "bear", "cat", "strawberry", "cherries", "bow", "daisy", "cloud",
                               "moon", "letter", "pudding", "boba", "peach", "rainbow", "candy", "cake", "bolt", "orbit",
                               "film-frame", "headphones", "comet", "checker", "mountain", "vinyl"]

    public static func color(_ hex: String) -> CGColor {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = UInt32(digits.prefix(6), radix: 16) ?? 0
        return CGColor(red: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255,
                       blue: CGFloat(n & 255) / 255, alpha: 1)
    }

    public static func draw(_ name: String, in rect: CGRect, context cg: CGContext) {
        cg.saveGState(); defer { cg.restoreGState() }
        let unit = min(rect.width, rect.height) / 100
        cg.translateBy(x: rect.midX - 50 * unit, y: rect.midY - 50 * unit)
        cg.scaleBy(x: unit, y: unit)
        cg.setLineCap(.round); cg.setLineJoin(.round)
        let ink = ["bolt", "orbit", "film-frame", "headphones", "comet", "checker", "mountain", "vinyl"].contains(name) ? "#112332" : "#62443C", cream = "#FFF4DF", pink = "#F2A8B8", rose = "#D97091", mint = "#A8D9BB"
        func path(_ body: (CGMutablePath) -> Void) -> CGPath { let p = CGMutablePath(); body(p); return p }
        func paint(_ p: CGPath, _ fill: String, edge: Bool = true, cut: Bool = true) {
            if cut { cg.addPath(p); cg.setLineWidth(8); cg.setStrokeColor(color("#FFFFFF")); cg.strokePath() }
            cg.addPath(p); cg.setFillColor(color(fill)); cg.fillPath()
            if edge { cg.addPath(p); cg.setStrokeColor(color(ink)); cg.setLineWidth(2.2); cg.strokePath() }
        }
        func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: String, detail: Bool = false) {
            paint(CGPath(ellipseIn: CGRect(x: x, y: y, width: w, height: h), transform: nil), fill, edge: !detail, cut: !detail)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ fill: String, detail: Bool = false) {
            paint(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil), fill, edge: !detail, cut: !detail)
        }
        func line(_ points: [CGPoint], _ fill: String = "#62443C", _ width: CGFloat = 2.2) {
            guard let first = points.first else { return }
            cg.beginPath(); cg.move(to: first); for p in points.dropFirst() { cg.addLine(to: p) }
            cg.setStrokeColor(color(fill)); cg.setLineWidth(width); cg.strokePath()
        }
        func polygon(_ points: [CGPoint], _ fill: String, detail: Bool = false) {
            paint(path { p in p.addLines(between: points); p.closeSubpath() }, fill, edge: !detail, cut: !detail)
        }
        func face(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 24) {
            oval(x - width / 2 - 2, y - 3, 4, 6, ink, detail: true)
            oval(x + width / 2 - 2, y - 3, 4, 6, ink, detail: true)
            oval(x - width / 2 - 9, y + 6, 10, 5, pink, detail: true)
            oval(x + width / 2, y + 6, 10, 5, pink, detail: true)
            let p = path { p in p.move(to: CGPoint(x: x - 4, y: y + 4)); p.addQuadCurve(to: CGPoint(x: x + 4, y: y + 4), control: CGPoint(x: x, y: y + 11)) }
            cg.addPath(p); cg.setLineWidth(1.8); cg.setStrokeColor(color(ink)); cg.strokePath()
        }
        func sparkle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ fill: String = "#F3CD77") {
            polygon([CGPoint(x: x, y: y-r), CGPoint(x: x+r*0.3, y: y-r*0.3), CGPoint(x: x+r, y: y),
                     CGPoint(x: x+r*0.3, y: y+r*0.3), CGPoint(x: x, y: y+r), CGPoint(x: x-r*0.3, y: y+r*0.3),
                     CGPoint(x: x-r, y: y), CGPoint(x: x-r*0.3, y: y-r*0.3)], fill, detail: true)
        }
        func heart(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat, _ fill: String) {
            let p = path { p in
                p.move(to: CGPoint(x: x, y: y + 0.35 * scale))
                p.addCurve(to: CGPoint(x: x - 0.48 * scale, y: y - 0.1 * scale), control1: CGPoint(x: x - 0.12 * scale, y: y + 0.23 * scale), control2: CGPoint(x: x - 0.48 * scale, y: y + 0.12 * scale))
                p.addCurve(to: CGPoint(x: x, y: y - 0.21 * scale), control1: CGPoint(x: x - 0.48 * scale, y: y - 0.48 * scale), control2: CGPoint(x: x - 0.15 * scale, y: y - 0.45 * scale))
                p.addCurve(to: CGPoint(x: x + 0.48 * scale, y: y - 0.1 * scale), control1: CGPoint(x: x + 0.15 * scale, y: y - 0.45 * scale), control2: CGPoint(x: x + 0.48 * scale, y: y - 0.48 * scale))
                p.addCurve(to: CGPoint(x: x, y: y + 0.35 * scale), control1: CGPoint(x: x + 0.48 * scale, y: y + 0.12 * scale), control2: CGPoint(x: x + 0.12 * scale, y: y + 0.23 * scale)); p.closeSubpath()
            }; paint(p, fill)
        }

        switch name {
        case "bunny":
            oval(25, 9, 18, 47, cream); oval(56, 9, 18, 47, cream)
            oval(31, 16, 6, 29, pink, detail: true); oval(62, 16, 6, 29, pink, detail: true)
            oval(17, 37, 66, 51, cream); face(50, 61)
            oval(30, 42, 15, 5, "#FFFFFF", detail: true)
            heart(79, 27, 16, pink)
        case "bear":
            oval(17, 20, 25, 27, "#DDB48B"); oval(60, 20, 25, 27, "#DDB48B")
            oval(23, 27, 12, 12, pink, detail: true); oval(67, 27, 12, 12, pink, detail: true)
            oval(15, 30, 71, 57, "#E5BF93")
            oval(35, 55, 30, 25, cream, detail: true); face(50, 56, 30)
            oval(47, 62, 6, 4, ink, detail: true)
            sparkle(79, 12, 7)
        case "cat":
            paint(path { p in
                p.move(to: CGPoint(x: 21, y: 45)); p.addLine(to: CGPoint(x: 21, y: 17)); p.addQuadCurve(to: CGPoint(x: 39, y: 34), control: CGPoint(x: 31, y: 19))
                p.addQuadCurve(to: CGPoint(x: 63, y: 34), control: CGPoint(x: 50, y: 28)); p.addLine(to: CGPoint(x: 80, y: 17)); p.addLine(to: CGPoint(x: 80, y: 47))
                p.addCurve(to: CGPoint(x: 50, y: 86), control1: CGPoint(x: 93, y: 82), control2: CGPoint(x: 71, y: 87))
                p.addCurve(to: CGPoint(x: 21, y: 45), control1: CGPoint(x: 15, y: 88), control2: CGPoint(x: 11, y: 66)); p.closeSubpath()
            }, "#F5C88E")
            polygon([CGPoint(x: 25, y: 28), CGPoint(x: 26, y: 43), CGPoint(x: 35, y: 36)], pink, detail: true)
            polygon([CGPoint(x: 76, y: 28), CGPoint(x: 76, y: 43), CGPoint(x: 67, y: 36)], pink, detail: true)
            face(50, 61, 27); line([CGPoint(x: 45,y: 36),CGPoint(x: 47,y: 44)], "#D69157", 3)
            line([CGPoint(x: 56,y: 36),CGPoint(x: 54,y: 44)], "#D69157", 3)
            line([CGPoint(x: 16,y: 64),CGPoint(x: 28,y: 66)]); line([CGPoint(x: 73,y: 66),CGPoint(x: 85,y: 64)])
        case "strawberry":
            paint(path { p in
                p.move(to: CGPoint(x: 50,y: 31)); p.addCurve(to: CGPoint(x: 82,y: 46), control1: CGPoint(x: 69,y: 22), control2: CGPoint(x: 91,y: 25))
                p.addCurve(to: CGPoint(x: 50,y: 88), control1: CGPoint(x: 79,y: 64), control2: CGPoint(x: 63,y: 83))
                p.addCurve(to: CGPoint(x: 18,y: 46), control1: CGPoint(x: 31,y: 84), control2: CGPoint(x: 22,y: 65))
                p.addCurve(to: CGPoint(x: 50,y: 31), control1: CGPoint(x: 8,y: 26), control2: CGPoint(x: 33,y: 23)); p.closeSubpath()
            }, "#EF879B")
            polygon([CGPoint(x: 50,y: 14),CGPoint(x: 57,y: 28),CGPoint(x: 77,y: 23),CGPoint(x: 64,y: 39),CGPoint(x: 50,y: 34),CGPoint(x: 35,y: 40),CGPoint(x: 23,y: 23),CGPoint(x: 42,y: 28)], mint)
            for point in [(29.0,46.0),(44,43),(63,46),(37,61),(60,61),(49,73)] { oval(point.0, point.1, 3, 5, cream, detail: true) }
            sparkle(88, 20, 6)
        case "cherries":
            line([CGPoint(x: 32,y: 59),CGPoint(x: 48,y: 22),CGPoint(x: 71,y: 66)], "#FFFFFF", 9)
            line([CGPoint(x: 32,y: 59),CGPoint(x: 48,y: 22),CGPoint(x: 71,y: 66)], "#7A9860", 4)
            oval(13, 48, 39, 37, "#E68096"); oval(51, 54, 37, 35, "#CE6480")
            oval(20, 56, 9, 5, "#FFD5D9", detail: true); oval(59, 62, 8, 4, "#FFD5D9", detail: true)
            paint(path { p in p.move(to: CGPoint(x: 48,y: 22)); p.addQuadCurve(to: CGPoint(x: 78,y: 17), control: CGPoint(x: 63,y: 3)); p.addQuadCurve(to: CGPoint(x: 48,y: 22), control: CGPoint(x: 66,y: 33)) }, mint)
        case "bow":
            polygon([CGPoint(x: 41,y: 48),CGPoint(x: 28,y: 82),CGPoint(x: 42,y: 76),CGPoint(x: 50,y: 89),CGPoint(x: 56,y: 50)], pink)
            polygon([CGPoint(x: 51,y: 49),CGPoint(x: 66,y: 85),CGPoint(x: 72,y: 73),CGPoint(x: 85,y: 74),CGPoint(x: 61,y: 44)], pink)
            paint(path { p in
                p.move(to: CGPoint(x: 48,y: 40)); p.addCurve(to: CGPoint(x: 16,y: 21), control1: CGPoint(x: 32,y: 28), control2: CGPoint(x: 24,y: 11))
                p.addQuadCurve(to: CGPoint(x: 16,y: 63), control: CGPoint(x: 6,y: 42)); p.addQuadCurve(to: CGPoint(x: 48,y: 51), control: CGPoint(x: 26,y: 69)); p.closeSubpath()
            }, pink)
            paint(path { p in
                p.move(to: CGPoint(x: 53,y: 40)); p.addCurve(to: CGPoint(x: 85,y: 21), control1: CGPoint(x: 69,y: 28), control2: CGPoint(x: 76,y: 11))
                p.addQuadCurve(to: CGPoint(x: 85,y: 63), control: CGPoint(x: 95,y: 42)); p.addQuadCurve(to: CGPoint(x: 53,y: 51), control: CGPoint(x: 75,y: 69)); p.closeSubpath()
            }, pink)
            line([CGPoint(x: 27,y: 34),CGPoint(x: 45,y: 45)], rose, 2.5); line([CGPoint(x: 75,y: 34),CGPoint(x: 57,y: 45)], rose, 2.5)
            box(43, 34, 16, 24, 6, "#E890A6"); oval(47, 38, 5, 12, "#FFD4DD", detail: true)
        case "daisy":
            for i in 0..<8 {
                cg.saveGState(); cg.translateBy(x: 50,y: 50); cg.rotate(by: CGFloat(i) * .pi / 4)
                oval(-12, -38, 24, 37, cream); cg.restoreGState()
            }
            oval(29, 29, 42, 42, "#F5CF77"); face(50, 48, 17)
        case "cloud":
            paint(path { p in
                p.move(to: CGPoint(x: 24,y: 75)); p.addCurve(to: CGPoint(x: 21,y: 42), control1: CGPoint(x: 3,y: 75), control2: CGPoint(x: 3,y: 43))
                p.addCurve(to: CGPoint(x: 55,y: 28), control1: CGPoint(x: 19,y: 18), control2: CGPoint(x: 47,y: 15))
                p.addCurve(to: CGPoint(x: 80,y: 43), control1: CGPoint(x: 70,y: 22), control2: CGPoint(x: 81,y: 29))
                p.addCurve(to: CGPoint(x: 77,y: 75), control1: CGPoint(x: 98,y: 46), control2: CGPoint(x: 98,y: 76)); p.closeSubpath()
            }, "#F4FAFF")
            face(51, 54, 27); sparkle(22, 88, 5, "#ACCBE9"); sparkle(75, 88, 5, "#ACCBE9")
        case "moon":
            paint(path { p in
                p.move(to: CGPoint(x: 61,y: 14)); p.addCurve(to: CGPoint(x: 82,y: 72), control1: CGPoint(x: 14,y: 8), control2: CGPoint(x: 9,y: 89))
                p.addCurve(to: CGPoint(x: 61,y: 14), control1: CGPoint(x: 40,y: 79), control2: CGPoint(x: 37,y: 38)); p.closeSubpath()
            }, "#C5B5E5")
            sparkle(73, 31, 14); sparkle(85, 11, 5, "#E8B8CA"); sparkle(21, 80, 5)
            oval(29, 50, 5, 5, "#FFF5E0", detail: true)
        case "letter":
            box(13, 31, 74, 52, 8, "#FFF2D8")
            line([CGPoint(x: 16,y: 76),CGPoint(x: 43,y: 55),CGPoint(x: 58,y: 55),CGPoint(x: 84,y: 76)], "#DDBA93", 2)
            polygon([CGPoint(x: 17,y: 33),CGPoint(x: 50,y: 60),CGPoint(x: 83,y: 33)], "#FFE5C4")
            heart(50, 52, 26, pink); heart(77, 16, 16, pink)
            sparkle(21, 18, 5)
        case "pudding":
            oval(12, 76, 76, 13, "#DCC9E8")
            paint(path { p in p.move(to: CGPoint(x: 30,y: 29)); p.addQuadCurve(to: CGPoint(x: 70,y: 29), control: CGPoint(x: 50,y: 19)); p.addLine(to: CGPoint(x: 81,y: 76)); p.addQuadCurve(to: CGPoint(x: 19,y: 76), control: CGPoint(x: 50,y: 87)); p.closeSubpath() }, "#F9DA8C")
            paint(path { p in p.move(to: CGPoint(x: 30,y: 29)); p.addQuadCurve(to: CGPoint(x: 70,y: 29), control: CGPoint(x: 50,y: 18)); p.addLine(to: CGPoint(x: 73,y: 41)); p.addQuadCurve(to: CGPoint(x: 27,y: 41), control: CGPoint(x: 47,y: 51)); p.closeSubpath() }, "#C99060", edge: false, cut: false)
            face(50, 60); oval(41, 18, 18, 9, cream); oval(48, 10, 9, 9, "#EB8D9E")
        case "boba":
            line([CGPoint(x: 55,y: 46),CGPoint(x: 61,y: 9)], "#FFFFFF", 13)
            line([CGPoint(x: 55,y: 46),CGPoint(x: 61,y: 9)], "#BBABD8", 7)
            polygon([CGPoint(x: 24,y: 34),CGPoint(x: 76,y: 34),CGPoint(x: 69,y: 87),CGPoint(x: 31,y: 87)], "#EBD1AC")
            box(20, 28, 60, 13, 6, cream)
            for p in [(38.0,76.0),(50,78),(62,76),(43,68),(57,68)] { oval(p.0-3.5, p.1-3.5, 7, 7, "#8A6556", detail: true) }
            face(50, 52, 20); sparkle(85, 49, 6)
        case "peach":
            paint(path { p in
                p.move(to: CGPoint(x: 50,y: 31)); p.addCurve(to: CGPoint(x: 18,y: 58), control1: CGPoint(x: 17,y: 13), control2: CGPoint(x: 9,y: 40))
                p.addCurve(to: CGPoint(x: 50,y: 87), control1: CGPoint(x: 25,y: 79), control2: CGPoint(x: 47,y: 84))
                p.addCurve(to: CGPoint(x: 83,y: 58), control1: CGPoint(x: 70,y: 80), control2: CGPoint(x: 85,y: 76))
                p.addCurve(to: CGPoint(x: 50,y: 31), control1: CGPoint(x: 96,y: 27), control2: CGPoint(x: 65,y: 18)); p.closeSubpath()
            }, "#F6BCC1")
            let seam = path { p in p.move(to: CGPoint(x: 50,y: 35)); p.addQuadCurve(to: CGPoint(x: 51,y: 75), control: CGPoint(x: 42,y: 51)) }
            cg.addPath(seam); cg.setStrokeColor(color("#E19BAA")); cg.setLineWidth(2); cg.strokePath()
            paint(path { p in p.move(to: CGPoint(x: 51,y: 27)); p.addQuadCurve(to: CGPoint(x: 78,y: 12), control: CGPoint(x: 57,y: 7)); p.addQuadCurve(to: CGPoint(x: 51,y: 27), control: CGPoint(x: 74,y: 38)) }, mint)
            oval(25, 38, 11, 6, "#FFE2D8", detail: true)
        case "rainbow":
            for (r, colorHex) in [(34.0,"#FFFFFF"),(31,"#EFA3B5"),(23,"#F5D489"),(15,"#AAD5C0")] {
                cg.beginPath(); cg.addArc(center: CGPoint(x: 50,y: 65), radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
                cg.setStrokeColor(color(colorHex)); cg.setLineWidth(r == 34 ? 16 : 8); cg.strokePath()
            }
            oval(7, 61, 26, 20, cream); oval(67, 61, 26, 20, cream)
            sparkle(77, 18, 6, "#C5B5E5")
        case "candy":
            polygon([CGPoint(x: 29,y: 38),CGPoint(x: 10,y: 29),CGPoint(x: 14,y: 49),CGPoint(x: 9,y: 66),CGPoint(x: 31,y: 58)], "#ABD8C3")
            polygon([CGPoint(x: 70,y: 38),CGPoint(x: 90,y: 29),CGPoint(x: 85,y: 49),CGPoint(x: 90,y: 66),CGPoint(x: 70,y: 58)], "#ABD8C3")
            oval(25, 25, 50, 49, "#F8C5D2")
            line([CGPoint(x: 45,y: 30),CGPoint(x: 36,y: 66)], "#FFF1D6", 8)
            line([CGPoint(x: 63,y: 34),CGPoint(x: 55,y: 70)], "#FFF1D6", 8)
            sparkle(35, 13, 6); sparkle(73, 83, 5, pink)
        case "cake":
            polygon([CGPoint(x: 25,y: 50),CGPoint(x: 75,y: 50),CGPoint(x: 67,y: 86),CGPoint(x: 33,y: 86)], "#C5B5E5")
            for x in [38.0,50,62] { line([CGPoint(x: x,y: 60),CGPoint(x: x,y: 80)], "#AA96CC", 2) }
            paint(path { p in p.move(to: CGPoint(x: 20,y: 51)); p.addCurve(to: CGPoint(x: 35,y: 31), control1: CGPoint(x: 12,y: 39), control2: CGPoint(x: 24,y: 28)); p.addCurve(to: CGPoint(x: 67,y: 31), control1: CGPoint(x: 38,y: 6), control2: CGPoint(x: 65,y: 7)); p.addCurve(to: CGPoint(x: 80,y: 51), control1: CGPoint(x: 81,y: 28), control2: CGPoint(x: 91,y: 42)); p.addQuadCurve(to: CGPoint(x: 20,y: 51), control: CGPoint(x: 50,y: 66)); p.closeSubpath() }, cream)
            oval(45, 7, 12, 12, "#EC98A9"); face(50, 42, 19)
        case "bolt":
            polygon([CGPoint(x: 50,y: 8),CGPoint(x: 86,y: 29),CGPoint(x: 86,y: 72),CGPoint(x: 50,y: 93),CGPoint(x: 14,y: 72),CGPoint(x: 14,y: 29)], "#172B38")
            polygon([CGPoint(x: 57,y: 17),CGPoint(x: 30,y: 54),CGPoint(x: 49,y: 54),CGPoint(x: 39,y: 83),CGPoint(x: 74,y: 43),CGPoint(x: 53,y: 43)], "#C4EF78")
            line([CGPoint(x: 22,y: 35),CGPoint(x: 22,y: 62)], "#78C9EA", 2.5)
            line([CGPoint(x: 78,y: 57),CGPoint(x: 78,y: 67),CGPoint(x: 61,y: 78)], "#78C9EA", 2.5)
        case "orbit":
            oval(11, 11, 78, 78, "#182A3E")
            let orbit = CGPath(ellipseIn: CGRect(x: 7,y: 35,width: 86,height: 32), transform: nil)
            cg.addPath(orbit); cg.setStrokeColor(color("#B7A6DF")); cg.setLineWidth(2); cg.strokePath()
            polygon([CGPoint(x: 30,y: 64),CGPoint(x: 17,y: 83),CGPoint(x: 40,y: 72)], "#BBED81")
            polygon([CGPoint(x: 73,y: 18),CGPoint(x: 70,y: 70),CGPoint(x: 53,y: 57),CGPoint(x: 31,y: 54)], "#8ACCE3")
            polygon([CGPoint(x: 73,y: 18),CGPoint(x: 53,y: 57),CGPoint(x: 50,y: 75),CGPoint(x: 40,y: 62)], "#5892BE")
            line([CGPoint(x: 61,y: 38),CGPoint(x: 60,y: 49)], "#E6FAFF", 3)
            sparkle(23, 24, 4, "#C5ED84"); sparkle(79, 79, 4, "#C5ED84")
        case "film-frame":
            box(12, 12, 76, 76, 9, "#172B38")
            box(23, 26, 54, 48, 2, "#BDE783", detail: true)
            for x in stride(from: 22.0, through: 70, by: 12) {
                box(x, 17, 7, 5, 1, "#F8F3DF", detail: true)
                box(x, 79, 7, 5, 1, "#F8F3DF", detail: true)
            }
            oval(55, 33, 12, 12, "#F8F3DF", detail: true)
            polygon([CGPoint(x: 23,y: 69),CGPoint(x: 42,y: 44),CGPoint(x: 55,y: 59),CGPoint(x: 64,y: 50),CGPoint(x: 77,y: 69)], "#305E68", detail: true)
        case "headphones":
            oval(11, 11, 78, 78, "#233447")
            let arch = path { p in p.move(to: CGPoint(x: 25,y: 58)); p.addCurve(to: CGPoint(x: 75,y: 58), control1: CGPoint(x: 21,y: 12), control2: CGPoint(x: 79,y: 12)) }
            cg.addPath(arch); cg.setStrokeColor(color("#BDE783")); cg.setLineWidth(9); cg.strokePath()
            box(18, 49, 18, 31, 7, "#91D3E8"); box(64, 49, 18, 31, 7, "#91D3E8")
            line([CGPoint(x: 40,y: 64),CGPoint(x: 40,y: 72)], "#BDE783", 3)
            line([CGPoint(x: 50,y: 55),CGPoint(x: 50,y: 79)], "#BDE783", 3)
            line([CGPoint(x: 59,y: 62),CGPoint(x: 59,y: 72)], "#BDE783", 3)
        case "comet":
            oval(12, 12, 76, 76, "#192D43")
            polygon([CGPoint(x: 21,y: 76),CGPoint(x: 57,y: 19),CGPoint(x: 82,y: 37)], "#A8A1DE")
            line([CGPoint(x: 22,y: 66),CGPoint(x: 48,y: 34)], "#91D3E8", 4)
            sparkle(65, 34, 19, "#C8EE87"); sparkle(28, 28, 6, "#F5F4DE")
            sparkle(73, 72, 8, "#91D3E8")
        case "checker":
            box(12, 12, 76, 76, 14, "#172B38")
            for row in 0..<4 { for column in 0..<4 where (row + column).isMultiple(of: 2) {
                box(22 + Double(column) * 14, 22 + Double(row) * 14, 14, 14, 1, "#C8EE87", detail: true)
            } }
            line([CGPoint(x: 21,y: 81),CGPoint(x: 79,y: 19)], "#8DD0E7", 4)
        case "mountain":
            polygon([CGPoint(x: 50,y: 9),CGPoint(x: 89,y: 30),CGPoint(x: 85,y: 73),CGPoint(x: 50,y: 91),CGPoint(x: 15,y: 73),CGPoint(x: 11,y: 30)], "#223D3A")
            oval(60, 24, 16, 16, "#CCE987", detail: true)
            polygon([CGPoint(x: 20,y: 70),CGPoint(x: 42,y: 29),CGPoint(x: 62,y: 70)], "#8AD0DB", detail: true)
            polygon([CGPoint(x: 40,y: 70),CGPoint(x: 65,y: 44),CGPoint(x: 82,y: 70)], "#C8EE87", detail: true)
            polygon([CGPoint(x: 34,y: 44),CGPoint(x: 42,y: 29),CGPoint(x: 49,y: 44),CGPoint(x: 41,y: 40)], "#F8F3DF", detail: true)
            line([CGPoint(x: 31,y: 79),CGPoint(x: 67,y: 79)], "#F8F3DF", 2)
        case "vinyl":
            oval(10, 10, 80, 80, "#172B38")
            for radius in [31.0, 25.0] {
                cg.addEllipse(in: CGRect(x: 50-radius,y: 50-radius,width: radius*2,height: radius*2))
                cg.setStrokeColor(color("#52707F")); cg.setLineWidth(1.5); cg.strokePath()
            }
            oval(34, 34, 32, 32, "#C8EE87", detail: true)
            oval(46, 46, 8, 8, "#172B38", detail: true)
            line([CGPoint(x: 29,y: 27),CGPoint(x: 34,y: 35)], "#F8F3DF", 3)
            line([CGPoint(x: 22,y: 37),CGPoint(x: 28,y: 41)], "#F8F3DF", 3)
            sparkle(82, 16, 8, "#91D3E8")
        default: break
        }
    }
}
