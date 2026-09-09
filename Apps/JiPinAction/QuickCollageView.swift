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
            assets: AssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        ))
    }

    var body: some View {
        NavigationStack {
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
                        Text("输出 \(session.outputSizeLabel)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .accessibilityLabel("实际输出尺寸 \(session.outputSizeLabel)")
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
                Spacer()
            }
            .navigationTitle("极拼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
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
                    .disabled(photos.count < 2 || isWorking)
                    Button("保存") { Task { await saveImage() } }
                        .disabled(photos.count < 2 || isWorking)
                        .accessibilityLabel("保存到相册")
                        .accessibilityIdentifier("quick-save-album")
                    Button("分享") { Task { await shareImage() } }
                        .disabled(photos.count < 2 || isWorking)
                        .accessibilityLabel("系统分享")
                        .accessibilityIdentifier("quick-share")
                }
            }
            .onAppear { refresh(invalidateExport: false) }
            .sheet(isPresented: $showShare) {
                if let exportData {
                    QuickShareSheet(data: exportData)
                }
            }
        }
    }

    private var JiPinThemeAccent: Color {
        Color(red: 1, green: 0.353, blue: 0.212)
    }

    private func refresh(invalidateExport: Bool = true) {
        if invalidateExport {
            exportData = nil
        }
        if session.selectedID == nil {
            session.selectedID = session.project.photoLayers.first?.id
        }
        preview = session.previewImage(maxSide: 900)
    }

    private func applyBackgroundPhoto(_ items: [PhotosPickerItem]) async {
        defer { backgroundPicker = [] }
        guard let item = items.first else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let stripped = ImageIOHelpers.strippedJPEG(from: data, quality: 0.95) else {
            message = "背景图无法导入。如果原图还在 iCloud，请联网后重试。"
            return
        }
        let photo = ImportedPhoto(
            filename: "background.jpg",
            data: stripped,
            pixelSize: ImageIOHelpers.pixelSize(of: stripped),
            utType: "public.jpeg"
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
        isWorking = true
        session.project.originatedFromExtension = true
        session.project.name = "相册快拼 \(session.project.name)"
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
        if let exportData { return exportData }
        let size = ExportGeometry.extensionOutputSize(for: session.project, assets: session.assets)
        let assets = DataAssetLibrary(images: session.assets.images)
        let project = session.project
        return await Task.detached(priority: .userInitiated) {
            CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size)
        }.value
    }

    private func shareImage() async {
        isWorking = true
        message = "正在生成…"
        guard let data = await generateJPEG() else {
            message = "生成失败。"
            isWorking = false
            return
        }
        exportData = data
        isWorking = false
        showShare = true
    }

    private func saveImage() async {
        isWorking = true
        guard let data = await generateJPEG() else {
            message = "生成失败。"
            isWorking = false
            return
        }
        exportData = data
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
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
    var data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jipin-quick.jpg")
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
