import Photos
import SwiftUI
import UniformTypeIdentifiers
import JiPinCore

struct ExportView: View {
    @ObservedObject var session: EditorSession
    var onSaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var preview: UIImage?
    @State private var estimated = "估算生成后显示实际大小"
    @State private var actualSize: String?
    @State private var fileData: Data?
    @State private var isExporting = false
    @State private var message: String?
    @State private var showShare = false
    @State private var limitChoice: ExportLimitDecision?
    @State private var useScaled = false
    @State private var saveToFiles = false
    @State private var exportJobID = UUID()
    @State private var shareURL: URL?
    @State private var isSavingToAlbum = false
    @State private var showPages = false

    private var isBusy: Bool { isExporting || isSavingToAlbum }

    var body: some View {
        NavigationStack {
            Form {
                Section("预览") {
                    if let preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                    } else {
                        ProgressView()
                    }
                }
                Section("输出") {
                    Picker("格式", selection: $session.project.exportPreference.format) {
                        ForEach(ExportFormat.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("尺寸", selection: $session.project.exportPreference.quality) {
                        ForEach(ExportQuality.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("export-quality")
                    if session.project.mode == .freeform || session.project.mode == .poster {
                        Toggle("透明背景（PNG）", isOn: Binding(
                            get: { session.project.exportPreference.transparentBackground },
                            set: { value in
                                session.project.exportPreference.transparentBackground = value
                                if value {
                                    session.project.exportPreference.format = .png
                                    session.project.background.isHidden = true
                                }
                            }
                        ))
                        if session.project.exportPreference.format == .jpeg {
                            Text("JPEG 会填充背景，透明导出请改用 PNG。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("文件大小", value: actualSize ?? estimated)
                        .accessibilityIdentifier("export-file-size")
                    sizeFootnote
                    if session.lowResolutionWarning {
                        Text("有照片分辨率偏低，按当前尺寸放大后可能发糊。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("export-low-res")
                    }
                }
                .disabled(isBusy)
                if case .needsChoice(let computed, let scaled) = limitChoice {
                    Section("长图超出上限") {
                        Text("完整尺寸约为 \(Int(computed.width))×\(Int(computed.height))，超过边长或总像素上限。")
                        Button("接受等比缩小到 \(Int(scaled.width))×\(Int(scaled.height))") {
                            useScaled = true
                        }
                        .accessibilityIdentifier("export-accept-scale")
                        Text("也可以在下面移出部分照片。不会静默裁掉尾部。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(session.project.photoLayers.enumerated()), id: \.element.id) { index, object in
                            Button("移出第 \(index + 1) 张") {
                                session.select(object.id)
                                session.removeSelectedPhoto()
                                useScaled = false
                                refresh()
                            }
                            .disabled(session.project.photoOrder.count <= 2 || isBusy)
                            .accessibilityIdentifier("export-drop-photo-\(index)")
                        }
                    }
                }
                Section {
                    if session.project.mode == .longStrip {
                        Button("长图分页导出") { showPages = true }
                            .disabled(isBusy)
                            .accessibilityIdentifier("export-pages")
                    }
                    Button(isExporting ? "正在生成…" : "生成文件") {
                        Task { await generate() }
                    }
                    .disabled(isBusy)
                    .accessibilityIdentifier("export-generate")
                    Button("系统分享") { Task { await shareGenerated() } }
                        .disabled(isBusy)
                        .accessibilityIdentifier("export-share")
                        .accessibilityHidden(false)
                    Button("存储到文件") { Task { await exportToFiles() } }
                        .disabled(isBusy)
                        .accessibilityIdentifier("export-save-files")
                        .accessibilityHidden(false)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if let message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("export-message")
                    }
                    Button { Task { await saveToAlbum() } } label: {
                        HStack {
                            if isSavingToAlbum { ProgressView().tint(.white) }
                            Label(isSavingToAlbum ? "正在保存…" : "保存到相册", systemImage: "square.and.arrow.down")
                        }.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(isBusy).accessibilityIdentifier("export-save-album")
                    Text("直接保存，无需先生成文件")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding().background(.regularMaterial)
            }
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(isBusy) } }
            .interactiveDismissDisabled(isBusy)
            .onAppear { refresh() }
            .sheet(isPresented: $showPages) { PagedExportView(session: session, onSaved: finishSaving) }
            .onChange(of: session.project.exportPreference) { _, _ in refresh() }
            .sheet(isPresented: $showShare, onDismiss: cleanupShareFile) {
                if let shareURL { ShareSheet(items: [shareURL]) }
            }
            .fileExporter(
                isPresented: $saveToFiles,
                document: ExportDocument(data: fileData ?? Data(), format: session.project.exportPreference.format),
                contentType: session.project.exportPreference.format == .png ? .png : .jpeg,
                defaultFilename: session.project.name
            ) { result in
                switch result {
                case .success: message = "已存储到文件。"
                case .failure(let error): message = "未能存储文件：\(error.localizedDescription)"
                }
            }
            .onDisappear { exportJobID = UUID() }
        }
    }

    private var sizeFootnote: some View {
        Group {
            switch ExportGeometry.outputSize(for: session.project, assets: session.assets.snapshot) {
            case .ok(let size):
                Text("输出约 \(Int(size.width))×\(Int(size.height)) 像素。大小为预估，编码完成后显示实际值。PNG 无 JPEG 压缩损失，但裁切缩放仍会改变像素。")
            case .needsChoice(let computed, _):
                Text("当前计算尺寸 \(Int(computed.width))×\(Int(computed.height))。")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func refresh() {
        exportJobID = UUID()
        session.refreshWarnings()
        limitChoice = ExportGeometry.outputSize(for: session.project, assets: session.assets.snapshot)
        preview = session.previewImage(maxSide: 720)
        switch limitChoice {
        case .ok(let size):
            estimated = ExportGeometry.estimatedSizeLabel(size: size, format: session.project.exportPreference.format)
        case .needsChoice:
            estimated = "超出上限时请先选择缩小或减少照片"
        case .none:
            estimated = "估算生成后显示实际大小"
        }
        actualSize = nil
        fileData = nil
    }

    private func canvasSize() -> CGSize? {
        switch ExportGeometry.outputSize(for: session.project, assets: session.assets.snapshot) {
        case .ok(let size):
            return size
        case .needsChoice(_, let scaled):
            return useScaled ? scaled : nil
        }
    }

    private func generate() async {
        guard !isExporting else { return }
        session.refreshWarnings()
        guard let size = canvasSize() else {
            message = "请先选择缩小输出，或减少照片。"
            return
        }
        if session.missingAssetWarning {
            message = "有素材缺失或无法读取。请替换照片或去掉损坏贴纸后再导出，不会把半成品当成成功导出。"
            return
        }
        guard ExportJobLock.tryBegin() else {
            message = "同一时间只能导出一份，请等待当前任务完成。"
            return
        }
        isExporting = true
        message = nil
        let jobID = UUID()
        exportJobID = jobID
        defer {
            isExporting = false
            ExportJobLock.end()
        }
        let project = session.project
        let assets = DataAssetLibrary(images: session.assets.images)
        let data: Data? = await Task.detached(priority: .userInitiated) {
            if project.exportPreference.format == .png {
                return CollageRenderer.shared.pngData(project: project, assets: assets, canvasSize: size)
            }
            return CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size)
        }.value
        guard exportJobID == jobID, session.project.id == project.id else { return }
        fileData = data
        if let data {
            actualSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            preview = UIImage(data: data)
            message = "已生成 \(Int(size.width))×\(Int(size.height)) 文件。"
        } else {
            message = "生成失败，请检查素材是否完整。"
        }
    }

    private func ensureFile() async -> Data? {
        if let fileData { return fileData }
        await generate()
        return fileData
    }

    private func shareGenerated() async {
        guard let data = await ensureFile() else { return }
        do {
            cleanupShareFile()
            shareURL = try ExportFile.write(data: data, format: session.project.exportPreference.format)
            showShare = true
        } catch { message = "无法准备分享文件：\(error.localizedDescription)" }
    }

    private func exportToFiles() async {
        guard await ensureFile() != nil else { return }
        saveToFiles = true
    }

    private func saveToAlbum() async {
        guard !isSavingToAlbum else { return }
        isSavingToAlbum = true
        defer { isSavingToAlbum = false }
        guard let data = await ensureFile() else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            message = "未获得添加照片权限。项目仍保留，可改用系统分享或存储到文件。"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            message = "已保存到相册。"
            finishSaving()
        } catch {
            message = "保存失败：\(error.localizedDescription)。项目仍保留，可以重试或存储到文件。"
        }
    }

    private func finishSaving() {
        if let onSaved { onSaved() } else { dismiss() }
    }

    private func cleanupShareFile() {
        if let shareURL { try? FileManager.default.removeItem(at: shareURL) }
        shareURL = nil
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .jpeg] }
    var data: Data
    var format: ExportFormat

    init(data: Data, format: ExportFormat) {
        self.data = data
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        format = .png
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
