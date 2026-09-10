import Photos
import PhotosUI
import SwiftUI
import JiPinCore

struct QuickCollageView: View {
    let photos: [ImportedPhoto]
    let failed: [ImportedPhoto]
    var overflowCount: Int = 0
    var onCancel: () -> Void
    var onFinish: () -> Void

    @StateObject private var session: EditorSession
    @State private var message: String?
    @State private var isWorking = false
    @State private var preview: UIImage?
    @State private var exportData: Data?
    @State private var showShare = false
    @State private var backgroundPicker: [PhotosPickerItem] = []
    @State private var shareURL: URL?
    @State private var showImportIssues = false
    @State private var acceptedImportIssues = false
    @State private var didCancel = false

    init(photos: [ImportedPhoto], failed: [ImportedPhoto], overflowCount: Int = 0, onCancel: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.photos = photos
        self.failed = failed
        self.overflowCount = overflowCount
        self.onCancel = onCancel
        self.onFinish = onFinish
        let project = ProjectFactory.make(
            mode: .template,
            photos: photos,
            originatedFromExtension: true
        )
        _session = StateObject(wrappedValue: EditorSession(
            project: project,
            assets: AssetLibrary(photos: photos),
            autosaves: false
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 12) {
                if photos.count < 2 {
                    ContentUnavailableView(
                        "扩展支持 2–9 张照片",
                        systemImage: "photo.on.rectangle",
                        description: Text("请在相册中多选 2 到 9 张后再从分享菜单的操作区打开极拼。完整编辑请打开极拼 App。")
                    )
                } else {
                    Text("快速拼图：模板、横竖拼接、排序、裁切、背景和间距。文字贴纸与海报请保存草稿后到极拼继续。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    if session.project.hasLivePhotos {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("已保留 \(session.project.resolvedLiveSources.count) 张 Live 的动态", systemImage: "livephoto")
                                .font(.subheadline.weight(.semibold))
                            Text("保存 Live 草稿后，打开极拼的草稿页继续编辑和导出动态。这里的保存图片和分享仅输出静态封面。")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("保存 Live 草稿") { Task { await saveDraft() } }
                                .buttonStyle(.borderedProminent).disabled(!canProcess || isWorking)
                                .accessibilityIdentifier("quick-save-live-draft")
                        }.padding().background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
                    }
                    if let preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                    if overflowCount > 0 {
                        Text("扩展最多 9 张，已忽略多出的 \(overflowCount) 张。更多照片请在极拼 App 中导入。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .accessibilityIdentifier("quick-overflow")
                    }
                    if !failed.isEmpty {
                        Text("有 \(failed.count) 张未能导入，未静默丢弃。可取消后重试，或继续使用已导入的照片。")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .accessibilityIdentifier("quick-failed")
                    }
                    Picker("模式", selection: Binding(
                        get: { session.project.mode },
                        set: { mode in
                            let rebuilt = ProjectFactory.make(mode: mode, photos: photos, originatedFromExtension: true)
                            session.project = rebuilt
                            refresh()
                        }
                    )) {
                        Text("模板").tag(CollageMode.template)
                        Text("长图").tag(CollageMode.longStrip)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if session.project.mode == .template {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(CollageGridLayoutCatalog.layouts(forPhotoCount: photos.count)) { layout in
                                    Button(layout.name) {
                                        session.changeLayout(layout)
                                        refresh()
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(session.project.layoutID == layout.id ? JiPinThemeAccent : Color.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Picker("方向", selection: Binding(
                            get: { session.project.longStrip?.direction ?? .vertical },
                            set: { direction in
                                session.project.longStrip = LongStripSpec(direction: direction, spacing: session.project.spacing)
                                refresh()
                            }
                        )) {
                            Text("纵向").tag(StripDirection.vertical)
                            Text("横向").tag(StripDirection.horizontal)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        Text("输出 \(quickOutputLabel)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .accessibilityLabel("实际输出尺寸 \(quickOutputLabel)")
                    }

                    HStack {
                        Text("间距")
                        Slider(value: Binding(
                            get: { session.project.spacing },
                            set: { session.project.spacing = $0; refresh() }
                        ), in: 0...0.08)
                        Text("边距")
                        Slider(value: Binding(
                            get: { session.project.outerMargin },
                            set: { session.project.outerMargin = $0; refresh() }
                        ), in: 0...0.1)
                    }
                    .padding(.horizontal)
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("间距和边距")
                    Button("无缝拼接") {
                        session.project.spacing = 0
                        session.project.outerMargin = 0
                        refresh()
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .accessibilityIdentifier("quick-seamless")
                    .accessibilityHint("间距和边距设为零")

                    if let selected = session.selected ?? session.project.photoLayers.first {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当前照片裁切与排序")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("上一张") { stepPhoto(-1) }
                                Button("下一张") { stepPhoto(1) }
                                Button("前移") {
                                    session.select(selected.id)
                                    session.movePhoto(forward: false)
                                    refresh()
                                }
                                .accessibilityLabel("当前照片前移")
                                Button("后移") {
                                    session.select(selected.id)
                                    session.movePhoto(forward: true)
                                    refresh()
                                }
                                .accessibilityLabel("当前照片后移")
                            }
                            .buttonStyle(.bordered)
                            cropSlider("上", key: \.top, photoID: selected.id)
                            cropSlider("下", key: \.bottom, photoID: selected.id)
                            cropSlider("左", key: \.left, photoID: selected.id)
                            cropSlider("右", key: \.right, photoID: selected.id)
                            HStack {
                                Text("缩放")
                                Slider(
                                    value: Binding(
                                        get: { selected.photo?.crop.zoom ?? 1 },
                                        set: { zoom in
                                            session.select(selected.id)
                                            session.setPhotoContent(zoom: zoom)
                                            refresh()
                                        }
                                    ),
                                    in: 1...4
                                )
                            }
                            .font(.caption)
                            .accessibilityLabel("照片内容缩放")
                            Picker("显示", selection: Binding(
                                get: { selected.photo?.contentMode ?? .fill },
                                set: { mode in
                                    session.select(selected.id)
                                    session.checkpoint()
                                    session.updateSelected { $0.photo?.contentMode = mode }
                                    refresh()
                                }
                            )) {
                                Text("铺满裁切").tag(PhotoContentMode.fill)
                                Text("完整显示").tag(PhotoContentMode.fit)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("quick-content-mode")
                        }
                        .padding(.horizontal)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(BackgroundCatalog.all.prefix(8)) { preset in
                                Button(preset.name) {
                                    session.project.background = preset.spec
                                    refresh()
                                }
                                .buttonStyle(.bordered)
                            }
                            PhotosPicker(
                                selection: $backgroundPicker,
                                maxSelectionCount: 1,
                                matching: .images
                            ) {
                                Label("选图作背景", systemImage: "photo")
                            }
                            .accessibilityIdentifier("quick-bg-photo")
                            .onChange(of: backgroundPicker) { _, items in
                                Task { await applyBackgroundPhoto(items) }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .disabled(isWorking)
            }
            .navigationTitle("极拼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { didCancel = true; onCancel() }
                        .accessibilityLabel("取消快速拼图")
                        .accessibilityIdentifier("quick-cancel")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Menu {
                        Button("保存草稿") { Task { await saveDraft() } }
                            .accessibilityHint("保存后请打开极拼 App 的草稿页继续")
                            .accessibilityIdentifier("quick-save-draft")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多")
                    .accessibilityIdentifier("quick-more")
                    .disabled(!canProcess || isWorking)
                    Button(session.project.hasLivePhotos ? "存图片" : "保存") { Task { await saveImage() } }
                        .disabled(!canProcess || isWorking)
                        .accessibilityLabel(session.project.hasLivePhotos ? "保存静态图片到相册" : "保存到相册")
                        .accessibilityIdentifier("quick-save-album")
                    Button(session.project.hasLivePhotos ? "分享图片" : "分享") { Task { await shareImage() } }
                        .disabled(!canProcess || isWorking)
                        .accessibilityLabel("系统分享")
                        .accessibilityIdentifier("quick-share")
                }
            }
            .onAppear {
                refresh(invalidateExport: false)
                showImportIssues = photos.count >= 2 && (!failed.isEmpty || overflowCount > 0)
            }
            .task(id: session.project) {
                let request = PreviewRequest(project: session.project, displaySize: previewSize, displayScale: 1)
                let rendered = await PreviewRendering.shared.render(request, assets: session.assets.snapshot)
                if !Task.isCancelled { preview = rendered }
            }
            .alert("确认导入的照片", isPresented: $showImportIssues) {
                Button("继续使用这 \(photos.count) 张") { acceptedImportIssues = true }
                Button("取消并重新选择", role: .cancel, action: onCancel)
            } message: {
                Text("有 \(failed.count) 张读取失败，\(overflowCount) 张超过数量上限。确认后仅使用已成功导入的 \(photos.count) 张。")
            }
            .sheet(isPresented: $showShare, onDismiss: {
                if let shareURL { try? FileManager.default.removeItem(at: shareURL) }
                shareURL = nil
            }) {
                if let shareURL { QuickShareSheet(url: shareURL) }
            }
        }
    }

    private var JiPinThemeAccent: Color {
        Color(red: 1, green: 0.353, blue: 0.212)
    }

    private var canProcess: Bool {
        PhotoLimits.extensionRange.contains(photos.count) && (acceptedImportIssues || (failed.isEmpty && overflowCount == 0))
    }

    private var previewSize: CGSize {
        let output = ExportGeometry.extensionOutputSize(for: session.project, assets: session.assets.snapshot)
        let scale = 900 / max(output.width, output.height, 1)
        return CGSize(width: max(1, output.width * scale), height: max(1, output.height * scale))
    }

    private var quickOutputLabel: String {
        let size = ExportGeometry.extensionOutputSize(for: session.project, assets: session.assets.snapshot)
        return "\(Int(size.width))×\(Int(size.height)) 像素"
    }

    private func refresh(invalidateExport: Bool = true) {
        if invalidateExport {
            exportData = nil
        }
        if session.selectedID == nil {
            session.selectedID = session.project.photoLayers.first?.id
        }
    }

    private func applyBackgroundPhoto(_ items: [PhotosPickerItem]) async {
        defer { backgroundPicker = [] }
        guard let item = items.first else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let stripped = ImageIOHelpers.sanitizedImageData(from: data, maxLongSide: 4096, maxPixelCount: 4_194_304) else {
            message = "背景图无法导入。如果原图还在 iCloud，请联网后重试。"
            return
        }
        let photo = ImportedPhoto(
            filename: "背景图片",
            data: stripped,
            pixelSize: ImageIOHelpers.pixelSize(of: stripped),
            utType: ImageIOHelpers.typeIdentifier(of: stripped)
        )
        session.assets.ingest([photo])
        session.checkpoint()
        session.project.background = BackgroundSpec(kind: .image, imageAssetID: photo.id)
        refresh()
    }

    private func stepPhoto(_ delta: Int) {
        let photos = session.project.photoLayers
        guard let current = session.selectedID, let index = photos.firstIndex(where: { $0.id == current }) else {
            session.selectedID = photos.first?.id
            return
        }
        let next = (index + delta + photos.count) % photos.count
        session.selectedID = photos[next].id
    }

    private func cropSlider(_ title: String, key: WritableKeyPath<PhotoCrop, Double>, photoID: UUID) -> some View {
        HStack {
            Text(title).frame(width: 24)
            Slider(
                value: Binding(
                    get: { session.project.object(id: photoID)?.photo?.crop[keyPath: key] ?? 0 },
                    set: { value in
                        session.project.updateObject(id: photoID) { $0.photo?.crop[keyPath: key] = min(max(value, 0), 0.45) }
                        refresh()
                    }
                ),
                in: 0...0.45
            )
        }
        .font(.caption)
        .accessibilityLabel("裁切\(title)")
    }

    private func saveDraft() async {
        guard canProcess, !isWorking else { return }
        if Bundle.main.bundleURL.pathExtension == "appex" && !session.store.isUsingAppGroup {
            message = "当前安装无法与极拼共享草稿。请先保存拼图或系统分享，重新安装正确签名的极拼后再试。"
            return
        }
        isWorking = true
        session.project.originatedFromExtension = true
        if !session.project.name.hasPrefix("相册快拼") { session.project.name = "相册快拼 \(session.project.name)" }
        session.project.touch()
        await session.persistNow()
        if let error = session.lastError {
            message = error
        } else if DraftStore.shared.isUsingAppGroup {
            message = "草稿已保存。打开极拼 App，在草稿页继续完整编辑。扩展不会自动跳转到主 App。"
        } else {
            message = "草稿已保存到本 App。当前安装无法写入 App Group，相册扩展与主 App 不能共享这份草稿。真机请用同一 Development Team 签名后再从相册交接。"
        }
        isWorking = false
    }

    private func generateJPEG() async -> Data? {
        session.refreshWarnings()
        guard !session.missingAssetWarning else { return nil }
        if let exportData { return exportData }
        let size = ExportGeometry.extensionOutputSize(for: session.project, assets: session.assets.snapshot)
        let assets = DataAssetLibrary(images: session.assets.images)
        let project = session.project
        return await Task.detached(priority: .userInitiated) {
            CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size)
        }.value
    }

    private func shareImage() async {
        guard canProcess, !isWorking else { return }
        isWorking = true
        message = "正在生成…"
        guard let data = await generateJPEG() else {
            message = "生成失败。"
            isWorking = false
            return
        }
        exportData = data
        isWorking = false
        guard !didCancel else { return }
        do {
            shareURL = try ExportFile.write(data: data, format: .jpeg)
            showShare = true
        } catch { message = "无法准备分享文件：\(error.localizedDescription)" }
    }

    private func saveImage() async {
        guard canProcess, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        guard let data = await generateJPEG() else {
            message = "生成失败。"
            isWorking = false
            return
        }
        exportData = data
        guard !didCancel else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard !didCancel else { return }
        guard status == .authorized || status == .limited else {
            message = "没有添加照片权限。草稿仍可保存，也可以用系统分享。"
            isWorking = false
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            message = "已保存到相册。"
            try? await Task.sleep(nanoseconds: 600_000_000)
            onFinish()
        } catch {
            message = error.localizedDescription
        }
        isWorking = false
    }
}

private struct QuickShareSheet: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
