import SwiftUI
import UIKit
import JiPinCore

struct EditorView: View {
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
                    Button("完成", action: onClose)
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
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
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
        if session.project.mode == .longStrip {
            let preview = session.previewImage(maxSide: min(size.width, size.height) * 0.9) ?? UIImage()
            if preview.size.width > 1 {
                let scale = min(size.width / preview.size.width, size.height / preview.size.height, 1)
                return CGSize(width: preview.size.width * scale, height: preview.size.height * scale)
            }
        }
        let ratio = session.project.canvas.ratio
        var width = size.width * 0.9
        var height = width / ratio
        if height > size.height * 0.9 {
            height = size.height * 0.9
            width = height * ratio
        }
        return CGSize(width: max(width, 10), height: max(height, 10))
    }
}

struct CanvasInteractView: View {
    @ObservedObject var session: EditorSession
    var canvasSize: CGSize
    @Binding var canvasZoom: CGFloat
    @State private var preview: UIImage?
    @State private var dragStart: CanvasTransform?
    @State private var cropStart: PhotoCrop?
    @State private var pinchBaseZoom: CGFloat?
    @State private var pinchLastValue: CGFloat = 1
    @State private var rotationBase: Double?
    @State private var dragObjectID: UUID?

    var body: some View {
        ZStack {
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
            }
            liveInk
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture(count: 2).onEnded { event in
                guard !session.isDrawingTool else { return }
                if let id = session.hitTest(event.location, canvasSize: canvasSize) {
                    session.select(id)
                    if session.project.object(id: id)?.kind == .text {
                        session.activeTool = .text
                    }
                }
            }
        )
        .gesture(canvasGesture)
        .accessibilityHint(session.isDrawingTool ? "在画布上拖动即可绘制" : "拖动可移动当前对象；模板和长图中拖到另一张照片可交换；选中格子内照片时小幅拖动可平移画面；双指缩放或旋转。旋转、排序和层级也可用按钮完成。")
        .accessibilityValue(canvasAccessibilityValue)
        .onAppear { refreshPreview() }
        .onChange(of: session.project) { _, _ in refreshPreview() }
        .onChange(of: session.compareOriginal) { _, _ in refreshPreview() }
        .accessibilityElement(children: .contain)
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
        if session.project.mode == .longStrip {
            parts.append("输出 \(session.outputSizeLabel)")
        }
        if let selected = session.selected {
            parts.append("已选中\(selected.displayName)")
            if selected.isLocked { parts.append("已锁定") }
        } else {
            parts.append("未选中对象，双指可缩放画布")
        }
        return parts.joined(separator: "，")
    }

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
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
                        if hypot(value.translation.width, value.translation.height) < 2,
                           session.project.mode == .template,
                           let current = session.selectedID,
                           current != id,
                           session.selected?.kind == .photo,
                           session.project.object(id: id)?.kind == .photo {
                            session.swapPhotos(a: current, b: id)
                            session.select(id)
                            return
                        }
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
                    session.setPhotoContent(
                        offsetX: (cropStart?.offsetX ?? 0) + dx,
                        offsetY: (cropStart?.offsetY ?? 0) + dy
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
            .overlay(alignment: .top) {
                HStack(spacing: 8) {
                    Button {
                        session.rotateSelected(degrees: 90)
                    } label: {
                        Image(systemName: "rotate.right")
                    }
                    .accessibilityLabel("旋转 90 度")
                    if object.kind == .photo {
                        Button {
                            session.flipSelected(horizontal: true)
                        } label: {
                            Image(systemName: "flip.horizontal")
                        }
                        .accessibilityLabel("水平翻转")
                    }
                }
                .padding(6)
                .background(.ultraThinMaterial, in: Capsule())
                .position(x: rect.midX, y: max(rect.minY - 22, 18))
            }
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

    private func refreshPreview() {
        preview = session.previewImage(maxSide: max(canvasSize.width, canvasSize.height) * UIScreen.main.scale)
    }
}

struct ToolRail: View {
    @ObservedObject var session: EditorSession
    @Binding var showLayers: Bool

    var tools: [EditorTool] {
        switch session.project.mode {
        case .template: return [.layout, .adjust, .crop, .filter, .color, .border, .background, .text, .sticker, .layer, .mosaic, .doodle]
        case .freeform: return [.layout, .adjust, .crop, .filter, .color, .border, .background, .text, .sticker, .layer, .mosaic, .doodle]
        case .poster: return [.layout, .adjust, .crop, .text, .sticker, .filter, .color, .border, .background, .layer, .mosaic, .doodle]
        case .longStrip: return [.layout, .crop, .adjust, .filter, .color, .border, .background, .text, .sticker, .layer, .mosaic, .doodle]
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
    }
}

struct CopyModeView: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var target: CollageMode = .freeform
    @State private var preview: ModeCopyPreview?
    @State private var kept: Set<UUID> = []

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
                        Section("无法承接") {
                            ForEach(preview.droppedKinds, id: \.self, content: Text.init)
                        }
                    }
                }
                if needsPhotoPick {
                    Section("选择要带走的照片（\(PhotoLimits.range(for: target).lowerBound)–\(PhotoLimits.range(for: target).upperBound) 张）") {
                        ForEach(session.project.photoOrder, id: \.self) { id in
                            Button {
                                toggle(id)
                            } label: {
                                HStack {
                                    Text(photoName(id))
                                    Spacer()
                                    if kept.contains(id) { Image(systemName: "checkmark") }
                                }
                            }
                            .accessibilityAddTraits(kept.contains(id) ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle("复制到其他模式")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建副本") { createCopy() }
                        .disabled(!canCreate)
                }
            }
            .onAppear {
                preview = ProjectFactory.previewCopy(from: session.project, to: target)
                resetKept()
            }
            .onChange(of: target) { _, value in
                preview = ProjectFactory.previewCopy(from: session.project, to: value)
                resetKept()
            }
        }
    }

    private var range: ClosedRange<Int> { PhotoLimits.range(for: target) }
    private var needsPhotoPick: Bool { session.project.photoOrder.count > range.upperBound }
    private var selectedCount: Int { needsPhotoPick ? kept.count : session.project.photoOrder.count }
    private var canCreate: Bool { range.contains(selectedCount) }

    private func resetKept() {
        kept = Set(session.project.photoOrder.prefix(range.upperBound))
    }

    private func toggle(_ id: UUID) {
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

    private func createCopy() {
        let ids = needsPhotoPick
            ? session.project.photoOrder.filter { kept.contains($0) }
            : session.project.photoOrder
        let photos = ids.compactMap { id -> ImportedPhoto? in
            guard let data = session.assets.data(for: id) else { return nil }
            return ImportedPhoto(
                filename: id.uuidString,
                data: data,
                pixelSize: session.assets.pixelSizes[id] ?? .zero,
                utType: "public.jpeg"
            )
        }
        let copy = ProjectFactory.copy(project: session.project, to: target, photos: photos)
        let newSession = EditorSession(project: copy, assets: AssetLibrary(images: session.assets.images))
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
