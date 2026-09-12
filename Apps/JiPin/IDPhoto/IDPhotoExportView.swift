import SwiftUI
import Photos
import UniformTypeIdentifiers
import JiPinCore

struct IDPhotoExportView: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: IDPhotoExportSnapshot
    let onQualityChanged: (IDPhotoExportQuality) -> Void
    let onSaved: () -> Void
    @State private var quality: IDPhotoExportQuality
    @State private var data: Data?
    @State private var preview: UIImage?
    @State private var isPreparing = false
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var shareTask: Task<Void, Never>?
    @State private var message: String?
    @State private var deniedPermission = false
    @State private var showShare = false
    @State private var showFile = false
    @State private var shareURL: URL?
    @State private var prepareTask: Task<Void, Never>?
    @State private var prepareID = UUID()

    init(snapshot: IDPhotoExportSnapshot, onQualityChanged: @escaping (IDPhotoExportQuality) -> Void,
         onSaved: @escaping () -> Void) {
        self.snapshot = snapshot; self.onQualityChanged = onQualityChanged; self.onSaved = onSaved
        _quality = State(initialValue: snapshot.project.exportQuality)
    }

    private var configuration: IDPhotoExportConfiguration? {
        try? IDPhotoExportConfiguration(template: snapshot.project.template, quality: quality)
    }

    private var outputSize: CGSize { configuration?.pixelSize ?? snapshot.project.template.pixelSize }
    private var sizeDescription: String { "\(Int(outputSize.width)) × \(Int(outputSize.height)) px" }
    private var needsUpscaling: Bool {
        let source = ImageIOHelpers.pixelSize(of: snapshot.sourceData)
        return max(outputSize.width / max(source.width, 1), outputSize.height / max(source.height, 1)) * snapshot.project.crop.zoom > 1.01
    }

    private var filename: String {
        let project = snapshot.project
        let title = project.template.isCustom ? "自定义" : project.template.title
        let background = project.keepOriginalBackground ? "原背景" : project.background.title
        return "极拼_\(title)_\(background)_\(quality.title)_\(Int(outputSize.width))x\(Int(outputSize.height))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let preview {
                        Image(uiImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 210)
                            .accessibilityLabel("证件照导出预览")
                    } else if isPreparing {
                        ProgressView("正在生成高质量照片…").frame(maxWidth: .infinity).padding()
                    }
                }
                Section("输出规格") {
                    Picker("清晰度", selection: $quality) {
                        ForEach(IDPhotoExportQuality.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }.pickerStyle(.menu).accessibilityIdentifier("idphoto-export-quality")
                        .disabled(isSaving || isSharing || isPreparing || showShare || showFile)
                    LabeledContent("尺寸", value: sizeDescription)
                        .accessibilityIdentifier("idphoto-export-size")
                    LabeledContent("规格", value: "\(snapshot.project.template.title) · \(snapshot.project.template.millimeterDescription)")
                    LabeledContent("格式", value: "JPEG · \(quality.title)")
                    LabeledContent("打印分辨率", value: "\(configuration?.ppi ?? snapshot.project.template.ppi) ppi")
                    LabeledContent("文件大小", value: data.map { ByteCountFormatter.string(fromByteCount: Int64($0.count), countStyle: .file) } ?? "正在计算")
                    Text(snapshot.project.template.isCustom
                         ? "两种清晰度均保持自定义像素；压缩版文件更小。原照片不会被覆盖。"
                         : "高清从原图保留更多像素；压缩版按模板标准像素输出，适合有尺寸要求的上传。打印规格不变。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if needsUpscaling {
                        Text("原片在当前裁切下的像素较少，高清无法补回已有的模糊细节。可换用更清晰的原片或减少放大。")
                            .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("idphoto-export-source-warning")
                    }
                }
                Section {
                    Button("系统分享") { share() }.disabled(data == nil || isSaving || isSharing).accessibilityIdentifier("idphoto-share")
                    Button("存储到文件") { showFile = true }.disabled(data == nil || isSaving || isSharing).accessibilityIdentifier("idphoto-file")
                }
            }.navigationTitle("保存证件照").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { prepareTask?.cancel(); prepareID = UUID(); dismiss() }
                            .disabled(isSaving).accessibilityIdentifier("idphoto-export-close")
                    }
                }
                .interactiveDismissDisabled(isSaving)
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let message {
                            Text(message).font(.footnote).accessibilityIdentifier("idphoto-export-message")
                            if deniedPermission {
                                HStack {
                                    Button("打开系统设置") {
                                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                        UIApplication.shared.open(url)
                                    }
                                    Spacer()
                                    Button("存储到文件") { showFile = true }
                                        .accessibilityIdentifier("idphoto-file-alternative")
                                }.font(.subheadline)
                            }
                            if data == nil && !isPreparing {
                                Button("重新生成", action: prepare).accessibilityIdentifier("idphoto-export-retry")
                            }
                        }
                        Button { saveAlbum() } label: {
                            Label(isSaving ? "正在保存…" : "保存到相册", systemImage: "square.and.arrow.down")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(data == nil || isSaving || isSharing || isPreparing)
                            .accessibilityIdentifier("idphoto-save-album")
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                }
                .task { prepare() }
                .onChange(of: quality) { _, value in onQualityChanged(value); prepare() }
                .onDisappear { prepareTask?.cancel(); shareTask?.cancel(); prepareID = UUID(); cleanupShareFile() }
                .sheet(isPresented: $showShare, onDismiss: cleanupShareFile) {
                    if let shareURL { ShareSheet(items: [shareURL]) }
                }
                .fileExporter(isPresented: $showFile, document: data.map { ExportDocument(data: $0, format: .jpeg) },
                              contentType: .jpeg, defaultFilename: filename) { result in
                    switch result {
                    case .success: message = "文件已保存。"
                    case .failure(let error): message = "文件未能保存：\(error.localizedDescription)"
                    }
                }
        }
    }

    private func prepare() {
        guard !isSaving else { return }
        prepareTask?.cancel()
        let token = UUID(); prepareID = token
        // Never leave the previous quality's bytes available behind a new label.
        data = nil; preview = nil; deniedPermission = false
        isPreparing = true; message = nil
        var project = snapshot.project
        project.exportQuality = quality
        let frozen = IDPhotoExportSnapshot(project: project, sourceData: snapshot.sourceData,
                                          maskData: snapshot.maskData, faces: snapshot.faces)
        prepareTask = Task {
            do {
                let encoded = try await Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try IDPhotoRenderer.jpegData(project: frozen.project, sourceData: frozen.sourceData,
                                                        maskData: frozen.maskData, faces: frozen.faces)
                }.value
                try Task.checkCancellation()
                guard prepareID == token else { return }
                data = encoded; preview = UIImage(data: encoded); isPreparing = false
                #if DEBUG
                if let path = ProcessInfo.processInfo.environment["JIPIN_IDPHOTO_EXPORT_PATH"] {
                    try? encoded.write(to: URL(fileURLWithPath: path), options: .atomic)
                }
                #endif
            } catch is CancellationError { } catch {
                guard prepareID == token else { return }
                isPreparing = false; message = "生成失败：\(error.localizedDescription)"
            }
        }
    }

    private func saveAlbum() {
        guard let data, !isSaving, !isSharing else { return }
        isSaving = true; message = nil; deniedPermission = false
        Task {
            defer { isSaving = false }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                deniedPermission = true
                message = "没有相册保存权限，照片尚未保存。请在系统设置中允许极拼添加照片，或选择存储到文件。"
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
                }
                onSaved()
            } catch {
                message = "保存失败，当前编辑仍然保留：\(error.localizedDescription)"
            }
        }
    }

    private func share() {
        guard let data, !isSaving, !isSharing else { return }
        isSharing = true
        cleanupShareFile()
        let name = filename
        shareTask = Task {
            defer { isSharing = false }
            do {
                let file = try await Task.detached(priority: .userInitiated) {
                    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JiPin-IDPhoto-\(UUID().uuidString)", isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let url = directory.appendingPathComponent(name).appendingPathExtension("jpg")
                    try data.write(to: url, options: .atomic)
                    return url
                }.value
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: file.deletingLastPathComponent()); return
                }
                shareURL = file; showShare = true
            } catch { message = "分享文件准备失败：\(error.localizedDescription)" }
        }
    }

    private func cleanupShareFile() {
        if let shareURL { try? FileManager.default.removeItem(at: shareURL.deletingLastPathComponent()) }
        shareURL = nil
    }
}
