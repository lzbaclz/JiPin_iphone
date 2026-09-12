import Foundation
import CoreGraphics

public enum IDPhotoValidationError: LocalizedError, Equatable {
    case invalidTemplate, invalidCrop, invalidAdjustments, invalidStroke, invalidFaceRegion
    case invalidProject, unsupportedVersion
    case invalidCustomName, invalidFileLimit

    public var errorDescription: String? {
        switch self {
        case .invalidTemplate: return "尺寸须为每边 100–2048 像素，且总像素不超过 400 万。"
        case .invalidCrop: return "照片构图参数无效，请重新调整。"
        case .invalidAdjustments: return "轻修参数无效，请重置轻修。"
        case .invalidStroke: return "修边记录无效，请重新检查照片边缘。"
        case .invalidFaceRegion: return "人脸分析记录无效，请重新识别人像。"
        case .invalidProject: return "证件照草稿数据不完整，无法打开。"
        case .unsupportedVersion: return "此证件照草稿由其他版本创建，请更新极拼后打开。"
        case .invalidCustomName: return "名称请控制在 40 个字以内，不要包含换行或控制字符。"
        case .invalidFileLimit: return "文件上限请填写 1–20000 KB 的整数，或留空不限制。"
        }
    }
}

/// Dimensions are a snapshot. Fixed pixel dimensions are never inferred from a rounded aspect ratio.
public struct IDPhotoTemplate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var widthMM: Double
    public var heightMM: Double
    public var width: Int
    public var height: Int
    public var ppi: Int

    public init(id: String, title: String, widthMM: Double, heightMM: Double, width: Int, height: Int, ppi: Int = 300) {
        self.id = id; self.title = title; self.widthMM = widthMM; self.heightMM = heightMM
        self.width = width; self.height = height; self.ppi = ppi
    }

    public var pixelSize: CGSize { CGSize(width: width, height: height) }
    public var isCustom: Bool { id.hasPrefix("custom-") }
    public var displaySize: String { isCustom ? "\(width) × \(height) px" : millimeterDescription }
    public var dimensionDescription: String { "\(width)×\(height) px · \(ppi) ppi" }
    public var millimeterDescription: String {
        let format: (Double) -> String = { $0.rounded() == $0 ? String(Int($0)) : String(format: "%.1f", $0) }
        return "\(format(widthMM))×\(format(heightMM)) mm"
    }

    public func validate() throws {
        guard (1...100).contains(id.count), (1...100).contains(title.count),
              widthMM.isFinite, heightMM.isFinite, widthMM > 0, heightMM > 0,
              widthMM <= 1_000, heightMM <= 1_000, (72...1_200).contains(ppi),
              (100...2_048).contains(width), (100...2_048).contains(height),
              width * height <= 4_000_000 else { throw IDPhotoValidationError.invalidTemplate }
    }

    public static func custom(width: Int, height: Int, ppi: Int = 300, title: String = "自定义像素") throws -> Self {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "自定义像素" : trimmed
        guard name.count <= 40, name.utf8.count <= 160,
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw IDPhotoValidationError.invalidCustomName
        }
        let value = Self(id: "custom-\(width)x\(height)", title: name, widthMM: Double(width) / Double(ppi) * 25.4,
                         heightMM: Double(height) / Double(ppi) * 25.4, width: width, height: height, ppi: ppi)
        try value.validate()
        return value
    }

    public static func pixels(millimeters: Double, ppi: Int = 300) -> Int? {
        guard millimeters.isFinite, millimeters > 0, millimeters <= 1_000, (72...1_200).contains(ppi) else { return nil }
        return Int((millimeters / 25.4 * Double(ppi)).rounded(.toNearestOrAwayFromZero))
    }

    private enum CodingKeys: String, CodingKey { case id, title, widthMM, heightMM, width, height, ppi }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        widthMM = try c.decode(Double.self, forKey: .widthMM); heightMM = try c.decode(Double.self, forKey: .heightMM)
        width = try c.decode(Int.self, forKey: .width); height = try c.decode(Int.self, forKey: .height)
        ppi = try c.decode(Int.self, forKey: .ppi)
        try validate()
    }
}

public enum IDPhotoTemplateCatalog {
    public static let all: [IDPhotoTemplate] = [
        .init(id: "id-25x35", title: "一寸", widthMM: 25, heightMM: 35, width: 295, height: 413),
        .init(id: "id-35x49", title: "二寸", widthMM: 35, heightMM: 49, width: 413, height: 579),
        .init(id: "id-22x32", title: "小一寸", widthMM: 22, heightMM: 32, width: 260, height: 378),
        .init(id: "id-35x45", title: "小二寸", widthMM: 35, heightMM: 45, width: 413, height: 531),
        .init(id: "id-33x48", title: "大一寸", widthMM: 33, heightMM: 48, width: 390, height: 567)
    ]
    public static let defaultTemplate = all[0]
    public static func template(id: String) -> IDPhotoTemplate? { all.first { $0.id == id } }
    public static func custom(width: Int, height: Int) throws -> IDPhotoTemplate {
        try IDPhotoTemplate.custom(width: width, height: height)
    }
}
