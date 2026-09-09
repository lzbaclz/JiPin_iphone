import Foundation

public enum PosterTheme: String, Codable, CaseIterable, Sendable, Identifiable {
    case travel, daily, birthday, holiday, product, social

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .travel: return "旅行"
        case .daily: return "日常记录"
        case .birthday: return "生日"
        case .holiday: return "节日"
        case .product: return "商品展示"
        case .social: return "社交封面"
        }
    }
}

public struct PosterPhotoSlot: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var frame: NormalizedRect
    public var cornerRadius: Double
}

public struct PosterTextSlot: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var defaultText: String
    public var frame: NormalizedRect
    public var style: TextPayload
}

public struct PosterDecoration: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var stickerID: String
    public var frame: NormalizedRect
    public var rotation: Double
}

public struct PosterTemplate: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var theme: PosterTheme
    public var canvas: CanvasSpec
    public var supportedCanvases: [CanvasSpec]
    public var background: BackgroundSpec
    public var photoSlots: [PosterPhotoSlot]
    public var texts: [PosterTextSlot]
    public var decorations: [PosterDecoration]

    public var photoCount: Int { photoSlots.count }
}

public enum PosterTemplateCatalog {
    public static let all: [PosterTemplate] = makeAll()

    public static func template(id: String) -> PosterTemplate? {
        all.first { $0.id == id }
    }

    public static func templates(theme: PosterTheme) -> [PosterTemplate] {
        all.filter { $0.theme == theme }
    }

    public static func matching(photoCount: Int) -> [PosterTemplate] {
        all.filter { $0.photoCount == photoCount }
    }

    public static func closest(photoCount: Int) -> [PosterTemplate] {
        let exact = matching(photoCount: photoCount)
        if !exact.isEmpty { return exact }
        return all.sorted { abs($0.photoCount - photoCount) < abs($1.photoCount - photoCount) }
    }

    private static func makeAll() -> [PosterTemplate] {
        [
            travelJournal(),
            travelMap(),
            travelSunset(),
            dailyFour(),
            dailyNote(),
            dailyMood(),
            dailySplit(),
            birthdayCake(),
            birthdayParty(),
            birthdayWish(),
            holidaySpring(),
            holidayNight(),
            holidayGift(),
            productHero(),
            productCompare(),
            productShelf(),
            socialStory(),
            socialCover(),
            socialQuote(),
            socialGrid()
        ]
    }

    private static func slot(_ id: String, x: Double, y: Double, w: Double, h: Double, r: Double = 0.02) -> PosterPhotoSlot {
        PosterPhotoSlot(id: id, frame: NormalizedRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private static func text(
        _ id: String,
        _ value: String,
        x: Double, y: Double, w: Double, h: Double,
        size: Double,
        color: String,
        font: String = ".AppleSystemUIFont",
        align: TextAlignmentKind = .center
    ) -> PosterTextSlot {
        PosterTextSlot(
            id: id,
            defaultText: value,
            frame: NormalizedRect(x: x, y: y, width: w, height: h),
            style: TextPayload(text: value, fontName: font, fontSize: size, colorHex: color, alignment: align)
        )
    }

    private static func deco(_ id: String, sticker: String, x: Double, y: Double, w: Double, h: Double, rotation: Double = 0) -> PosterDecoration {
        PosterDecoration(
            id: id,
            stickerID: sticker,
            frame: NormalizedRect(x: x, y: y, width: w, height: h),
            rotation: rotation
        )
    }

    private static func travelJournal() -> PosterTemplate {
        PosterTemplate(
            id: "p-travel-journal",
            name: "旅途手记",
            theme: .travel,
            canvas: .portrait34,
            supportedCanvases: [.portrait34, .portrait916],
            background: BackgroundSpec(kind: .solid, presetID: "solid-sand", colorHex: "#EDE4D4"),
            photoSlots: [
                slot("a", x: 0.08, y: 0.18, w: 0.84, h: 0.42, r: 0.01),
                slot("b", x: 0.08, y: 0.62, w: 0.4, h: 0.24),
                slot("c", x: 0.52, y: 0.62, w: 0.4, h: 0.24)
            ],
            texts: [
                text("title", "旅途手记", x: 0.08, y: 0.06, w: 0.84, h: 0.07, size: 0.055, color: "#3A2A1A"),
                text("place", "城市 · 日期", x: 0.08, y: 0.12, w: 0.84, h: 0.05, size: 0.028, color: "#7A5A3A")
            ],
            decorations: [deco("plane", sticker: "life-airplane", x: 0.8, y: 0.055, w: 0.12, h: 0.06)]
        )
    }

    private static func travelMap() -> PosterTemplate {
        PosterTemplate(
            id: "p-travel-map",
            name: "路线打卡",
            theme: .travel,
            canvas: .square,
            supportedCanvases: [.square],
            background: BackgroundSpec(kind: .gradient, presetID: "grad-sky", colorHex: "#C9E7F2", secondaryHex: "#F7F1E3"),
            photoSlots: [
                slot("a", x: 0.06, y: 0.2, w: 0.54, h: 0.62),
                slot("b", x: 0.62, y: 0.2, w: 0.32, h: 0.3),
                slot("c", x: 0.62, y: 0.52, w: 0.32, h: 0.3)
            ],
            texts: [
                text("title", "NEXT STOP", x: 0.06, y: 0.05, w: 0.88, h: 0.08, size: 0.05, color: "#1C3A4A", align: .leading),
                text("place", "地点名称", x: 0.06, y: 0.86, w: 0.88, h: 0.08, size: 0.035, color: "#1C3A4A", align: .leading)
            ],
            decorations: [deco("pin", sticker: "life-location", x: 0.82, y: 0.06, w: 0.1, h: 0.1)]
        )
    }

    private static func travelSunset() -> PosterTemplate {
        PosterTemplate(
            id: "p-travel-sunset",
            name: "日落明信片",
            theme: .travel,
            canvas: .landscape169,
            supportedCanvases: [.landscape169, .landscape43],
            background: BackgroundSpec(kind: .solid, presetID: "solid-dusk", colorHex: "#2A1B18"),
            photoSlots: [slot("a", x: 0.04, y: 0.08, w: 0.6, h: 0.84, r: 0)],
            texts: [
                text("title", "SUNSET", x: 0.68, y: 0.28, w: 0.28, h: 0.2, size: 0.07, color: "#F4E2C7"),
                text("place", "海边\n某一刻", x: 0.68, y: 0.52, w: 0.28, h: 0.24, size: 0.035, color: "#E8C9A2")
            ],
            decorations: []
        )
    }

    private static func dailyFour() -> PosterTemplate {
        PosterTemplate(
            id: "p-daily-four",
            name: "四格日记",
            theme: .daily,
            canvas: .square,
            supportedCanvases: [.square, .portrait34],
            background: BackgroundSpec(kind: .solid, presetID: "solid-cream", colorHex: "#F4F1EA"),
            photoSlots: [
                slot("a", x: 0.06, y: 0.16, w: 0.42, h: 0.36),
                slot("b", x: 0.52, y: 0.16, w: 0.42, h: 0.36),
                slot("c", x: 0.06, y: 0.54, w: 0.42, h: 0.36),
                slot("d", x: 0.52, y: 0.54, w: 0.42, h: 0.36)
            ],
            texts: [text("title", "今日记录", x: 0.06, y: 0.04, w: 0.88, h: 0.1, size: 0.045, color: "#1C1A17")],
            decorations: [deco("note", sticker: "label-daily", x: 0.74, y: 0.045, w: 0.2, h: 0.07)]
        )
    }

    private static func dailyNote() -> PosterTemplate {
        PosterTemplate(
            id: "p-daily-note",
            name: "便签拼贴",
            theme: .daily,
            canvas: .portrait34,
            supportedCanvases: [.portrait34],
            background: BackgroundSpec(kind: .texture, presetID: "tex-paper", colorHex: "#F7F3E8"),
            photoSlots: [
                slot("a", x: 0.1, y: 0.12, w: 0.8, h: 0.46, r: 0.01),
                slot("b", x: 0.1, y: 0.62, w: 0.38, h: 0.24)
            ],
            texts: [
                text("title", "一点点日常", x: 0.52, y: 0.62, w: 0.38, h: 0.1, size: 0.032, color: "#3A3328", align: .leading),
                text("body", "写一句今天的话", x: 0.52, y: 0.72, w: 0.38, h: 0.14, size: 0.024, color: "#6A5E4E", align: .leading)
            ],
            decorations: [deco("heart", sticker: "geo-heart", x: 0.78, y: 0.08, w: 0.1, h: 0.08)]
        )
    }

    private static func dailyMood() -> PosterTemplate {
        PosterTemplate(
            id: "p-daily-mood",
            name: "心情卡片",
            theme: .daily,
            canvas: .portrait916,
            supportedCanvases: [.portrait916],
            background: BackgroundSpec(kind: .gradient, presetID: "grad-peach", colorHex: "#F8D3C5", secondaryHex: "#FFF6EE"),
            photoSlots: [slot("a", x: 0.08, y: 0.12, w: 0.84, h: 0.56, r: 0.04)],
            texts: [
                text("title", "MOOD", x: 0.08, y: 0.72, w: 0.84, h: 0.08, size: 0.05, color: "#5A2A24"),
                text("body", "今天的心情是……", x: 0.08, y: 0.82, w: 0.84, h: 0.1, size: 0.03, color: "#7A4A40")
            ],
            decorations: []
        )
    }

    private static func dailySplit() -> PosterTemplate {
        PosterTemplate(
            id: "p-daily-split",
            name: "左右对照",
            theme: .daily,
            canvas: .landscape43,
            supportedCanvases: [.landscape43, .square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-white", colorHex: "#FFFFFF"),
            photoSlots: [
                slot("a", x: 0.03, y: 0.1, w: 0.46, h: 0.8, r: 0),
                slot("b", x: 0.51, y: 0.1, w: 0.46, h: 0.8, r: 0)
            ],
            texts: [text("title", "BEFORE    AFTER", x: 0.05, y: 0.02, w: 0.9, h: 0.07, size: 0.03, color: "#222222")],
            decorations: [deco("tag", sticker: "label-compare", x: 0.4, y: 0.88, w: 0.2, h: 0.08)]
        )
    }

    private static func birthdayCake() -> PosterTemplate {
        PosterTemplate(
            id: "p-bday-cake",
            name: "生日贺卡",
            theme: .birthday,
            canvas: .portrait34,
            supportedCanvases: [.portrait34, .square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-rose", colorHex: "#F8E1E7"),
            photoSlots: [slot("a", x: 0.14, y: 0.2, w: 0.72, h: 0.5, r: 0.5)],
            texts: [
                text("title", "Happy Birthday", x: 0.08, y: 0.06, w: 0.84, h: 0.1, size: 0.048, color: "#8A3048"),
                text("name", "写下名字", x: 0.08, y: 0.74, w: 0.84, h: 0.08, size: 0.04, color: "#5A2030"),
                text("wish", "祝你生日快乐", x: 0.08, y: 0.84, w: 0.84, h: 0.08, size: 0.028, color: "#8A5060")
            ],
            decorations: [
                deco("gift", sticker: "life-gift", x: 0.08, y: 0.08, w: 0.1, h: 0.08),
                deco("spark", sticker: "life-sparkle", x: 0.82, y: 0.08, w: 0.1, h: 0.08)
            ]
        )
    }

    private static func birthdayParty() -> PosterTemplate {
        PosterTemplate(
            id: "p-bday-party",
            name: "派对拼贴",
            theme: .birthday,
            canvas: .square,
            supportedCanvases: [.square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-lemon", colorHex: "#FFF4C8"),
            photoSlots: [
                slot("a", x: 0.06, y: 0.18, w: 0.54, h: 0.54),
                slot("b", x: 0.62, y: 0.18, w: 0.32, h: 0.26),
                slot("c", x: 0.62, y: 0.46, w: 0.32, h: 0.26)
            ],
            texts: [text("title", "PARTY TIME", x: 0.06, y: 0.76, w: 0.88, h: 0.16, size: 0.055, color: "#D35400")],
            decorations: [deco("flag", sticker: "date-flag", x: 0.78, y: 0.05, w: 0.14, h: 0.1)]
        )
    }

    private static func birthdayWish() -> PosterTemplate {
        PosterTemplate(
            id: "p-bday-wish",
            name: "愿望清单",
            theme: .birthday,
            canvas: .portrait916,
            supportedCanvases: [.portrait916],
            background: BackgroundSpec(kind: .gradient, presetID: "grad-candy", colorHex: "#FFD1DC", secondaryHex: "#E0C3FC"),
            photoSlots: [
                slot("a", x: 0.1, y: 0.12, w: 0.8, h: 0.38),
                slot("b", x: 0.1, y: 0.52, w: 0.38, h: 0.22)
            ],
            texts: [
                text("title", "Make a wish", x: 0.1, y: 0.04, w: 0.8, h: 0.07, size: 0.04, color: "#4A2040"),
                text("list", "愿望 1\n愿望 2\n愿望 3", x: 0.52, y: 0.52, w: 0.38, h: 0.22, size: 0.024, color: "#4A2040", align: .leading)
            ],
            decorations: [deco("star", sticker: "geo-star", x: 0.8, y: 0.76, w: 0.12, h: 0.1)]
        )
    }

    private static func holidaySpring() -> PosterTemplate {
        PosterTemplate(
            id: "p-holi-spring",
            name: "新春祝福",
            theme: .holiday,
            canvas: .portrait34,
            supportedCanvases: [.portrait34],
            background: BackgroundSpec(kind: .solid, presetID: "solid-red", colorHex: "#9B1B1B"),
            photoSlots: [
                slot("a", x: 0.12, y: 0.2, w: 0.76, h: 0.46, r: 0.02)
            ],
            texts: [
                text("title", "新春快乐", x: 0.08, y: 0.06, w: 0.84, h: 0.1, size: 0.055, color: "#F8E6C8"),
                text("wish", "万事如意 年年有余", x: 0.08, y: 0.72, w: 0.84, h: 0.16, size: 0.032, color: "#F8E6C8")
            ],
            decorations: [deco("leaf", sticker: "life-leaf", x: 0.08, y: 0.08, w: 0.1, h: 0.08)]
        )
    }

    private static func holidayNight() -> PosterTemplate {
        PosterTemplate(
            id: "p-holi-night",
            name: "节日夜色",
            theme: .holiday,
            canvas: .landscape169,
            supportedCanvases: [.landscape169],
            background: BackgroundSpec(kind: .solid, presetID: "solid-night", colorHex: "#12162A"),
            photoSlots: [
                slot("a", x: 0.0, y: 0.0, w: 1, h: 1, r: 0)
            ],
            texts: [
                text("title", "FESTIVE NIGHT", x: 0.08, y: 0.72, w: 0.84, h: 0.1, size: 0.045, color: "#FFFFFF", align: .leading),
                text("date", "写下日期", x: 0.08, y: 0.84, w: 0.5, h: 0.08, size: 0.03, color: "#F8E6C8", align: .leading)
            ],
            decorations: [deco("moon", sticker: "life-moon", x: 0.84, y: 0.08, w: 0.1, h: 0.12)]
        )
    }

    private static func holidayGift() -> PosterTemplate {
        PosterTemplate(
            id: "p-holi-gift",
            name: "礼物清单",
            theme: .holiday,
            canvas: .square,
            supportedCanvases: [.square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-pine", colorHex: "#1F4A3A"),
            photoSlots: [
                slot("a", x: 0.08, y: 0.18, w: 0.4, h: 0.62),
                slot("b", x: 0.52, y: 0.18, w: 0.4, h: 0.3),
                slot("c", x: 0.52, y: 0.5, w: 0.4, h: 0.3)
            ],
            texts: [text("title", "GIFT LIST", x: 0.08, y: 0.04, w: 0.84, h: 0.12, size: 0.05, color: "#F4E2C7")],
            decorations: [deco("gift", sticker: "life-gift", x: 0.82, y: 0.84, w: 0.1, h: 0.1)]
        )
    }

    private static func productHero() -> PosterTemplate {
        PosterTemplate(
            id: "p-prod-hero",
            name: "主图详情",
            theme: .product,
            canvas: .portrait34,
            supportedCanvases: [.portrait34, .square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-white", colorHex: "#FFFFFF"),
            photoSlots: [
                slot("a", x: 0.08, y: 0.08, w: 0.84, h: 0.54, r: 0.02),
                slot("b", x: 0.08, y: 0.65, w: 0.26, h: 0.18, r: 0.01),
                slot("c", x: 0.37, y: 0.65, w: 0.26, h: 0.18, r: 0.01),
                slot("d", x: 0.66, y: 0.65, w: 0.26, h: 0.18, r: 0.01)
            ],
            texts: [
                text("title", "商品名称", x: 0.08, y: 0.85, w: 0.84, h: 0.06, size: 0.032, color: "#1A1A1A", align: .leading),
                text("price", "价格 / 卖点", x: 0.08, y: 0.91, w: 0.84, h: 0.05, size: 0.024, color: "#C0392B", align: .leading)
            ],
            decorations: [deco("new", sticker: "label-new", x: 0.72, y: 0.1, w: 0.18, h: 0.07)]
        )
    }

    private static func productCompare() -> PosterTemplate {
        PosterTemplate(
            id: "p-prod-compare",
            name: "细节对比",
            theme: .product,
            canvas: .landscape43,
            supportedCanvases: [.landscape43],
            background: BackgroundSpec(kind: .solid, presetID: "solid-gray", colorHex: "#F2F2F2"),
            photoSlots: [
                slot("a", x: 0.04, y: 0.14, w: 0.44, h: 0.72, r: 0.01),
                slot("b", x: 0.52, y: 0.14, w: 0.44, h: 0.72, r: 0.01)
            ],
            texts: [
                text("l", "细节 A", x: 0.04, y: 0.04, w: 0.44, h: 0.08, size: 0.03, color: "#222"),
                text("r", "细节 B", x: 0.52, y: 0.04, w: 0.44, h: 0.08, size: 0.03, color: "#222")
            ],
            decorations: [deco("arrow", sticker: "arrow-right", x: 0.45, y: 0.46, w: 0.1, h: 0.08)]
        )
    }

    private static func productShelf() -> PosterTemplate {
        PosterTemplate(
            id: "p-prod-shelf",
            name: "货架九图",
            theme: .product,
            canvas: .square,
            supportedCanvases: [.square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-white", colorHex: "#FFFFFF"),
            photoSlots: (0..<9).map { i in
                let c = Double(i % 3)
                let r = Double(i / 3)
                return slot("p\(i)", x: 0.04 + c * 0.31, y: 0.12 + r * 0.28, w: 0.29, h: 0.26, r: 0.01)
            },
            texts: [text("title", "系列展示", x: 0.04, y: 0.02, w: 0.7, h: 0.08, size: 0.036, color: "#111", align: .leading)],
            decorations: [deco("hot", sticker: "label-hot", x: 0.76, y: 0.03, w: 0.18, h: 0.07)]
        )
    }

    private static func socialStory() -> PosterTemplate {
        PosterTemplate(
            id: "p-soc-story",
            name: "故事封面",
            theme: .social,
            canvas: .portrait916,
            supportedCanvases: [.portrait916],
            background: BackgroundSpec(kind: .solid, presetID: "solid-ink", colorHex: "#111111"),
            photoSlots: [slot("a", x: 0, y: 0, w: 1, h: 1, r: 0)],
            texts: [
                text("title", "写下标题", x: 0.08, y: 0.72, w: 0.84, h: 0.1, size: 0.048, color: "#FFFFFF", align: .leading),
                text("sub", "补充一句说明", x: 0.08, y: 0.84, w: 0.84, h: 0.08, size: 0.026, color: "#EEEEEE", align: .leading)
            ],
            decorations: []
        )
    }

    private static func socialCover() -> PosterTemplate {
        PosterTemplate(
            id: "p-soc-cover",
            name: "双图封面",
            theme: .social,
            canvas: .portrait916,
            supportedCanvases: [.portrait916, .portrait34],
            background: BackgroundSpec(kind: .solid, presetID: "solid-navy", colorHex: "#1B2430"),
            photoSlots: [
                slot("a", x: 0, y: 0, w: 1, h: 0.62, r: 0),
                slot("b", x: 0.08, y: 0.5, w: 0.36, h: 0.22, r: 0.02)
            ],
            texts: [
                text("title", "封面标题", x: 0.08, y: 0.76, w: 0.84, h: 0.1, size: 0.045, color: "#FFFFFF", align: .leading)
            ],
            decorations: [deco("cam", sticker: "life-camera", x: 0.82, y: 0.08, w: 0.1, h: 0.08)]
        )
    }

    private static func socialQuote() -> PosterTemplate {
        PosterTemplate(
            id: "p-soc-quote",
            name: "金句卡片",
            theme: .social,
            canvas: .square,
            supportedCanvases: [.square, .portrait34],
            background: BackgroundSpec(kind: .gradient, presetID: "grad-ink", colorHex: "#232526", secondaryHex: "#414345"),
            photoSlots: [slot("a", x: 0.08, y: 0.08, w: 0.84, h: 0.5, r: 0.02)],
            texts: [
                text("quote", "“把想说的话写在这里”", x: 0.08, y: 0.62, w: 0.84, h: 0.2, size: 0.036, color: "#FFFFFF"),
                text("by", "— 署名", x: 0.08, y: 0.84, w: 0.84, h: 0.08, size: 0.024, color: "#DDDDDD")
            ],
            decorations: [deco("quote", sticker: "date-quote", x: 0.08, y: 0.6, w: 0.08, h: 0.08)]
        )
    }

    private static func socialGrid() -> PosterTemplate {
        PosterTemplate(
            id: "p-soc-grid",
            name: "三图封面",
            theme: .social,
            canvas: .portrait34,
            supportedCanvases: [.portrait34, .square],
            background: BackgroundSpec(kind: .solid, presetID: "solid-cream", colorHex: "#F4F1EA"),
            photoSlots: [
                slot("a", x: 0.06, y: 0.16, w: 0.88, h: 0.42),
                slot("b", x: 0.06, y: 0.6, w: 0.43, h: 0.28),
                slot("c", x: 0.51, y: 0.6, w: 0.43, h: 0.28)
            ],
            texts: [text("title", "本周精选", x: 0.06, y: 0.04, w: 0.88, h: 0.1, size: 0.045, color: "#1C1A17", align: .leading)],
            decorations: [deco("like", sticker: "label-like", x: 0.74, y: 0.05, w: 0.18, h: 0.07)]
        )
    }
}
