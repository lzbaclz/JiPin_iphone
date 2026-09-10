import Foundation

public enum JiPin {
    public static let schemaVersion = 3
    public static let appGroupID = "group.com.jipin.JiPin"
    public static let displayName = "极拼"
    public static let maxUndo = 50
    public static let maxObjects = 60
    public static let maxTextObjects = 20
    public static let maxDoodleStrokes = 80
    public static let doodleSampleSpacing = 0.008
    public static let autosaveDelayNanoseconds: UInt64 = 500_000_000
    public static let snapThreshold: Double = 8
    public static let jpegQuality: CGFloat = 0.9

    public enum Export {
        public static let standardLongSide: CGFloat = 2048
        public static let hdLongSide: CGFloat = 4096
        public static let longStripStandard: CGFloat = 1080
        public static let longStripHD: CGFloat = 1440
        public static let maxLongSide: CGFloat = 16384
        public static let maxPixelCount: CGFloat = 16_777_216
        public static let extensionLongSide: CGFloat = 2048
    }
}

public enum PhotoLimits {
    public static let pickerWithoutMode = 20
    public static let extensionRange = 2...9

    public static func range(for mode: CollageMode) -> ClosedRange<Int> {
        switch mode {
        case .template: return 2...16
        case .freeform: return 1...16
        case .poster: return 1...9
        case .longStrip: return 2...20
        }
    }

    public static func modes(forPhotoCount count: Int) -> [CollageMode] {
        CollageMode.allCases.filter { range(for: $0).contains(count) }
    }

    public static func validate(_ count: Int, mode: CollageMode?) -> PhotoCountDecision {
        if let mode {
            let r = range(for: mode)
            if count == 0 { return .needPhotos(minimum: r.lowerBound) }
            if count < r.lowerBound { return .tooFew(minimum: r.lowerBound) }
            if count > r.upperBound { return .tooMany(maximum: r.upperBound) }
            return .ok
        }
        if count == 0 { return .needPhotos(minimum: 1) }
        if count > pickerWithoutMode { return .tooMany(maximum: pickerWithoutMode) }
        if modes(forPhotoCount: count).isEmpty { return .tooMany(maximum: pickerWithoutMode) }
        return .ok
    }

    public static func validateExtension(_ count: Int) -> PhotoCountDecision {
        if count == 0 { return .needPhotos(minimum: extensionRange.lowerBound) }
        if count < extensionRange.lowerBound { return .tooFew(minimum: extensionRange.lowerBound) }
        if count > extensionRange.upperBound { return .tooMany(maximum: extensionRange.upperBound) }
        return .ok
    }
}

public enum PhotoCountDecision: Equatable, Sendable {
    case ok
    case needPhotos(minimum: Int)
    case tooFew(minimum: Int)
    case tooMany(maximum: Int)
}

public enum CollageMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case template
    case freeform
    case poster
    case longStrip

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .template: return "模板拼图"
        case .freeform: return "自由拼图"
        case .poster: return "海报拼图"
        case .longStrip: return "长图拼接"
        }
    }

    public var subtitle: String {
        switch self {
        case .template: return "网格与分屏布局"
        case .freeform: return "自由摆放与图层"
        case .poster: return "主题版式与标题"
        case .longStrip: return "横拼或竖拼长图"
        }
    }

    public var systemImage: String {
        switch self {
        case .template: return "square.grid.2x2"
        case .freeform: return "rectangle.3.group"
        case .poster: return "doc.richtext"
        case .longStrip: return "rectangle.split.1x2"
        }
    }
}

public enum ExportJobLock {
    private static let lock = NSLock()
    private static var running = false

    public static func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if running { return false }
        running = true
        return true
    }

    public static func end() {
        lock.lock()
        running = false
        lock.unlock()
    }
}
