import Foundation

@main
struct ExportDesignAssets {
    struct Sticker: Encodable {
        let id: String
        let name: String
        let category: String
        let kind: String
        let drawing: String
        let color: String
    }
    struct Background: Encodable {
        let id: String
        let name: String
        let spec: BackgroundSpec
        let texture: String?
    }
    struct Filter: Encodable {
        let id: String
        let name: String
        let coreImageFilter: String?
        let contrast: Double
        let saturation: Double
        let temperature: Double
    }
    struct Catalog: Encodable {
        let schemaVersion = 3
        let layouts = CollageGridLayoutCatalog.all
        let posters = PosterTemplateCatalog.all
        let stickers: [Sticker]
        let backgrounds: [Background]
        let filters: [Filter]
        let styles = StyleRecipeCatalog.all
        let decorativeFrames = DecorationFrameCatalog.all
        let illustrationSource = "Apps/JiPin/StudioPreviews.swift"
    }

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "JiPinDesignExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pass the output JSON path."])
        }
        let catalog = Catalog(
            stickers: StickerCatalog.all.map { item in
                let kind: String
                let drawing: String
                switch item.render {
                case .symbol(let name): kind = "systemSymbol"; drawing = name
                case .shape(let name): kind = "shape"; drawing = name
                case .badge: kind = "badge"; drawing = item.name
                case .illustration(let name): kind = "originalVector"; drawing = name
                }
                return Sticker(id: item.id, name: item.name, category: item.category.rawValue,
                               kind: kind, drawing: drawing, color: item.defaultTint)
            },
            backgrounds: BackgroundCatalog.all.map { Background(id: $0.id, name: $0.name, spec: $0.spec, texture: $0.texture?.rawValue) },
            filters: FilterCatalog.all.map { Filter(id: $0.id, name: $0.name, coreImageFilter: $0.ciName,
                                                   contrast: $0.extraContrast, saturation: $0.extraSaturation, temperature: $0.extraTemperature) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(catalog).write(to: destination, options: .atomic)
        print("Exported \(catalog.layouts.count) layouts, \(catalog.posters.count) posters, \(catalog.stickers.count) stickers, \(catalog.backgrounds.count) backgrounds and \(catalog.filters.count) filters.")
    }
}
