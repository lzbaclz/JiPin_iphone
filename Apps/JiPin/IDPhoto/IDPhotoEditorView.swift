import SwiftUI
import PhotosUI
import JiPinCore

private enum IDPhotoTool: String, CaseIterable, Identifiable {
    case size, background, retouch, brush
    var id: String { rawValue }
    var title: String {
        switch self { case .size: return "尺寸"; case .background: return "底色"; case .retouch: return "轻修"; case .brush: return "修边" }
    }
    var symbol: String {
        switch self { case .size: return "crop"; case .background: return "circle.lefthalf.filled"; case .retouch: return "slider.horizontal.3"; case .brush: return "paintbrush.pointed" }
    }
}

struct IDPhotoEditorView: View {
    @ObservedObject var session: IDPhotoSession
    let onClose: () -> Void
    @State private var tool: IDPhotoTool = .background
    @State private var isComparing = false
    @State private var restores = true
    @State private var brushDiameter = 24.0
    @State private var customSize = false
    @State private var export: IDPhotoExportSnapshot?
    @State private var isPreparingExport = false
    @State private var showPicker = false
    @State private var replacement: PhotosPickerItem?
    @State private var replacementTask: Task<Void, Never>?
    @State private var replacementID = UUID()
    @State private var isReplacing = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(session.project.template.title) · \(session.project.template.displaySize)")
                                .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 4)
                            Button(isComparing ? "返回成品" : "对比原图") { isComparing.toggle() }
                                .font(.subheadline).accessibilityIdentifier("idphoto-compare")
                                .onLongPressGesture(minimumDuration: 0.2, pressing: { isComparing = $0 }, perform: {})
                        }
                        Text(session.outputSummary).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("idphoto-output-size")
                    }.padding(.horizontal).padding(.top, 8)
                    IDPhotoCropView(image: isComparing ? session.originalPreview : session.preview,
                                    project: session.project, sourceSize: session.sourceSize,
                                    isBrush: tool == .brush, isComparing: isComparing,
                                    restores: restores, brushDiameter: brushDiameter,
                                    enabled: session.preview != nil && !isReplacing && !session.isClosing && (tool != .brush || (session.hasMask && !session.isRendering)),
                                    onBegin: { session.beginTransaction() },
                                    onCrop: { crop in session.editCrop { $0 = crop } },
                                    onEnd: { session.endTransaction() },
                                    onStroke: { stroke in
                                        let points = session.project.strokes.reduce(0) { $0 + $1.points.count }
                                        guard session.project.strokes.count < 500, points + stroke.points.count <= 250_000 else {
                                            session.errorMessage = "修边记录已达到上限，请撤销不需要的笔画后继续。"; return
                                        }
                                        session.edit { $0.strokes.append(stroke) }
                                    })
                        .frame(height: max(170, min(360, proxy.size.height * 0.43)))
                        .overlay(alignment: .bottomTrailing) {
                            if session.isRendering || session.isAnalyzing {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text(session.isAnalyzing ? "正在识别人像" : "更新预览").font(.caption)
                                }.padding(8).background(.regularMaterial, in: Capsule()).padding(8)
                                    .accessibilityIdentifier("idphoto-processing")
                            }
                        }
                    Text(tool == .brush ? "单指擦除／恢复 · 双指放大与移动检查，不改变构图" : "单指移动 · 双指缩放和旋转，也可在尺寸页微调")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal).padding(.vertical, 6)
                    toolBar
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if let warning = session.analysisWarning { analysisNotice(warning) }
                            if session.isLowResolution {
                                Label("原片有效像素偏少，建议换用更清晰的原图。", systemImage: "exclamationmark.triangle")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            switch tool {
                            case .size: sizePanel
                            case .background: backgroundPanel
                            case .retouch: retouchPanel
                            case .brush: brushPanel
                            }
                        }.padding()
                    }.frame(maxHeight: .infinity).accessibilityIdentifier("idphoto-tool-panel")
                    if let notice = session.notice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary).padding(6)
                            .accessibilityIdentifier("idphoto-notice")
                    }
                }
            }
            .disabled(session.isClosing || isReplacing || isPreparingExport)
            .background(JiPinTheme.grouped)
            .navigationTitle("制作证件照").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(session.isClosing ? "保存中…" : "完成") {
                        Task { if await session.close() { onClose() } }
                    }.disabled(session.isClosing || isReplacing || isPreparingExport).accessibilityIdentifier("idphoto-close")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: session.undo) { Image(systemName: "arrow.uturn.backward") }
                        .disabled(session.undoCount == 0 || isReplacing || session.isClosing || isPreparingExport).accessibilityLabel("撤销").accessibilityIdentifier("idphoto-undo")
                    Button(action: session.redo) { Image(systemName: "arrow.uturn.forward") }
                        .disabled(session.redoCount == 0 || isReplacing || session.isClosing || isPreparingExport).accessibilityLabel("重做").accessibilityIdentifier("idphoto-redo")
                    Button(isPreparingExport ? "保存草稿…" : "保存") {
                        isPreparingExport = true
                        Task {
                            defer { isPreparingExport = false }
                            session.endTransaction()
                            guard await session.persistNow() else { return }
                            export = session.exportSnapshot()
                        }
                    }
                        .fontWeight(.semibold).disabled(session.preview == nil || session.isAnalyzing || isReplacing || session.isClosing || isPreparingExport)
                        .accessibilityIdentifier("idphoto-export")
                }
            }
            .sheet(isPresented: $customSize) {
                IDPhotoCustomSizeView(template: session.project.template, byteLimit: session.project.exportByteLimit,
                                      preservesOriginal: session.project.keepOriginalBackground && session.project.adjustments.isIdentity) { specification in
                    session.edit {
                        $0.template = specification.template; $0.exportByteLimit = specification.byteLimit
                        if specification.preservesOriginal {
                            $0.keepOriginalBackground = true; $0.adjustments = .init(); $0.strokes = []
                        }
                    }
                }
            }
            .sheet(item: $export) { snapshot in
                IDPhotoExportView(snapshot: snapshot, onQualityChanged: { value in
                    session.edit { $0.exportQuality = value }
                    Task { await session.persistNow() }
                }) {
                    export = nil
                    session.notice = "已保存到相册。"
                }
            }
            .alert("暂时无法完成", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
                Button("好") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
            .photosPicker(isPresented: $showPicker, selection: $replacement, matching: PhotoImporter.stillImages)
            .onChange(of: replacement) { _, item in if let item { replacePhoto(item) } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .inactive { session.endTransaction(); Task { await session.persistNow() } }
            }
            .onDisappear { replacementTask?.cancel(); replacementID = UUID() }
            .overlay {
                if isReplacing {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        VStack(spacing: 18) {
                            ProgressView("正在读取新照片…")
                            Button("取消读取") { replacementTask?.cancel(); replacementID = UUID(); isReplacing = false }
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            ForEach(IDPhotoTool.allCases) { item in
                Button {
                    session.endTransaction(); tool = item; isComparing = false
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.title3)
                        Text(item.title).font(.subheadline.weight(tool == item ? .semibold : .regular))
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(tool == item ? JiPinTheme.accent : .primary)
                }.buttonStyle(.plain).accessibilityIdentifier("idphoto-tool-\(item.rawValue)")
                    .accessibilityAddTraits(tool == item ? [.isSelected] : [])
            }
        }.background(JiPinTheme.surface)
    }

    private func analysisNotice(_ warning: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(warning).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("idphoto-analysis-warning")
            HStack {
                Button("重试识别", action: session.analyze).disabled(session.isAnalyzing || session.isClosing).accessibilityIdentifier("idphoto-retry")
                Button("换张照片") { replacement = nil; showPicker = true }.accessibilityIdentifier("idphoto-replace")
            }.font(.subheadline).buttonStyle(.bordered)
        }
    }

    private var sizePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { customSize = true } label: {
                Label("按网站要求自定义", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.bordered).accessibilityIdentifier("idphoto-custom")
            HStack {
                Text("通用打印尺寸").font(.headline)
                Spacer()
                IDPhotoSizeGuideButton(selection: session.project.template)
            }
            IDPhotoTemplateGrid(selection: session.project.template, quality: session.project.exportQuality) { template in session.edit { $0.template = template } }
            HStack {
                Button("换张照片") { replacement = nil; showPicker = true }.accessibilityIdentifier("idphoto-replace-photo")
                Spacer()
            }.buttonStyle(.bordered)
            Text("构图微调").font(.headline)
            HStack {
                Button("缩小") { session.editCrop { $0.zoom = max(1, $0.zoom / 1.08) } }.accessibilityIdentifier("idphoto-zoom-out")
                Text("\(session.project.crop.zoom * 100, specifier: "%.0f")%")
                    .font(.subheadline.monospacedDigit()).frame(minWidth: 55).accessibilityIdentifier("idphoto-zoom-value")
                Button("放大") { session.editCrop { $0.zoom = min(8, $0.zoom * 1.08) } }.accessibilityIdentifier("idphoto-zoom-in")
                Spacer()
                Button("复位") { session.editCrop { $0 = .init() } }.accessibilityIdentifier("idphoto-crop-reset")
            }.buttonStyle(.bordered)
            HStack {
                cropArrow("人物左移", symbol: "arrow.left", x: 0.015, y: 0)
                cropArrow("人物右移", symbol: "arrow.right", x: -0.015, y: 0)
                cropArrow("人物上移", symbol: "arrow.up", x: 0, y: 0.015)
                cropArrow("人物下移", symbol: "arrow.down", x: 0, y: -0.015)
                Spacer()
                Button("左转") { session.editCrop { $0.rotationDegrees = max(-180, $0.rotationDegrees - 1) } }.accessibilityIdentifier("idphoto-rotate-left")
                Button("右转") { session.editCrop { $0.rotationDegrees = min(180, $0.rotationDegrees + 1) } }.accessibilityIdentifier("idphoto-rotate-right")
            }.buttonStyle(.bordered).font(.subheadline)
            Text("旋转 \(session.project.crop.rotationDegrees, specifier: "%.1f")° · 辅助线仅帮助构图，不是证件审核标准。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func cropArrow(_ title: String, symbol: String, x: Double, y: Double) -> some View {
        Button { session.editCrop { $0.centerX = min(1, max(0, $0.centerX + x)); $0.centerY = min(1, max(0, $0.centerY + y)) } }
        label: { Image(systemName: symbol) }
            .accessibilityLabel(title).accessibilityIdentifier("idphoto-move-\(symbol)")
    }

    private var backgroundPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(session.hasMask ? "保留原背景" : "保留原背景，仅调整尺寸", isOn: Binding(get: { session.project.keepOriginalBackground }, set: { value in
                session.edit { $0.keepOriginalBackground = value }
            })).font(.subheadline).disabled(!session.hasMask).accessibilityIdentifier("idphoto-preserve-bg")
            HStack(alignment: .top, spacing: 8) {
                ForEach(IDPhotoBackground.allCases) { background in
                    Button {
                        session.edit { $0.background = background; $0.keepOriginalBackground = false }
                    } label: {
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [Color(hex: background.topHex), Color(hex: background.bottomHex ?? background.topHex)], startPoint: .top, endPoint: .bottom))
                                .frame(height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.4), lineWidth: 1))
                                .overlay {
                                    if session.project.background == background && !session.project.keepOriginalBackground {
                                        Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, JiPinTheme.accent).font(.title3)
                                    }
                                }
                            Text(background.title).font(.caption).foregroundStyle(.primary).lineLimit(2)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain).disabled(!session.hasMask || session.isAnalyzing)
                        .accessibilityIdentifier("idphoto-color-\(background.rawValue)")
                        .accessibilityAddTraits(session.project.background == background && !session.project.keepOriginalBackground ? [.isSelected] : [])
                }
            }
            Text("尺寸与底色请按用途要求选择，渐变底不适用于要求纯色背景的场景。")
                .font(.footnote).foregroundStyle(.secondary)
            if !session.hasMask && !session.isAnalyzing {
                Text("当前保留原背景。成功识别人像后即可换底；原照片和编辑参数仍然保留。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var retouchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("自然轻修，保持本来的你").font(.headline)
            adjustmentSlider("亮度", keyPath: \.brightness, range: -20...20, id: "brightness", disabled: !session.hasMask)
            adjustmentSlider("轻磨皮", keyPath: \.smoothing, range: 0...30, id: "smoothing", disabled: !session.canSmooth)
            adjustmentSlider("色温", keyPath: \.temperature, range: -10...10, id: "temperature", disabled: !session.hasMask)
            HStack {
                Button("自然") { session.edit { $0.adjustments = .natural; if !session.canSmooth { $0.adjustments.smoothing = 0 } } }
                    .disabled(!session.hasMask).accessibilityIdentifier("idphoto-natural")
                Button("重置轻修") { session.edit { $0.adjustments = .init() } }.accessibilityIdentifier("idphoto-retouch-reset")
            }.buttonStyle(.bordered)
            Text(session.canSmooth ? "默认轻修为 0，不改变五官与脸型。磨皮仅用于保守的面部皮肤区域。" : "未识别到可靠的人像轮廓或单人人脸。请先重试识别；当前可继续调整尺寸。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func adjustmentSlider(_ title: String, keyPath: WritableKeyPath<IDPhotoAdjustments, Double>, range: ClosedRange<Double>, id: String, disabled: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(session.project.adjustments[keyPath: keyPath], specifier: "%.0f")").monospacedDigit()
                    .accessibilityIdentifier("idphoto-\(id)-value")
            }.font(.subheadline)
            Slider(value: Binding(get: { session.project.adjustments[keyPath: keyPath] }, set: { value in
                session.edit { $0.adjustments[keyPath: keyPath] = value }
            }), in: range, step: 1, onEditingChanged: { editing in
                if editing { session.beginTransaction() } else { session.endTransaction() }
            }).disabled(disabled).accessibilityLabel(title).accessibilityIdentifier("idphoto-\(id)")
        }
    }

    private var brushPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("修边操作", selection: $restores) {
                Text("恢复人物").tag(true)
                Text("擦除背景").tag(false)
            }.pickerStyle(.segmented).accessibilityIdentifier("idphoto-brush-mode")
            Text(restores ? "涂过的地方恢复原照片内容，用于补回头发或衣领。" : "涂过的地方显示新底色，用于清除多余背景。")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                Text("笔刷大小")
                Spacer()
                Text("\(brushDiameter, specifier: "%.0f")").monospacedDigit()
            }.font(.subheadline)
            Slider(value: $brushDiameter, in: 6...64, step: 1).accessibilityLabel("笔刷大小").accessibilityIdentifier("idphoto-brush-size")
            Text("已记录 \(session.project.strokes.count) 笔 · 双指放大后可细修，松开一笔后更新成品。")
                .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("idphoto-stroke-count")
            Button("清除手动修边") { session.edit { $0.strokes = [] } }
                .buttonStyle(.bordered).disabled(session.project.strokes.isEmpty).accessibilityIdentifier("idphoto-brush-reset")
            if !session.hasMask {
                Text("需先成功识别人像才能修边。可在上方重试识别或更换照片。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.disabled(!session.hasMask)
    }

    private func replacePhoto(_ item: PhotosPickerItem) {
        replacementTask?.cancel()
        let token = UUID(); replacementID = token; isReplacing = true
        replacementTask = Task {
            let result = await PhotoImporter.load([item], preserveLive: false)
            guard !Task.isCancelled, replacementID == token else { return }
            guard let photo = result.ok.first else {
                isReplacing = false
                session.errorMessage = result.failed.first?.failureReason ?? "未能读取新照片。"
                return
            }
            if await session.replaceSource(photo.data) { isComparing = false }
            guard replacementID == token else { return }
            isReplacing = false
        }
    }
}
