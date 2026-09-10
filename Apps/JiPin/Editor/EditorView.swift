import SwiftUI
import UIKit
import JiPinCore

struct EditorView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: EditorSession
    var onClose: () -> Void
    @State private var showExport = false
    @State private var showCopyMode = false
    @State private var showLayers = false
    @State private var canvasZoom: CGFloat = 1
    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasArea
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    ToolRail(session: session, showLayers: $showLayers)
                    ToolDetailPanel(session: session)
                }
                .background(JiPinTheme.surface)
            }
            .background(JiPinTheme.grouped.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(session.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.isClosingEditor ? "保存中…" : "完成", action: onClose)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        session.undoLast()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!session.undo.canUndo)
                    .accessibilityLabel("撤销")
                    Button {
                        session.redoLast()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!session.undo.canRedo)
                    .accessibilityLabel("重做")
                    Menu {
                        Button("重命名草稿") {
                            renameText = session.project.name
                            showRename = true
                        }
                        .accessibilityIdentifier("editor-rename")
                        copyModeButton
                        layersButton
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多")
                    .accessibilityIdentifier("editor-more")
                    Button("导出") { showExport = true }
                        .accessibilityIdentifier("editor-export")
                }
            }
            .sheet(isPresented: $showExport) {
                ExportView(session: session)
            }
            .sheet(isPresented: $showCopyMode) {
                CopyModeView(session: session)
            }
            .sheet(isPresented: $showLayers) {
                LayerListView(session: session)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                Task { await session.persistNow() }
            }
            .alert("提示", isPresented: Binding(
                get: { session.lastError != nil },
                set: { if !$0 { session.lastError = nil } }
            )) {
                Button("好") { session.lastError = nil }
            } message: {
                Text(session.lastError ?? "")
            }
            .alert("重命名草稿", isPresented: $showRename) {
                TextField("名称", text: $renameText)
                Button("保存") { session.renameProject(renameText) }
                Button("取消", role: .cancel) {}
            }
            .disabled(appState.isClosingEditor)
        }
    }

    private var copyModeButton: some View {
        Button {
            showCopyMode = true
        } label: {
            Image(systemName: "square.on.square")
        }
        .accessibilityLabel("复制到其他模式")
        .accessibilityIdentifier("editor-copy-mode")
    }

    private var layersButton: some View {
        Button {
            showLayers = true
        } label: {
            Image(systemName: "square.3.layers.3d")
        }
        .accessibilityLabel("图层列表")
        .accessibilityIdentifier("editor-layers")
    }

    private var canvasArea: some View {
        GeometryReader { proxy in
            let fitted = fittedCanvas(in: proxy.size)
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    CanvasInteractView(session: session, canvasSize: fitted, canvasZoom: $canvasZoom)
                        .frame(width: fitted.width, height: fitted.height)
                        .scaleEffect(canvasZoom)
                        .frame(width: fitted.width * canvasZoom, height: fitted.height * canvasZoom)
                        .clipShape(RoundedRectangle(cornerRadius: session.project.mode == .longStrip ? 0 : 4))
                        .shadow(color: .black.opacity(0.12), radius: session.project.mode == .longStrip ? 0 : 12, y: 6)
                        .padding(16)
                }
            }
            .overlay(alignment: .top) {
                if session.project.mode == .longStrip {
                    Text("输出 \(session.outputSizeLabel)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                        .accessibilityLabel("实际输出尺寸 \(session.outputSizeLabel)")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 8) {
                    Button("缩小") { canvasZoom = max(canvasZoom / 1.2, 0.4) }
                        .accessibilityLabel("缩小画布")
                        .accessibilityIdentifier("canvas-zoom-out")
                    Button("\(Int(canvasZoom * 100))%") { canvasZoom = 1 }
                        .accessibilityLabel("画布缩放 \(Int(canvasZoom * 100)) 百分之")
                        .accessibilityIdentifier("canvas-zoom-reset")
                    Button("放大") { canvasZoom = min(canvasZoom * 1.2, 4) }
                        .accessibilityLabel("放大画布")
                        .accessibilityIdentifier("canvas-zoom-in")
                }
                .font(.caption2.weight(.semibold))
                .padding(8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func fittedCanvas(in size: CGSize) -> CGSize {
        let available = CGSize(width: max(size.width - 32, 1), height: max(size.height - 32, 1))
        if session.project.mode == .longStrip {
            let output = ExportGeometry.outputSize(for: session.project, assets: session.assets.snapshot)
            let dimensions: CGSize
            switch output {
            case .ok(let value), .needsChoice(_, let value): dimensions = value
            }
            let ratio = max(dimensions.width, 1) / max(dimensions.height, 1)
            if session.project.longStrip?.direction == .horizontal {
                return CGSize(width: available.height * ratio, height: available.height)
            }
            return CGSize(width: available.width, height: available.width / ratio)
        }
        let ratio = session.project.canvas.ratio
        var width = available.width
        var height = width / ratio
        if height > available.height {
            height = available.height
            width = height * ratio
        }
        return CGSize(width: max(width, 10), height: max(height, 10))
    }
}

struct CanvasInteractView: View {
    @ObservedObject var session: EditorSession
    var canvasSize: CGSize
    @Binding var canvasZoom: CGFloat
    @Environment(\.displayScale) private var displayScale
    @State private var preview: UIImage?
    @State private var dragStart: CanvasTransform?
    @State private var cropStart: PhotoCrop?
    @State private var pinchBaseZoom: CGFloat?
    @State private var pinchLastValue: CGFloat = 1
    @State private var rotationBase: Double?
    @State private var dragObjectID: UUID?

    var body: some View {
        ZStack {
            if session.project.background.isHidden && session.project.exportPreference.format == .png {
                Canvas { context, size in
                    let step: CGFloat = 14
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                    for row in 0..<Int(ceil(size.height / step)) {
                        for column in 0..<Int(ceil(size.width / step)) where (row + column).isMultiple(of: 2) {
                            context.fill(Path(CGRect(x: CGFloat(column) * step, y: CGFloat(row) * step, width: step, height: step)), with: .color(.gray.opacity(0.16)))
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: canvasSize.width, height: canvasSize.height)
            } else {
                JiPinTheme.canvas
            }
            ForEach(session.guides, id: \.position) { guide in
                guideView(guide)
            }
            if let selected = session.selected, selected.isVisible, !session.isDrawingTool {
                selectionChrome(selected)
                    .accessibilityHidden(true)
            }
            liveInk
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture(count: 1).onEnded { event in
                guard !session.isDrawingTool else { return }
                session.select(session.hitTest(event.location, canvasSize: canvasSize))
            }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 2).onEnded { event in
                guard !session.isDrawingTool else { return }
                if let id = session.hitTest(event.location, canvasSize: canvasSize) {
                    session.select(id)
                    if session.project.object(id: id)?.kind == .text {
                        session.activeTool = .text
                        session.wantsTextFocus = true
                    }
                }
            }
        )
        .gesture(canvasGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityHint(session.isDrawingTool ? "在画布上拖动即可绘制" : "拖动可移动当前对象；模板和长图中拖到另一张照片可交换；选中格子内照片时小幅拖动可平移画面；双指缩放或旋转。旋转、排序和层级也可用按钮完成。")
        .accessibilityLabel("拼图画布")
        .accessibilityValue(canvasAccessibilityValue)
        .accessibilityIdentifier("editor-canvas")
        .task(id: previewRequest) { await refreshPreview() }
        .overlay(alignment: .bottom) {
            VStack {
                if session.compareOriginal {
                    Text("正在对比原图")
                        .font(.caption2)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                if session.lowResolutionWarning {
                    Text("有照片分辨率偏低，放大后可能发糊")
                        .font(.caption2)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                if session.missingAssetWarning {
                    Text("有素材缺失，请替换后再导出")
                        .font(.caption2)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(8)
        }
    }

    private var canvasAccessibilityValue: String {
        var parts: [String] = []
        if let preview { parts.append("预览 \(Int(preview.size.width)) × \(Int(preview.size.height)) 像素") }
        if session.project.mode == .longStrip {
            parts.append("输出 \(session.outputSizeLabel)")
        }
        if let selected = session.selected {
            if let index = session.project.photoLayers.firstIndex(where: { $0.id == selected.id }) {
                parts.append("已选中第 \(index + 1) 张照片")
            } else { parts.append("已选中\(selected.displayName)") }
            if selected.isLocked { parts.append("已锁定") }
        } else {
            parts.append("未选中对象，双指可缩放画布")
        }
        return parts.joined(separator: "，")
    }

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: session.isDrawingTool ? 0 : 8, coordinateSpace: .local)
            .onChanged { value in
                if session.isDrawingTool {
                    if session.livePoints.isEmpty {
                        session.beginDraw(at: value.startLocation, canvasSize: canvasSize)
                    }
                    session.continueDraw(at: value.location, canvasSize: canvasSize)
                    return
                }
                if dragStart == nil {
                    if let id = session.hitTest(value.startLocation, canvasSize: canvasSize) {
                        session.select(id)
                        session.beginGesture()
                        dragStart = session.selected?.transform
                        cropStart = session.selected?.photo?.crop
                        dragObjectID = id
                    } else {
                        session.select(nil)
                        dragObjectID = nil
                    }
                }
                guard let start = dragStart, session.selected?.isLocked != true else { return }
                let dx = value.translation.width / canvasSize.width
                let dy = value.translation.height / canvasSize.height
                if session.pansPhotoContent {
                    let pan = session.photoPanTranslation(value.translation, canvasSize: canvasSize)
                    session.setPhotoContent(
                        offsetX: (cropStart?.offsetX ?? 0) + pan.width,
                        offsetY: (cropStart?.offsetY ?? 0) + pan.height
                    )
                } else {
                    session.moveSelected(centerX: start.centerX + dx, centerY: start.centerY + dy, canvasSize: canvasSize)
                }
            }
            .onEnded { value in
                if session.isDrawingTool {
                    session.endDraw(canvasSize: canvasSize)
                    return
                }
                let startID = dragObjectID
                let originalCrop = cropStart
                dragStart = nil
                cropStart = nil
                dragObjectID = nil
                if let startID,
                   session.project.mode != .freeform,
                   hypot(value.translation.width, value.translation.height) > 28,
                   let endID = session.hitTest(value.location, canvasSize: canvasSize),
                   startID != endID,
                   session.project.object(id: startID)?.kind == .photo,
                   session.project.object(id: endID)?.kind == .photo {
                    if let originalCrop { session.project.updateObject(id: startID) { $0.photo?.crop = originalCrop } }
                    session.swapPhotos(a: startID, b: endID)
                    session.select(endID)
                }
                session.endGesture()
            }
            .simultaneously(with: MagnificationGesture().onChanged { value in
                guard !session.isDrawingTool else { return }
                let zoomCanvas = session.selected == nil || session.selected?.isLocked == true
                if zoomCanvas {
                    if pinchBaseZoom == nil { pinchBaseZoom = canvasZoom }
                    canvasZoom = min(max((pinchBaseZoom ?? 1) * value, 0.4), 4)
                } else {
                    if pinchBaseZoom == nil {
                        session.beginGesture()
                        pinchBaseZoom = 1
                        pinchLastValue = 1
                    }
                    session.scaleSelected(value / max(pinchLastValue, 0.01))
                    pinchLastValue = value
                }
            }.onEnded { _ in
                pinchBaseZoom = nil
                pinchLastValue = 1
                if !session.isDrawingTool { session.endGesture() }
            })
            .simultaneously(with: RotationGesture().onChanged { angle in
                guard !session.isDrawingTool, session.selected != nil, session.selected?.isLocked != true else { return }
                if rotationBase == nil {
                    session.beginGesture()
                    rotationBase = session.selected?.transform.rotation ?? 0
                }
                session.setSelectedRotation((rotationBase ?? 0) + angle.degrees)
            }.onEnded { _ in
                rotationBase = nil
                if !session.isDrawingTool { session.endGesture() }
            })
    }

    @ViewBuilder
    private var liveInk: some View {
        let points = session.livePoints.map { CGPoint(x: $0.x * canvasSize.width, y: $0.y * canvasSize.height) }
        if points.count >= 1 {
            Canvas { context, _ in
                if session.brushMode == .cover, let first = points.first, let last = points.last {
                    let rect = CGRect(
                        x: min(first.x, last.x),
                        y: min(first.y, last.y),
                        width: abs(last.x - first.x),
                        height: abs(last.y - first.y)
                    )
                    context.fill(Path(rect), with: .color(Color(hex: session.brushColorHex).opacity(0.55)))
                } else if session.brushMode == .mosaic {
                    for point in points {
                        let r = session.mosaicRadius * min(canvasSize.width, canvasSize.height)
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                            with: .color(.black.opacity(0.28))
                        )
                    }
                } else if points.count >= 2 {
                    var path = Path()
                    path.move(to: points[0])
                    if session.brushMode == .line || session.brushMode == .arrow {
                        path.addLine(to: points.last ?? points[0])
                    } else {
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    let previewColor: Color = session.brushMode == .eraser
                        ? Color.white.opacity(0.72)
                        : Color(hex: session.brushColorHex).opacity(session.brushOpacity)
                    context.stroke(
                        path,
                        with: .color(previewColor),
                        style: StrokeStyle(
                            lineWidth: session.brushWidth * min(canvasSize.width, canvasSize.height),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func selectionChrome(_ object: LayerObject) -> some View {
        let rect = session.selectionRect(for: object, canvasSize: canvasSize)
        return Rectangle()
            .stroke(JiPinTheme.accent, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func guideView(_ guide: SnapGuide) -> some View {
        Rectangle()
            .fill(JiPinTheme.accent.opacity(0.7))
            .frame(
                width: guide.axis == .vertical ? 1 : canvasSize.width,
                height: guide.axis == .horizontal ? 1 : canvasSize.height
            )
            .position(
                x: guide.axis == .vertical ? guide.position * canvasSize.width : canvasSize.width / 2,
                y: guide.axis == .horizontal ? guide.position * canvasSize.height : canvasSize.height / 2
            )
    }

    private var previewRequest: PreviewRequest {
        PreviewRequest(project: session.previewProject, displaySize: canvasSize,
                       displayScale: displayScale, zoom: canvasZoom, assetRevision: session.assets.revision)
    }

    private func refreshPreview() async {
        guard canvasSize.width >= 24, canvasSize.height >= 24 else { return }
        let request = previewRequest
        let assets = session.assets.snapshot
        await Task.yield()
        guard !Task.isCancelled else { return }
        let rendered = await PreviewRendering.shared.render(request, assets: assets)
        guard !Task.isCancelled else { return }
        preview = rendered
    }
}

struct ToolRail: View {
    @ObservedObject var session: EditorSession
    @Binding var showLayers: Bool

    var tools: [EditorTool] {
        switch session.project.mode {
        case .template: return [.layout, .style, .adjust, .crop, .filter, .color, .border, .background, .text, .sticker, .layer, .mosaic, .doodle]
        case .freeform: return [.layout, .style, .adjust, .crop, .filter, .color, .border, .background, .text, .sticker, .layer, .mosaic, .doodle]
        case .poster: return [.layout, .style, .adjust, .crop, .text, .sticker, .filter, .color, .border, .background, .layer, .mosaic, .doodle]
        case .longStrip: return [.layout, .style, .crop, .adjust, .filter, .color, .border, .background, .text, .sticker, .layer, .mosaic, .doodle]
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tools) { tool in
                    Button {
                        if tool == .layer {
                            showLayers = true
                        } else {
                            session.selectTool(tool)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.systemImage)
                            Text(tool.title).font(.caption2)
                        }
                        .foregroundStyle(session.activeTool == tool ? JiPinTheme.accent : JiPinTheme.ink)
                        .frame(width: 58, height: 52)
                    }
                    .accessibilityLabel(tool.title)
                    .accessibilityIdentifier("tool-\(tool.rawValue)")
                    .accessibilityAddTraits(session.activeTool == tool ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(JiPinTheme.surface)
        .accessibilityIdentifier("editor-tool-rail")
    }
}

struct CopyModeView: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var target: CollageMode = .freeform
    @State private var preview: ModeCopyPreview?
    @State private var kept: Set<Int> = []
    @State private var posterID: String?
    @State private var isCopying = false
    @State private var copyError: String?

    var body: some View {
        NavigationStack {
            List {
                Picker("目标模式", selection: $target) {
                    ForEach(CollageMode.allCases.filter { $0 != session.project.mode }) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if let preview {
                    if !preview.warnings.isEmpty {
                        Section("需要确认") {
                            ForEach(preview.warnings, id: \.self, content: Text.init)
                        }
                    }
                    if !preview.droppedKinds.isEmpty {
                        Section("切换说明") {
                            ForEach(preview.droppedKinds, id: \.self, content: Text.init)
                        }
                    }
                }
                if needsPhotoPick {
                    Section("选择要带走的照片（\(PhotoLimits.range(for: target).lowerBound)–\(PhotoLimits.range(for: target).upperBound) 张）") {
                        ForEach(Array(session.project.photoOrder.enumerated()), id: \.offset) { index, _ in
                            Button {
                                toggle(index)
                            } label: {
                                HStack {
                                    Text("照片 \(index + 1)")
                                    Spacer()
                                    if kept.contains(index) { Image(systemName: "checkmark") }
                                }
                            }
                            .accessibilityAddTraits(kept.contains(index) ? .isSelected : [])
                        }
                    }
                }
                if target == .poster {
                    Section("海报模板") {
                        if matchingPosters.isEmpty {
                            Text("当前照片数量没有匹配的海报，请在上方调整选择数量。")
                        } else {
                            Picker("选择版式", selection: $posterID) {
                                ForEach(matchingPosters) { template in
                                    Text(template.name).tag(Optional(template.id))
                                }
                            }
                        }
                    }
                }
                if let copyError { Text(copyError).foregroundStyle(.red) }
            }
            .navigationTitle("复制到其他模式")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCopying ? "正在保存…" : "创建副本") { Task { await createCopy() } }
                        .disabled(!canCreate || isCopying)
                }
            }
            .onAppear {
                if target == session.project.mode { target = CollageMode.allCases.first { $0 != session.project.mode } ?? .template }
                preview = ProjectFactory.previewCopy(from: session.project, to: target)
                resetKept()
            }
            .onChange(of: target) { _, value in
                preview = ProjectFactory.previewCopy(from: session.project, to: value)
                resetKept()
            }
            .onChange(of: kept) { _, _ in posterID = matchingPosters.first?.id }
        }
    }

    private var range: ClosedRange<Int> { PhotoLimits.range(for: target) }
    private var needsPhotoPick: Bool { session.project.photoOrder.count > range.upperBound || target == .poster }
    private var selectedCount: Int { needsPhotoPick ? kept.count : session.project.photoOrder.count }
    private var matchingPosters: [PosterTemplate] { PosterTemplateCatalog.matching(photoCount: selectedCount) }
    private var canCreate: Bool { range.contains(selectedCount) && (target != .poster || matchingPosters.contains { $0.id == posterID }) }

    private func resetKept() {
        kept = Set(0..<min(session.project.photoOrder.count, range.upperBound))
        posterID = matchingPosters.first?.id
    }

    private func toggle(_ id: Int) {
        if kept.contains(id) {
            kept.remove(id)
        } else if kept.count < range.upperBound {
            kept.insert(id)
        }
    }

    private func photoName(_ id: UUID) -> String {
        if let index = session.project.photoOrder.firstIndex(of: id) {
            return "照片 \(index + 1)"
        }
        return id.uuidString
    }

    private func createCopy() async {
        isCopying = true
        defer { isCopying = false }
        let ids = needsPhotoPick
            ? session.project.photoOrder.enumerated().filter { kept.contains($0.offset) }.map(\.element)
            : session.project.photoOrder
        let photos = ids.compactMap { id -> ImportedPhoto? in
            guard let data = session.assets.data(for: id) else { return nil }
            return ImportedPhoto(
                id: id,
                filename: id.uuidString,
                data: data,
                pixelSize: session.assets.pixelSizes[id] ?? .zero,
                utType: ImageIOHelpers.typeIdentifier(of: data)
            )
        }
        guard photos.count == ids.count else { copyError = "照片素材缺失，请先回到编辑器替换素材。"; return }
        guard await session.persistNow() else { copyError = session.lastError; return }
        let copy = ProjectFactory.copy(project: session.project, to: target, photos: photos, posterID: posterID)
        let newSession = EditorSession(project: copy, assets: AssetLibrary(images: session.assets.images))
        guard await newSession.persistNow() else { copyError = newSession.lastError; return }
        dismiss()
        appState.openEditor(newSession)
    }
}

struct LayerListView: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.project.objects.sorted { $0.zIndex > $1.zIndex }) { object in
                    Button {
                        session.select(object.id)
                    } label: {
                        HStack(spacing: 12) {
                            layerThumb(object)
                            Text(object.displayName)
                            Spacer()
                            if object.isLocked { Image(systemName: "lock") }
                            if !object.isVisible { Image(systemName: "eye.slash") }
                        }
                    }
                    .accessibilityLabel("\(object.displayName)\(object.isLocked ? " 已锁定" : "")\(object.isVisible ? "" : " 已隐藏")")
                    .accessibilityHint("点选后可用底部按钮调整层级、锁定或删除")
                }
            }
            .navigationTitle("图层")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("上移一层") { session.setZ(.up) }
                    Button("下移一层") { session.setZ(.down) }
                    Button("置顶") { session.setZ(.front) }
                    Button("置底") { session.setZ(.back) }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(session.selected?.isLocked == true ? "解锁" : "锁定") { session.toggleLock() }
                    Button(session.selected?.isVisible == false ? "显示" : "隐藏") { session.toggleVisible() }
                    Button("复制") { session.duplicateSelected() }
                    Button("删除", role: .destructive) { session.deleteSelected() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func layerThumb(_ object: LayerObject) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(JiPinTheme.elevated)
            if object.kind == .photo,
               let id = object.photo?.assetID,
               let data = session.assets.data(for: id),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: layerSymbol(object.kind))
                    .font(.caption)
                    .foregroundStyle(JiPinTheme.muted)
            }
        }
        .frame(width: 36, height: 36)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }

    private func layerSymbol(_ kind: LayerKind) -> String {
        switch kind {
        case .photo: return "photo"
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .shape: return "triangle"
        case .doodle: return "pencil.tip"
        }
    }
}
