import SwiftUI
import JiPinCore

struct ModePickerSheet: View {
    let photos: [ImportedPhoto]
    var preset: CollageMode?
    var preferredLayoutID: String?
    var preferredPosterID: String?
    var locksMode: Bool
    var onStart: (CollageMode, String?, String?, [ImportedPhoto]) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var assets: AssetLibrary
    @State private var mode: CollageMode?
    @State private var layoutID: String?
    @State private var posterID: String?
    @State private var selectedPhotos: Set<Int> = []
    @State private var preview: CollageProject?
    @State private var choices: [ResultChoice] = []

    private struct ResultChoice: Identifiable {
        let id: String
        let name: String
        let project: CollageProject
    }

    init(photos: [ImportedPhoto], preset: CollageMode? = nil, preferredLayoutID: String? = nil,
         preferredPosterID: String? = nil, locksMode: Bool = false,
         onStart: @escaping (CollageMode, String?, String?, [ImportedPhoto]) -> Void) {
        self.photos = photos; self.preset = preset; self.preferredLayoutID = preferredLayoutID
        self.preferredPosterID = preferredPosterID; self.locksMode = locksMode; self.onStart = onStart
        _assets = StateObject(wrappedValue: AssetLibrary(photos: photos))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(locksMode ? (preset == .poster ? "选择喜欢的海报" : "选择喜欢的布局") : "你的照片，先看看效果").font(.title3.bold())
                        Spacer()
                        Text("\(photos.count) 张").font(.subheadline).foregroundStyle(.secondary)
                    }
                    modeHints
                    if !locksMode && !availableModes.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(availableModes) { item in
                                Button { chooseMode(item) } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: item.systemImage)
                                        Text(shortName(item)).font(.subheadline.weight(.semibold))
                                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .foregroundStyle(mode == item ? Color.white : JiPinTheme.ink)
                                        .background(mode == item ? JiPinTheme.accent : JiPinTheme.surface,
                                                    in: RoundedRectangle(cornerRadius: 14))
                                }.buttonStyle(.plain).accessibilityLabel(item.title)
                                    .accessibilityAddTraits(mode == item ? .isSelected : [])
                                    .accessibilityIdentifier("mode-choice-\(item.rawValue)")
                            }
                        }
                    }
                    if let preview {
                        ProjectThumbnail(project: preview, assets: assets, side: 650)
                            .frame(maxWidth: .infinity).frame(height: 250)
                            .padding(12).background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(mode?.title ?? "")实图预览，\(chosenPhotos.count)张照片")
                            .accessibilityIdentifier("mode-result-preview")
                    }
                    if !choices.isEmpty {
                        Text(mode == .poster ? "挑一张海报" : "换个布局")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(spacing: 12) {
                                ForEach(choices) { choice in
                                    Button {
                                        if mode == .poster { posterID = choice.id; resetPosterPhotos() }
                                        else { layoutID = choice.id; refreshPreview() }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ProjectThumbnail(project: choice.project, assets: assets, side: 260)
                                                .frame(width: 116, height: 130)
                                            HStack(spacing: 4) {
                                                Text(choice.name).font(.caption.weight(.medium)).lineLimit(2)
                                                if (mode == .poster ? posterID : layoutID) == choice.id {
                                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(JiPinTheme.accent)
                                                }
                                            }.frame(width: 116, alignment: .leading)
                                        }.padding(8).background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                                    }.buttonStyle(.plain).accessibilityLabel(choice.name)
                                        .accessibilityIdentifier("mode-result-\(choice.id)")
                                }
                            }
                        }
                    }
                    posterPhotoSelection
                    if chosenPhotos.filter({ $0.liveClip != nil }).count > LivePhotoPolicy.maxSources {
                        Text("每份动态拼图最多 9 张 Live，请返回减少 Live 照片后再开始。")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    Text("进入后还能调整布局、风格和文字，作品会自动保存为草稿。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background(JiPinTheme.canvas)
            .safeAreaInset(edge: .bottom) {
                Button { start() } label: {
                    Text("开始").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!canStart).accessibilityIdentifier("mode-start")
                    .padding().background(.regularMaterial)
            }
            .navigationTitle(locksMode ? (preset == .poster ? "选择海报" : "选择布局") : "选择模式").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onAppear {
                guard mode == nil else { return }
                chooseMode(preset.flatMap { availableModes.contains($0) ? $0 : nil } ?? availableModes.first)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder private var modeHints: some View {
        if photos.isEmpty {
            Text("还没有照片。请先选择至少 1 张。").accessibilityIdentifier("mode-hint-empty")
        } else if availableModes.isEmpty {
            Text("当前 \(photos.count) 张超出模式上限，请减少照片后再开始。")
                .accessibilityIdentifier("mode-hint-overflow")
        } else if !locksMode && photos.count == 1 {
            Text("1 张照片可进入自由拼图或海报拼图。模板与长图至少需要 2 张。")
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("mode-hint-single")
        } else if !locksMode && photos.count >= 17 {
            Text("\(photos.count) 张只能使用长图拼接。模板与自由拼图最多 16 张，海报最多 9 张。")
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("mode-hint-longstrip-only")
        }
    }

    @ViewBuilder private var posterPhotoSelection: some View {
        if mode == .poster, let template = posterID.flatMap(PosterTemplateCatalog.template(id:)), template.photoCount != photos.count {
            Text("为「\(template.name)」选择 \(template.photoCount) 张照片").font(.headline)
            if template.photoCount > photos.count {
                Text("照片不足，请换一个照片位更少的模板，或返回重新选图。").foregroundStyle(.secondary)
            } else {
                Text("已选 \(selectedPhotos.count)/\(template.photoCount) 张，其他照片不会放入这张海报。")
                    .font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))]) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        Button {
                            if selectedPhotos.contains(index) { selectedPhotos.remove(index) }
                            else if selectedPhotos.count < template.photoCount { selectedPhotos.insert(index) }
                            refreshPreview()
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                if let image = ImageIOHelpers.thumbnail(from: photo.data, maxLongSide: 160) {
                                    Image(uiImage: UIImage(cgImage: image)).resizable().scaledToFill().frame(width: 70, height: 70).clipped()
                                }
                                Image(systemName: selectedPhotos.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.white, JiPinTheme.accent).padding(4)
                            }.clipShape(RoundedRectangle(cornerRadius: 10))
                        }.accessibilityLabel("照片 \(index + 1)")
                            .accessibilityValue(selectedPhotos.contains(index) ? "已选择" : "未选择")
                    }
                }
            }
        }
    }

    private var availableModes: [CollageMode] {
        let modes = PhotoLimits.modes(forPhotoCount: photos.count)
        if locksMode, let preset { return modes.contains(preset) ? [preset] : [] }
        return modes
    }
    private var chosenPhotos: [ImportedPhoto] {
        mode == .poster ? photos.enumerated().filter { selectedPhotos.contains($0.offset) }.map(\.element) : photos
    }
    private var canStart: Bool {
        guard let mode, availableModes.contains(mode), chosenPhotos.filter({ $0.liveClip != nil }).count <= LivePhotoPolicy.maxSources else { return false }
        if mode == .poster {
            guard let template = posterID.flatMap(PosterTemplateCatalog.template(id:)) else { return false }
            return selectedPhotos.count == template.photoCount
        }
        return true
    }
    private func shortName(_ mode: CollageMode) -> String {
        switch mode { case .template: return "模板"; case .freeform: return "自由"; case .poster: return "海报"; case .longStrip: return "长图" }
    }
    private func chooseMode(_ value: CollageMode?) {
        mode = value
        choices = []
        switch value {
        case .template:
            let ranked = LayoutRecommender.ranked(photoSizes: photos.map(\.pixelSize), canvas: .square)
            let preferred = preferredLayoutID.flatMap(CollageGridLayoutCatalog.layout(id:))
            layoutID = preferred?.photoCount == photos.count ? preferred?.id : ranked.first?.layout.id
            posterID = nil
            choices = ranked.map { item in
                ResultChoice(id: item.layout.id, name: item.layout.name,
                             project: ProjectFactory.make(mode: .template, photos: photos, layoutID: item.layout.id))
            }
        case .poster:
            let matches = PosterTemplateCatalog.matching(photoCount: photos.count)
            let candidates = matches.isEmpty ? Array(PosterTemplateCatalog.closest(photoCount: photos.count).prefix(6)) : matches
            posterID = preferredPosterID ?? candidates.first?.id
            layoutID = nil
            choices = candidates.map { item in
                ResultChoice(id: item.id, name: "\(item.name) · \(item.photoCount)图",
                             project: ProjectFactory.make(mode: .poster, photos: Array(photos.prefix(item.photoCount)), posterID: item.id))
            }
        default:
            layoutID = nil; posterID = nil
        }
        resetPosterPhotos()
    }
    private func resetPosterPhotos() {
        let count = posterID.flatMap(PosterTemplateCatalog.template(id:))?.photoCount ?? photos.count
        selectedPhotos = Set(0..<min(count, photos.count))
        refreshPreview()
    }
    private func refreshPreview() {
        guard let mode, !chosenPhotos.isEmpty else { preview = nil; return }
        preview = ProjectFactory.make(mode: mode, photos: chosenPhotos, layoutID: layoutID, posterID: posterID)
    }
    private func start() {
        guard canStart, let mode else { return }
        onStart(mode, layoutID, posterID, chosenPhotos)
    }
}
