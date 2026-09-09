import Foundation

public struct PhotoStyle: Codable, Hashable, Sendable {
    public var filterID: String?
    public var intensity: Double
    public var adjust: ColorAdjust
    public var corner: Double
    public var stroke: StrokeStyle
    public var shadow: ShadowStyle
    public var polaroid: Bool

    public init(photo: PhotoPayload) {
        filterID = photo.filterID; intensity = photo.filterIntensity; adjust = photo.colorAdjust
        corner = photo.cornerRadius; stroke = photo.stroke; shadow = photo.shadow; polaroid = photo.polaroid
    }

    public func apply(to photo: inout PhotoPayload, effectsOnly: Bool = false) {
        photo.filterID = filterID; photo.filterIntensity = intensity; photo.colorAdjust = adjust
        if !effectsOnly {
            photo.cornerRadius = corner; photo.stroke = stroke; photo.shadow = shadow; photo.polaroid = polaroid
        }
    }
}

/// A reusable look contains no user photographs, text, layout slots or external asset references.
public struct StyleRecipe: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var background: BackgroundSpec
    public var spacing: Double
    public var margin: Double
    public var photoStyle: PhotoStyle

    public init(id: String = UUID().uuidString, name: String, subtitle: String = "我的搭配",
                project: CollageProject, photo: PhotoPayload? = nil) {
        self.id = id; self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)); self.subtitle = subtitle
        background = project.background
        if background.kind == .image { background.kind = .solid; background.presetID = nil }
        background.imageAssetID = nil
        background.isHidden = false
        spacing = project.spacing; margin = project.outerMargin
        photoStyle = PhotoStyle(photo: photo ?? project.photoLayers.first?.photo ?? PhotoPayload(assetID: UUID()))
    }

    public func applying(to original: CollageProject) -> CollageProject {
        var project = original
        project.background = background
        project.spacing = spacing; project.outerMargin = margin
        for index in project.objects.indices where !project.objects[index].isLocked {
            if var photo = project.objects[index].photo {
                photoStyle.apply(to: &photo)
                project.objects[index].photo = photo
            }
            if project.objects[index].text?.backgroundHex == nil, project.objects[index].text != nil {
                project.objects[index].text?.colorHex = Self.readableText(on: background.colorHex)
            }
        }
        return project
    }

    private static func readableText(on hex: String) -> String {
        let value = UInt32(String(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).prefix(6)), radix: 16) ?? 0xFFFFFF
        let luma = (Double((value >> 16) & 255) * 0.2126 + Double((value >> 8) & 255) * 0.7152 + Double(value & 255) * 0.0722) / 255
        return luma < 0.5 ? "#FFF6E8" : "#352E2B"
    }
}

public enum StyleRecipeCatalog {
    public static let all: [StyleRecipe] = [
        make("cream", "奶油日记", "暖白留边 · 柔和日常", "#FFF4E5", "daily", 0.4, 0.045, 0.045),
        make("mint", "薄荷旅行", "清新底色 · 轻盈圆角", "#E5F3E9", "fresh", 0.35, 0.06, 0.035),
        make("film", "胶片时光", "拍立得边 · 复古褪色", "#EBDFC9", "film", 0.7, 0.0, 0.05, true),
        make("white", "极简留白", "纯白画廊 · 保留原色", "#FFFFFF", nil, 1, 0.0, 0.06),
        make("sunset", "落日来信", "蜜桃暖调 · 温柔圆角", "#FAE0D9", "warm", 0.45, 0.05, 0.035),
        make("night", "午夜街头", "墨色边框 · 冷调光影", "#192329", "cool", 0.5, 0.01, 0.025)
    ]

    private static func make(_ id: String, _ name: String, _ subtitle: String, _ color: String,
                             _ filter: String?, _ intensity: Double, _ corner: Double, _ margin: Double,
                             _ polaroid: Bool = false) -> StyleRecipe {
        var project = CollageProject(mode: .template)
        project.background = BackgroundSpec(kind: .solid, presetID: nil, colorHex: color)
        project.spacing = 0.018; project.outerMargin = margin
        var photo = PhotoPayload(assetID: UUID())
        photo.filterID = filter; photo.filterIntensity = intensity; photo.cornerRadius = corner; photo.polaroid = polaroid
        return StyleRecipe(id: id, name: name, subtitle: subtitle, project: project, photo: photo)
    }
}

public struct StyleRecipeStore {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private var file: URL { directory.appendingPathComponent("styles.json") }

    public func load() throws -> [StyleRecipe] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([StyleRecipe].self, from: Data(contentsOf: file))
    }

    public func save(_ recipes: [StyleRecipe]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var location = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try location.setResourceValues(values)
        try JSONEncoder().encode(recipes).write(to: file, options: .atomic)
    }
}
