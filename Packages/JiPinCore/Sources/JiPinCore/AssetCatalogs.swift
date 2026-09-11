import Foundation

public enum StickerCategory: String, CaseIterable, Sendable, Identifiable {
    case cute, cool, label, date, arrow, geometry, life

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cute: return "可爱"
        case .cool: return "酷感"
        case .label: return "标签"
        case .date: return "日期"
        case .arrow: return "箭头"
        case .geometry: return "形状"
        case .life: return "生活"
        }
    }
}

public struct GeometryShape: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
}

public enum GeometryShapeCatalog {
    public static let all: [GeometryShape] = [
        .init(id: "arrow", name: "箭头"),
        .init(id: "triangle", name: "三角"),
        .init(id: "circle", name: "圆形"),
        .init(id: "square", name: "方形"),
        .init(id: "roundrect", name: "圆角"),
        .init(id: "star", name: "星形"),
        .init(id: "heart", name: "心形"),
        .init(id: "diamond", name: "菱形"),
        .init(id: "hexagon", name: "六边"),
        .init(id: "line", name: "直线")
    ]
}

public enum StickerRender: Hashable, Sendable {
    case illustration(String)
    case symbol(String)
    case badge
    case shape(String)
}

public struct StickerDefinition: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var category: StickerCategory
    public var render: StickerRender
    public var defaultTint: String
}

public enum StickerCatalog {
    public static let all: [StickerDefinition] = makeAll()

    public static func sticker(id: String) -> StickerDefinition? {
        all.first { $0.id == id }
    }

    public static func stickers(in category: StickerCategory) -> [StickerDefinition] {
        all.filter { $0.category == category }
    }

    private static func makeAll() -> [StickerDefinition] {
        var items: [StickerDefinition] = []
        func add(_ id: String, _ name: String, _ category: StickerCategory, _ render: StickerRender, tint: String = "#1C1A17") {
            items.append(StickerDefinition(id: id, name: name, category: category, render: render, defaultTint: tint))
        }

        let labels = [
            ("label-travel", "旅行"), ("label-daily", "日常"), ("label-birthday", "生日"),
            ("label-holiday", "节日"), ("label-new", "新品"), ("label-hot", "热卖"),
            ("label-compare", "对比"), ("label-recommend", "推荐"), ("label-new-en", "NEW"),
            ("label-sale", "SALE"), ("label-checkin", "打卡"), ("label-like", "喜欢")
        ]
        for (id, name) in labels { add(id, name, .label, .badge, tint: "#FF5A36") }

        add("date-calendar", "日历", .date, .symbol("calendar"))
        add("date-clock", "时钟", .date, .symbol("clock"))
        add("date-flag", "旗帜", .date, .symbol("flag"))
        add("date-bookmark", "书签", .date, .symbol("bookmark"))
        add("date-pin", "图钉", .date, .symbol("pin"))
        add("date-number", "数字", .date, .symbol("number"))
        add("date-text", "文字", .date, .symbol("textformat"))
        add("date-quote", "引号", .date, .symbol("quote.opening"))

        add("arrow-up", "向上", .arrow, .symbol("arrow.up"))
        add("arrow-down", "向下", .arrow, .symbol("arrow.down"))
        add("arrow-left", "向左", .arrow, .symbol("arrow.left"))
        add("arrow-right", "向右", .arrow, .symbol("arrow.right"))
        add("arrow-up-left", "左上", .arrow, .symbol("arrow.up.left"))
        add("arrow-up-right", "右上", .arrow, .symbol("arrow.up.right"))
        add("arrow-forward", "前进", .arrow, .symbol("arrow.forward"))
        add("arrow-swap", "互换", .arrow, .symbol("arrow.left.arrow.right"))

        add("geo-circle", "圆形", .geometry, .shape("circle"))
        add("geo-square", "方形", .geometry, .shape("square"))
        add("geo-triangle", "三角", .geometry, .shape("triangle"))
        add("geo-hexagon", "六边", .geometry, .shape("hexagon"))
        add("geo-star", "星星", .geometry, .shape("star"), tint: "#F4C430")
        add("geo-heart", "心形", .geometry, .shape("heart"), tint: "#E85D75")
        add("geo-diamond", "菱形", .geometry, .shape("diamond"))
        add("geo-plus", "加号", .geometry, .shape("plus"))
        add("geo-ring", "圆环", .geometry, .shape("ring"))
        add("geo-roundrect", "圆角矩形", .geometry, .shape("roundrect"))
        add("geo-oval", "椭圆", .geometry, .shape("oval"))
        add("geo-line", "线条", .geometry, .shape("line"))

        add("life-airplane", "飞机", .life, .symbol("airplane"))
        add("life-car", "汽车", .life, .symbol("car"))
        add("life-camera", "相机", .life, .symbol("camera"))
        add("life-photo", "照片", .life, .symbol("photo"))
        add("life-leaf", "叶子", .life, .symbol("leaf"))
        add("life-sun", "太阳", .life, .symbol("sun.max"))
        add("life-moon", "月亮", .life, .symbol("moon"))
        add("life-cloud", "云", .life, .symbol("cloud"))
        add("life-cup", "杯子", .life, .symbol("cup.and.saucer"))
        add("life-gift", "礼物", .life, .symbol("gift"))
        add("life-music", "音乐", .life, .symbol("music.note"))
        add("life-book", "书本", .life, .symbol("book"))
        add("life-location", "地点", .life, .symbol("location"))
        add("life-walk", "步行", .life, .symbol("figure.walk"))
        add("life-bike", "自行车", .life, .symbol("bicycle"))
        add("life-umbrella", "雨伞", .life, .symbol("umbrella"))
        add("life-sparkle", "闪光", .life, .symbol("sparkles"))
        add("life-flame", "火焰", .life, .symbol("flame"))
        add("life-snow", "雪花", .life, .symbol("snowflake"))
        add("life-drop", "水滴", .life, .symbol("drop"))
        let originals = [("bunny", "软软兔"), ("bear", "奶油熊"), ("cat", "橘子喵"), ("strawberry", "甜心草莓"),
                         ("cherries", "樱桃双双"), ("bow", "奶糖蝴蝶结"), ("daisy", "微笑雏菊"), ("cloud", "棉花云"),
                         ("moon", "晚安星月"), ("letter", "心动来信"), ("pudding", "焦糖布丁"), ("boba", "珍珠奶茶"),
                         ("peach", "水蜜桃桃"), ("rainbow", "雨后彩虹"), ("candy", "薄荷糖果"), ("cake", "生日小蛋糕")]
        for (key, name) in originals { add("cute-\(key)", name, .cute, .illustration(key), tint: "#F2A8B8") }
        add("cool-bolt", "闪电徽章", .cool, .illustration("bolt"), tint: "#C4EF78")
        add("cool-orbit", "星际飞行", .cool, .illustration("orbit"), tint: "#8ACCE3")
        for (key, name) in [("film-frame", "胶片瞬间"), ("headphones", "随身节拍"), ("comet", "流星信号"),
                            ("checker", "棋盘浪潮"), ("mountain", "山野徽章"), ("vinyl", "黑胶时刻")] {
            add("cool-\(key)", name, .cool, .illustration(key), tint: "#BDE783")
        }
        return items
    }
}

public enum BackgroundTexture: String, Sendable {
    case dots, grid, noise, paper
}

public struct BackgroundPreset: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var spec: BackgroundSpec
    public var texture: BackgroundTexture?
}

public enum BackgroundCatalog {
    public static let all: [BackgroundPreset] = [
        .init(id: "solid-cream", name: "米白", spec: BackgroundSpec(kind: .solid, presetID: "solid-cream", colorHex: "#F4F1EA"), texture: nil),
        .init(id: "solid-white", name: "纯白", spec: BackgroundSpec(kind: .solid, presetID: "solid-white", colorHex: "#FFFFFF"), texture: nil),
        .init(id: "solid-sand", name: "沙色", spec: BackgroundSpec(kind: .solid, presetID: "solid-sand", colorHex: "#EDE4D4"), texture: nil),
        .init(id: "solid-ink", name: "墨黑", spec: BackgroundSpec(kind: .solid, presetID: "solid-ink", colorHex: "#111111"), texture: nil),
        .init(id: "solid-navy", name: "海军蓝", spec: BackgroundSpec(kind: .solid, presetID: "solid-navy", colorHex: "#1B2430"), texture: nil),
        .init(id: "solid-rose", name: "玫瑰粉", spec: BackgroundSpec(kind: .solid, presetID: "solid-rose", colorHex: "#F8E1E7"), texture: nil),
        .init(id: "solid-red", name: "节日红", spec: BackgroundSpec(kind: .solid, presetID: "solid-red", colorHex: "#9B1B1B"), texture: nil),
        .init(id: "solid-pine", name: "松绿", spec: BackgroundSpec(kind: .solid, presetID: "solid-pine", colorHex: "#1F4A3A"), texture: nil),
        .init(id: "grad-sky", name: "天空", spec: BackgroundSpec(kind: .gradient, presetID: "grad-sky", colorHex: "#C9E7F2", secondaryHex: "#F7F1E3"), texture: nil),
        .init(id: "grad-peach", name: "蜜桃", spec: BackgroundSpec(kind: .gradient, presetID: "grad-peach", colorHex: "#F8D3C5", secondaryHex: "#FFF6EE"), texture: nil),
        .init(id: "grad-candy", name: "糖果", spec: BackgroundSpec(kind: .gradient, presetID: "grad-candy", colorHex: "#FFD1DC", secondaryHex: "#E0C3FC"), texture: nil),
        .init(id: "grad-ink", name: "暮色", spec: BackgroundSpec(kind: .gradient, presetID: "grad-ink", colorHex: "#232526", secondaryHex: "#414345"), texture: nil),
        .init(id: "grad-warm", name: "暖阳", spec: BackgroundSpec(kind: .gradient, presetID: "grad-warm", colorHex: "#F6D365", secondaryHex: "#FDA085"), texture: nil),
        .init(id: "grad-cool", name: "冷青", spec: BackgroundSpec(kind: .gradient, presetID: "grad-cool", colorHex: "#89F7FE", secondaryHex: "#66A6FF"), texture: nil),
        .init(id: "grad-dusk", name: "黄昏", spec: BackgroundSpec(kind: .gradient, presetID: "grad-dusk", colorHex: "#0F2027", secondaryHex: "#2C5364"), texture: nil),
        .init(id: "grad-mint", name: "薄荷", spec: BackgroundSpec(kind: .gradient, presetID: "grad-mint", colorHex: "#D4FC79", secondaryHex: "#96E6A1"), texture: nil),
        .init(id: "tex-dots", name: "点点", spec: BackgroundSpec(kind: .texture, presetID: "tex-dots", colorHex: "#F4F1EA"), texture: .dots),
        .init(id: "tex-grid", name: "网格", spec: BackgroundSpec(kind: .texture, presetID: "tex-grid", colorHex: "#F7F3E8"), texture: .grid),
        .init(id: "tex-noise", name: "噪点", spec: BackgroundSpec(kind: .texture, presetID: "tex-noise", colorHex: "#EEEAE2"), texture: .noise),
        .init(id: "tex-paper", name: "纸纹", spec: BackgroundSpec(kind: .texture, presetID: "tex-paper", colorHex: "#F7F3E8"), texture: .paper)
    ]

    public static func preset(id: String) -> BackgroundPreset? {
        all.first { $0.id == id }
    }
}

public struct FilterPreset: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var ciName: String?
    public var extraContrast: Double
    public var extraSaturation: Double
    public var extraTemperature: Double
}

public enum FilterCatalog {
    public static let all: [FilterPreset] = [
        .init(id: "daily", name: "日常", ciName: nil, extraContrast: 1.05, extraSaturation: 1.04, extraTemperature: 0.05),
        .init(id: "vivid", name: "鲜艳", ciName: "CIPhotoEffectChrome", extraContrast: 1.08, extraSaturation: 1.15, extraTemperature: 0),
        .init(id: "film", name: "胶片", ciName: "CIPhotoEffectFade", extraContrast: 0.95, extraSaturation: 0.9, extraTemperature: 0.08),
        .init(id: "warm", name: "暖阳", ciName: nil, extraContrast: 1.04, extraSaturation: 1.08, extraTemperature: 0.35),
        .init(id: "cool", name: "冷青", ciName: nil, extraContrast: 1.04, extraSaturation: 0.95, extraTemperature: -0.35),
        .init(id: "mono", name: "黑白", ciName: "CIPhotoEffectMono", extraContrast: 1.1, extraSaturation: 0, extraTemperature: 0),
        .init(id: "fade", name: "褪色", ciName: "CIPhotoEffectInstant", extraContrast: 0.92, extraSaturation: 0.85, extraTemperature: 0.12),
        .init(id: "dusk", name: "暮色", ciName: "CIPhotoEffectProcess", extraContrast: 1.12, extraSaturation: 0.9, extraTemperature: -0.1),
        .init(id: "fresh", name: "清新", ciName: "CIPhotoEffectTransfer", extraContrast: 1.02, extraSaturation: 1.05, extraTemperature: -0.05),
        .init(id: "drama", name: "戏剧", ciName: "CIPhotoEffectNoir", extraContrast: 1.2, extraSaturation: 0.2, extraTemperature: 0)
    ]

    public static func preset(id: String) -> FilterPreset? {
        all.first { $0.id == id }
    }
}

public enum SystemFontOption: String, CaseIterable, Sendable, Identifiable {
    case system
    case rounded
    case serif
    case monospaced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "系统"
        case .rounded: return "圆体"
        case .serif: return "衬线"
        case .monospaced: return "等宽"
        }
    }

    public var fontName: String {
        switch self {
        case .system: return ".AppleSystemUIFont"
        case .rounded: return ".AppleSystemUIFontRounded"
        case .serif: return ".AppleSystemUIFontSerif"
        case .monospaced: return ".AppleSystemUIFontMonospaced"
        }
    }
}
