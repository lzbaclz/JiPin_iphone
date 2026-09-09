import CoreGraphics
import Foundation
import UIKit

public enum HexColor {
    public static func cgColor(_ hex: String, alpha: CGFloat? = nil) -> CGColor {
        uiColor(hex, alpha: alpha).cgColor
    }

    public static func uiColor(_ hex: String, alpha: CGFloat? = nil) -> UIColor {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        var raw: UInt64 = 0
        Scanner(string: String(value.prefix(8))).scanHexInt64(&raw)
        let a: CGFloat
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        switch value.count {
        case 8:
            a = CGFloat((raw & 0xFF000000) >> 24) / 255
            r = CGFloat((raw & 0x00FF0000) >> 16) / 255
            g = CGFloat((raw & 0x0000FF00) >> 8) / 255
            b = CGFloat(raw & 0x000000FF) / 255
        case 6:
            a = 1
            r = CGFloat((raw & 0xFF0000) >> 16) / 255
            g = CGFloat((raw & 0x00FF00) >> 8) / 255
            b = CGFloat(raw & 0x0000FF) / 255
        default:
            return UIColor(white: 0.9, alpha: alpha ?? 1)
        }
        return UIColor(red: r, green: g, blue: b, alpha: alpha ?? a)
    }
}
