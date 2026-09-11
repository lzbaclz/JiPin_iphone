import PhotosUI
import SwiftUI
import JiPinCore

struct ToolDetailPanel: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.vertical) {
            Group {
                switch session.activeTool {
                case .layout: LayoutTools(session: session)
                case .adjust: AdjustTools(session: session)
                case .crop: CropTools(session: session)
                case .filter: FilterTools(session: session)
                case .color: ColorTools(session: session)
                case .text: TextTools(session: session)
                case .sticker: StickerTools(session: session)
                case .background: BackgroundTools(session: session)
                case .border: BorderTools(session: session)
                case .layer: EmptyView()
                case .mosaic: MosaicTools(session: session)
                case .doodle: DoodleTools(session: session)
                case .style: StyleTools(session: session)
                case .livePhoto: LivePhotoTools(session: session)
                }
            }
            .padding()
            }
            .frame(height: 240)
            .accessibilityIdentifier("editor-tool-panel")
            .background(JiPinTheme.surface)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct LayoutTools: View {
    @ObservedObject var session: EditorSession
    @EnvironmentObject private var appState: AppState
    @State private var pendingPoster: PosterTemplate?
    @State private var customWidth = 4.0
    @State private var customHeight = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoRosterBar(session: session)
            if session.project.mode == .template {
                Text("画布比例")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(CanvasSpec.presets, id: \.title) { spec in
                            chip(spec.title, selected: session.project.canvas == spec) {
                                session.setCanvas(spec)
                            }
                        }
                    }
                }
                LayoutRecommendationsView(session: session)
                HStack {
                    Text("间距")
                    Slider(value: Binding(
                        get: { session.project.spacing },
                        set: { value in session.updateProject { $0.spacing = value } }
                    ), in: 0...0.08) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }
                    Text("边距")
                    Slider(value: Binding(
                        get: { session.project.outerMargin },
                        set: { value in session.updateProject { $0.outerMargin = value } }
                    ), in: 0...0.1) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }
                    Button("无缝") {
                        session.checkpoint()
                        session.project.spacing = 0
                        session.project.outerMargin = 0
                        session.scheduleSave()
                    }
                    .accessibilityIdentifier("template-seamless")
                    .accessibilityHint("间距和边距设为零")
                }
                .font(.caption)
                Text("拖动调整画面，双指缩放旋转；长按后拖到另一格交换。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if session.project.mode == .poster {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(PosterTemplateCatalog.all) { poster in
                            Button {
                                if poster.photoCount == session.project.photoOrder.count {
                                    session.changePoster(poster)
                                } else {
                                    pendingPoster = poster
                                }
                            } label: {
                                VStack {
                                    PosterThumb(poster: poster)
                                        .frame(width: 56, height: 72)
                                    Text(poster.name).font(.caption2)
                                    Text("\(poster.photoCount) 图").font(.caption2)
                                }
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    appState.favorites.togglePoster(poster.id)
                                } label: {
                                    Image(systemName: appState.favorites.posters.contains(poster.id) ? "star.fill" : "star")
                                        .font(.caption2)
                                }
                                .accessibilityLabel("收藏海报 \(poster.name)")
                            }
                        }
                    }
                }
                Text("数量不一致时会弹出确认，可换模板或明确选择保留哪些照片，不会静默丢掉多余照片。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let posterID = session.project.posterID,
                   let poster = PosterTemplateCatalog.template(id: posterID),
                   session.project.photoOrder.count > poster.photoCount {
                    Text("当前版式使用 \(poster.photoCount) 张，另有 \(session.project.photoOrder.count - poster.photoCount) 张未放入照片位。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let posterID = session.project.posterID,
                   let poster = PosterTemplateCatalog.template(id: posterID),
                   poster.supportedCanvases.count > 1 {
                    Text("该模板支持的比例")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        ForEach(poster.supportedCanvases, id: \.title) { spec in
                            chip(spec.title, selected: session.project.canvas == spec) {
                                session.setCanvas(spec)
                            }
                        }
                    }
                } else {
                    Text("当前海报按设计比例锁定，避免简单拉伸变形。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if session.project.mode == .longStrip {
                Picker("方向", selection: Binding(
                    get: { session.project.longStrip?.direction ?? .vertical },
                    set: { direction in
                        session.checkpoint()
                        session.project.longStrip = LongStripSpec(direction: direction, spacing: session.project.spacing)
                        session.scheduleSave()
                    }
                )) {
                    ForEach(StripDirection.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("间距")
                    Slider(value: Binding(
                        get: { session.project.spacing },
                        set: { value in session.updateProject { $0.spacing = value } }
                    ), in: 0...0.08) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }
                }
                Button("无缝拼接") {
                    session.checkpoint()
                    session.project.spacing = 0
                    session.scheduleSave()
                }
                .accessibilityIdentifier("longstrip-seamless")
                .accessibilityHint("间距设为零")
                Text("照片 \(session.outputSizeLabel)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("照片输出尺寸 \(session.outputSizeLabel)")
            } else {
                HStack {
                    ForEach(CanvasSpec.presets, id: \.title) { spec in
                        chip(spec.title, selected: session.project.canvas == spec) {
                            session.setCanvas(spec)
                        }
                    }
                    Button("自定义") {
                        session.setCanvas(CanvasSpec(aspectWidth: customWidth, aspectHeight: customHeight, isCustom: true))
                    }
                }
                HStack {
                    Text("自定义宽")
                    Slider(value: $customWidth, in: 1...20, step: 1)
                    Text("高")
                    Slider(value: $customHeight, in: 1...20, step: 1)
                    Text("\(Int(customWidth)):\(Int(customHeight))")
                        .font(.caption.monospacedDigit())
                }
                .font(.caption)
                Toggle("对齐吸附", isOn: Binding(
                    get: { session.project.snapEnabled },
                    set: { value in session.updateProject { $0.snapEnabled = value } }
                ))
                .accessibilityIdentifier("canvas-snap-toggle")
                Text("可吸附画布中心、边缘和其他对象的边缘。关闭后自由移动。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $pendingPoster) { poster in
            PosterMatchSheet(session: session, template: poster)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(selected ? JiPinTheme.accent : .secondary)
    }
}

struct LayoutThumb: View {
    let layout: CollageGridLayout
    var body: some View {
        Canvas { context, size in
            for cell in layout.cells {
                let rect = CGRect(
                    x: cell.x * size.width + 1,
                    y: cell.y * size.height + 1,
                    width: cell.width * size.width - 2,
                    height: cell.height * size.height - 2
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(JiPinTheme.accent.opacity(0.8)))
            }
        }
        .background(JiPinTheme.canvas, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct PosterThumb: View {
    let poster: PosterTemplate

    var body: some View {
        Image(uiImage: StudioPreviewCache.poster(poster))
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(JiPinTheme.ink.opacity(0.08)))
            .accessibilityLabel("海报预览 \(poster.name)，\(poster.photoCount) 个照片位")
    }
}

struct PhotoRosterBar: View {
    @ObservedObject var session: EditorSession
    @State private var picker: [PhotosPickerItem] = []
    @State private var posterBatch: ModePickerLaunch?
    @State private var pendingPhotos: [ImportedPhoto] = []
    @State private var importErrors = ""
    @State private var showImportErrors = false

    var body: some View {
        let range = PhotoLimits.range(for: session.project.mode)
        VStack(alignment: .leading, spacing: 8) {
            Text("照片 \(session.project.photoOrder.count) 张，本模式 \(range.lowerBound)–\(range.upperBound) 张")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if session.remainingPhotoSlots > 0 {
                    PhotosPicker(
                        selection: $picker,
                        maxSelectionCount: session.remainingPhotoSlots,
                        matching: PhotoImporter.stillImages
                    ) {
                        Label("添加照片", systemImage: "plus")
                    }
                    .task(id: picker) {
                        let items = picker
                        guard !items.isEmpty else { return }
                        let loaded = await PhotoImporter.load(items, maxLiveCount: max(0, LivePhotoPolicy.maxSources - session.project.resolvedLiveSources.count))
                        guard !Task.isCancelled else { return }
                        if !loaded.failed.isEmpty {
                            pendingPhotos = loaded.ok
                            importErrors = loaded.failed.compactMap(\.failureReason).joined(separator: "\n")
                            showImportErrors = true
                        } else {
                            appendPhotos(loaded.ok)
                        }
                        picker = []
                    }
                    .accessibilityHint("增加照片后会按新数量重新匹配布局")
                }
                Button("删除选中照片", role: .destructive) {
                    session.removeSelectedPhoto()
                }
                .disabled(session.selected?.kind != .photo)
                .accessibilityHint("不能少于当前模式的最少张数，数量变化后会重新匹配布局")
            }
            .buttonStyle(.bordered)
            .font(.subheadline)
        }
        .alert("部分照片未能导入", isPresented: $showImportErrors) {
            if !pendingPhotos.isEmpty {
                Button("添加成功的 \(pendingPhotos.count) 张") { appendPhotos(pendingPhotos); pendingPhotos = [] }
            }
            Button("取消", role: .cancel) { pendingPhotos = [] }
        } message: { Text(importErrors) }
        .sheet(item: $posterBatch) { batch in
            ModePickerSheet(photos: batch.photos, preset: .poster, locksMode: true) { _, _, posterID, photos in
                if let template = posterID.flatMap(PosterTemplateCatalog.template(id:)) {
                    session.applyPoster(template, importing: photos)
                }
                posterBatch = nil
            }
        }
    }

    private func appendPhotos(_ photos: [ImportedPhoto]) {
        guard !photos.isEmpty else { return }
        if session.project.mode == .poster {
            let current = session.project.photoOrder.compactMap { id -> ImportedPhoto? in
                guard let data = session.assets.data(for: id) else { return nil }
                return ImportedPhoto(id: id, filename: "已有照片", data: data, pixelSize: session.assets.pixelSizes[id] ?? .zero, utType: ImageIOHelpers.typeIdentifier(of: data))
            }
            posterBatch = ModePickerLaunch(photos: current + photos)
        } else { session.addPhotos(photos) }
    }
}

struct AdjustTools: View {
    @ObservedObject var session: EditorSession
    @State private var picker: [PhotosPickerItem] = []
    @State private var showLayerControls = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("构图调整").font(.headline)
            HStack {
                Button("旋转 90°") { session.rotateSelected(degrees: 90) }
                Button("水平翻转") { session.flipSelected(horizontal: true) }
                Button("垂直翻转") { session.flipSelected(horizontal: false) }
            }
            .buttonStyle(.bordered)
            HStack {
                Text("旋转")
                Slider(
                    value: Binding(
                        get: { session.selected?.transform.rotation ?? 0 },
                        set: { value in
                            session.setSelectedRotation(value)
                        }
                    ),
                    in: -180...180
                ) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
                Text("\(Int((session.selected?.transform.rotation ?? 0).rounded()))°")
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.caption)
            .accessibilityLabel("精细旋转")
            .accessibilityIdentifier("adjust-rotation-slider")
            HStack(spacing: 8) {
                Button("−1°") { session.rotateSelected(degrees: -1) }.accessibilityIdentifier("adjust-rotate-minus")
                Button("+1°") { session.rotateSelected(degrees: 1) }.accessibilityIdentifier("adjust-rotate-plus")
                if session.pansPhotoContent {
                    Button("−5%") { session.checkpoint(); session.zoomPhotoContent(1 / 1.05) }
                    Text("\(Int(((session.selected?.photo?.crop.zoom ?? 1) * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                    Button("+5%") { session.checkpoint(); session.zoomPhotoContent(1.05) }
                }
                Button("复位") {
                    session.checkpoint()
                    session.updateSelected {
                        $0.transform.rotation = 0
                        $0.photo?.crop.offsetX = 0; $0.photo?.crop.offsetY = 0; $0.photo?.crop.zoom = 1
                    }
                }.accessibilityIdentifier("adjust-reset-position")
            }.buttonStyle(.bordered).font(.caption)
            DisclosureGroup("图层与透明度", isExpanded: $showLayerControls) {
            HStack {
                Button(session.selected?.isLocked == true ? "解锁" : "锁定") { session.toggleLock() }
                Button(session.selected?.isVisible == false ? "显示" : "隐藏") { session.toggleVisible() }
                Button("复制") { session.duplicateSelected() }
                Button("删除", role: .destructive) { session.deleteSelected() }
            }
            .buttonStyle(.bordered)
            HStack {
                Text("透明度")
                Spacer()
                Text("\(Int(((session.selected?.opacity ?? 1) * 100).rounded()))%")
                    .monospacedDigit()
            }.font(.caption)
            Slider(
                value: Binding(
                    get: { session.selected?.opacity ?? 1 },
                    set: { value in
                        session.updateSelected { $0.opacity = value }
                    }
                ),
                in: 0...1
            ) { editing in
                if editing {
                    session.beginGesture()
                } else {
                    session.endGesture()
                }
            }
            .accessibilityLabel("图层透明度")
            }.padding(.top, 6)
            if session.selected?.kind == .photo {
                Text("照片管理").font(.headline).padding(.top, 6)
                PhotoRosterBar(session: session)
                HStack {
                    Button("照片前移") { session.movePhoto(forward: false) }
                    Button("照片后移") { session.movePhoto(forward: true) }
                }
                .buttonStyle(.bordered)
                Text("长按照片再拖动可交换，也可以使用前移、后移按钮。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                PhotosPicker(selection: $picker, maxSelectionCount: 1, matching: PhotoImporter.stillImages) {
                    Label("替换这张照片", systemImage: "photo.badge.plus")
                }
                .task(id: picker) {
                    let items = picker
                    guard !items.isEmpty else { return }
                    let originalSelection = session.selectedID
                    let loaded = await PhotoImporter.load(items)
                    guard !Task.isCancelled else { return }
                    guard session.selectedID == originalSelection else {
                        session.lastError = "当前照片已改变，请重新选择要替换的照片。"
                        picker = []
                        return
                    }
                    if let photo = loaded.ok.first {
                        session.replaceSelectedPhoto(photo)
                    } else if let error = loaded.failed.first?.failureReason { session.lastError = error }
                    picker = []
                }
                Picker("显示", selection: Binding(
                    get: { session.selected?.photo?.contentMode ?? .fill },
                    set: { mode in
                        session.checkpoint()
                        session.updateSelected { $0.photo?.contentMode = mode }
                    }
                )) {
                    Text("铺满裁切").tag(PhotoContentMode.fill)
                    Text("完整显示").tag(PhotoContentMode.fit)
                }
                .pickerStyle(.segmented)
            }
        }
        .font(.subheadline)
    }
}

struct CropTools: View {
    @ObservedObject var session: EditorSession
    var body: some View {
        VStack {
            slider("上", value: cropBinding(\.top), range: 0...0.45)
            slider("下", value: cropBinding(\.bottom), range: 0...0.45)
            slider("左", value: cropBinding(\.left), range: 0...0.45)
            slider("右", value: cropBinding(\.right), range: 0...0.45)
            slider("缩放", value: zoomBinding, range: 1...4)
            Text(session.pansPhotoContent ? "格子内拖动可平移画面，双指缩放可放大照片内容。" : "自由模式中拖动和双指缩放到整张照片对象。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func cropBinding(_ keyPath: WritableKeyPath<PhotoCrop, Double>) -> Binding<Double> {
        Binding(
            get: { session.selected?.photo?.crop[keyPath: keyPath] ?? 0 },
            set: { value in
                session.updateSelected { object in
                    object.photo?.crop[keyPath: keyPath] = min(max(value, 0), 0.45)
                }
            }
        )
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { session.selected?.photo?.crop.zoom ?? 1 },
            set: { value in
                session.setPhotoContent(zoom: value)
            }
        )
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).frame(width: 28)
            Slider(value: value, in: range) { editing in
                if editing { session.beginGesture() } else { session.endGesture() }
            }
        }
        .font(.caption)
    }
}

struct FilterTools: View {
    @ObservedObject var session: EditorSession
    private var intensity: Double { session.selected?.photo?.filterIntensity ?? 1 }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button("无") {
                        session.checkpoint()
                        session.updateSelected { $0.photo?.filterID = nil }
                    }
                    ForEach(FilterCatalog.all) { filter in
                        Button(filter.name) {
                            session.checkpoint()
                            session.updateSelected {
                                $0.photo?.filterID = filter.id
                                $0.photo?.filterIntensity = intensity
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(session.selected?.photo?.filterID == filter.id ? JiPinTheme.accent : .secondary)
                    }
                }
            }
            Slider(value: Binding(get: { intensity }, set: { value in
                session.updateSelected { $0.photo?.filterIntensity = value }
            }), in: 0...1) { editing in
                if editing {
                    session.beginGesture()
                } else {
                    session.endGesture()
                }
            }

            Toggle("原图对比", isOn: $session.compareOriginal)
                .accessibilityHint("打开后预览暂时去掉滤镜和调色，参数仍保留")
            Button("应用到全部照片") {
                session.applyFilterToAll(session.selected?.photo?.filterID, intensity: intensity)
            }
            .disabled(session.selected?.photo == nil)
        }
    }
}

struct ColorTools: View {
    @ObservedObject var session: EditorSession
    var body: some View {
        VStack {
            labeled("亮度", value: adj(\.brightness), range: -0.4...0.4)
            labeled("对比度", value: adj(\.contrast), range: 0.7...1.4)
            labeled("饱和度", value: adj(\.saturation), range: 0...1.8)
            labeled("色温", value: adj(\.temperature), range: -0.5...0.5)
            Button("同步色调到全部照片") { session.syncSelectedPhotoEffects() }
                .disabled(session.selected?.photo == nil)
                .accessibilityIdentifier("color-sync-all")
            Text("同步滤镜、强度和调色，锁定的照片保持原样。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func adj(_ key: WritableKeyPath<ColorAdjust, Double>) -> Binding<Double> {
        Binding(
            get: { session.selected?.photo?.colorAdjust[keyPath: key] ?? 0 },
            set: { value in session.updateSelected { $0.photo?.colorAdjust[keyPath: key] = value } }
        )
    }

    private func labeled(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).frame(width: 52, alignment: .leading)
            Slider(value: value, in: range) { editing in
                if editing { session.beginGesture() } else { session.endGesture() }
            }
        }
        .font(.caption)
    }
}

struct TextTools: View {
    @ObservedObject var session: EditorSession
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("添加文字") { session.addText() }
                    .accessibilityHint("支持中文、英文、数字和 emoji，可换行")
                Picker("字体", selection: fontBinding) {
                    ForEach(SystemFontOption.allCases) { font in
                        Text(font.title).tag(font.fontName)
                    }
                }
            }
            TextField("输入中文、英文或 emoji", text: textBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .lineLimit(3...6)
            ColorPicker("文字颜色", selection: colorBinding)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("字号")
                    Spacer()
                    Text("画布短边的 \(sizeBinding.wrappedValue * 100, specifier: "%.1f")%")
                        .monospacedDigit().foregroundStyle(.secondary)
                }.font(.caption)
                Slider(value: sizeBinding, in: 0.02...0.14) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
                .accessibilityLabel("文字字号").accessibilityIdentifier("text-size-slider")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("对齐").font(.caption)
                Picker("对齐", selection: alignBinding) {
                    Text("左").tag(TextAlignmentKind.leading)
                    Text("中").tag(TextAlignmentKind.center)
                    Text("右").tag(TextAlignmentKind.trailing)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("行距")
                    Spacer()
                    Text("\(lineBinding.wrappedValue, specifier: "%.2f") 倍")
                        .monospacedDigit().foregroundStyle(.secondary)
                }.font(.caption)
                Slider(value: lineBinding, in: 0.9...1.6) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
                .accessibilityLabel("文字行距").accessibilityIdentifier("text-line-spacing-slider")
            }
            HStack {
                ColorPicker("底色", selection: backgroundBinding)
                ColorPicker("描边色", selection: strokeColorBinding)
                ColorPicker("阴影色", selection: shadowColorBinding)
            }
            HStack {
                Text("描边")
                Slider(value: strokeBinding, in: 0...0.08) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
                .accessibilityLabel("文字描边宽度")
                Text("阴影")
                Slider(value: shadowBinding, in: 0...12) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
                .accessibilityLabel("文字阴影")
            }
            .font(.caption)
        }
        .onAppear {
            draft = session.selected?.text?.text ?? ""
            focused = session.selected?.kind == .text
        }
        .onChange(of: session.selectedID) { _, _ in
            draft = session.selected?.text?.text ?? draft
            focused = session.selected?.kind == .text && session.activeTool == .text
        }
        .onChange(of: session.activeTool) { _, tool in
            if tool == .text { focused = true }
        }
        .onChange(of: session.wantsTextFocus) { _, requested in
            if requested { focused = true; session.wantsTextFocus = false }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { focused = false }
            }
        }
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                session.beginGesture()
            } else {
                session.endGesture()
            }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { session.selected?.text?.text ?? draft },
            set: { value in
                draft = value
                session.updateSelected { $0.text?.text = value }
            }
        )
    }

    private var fontBinding: Binding<String> {
        Binding(
            get: { session.selected?.text?.fontName ?? SystemFontOption.system.fontName },
            set: { value in session.updateSelected { $0.text?.fontName = value } }
        )
    }

    private var sizeBinding: Binding<Double> {
        Binding(
            get: { session.selected?.text?.fontSize ?? 0.06 },
            set: { value in session.updateSelected { $0.text?.fontSize = value } }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: session.selected?.text?.colorHex ?? "#1C1A17") },
            set: { color in session.updateSelected { $0.text?.colorHex = color.hexString } }
        )
    }

    private var alignBinding: Binding<TextAlignmentKind> {
        Binding(
            get: { session.selected?.text?.alignment ?? .center },
            set: { value in session.updateSelected { $0.text?.alignment = value } }
        )
    }

    private var lineBinding: Binding<Double> {
        Binding(
            get: { session.selected?.text?.lineSpacing ?? 1.15 },
            set: { value in session.updateSelected { $0.text?.lineSpacing = value } }
        )
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(hex: session.selected?.text?.backgroundHex ?? "#00000000") },
            set: { color in session.updateSelected { $0.text?.backgroundHex = color.hexString } }
        )
    }

    private var strokeBinding: Binding<Double> {
        Binding(
            get: { session.selected?.text?.stroke.width ?? 0 },
            set: { value in session.updateSelected { $0.text?.stroke.width = value } }
        )
    }

    private var shadowBinding: Binding<Double> {
        Binding(
            get: { session.selected?.text?.shadow.radius ?? 0 },
            set: { value in session.updateSelected { $0.text?.shadow.radius = value } }
        )
    }

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: session.selected?.text?.stroke.colorHex ?? "#FFFFFF") },
            set: { color in session.updateSelected { $0.text?.stroke.colorHex = color.hexString } }
        )
    }

    private var shadowColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: session.selected?.text?.shadow.colorHex ?? "#00000088") },
            set: { color in session.updateSelected { $0.text?.shadow.colorHex = color.hexString } }
        )
    }
}

struct StickerTools: View {
    @ObservedObject var session: EditorSession
    @State private var category: StickerCategory = .cute
    @State private var showLibrary = false
    @State private var picker: [PhotosPickerItem] = []
    @State private var query = ""
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showLibrary = true } label: {
                Label("打开贴纸册 · 可爱 / 酷感", systemImage: "heart.square")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("sticker-library-open")
            if session.selected?.kind == .sticker {
                VStack(spacing: 8) {
                    HStack {
                        Text(session.selected?.displayName ?? "贴纸").font(.caption)
                        Spacer()
                        Button("翻转") { session.updateSelected { $0.transform.scaleX *= -1 } }
                        Button("复制") { session.duplicateSelected() }
                        Button("删除", role: .destructive) { session.deleteSelected() }
                    }.font(.caption)
                    HStack {
                        Text("透明度").font(.caption)
                        Slider(value: Binding(get: { session.selected?.opacity ?? 1 }, set: { value in
                            session.updateSelected { $0.opacity = value }
                        }), in: 0...1) { editing in
                            if editing { session.beginGesture() } else { session.endGesture() }
                        }.accessibilityLabel("贴纸透明度")
                    }
                }.disabled(session.selected?.isLocked == true)
            }
            TextField("搜索贴纸", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("搜索贴纸")
            Picker("分类", selection: $category) {
                ForEach(StickerCategory.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(visibleStickers) { sticker in
                        HStack(spacing: 4) {
                            Button {
                                session.addSticker(sticker.id)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(uiImage: StudioPreviewCache.sticker(sticker))
                                        .resizable().scaledToFit().frame(width: 54, height: 54)
                                    Text(sticker.name).font(.caption2)
                                }
                                .padding(8)
                                .background(JiPinTheme.canvas, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            Button {
                                appState.favorites.toggleSticker(sticker.id)
                            } label: {
                                Image(systemName: appState.favorites.stickers.contains(sticker.id) ? "star.fill" : "star")
                                    .font(.caption2)
                            }
                            .accessibilityLabel("收藏贴纸 \(sticker.name)")
                        }
                    }
                }
            }
            HStack {
                PhotosPicker(selection: $picker, maxSelectionCount: 1, matching: PhotoImporter.stillImages) {
                    Label("从相册添加装饰图", systemImage: "plus")
                }
                .task(id: picker) {
                    let items = picker
                    guard !items.isEmpty else { return }
                    let loaded = await PhotoImporter.load(items, preserveLive: false)
                    guard !Task.isCancelled else { return }
                    if let photo = loaded.ok.first { session.addImageDecoration(photo) }
                    else if let error = loaded.failed.first?.failureReason { session.lastError = error }
                    picker = []
                }
            }
            Text("几何形状")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(GeometryShapeCatalog.all, id: \.id) { shape in
                        Button(shape.name) { session.addShape(shape.id) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("shape-\(shape.id)")
                    }
                }
            }
            if session.selected?.kind == .shape {
                HStack {
                    ColorPicker("填充", selection: Binding(
                        get: { Color(hex: session.selected?.shape?.fillHex ?? "#FF5A36") },
                        set: { color in session.updateSelected { $0.shape?.fillHex = color.hexString } }
                    ))
                    ColorPicker("描边", selection: Binding(
                        get: { Color(hex: session.selected?.shape?.stroke.colorHex ?? "#1C1A17") },
                        set: { color in session.updateSelected { $0.shape?.stroke.colorHex = color.hexString } }
                    ))
                    Slider(
                        value: Binding(
                            get: { session.selected?.shape?.stroke.width ?? 0 },
                            set: { value in session.updateSelected { $0.shape?.stroke.width = value } }
                        ),
                        in: 0...0.12
                    ) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }
                    .accessibilityLabel("形状描边宽度")
                }
                .font(.caption)
            } else if session.selected?.kind == .sticker,
                      ![StickerCategory.cute, .cool].contains(session.selected?.sticker.flatMap { StickerCatalog.sticker(id: $0.stickerID)?.category } ?? .label) {
                ColorPicker("贴纸颜色", selection: Binding(
                    get: { Color(hex: session.selected?.sticker?.tintHex ?? "#1C1A17") },
                    set: { color in session.updateSelected { $0.sticker?.tintHex = color.hexString } }
                ))
            }
        }
        .sheet(isPresented: $showLibrary) { StickerLibrary(session: session) }
    }

    private var visibleStickers: [StickerDefinition] {
        let source: [StickerDefinition]
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            source = StickerCatalog.stickers(in: category)
        } else {
            source = StickerCatalog.all.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
            }
        }
        let favoriteIDs = appState.favorites.stickers
        return source.filter { favoriteIDs.contains($0.id) } + source.filter { !favoriteIDs.contains($0.id) }
    }
}

struct BackgroundTools: View {
    @ObservedObject var session: EditorSession
    @State private var picker: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BackgroundCatalog.all) { preset in
                        Button {
                            session.updateProject { $0.background = preset.spec; $0.exportPreference.transparentBackground = false }
                        } label: {
                            VStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [Color(hex: preset.spec.colorHex), Color(hex: preset.spec.secondaryHex ?? preset.spec.colorHex)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Text(preset.name).font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Picker("背景类型", selection: Binding(
                get: { session.project.background.kind },
                set: { kind in session.updateProject { $0.background.kind = kind; $0.background.isHidden = false; $0.background.presetID = nil } }
            )) {
                Text("纯色").tag(BackgroundKind.solid)
                Text("渐变").tag(BackgroundKind.gradient)
                if session.project.background.kind == .image { Text("图片").tag(BackgroundKind.image) }
                if session.project.background.kind == .texture { Text("纹理").tag(BackgroundKind.texture) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("background-kind")
            if session.project.background.kind == .solid || session.project.background.kind == .gradient {
                ColorPicker("背景颜色", selection: Binding(
                    get: { Color(hex: session.project.background.colorHex) },
                    set: { color in session.updateProject { $0.background.colorHex = color.hexString; $0.background.isHidden = false } }
                ), supportsOpacity: false)
                if session.project.background.kind == .gradient {
                    ColorPicker("渐变终点", selection: Binding(
                        get: { Color(hex: session.project.background.secondaryHex ?? "#FFFFFF") },
                        set: { color in session.updateProject { $0.background.secondaryHex = color.hexString } }
                    ), supportsOpacity: false)
                }
            }
            PhotosPicker(selection: $picker, maxSelectionCount: 1, matching: PhotoImporter.stillImages) {
                Label("选图作背景", systemImage: "photo")
            }
            .task(id: picker) {
                let items = picker
                guard !items.isEmpty else { return }
                let loaded = await PhotoImporter.load(items, preserveLive: false)
                guard !Task.isCancelled else { return }
                if let photo = loaded.ok.first {
                    session.assets.ingest([photo])
                    session.updateProject { $0.background = BackgroundSpec(kind: .image, imageAssetID: photo.id) }
                } else if let error = loaded.failed.first?.failureReason { session.lastError = error }
                picker = []
            }
            if session.project.mode == .freeform || session.project.mode == .poster {
                Toggle("透明背景", isOn: Binding(
                    get: { session.project.background.isHidden },
                    set: { value in
                        session.updateProject {
                            $0.background.isHidden = value
                            $0.exportPreference.transparentBackground = value
                            if value { $0.exportPreference.format = .png }
                        }
                    }
                ))
                Text("透明背景使用 PNG 保存；JPEG 会填充背景色。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct BorderTools: View {
    @ObservedObject var session: EditorSession
    @State private var showFrames = false
    var body: some View {
        VStack {
            Button { showFrames = true } label: {
                Label("挑选可爱边框", systemImage: "gift")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("frame-gallery-open")
            if let frame = session.project.decorationFrame {
                HStack {
                    Text(DecorationFrameCatalog.frame(id: frame.frameID)?.name ?? "装饰边框").font(.caption)
                    Slider(value: Binding(get: { session.project.decorationFrame?.width ?? 0.065 }, set: { value in
                        session.updateProject { $0.decorationFrame?.width = value }
                    }), in: 0.025...0.12) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }.accessibilityLabel("装饰边框粗细")
                    Button("移除") { session.setDecorationFrame(nil) }.accessibilityIdentifier("frame-remove-inline")
                }
            }
            Group {
            labeled("圆角", Binding(
                get: { session.selected?.photo?.cornerRadius ?? 0 },
                set: { value in session.updateSelected { $0.photo?.cornerRadius = value } }
            ), 0...0.5)
            labeled("描边", Binding(
                get: { session.selected?.photo?.stroke.width ?? 0 },
                set: { value in session.updateSelected { $0.photo?.stroke.width = value } }
            ), 0...0.08)
            labeled("阴影", Binding(
                get: { session.selected?.photo?.shadow.radius ?? 0 },
                set: { value in session.updateSelected { $0.photo?.shadow.radius = value } }
            ), 0...24)
            labeled("阴影偏移", Binding(
                get: { session.selected?.photo?.shadow.offsetY ?? 0 },
                set: { value in session.updateSelected { $0.photo?.shadow.offsetY = value } }
            ), 0...20)
            HStack {
                ColorPicker("描边色", selection: Binding(
                    get: { Color(hex: session.selected?.photo?.stroke.colorHex ?? "#FFFFFF") },
                    set: { color in session.updateSelected { $0.photo?.stroke.colorHex = color.hexString } }
                ))
                ColorPicker("阴影色", selection: Binding(
                    get: { Color(hex: session.selected?.photo?.shadow.colorHex ?? "#00000088") },
                    set: { color in session.updateSelected { $0.photo?.shadow.colorHex = color.hexString } }
                ))
            }
            Toggle("拍立得样式", isOn: Binding(
                get: { session.selected?.photo?.polaroid ?? false },
                set: { value in
                    session.checkpoint()
                    session.updateSelected { $0.photo?.polaroid = value }
                }
            ))
            }.disabled(session.selected?.photo == nil || session.selected?.isLocked == true)
        }
        .sheet(isPresented: $showFrames) { FrameGallery(session: session) }
    }

    private func labeled(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).frame(width: 56, alignment: .leading)
            Slider(value: value, in: range) { editing in
                if editing { session.beginGesture() } else { session.endGesture() }
            }
            .accessibilityLabel(title)
        }
        .font(.caption)
    }
}

struct MosaicTools: View {
    @ObservedObject var session: EditorSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("点选照片后，在照片上拖动绘制马赛克或矩形遮挡。效果会随裁切和旋转一起导出。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("工具", selection: $session.brushMode) {
                Text("马赛克").tag(EditorSession.BrushMode.mosaic)
                Text("色块").tag(EditorSession.BrushMode.cover)
            }
            .pickerStyle(.segmented)
            .onAppear { session.brushMode = .mosaic }
            if session.brushMode == .mosaic {
                Slider(value: $session.mosaicRadius, in: 0.02...0.12) { Text("范围") }
            } else {
                ColorPicker("遮挡颜色", selection: Binding(
                    get: { Color(hex: session.brushColorHex) },
                    set: { session.brushColorHex = $0.hexString }
                ))
            }
            Button("清除当前照片遮挡") { session.clearSelectedPhotoMask() }
                .buttonStyle(.bordered)
        }
    }
}

struct DoodleTools: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在画布上拖动绘制。一次连续拖动记为一步，可用撤销。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("画笔", selection: $session.brushMode) {
                Text("画笔").tag(EditorSession.BrushMode.freehand)
                Text("直线").tag(EditorSession.BrushMode.line)
                Text("箭头").tag(EditorSession.BrushMode.arrow)
                Text("橡皮").tag(EditorSession.BrushMode.eraser)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("doodle-brush-mode")
            .onAppear {
                if session.brushMode == .mosaic || session.brushMode == .cover {
                    session.brushMode = .freehand
                }
            }
            HStack {
                ColorPicker("颜色", selection: Binding(
                    get: { Color(hex: session.brushColorHex) },
                    set: { session.brushColorHex = $0.hexString }
                ))
                Slider(value: $session.brushWidth, in: 0.004...0.04) { Text("粗细") }
                Slider(value: $session.brushOpacity, in: 0.2...1) { Text("透明") }
            }
            Button("清除涂鸦") { session.clearDoodle() }
                .buttonStyle(.bordered)
        }
    }
}

struct PosterMatchSheet: View {
    @ObservedObject var session: EditorSession
    let template: PosterTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("模板「\(template.name)」需要 \(template.photoCount) 张照片，当前有 \(session.project.photoOrder.count) 张。")
                    if session.project.photoOrder.count > template.photoCount {
                        Text("请勾选要保留的照片，多余的不会被静默丢掉。")
                    } else {
                        Text("照片不足，请换一个照片位更少的模板，或返回添加照片。")
                    }
                }
                if session.project.photoOrder.count > template.photoCount {
                    Section("选择 \(template.photoCount) 张") {
                        ForEach(session.project.photoOrder, id: \.self) { id in
                            Button {
                                if selected.contains(id) {
                                    selected.remove(id)
                                } else if selected.count < template.photoCount {
                                    selected.insert(id)
                                }
                            } label: {
                                HStack {
                                    Text(shortName(id))
                                    Spacer()
                                    if selected.contains(id) { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("照片数量不匹配")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("换模板") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用选中照片") {
                        let kept = session.project.photoOrder.filter { selected.contains($0) }
                        session.applyPoster(template, keeping: kept)
                        dismiss()
                    }
                    .disabled(selected.count != template.photoCount)
                }
            }
            .onAppear {
                selected = Set(session.project.photoOrder.prefix(template.photoCount))
            }
        }
    }

    private func shortName(_ id: UUID) -> String {
        if let index = session.project.photoOrder.firstIndex(of: id) {
            return "照片 \(index + 1)"
        }
        return id.uuidString
    }
}

extension Color {
    init(hex: String) {
        self = Color(uiColor: HexColor.uiColor(hex))
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
