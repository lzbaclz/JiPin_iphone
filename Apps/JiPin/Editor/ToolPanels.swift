import PhotosUI
import SwiftUI
import JiPinCore

struct ToolDetailPanel: View {
    @ObservedObject var session: EditorSession

    var body: some View {
        VStack(spacing: 0) {
            Divider()
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
                }
            }
            .padding()
            .frame(minHeight: 132, maxHeight: 280)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(CollageGridLayoutCatalog.layouts(forPhotoCount: session.project.photoOrder.count)) { layout in
                            Button {
                                session.changeLayout(layout)
                            } label: {
                                VStack {
                                    LayoutThumb(layout: layout)
                                        .frame(width: 64, height: 64)
                                    Text(layout.name).font(.caption2)
                                }
                                .padding(6)
                                .background(session.project.layoutID == layout.id ? JiPinTheme.accent.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    appState.favorites.toggleTemplate(layout.id)
                                } label: {
                                    Image(systemName: appState.favorites.templates.contains(layout.id) ? "star.fill" : "star")
                                        .font(.caption2)
                                }
                                .accessibilityLabel("收藏布局")
                            }
                        }
                    }
                }
                HStack {
                    Text("间距")
                    Slider(value: Binding(
                        get: { session.project.spacing },
                        set: { session.project.spacing = $0 }
                    ), in: 0...0.08) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }
                    Text("边距")
                    Slider(value: Binding(
                        get: { session.project.outerMargin },
                        set: { session.project.outerMargin = $0 }
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
                Text("把一张照片拖到另一格即可交换，也可以先选中再点另一张。")
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
                        set: { session.project.spacing = $0 }
                    ), in: 0...0.08) { editing in
                        if editing { session.beginGesture() } else { session.endGesture() }
                    }
                }
                Text("输出 \(session.outputSizeLabel)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("实际输出尺寸 \(session.outputSizeLabel)")
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
                    set: { session.project.snapEnabled = $0 }
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
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: poster.background.colorHex)))
            if let secondary = poster.background.secondaryHex {
                let gradient = Gradient(colors: [Color(hex: poster.background.colorHex), Color(hex: secondary)])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
                )
            }
            for slot in poster.photoSlots {
                let rect = CGRect(
                    x: slot.frame.x * size.width + 1,
                    y: slot.frame.y * size.height + 1,
                    width: max(slot.frame.width * size.width - 2, 1),
                    height: max(slot.frame.height * size.height - 2, 1)
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: CGFloat(slot.cornerRadius) * min(size.width, size.height)),
                    with: .color(Color.white.opacity(0.55))
                )
            }
            for text in poster.texts {
                let rect = CGRect(
                    x: text.frame.x * size.width + 1,
                    y: text.frame.y * size.height + 1,
                    width: max(text.frame.width * size.width - 2, 1),
                    height: max(text.frame.height * size.height - 2, 1)
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Color(hex: text.style.colorHex).opacity(0.45)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(JiPinTheme.ink.opacity(0.08)))
        .accessibilityLabel("海报预览 \(poster.name)，\(poster.photoCount) 个照片位")
    }
}

struct PhotoRosterBar: View {
    @ObservedObject var session: EditorSession
    @State private var picker: [PhotosPickerItem] = []

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
                    .onChange(of: picker) { _, items in
                        Task {
                            let loaded = await PhotoImporter.load(items)
                            if !loaded.ok.isEmpty {
                                session.addPhotos(loaded.ok)
                            }
                            if !loaded.failed.isEmpty {
                                session.lastError = loaded.failed.compactMap(\.failureReason).joined(separator: "\n")
                            }
                            picker = []
                        }
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
    }
}

struct AdjustTools: View {
    @ObservedObject var session: EditorSession
    @State private var picker: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotoRosterBar(session: session)
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
                            session.updateSelected { $0.transform.rotation = value }
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
            HStack {
                Button("锁定") { session.toggleLock() }
                Button("隐藏") { session.toggleVisible() }
                Button("复制") { session.duplicateSelected() }
                Button("删除", role: .destructive) { session.deleteSelected() }
            }
            .buttonStyle(.bordered)
            Slider(
                value: Binding(
                    get: { session.selected?.opacity ?? 1 },
                    set: { value in
                        session.updateSelected { $0.opacity = value }
                    }
                ),
                in: 0.15...1
            ) { editing in
                if editing {
                    session.beginGesture()
                } else {
                    session.endGesture()
                }
            }
            Text("透明度")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if session.selected?.kind == .photo {
                HStack {
                    Button("照片前移") { session.movePhoto(forward: false) }
                    Button("照片后移") { session.movePhoto(forward: true) }
                }
                .buttonStyle(.bordered)
                Text("拖到另一张照片上可交换；也可以先选中再点另一张，或用前移后移按钮。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                PhotosPicker(selection: $picker, maxSelectionCount: 1, matching: PhotoImporter.stillImages) {
                    Label("替换这张照片", systemImage: "photo.badge.plus")
                }
                .onChange(of: picker) { _, items in
                    Task {
                        let loaded = await PhotoImporter.load(items)
                        if let photo = loaded.ok.first {
                            session.replaceSelectedPhoto(photo)
                        }
                        picker = []
                    }
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
    @State private var intensity: Double = 1

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
            Slider(value: $intensity, in: 0...1) { editing in
                if editing {
                    session.beginGesture()
                } else {
                    session.endGesture()
                }
            }
            .onChange(of: intensity) { _, value in
                session.updateSelected { $0.photo?.filterIntensity = value }
            }
            Toggle("原图对比", isOn: $session.compareOriginal)
                .accessibilityHint("打开后预览暂时去掉滤镜和调色，参数仍保留")
            Button("应用到全部照片") {
                session.applyFilterToAll(session.selected?.photo?.filterID, intensity: intensity)
            }
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
            HStack {
                ColorPicker("颜色", selection: colorBinding)
                Slider(value: sizeBinding, in: 0.02...0.14) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
            }
            HStack {
                Picker("对齐", selection: alignBinding) {
                    Text("左").tag(TextAlignmentKind.leading)
                    Text("中").tag(TextAlignmentKind.center)
                    Text("右").tag(TextAlignmentKind.trailing)
                }
                .pickerStyle(.segmented)
                Slider(value: lineBinding, in: 0.9...1.6) { editing in
                    if editing { session.beginGesture() } else { session.endGesture() }
                }
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
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                session.beginGesture()
            } else {
                session.endGesture()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focused = false }
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
    @State private var category: StickerCategory = .label
    @State private var picker: [PhotosPickerItem] = []
    @State private var query = ""
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("搜索贴纸", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("搜索贴纸")
            Picker("分类", selection: $category) {
                ForEach(StickerCategory.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(visibleStickers) { sticker in
                        HStack(spacing: 4) {
                            Button {
                                session.addSticker(sticker.id)
                            } label: {
                                Text(sticker.name)
                                    .font(.caption)
                                    .padding(8)
                                    .background(JiPinTheme.canvas, in: Capsule())
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
                .onChange(of: picker) { _, items in
                    Task {
                        if let photo = await PhotoImporter.load(items).ok.first {
                            session.addImageDecoration(photo)
                        }
                        picker = []
                    }
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
            } else if session.selected?.kind == .sticker {
                ColorPicker("贴纸颜色", selection: Binding(
                    get: { Color(hex: session.selected?.sticker?.tintHex ?? "#1C1A17") },
                    set: { color in session.updateSelected { $0.sticker?.tintHex = color.hexString } }
                ))
            }
        }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(BackgroundCatalog.all) { preset in
                    Button {
                        session.checkpoint()
                        session.project.background = preset.spec
                        session.scheduleSave()
                    } label: {
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: preset.spec.colorHex))
                                .frame(width: 44, height: 44)
                            Text(preset.name).font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                PhotosPicker(selection: $picker, maxSelectionCount: 1, matching: PhotoImporter.stillImages) {
                    Label("选图", systemImage: "photo")
                }
                .onChange(of: picker) { _, items in
                    Task {
                        if let photo = await PhotoImporter.load(items).ok.first {
                            session.assets.ingest([photo])
                            session.checkpoint()
                            session.project.background = BackgroundSpec(kind: .image, imageAssetID: photo.id)
                            session.scheduleSave()
                        }
                        picker = []
                    }
                }
                Toggle("隐藏背景", isOn: Binding(
                    get: { session.project.background.isHidden },
                    set: {
                        session.project.background.isHidden = $0
                        session.scheduleSave()
                    }
                ))
            }
        }
    }
}

struct BorderTools: View {
    @ObservedObject var session: EditorSession
    var body: some View {
        VStack {
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
        }
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
