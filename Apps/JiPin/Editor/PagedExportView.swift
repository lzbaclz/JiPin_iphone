import Photos
import SwiftUI
import JiPinCore

struct PagedExportView: View {
    @ObservedObject var session: EditorSession
    var onSaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var length = PageLength.reading
    @State private var exported: ExportedPages?
    @State private var task: Task<Void, Never>?
    @State private var busy = false
    @State private var saving = false
    @State private var active = true
    @State private var message: String?
    @State private var sharing = false
    @State private var thumbnails: [UIImage] = []
    private var plan: PageExportPlan? { try? PageExportPlan.make(project: session.project, assets: session.assets.snapshot, length: length) }

    var body: some View {
        NavigationStack {
            Form {
                Section("连续切片") {
                    Picker("每页长度", selection: $length) {
                        ForEach(PageLength.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).disabled(busy || saving)
                    if let plan, let first = plan.regions.first, let last = plan.regions.last {
                        Text("共 \(plan.regions.count) 页 · \(dimensions(first.size)) 像素")
                            .accessibilityIdentifier("pages-plan")
                        Text("最后一页 \(dimensions(last.size)) · 全部内容按顺序保留。")
                            .font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, image in
                                    VStack {
                                        Image(uiImage: image).resizable().scaledToFit().frame(width: 104, height: 160)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                        Text("\(index + 1)").font(.caption.monospacedDigit())
                                    }
                                }
                            }
                        }
                        Text("按固定长度切开，文字或照片可能跨页；可换每页长度查看接缝。此处保留标准/高清的原定宽度，不先把整张长图缩小。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("内容超出分页上限，请返回选择标准尺寸或减少照片。")
                    }
                }
                Section {
                    Button(busy ? "正在逐页生成…" : "生成分页文件") { generate() }
                        .disabled(busy || saving || plan == nil)
                        .accessibilityIdentifier("pages-generate")
                    if busy { Button("取消生成", role: .cancel) { task?.cancel() } }
                    if let exported {
                        Text("已生成 \(exported.files.count) 个文件 · \(ByteCountFormatter.string(fromByteCount: exported.byteCount, countStyle: .file))")
                            .accessibilityIdentifier("pages-result")
                        Button("分享全部 / 存储到文件") { sharing = true }
                            .disabled(saving).accessibilityIdentifier("pages-share")
                        Button(saving ? "正在保存…" : "保存全部到相册") { Task { await saveAlbum(exported) } }
                            .disabled(saving).accessibilityIdentifier("pages-save-album")
                    }
                    if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("长图分页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(saving) } }
            .interactiveDismissDisabled(saving)
            .task(id: length) { await makeThumbnails() }
            .onChange(of: length) { _, _ in clearFiles() }
            .sheet(isPresented: $sharing) {
                if let exported { ShareSheet(items: exported.files) }
            }
            .onDisappear { active = false; task?.cancel(); clearFiles() }
        }
    }

    private func dimensions(_ size: CGSize) -> String { "\(Int(size.width))×\(Int(size.height))" }
    private func clearFiles() { exported?.remove(); exported = nil; message = nil }

    private func generate() {
        guard !busy, let plan else { return }
        session.refreshWarnings()
        guard !session.missingAssetWarning else { message = "有素材缺失，请先返回替换后再导出。"; return }
        guard ExportJobLock.tryBegin() else { message = "请等待当前导出完成。"; return }
        clearFiles(); busy = true
        let project = session.project, assets = session.assets.snapshot
        task = Task {
            defer { busy = false; ExportJobLock.end() }
            let worker = Task.detached(priority: .userInitiated) {
                try PagedExporter.export(project: project, assets: assets, plan: plan)
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard active, !Task.isCancelled else { result.remove(); return }
                exported = result
            } catch is CancellationError { if active { message = "已取消，可以重新生成。" } }
            catch { if active { message = error.localizedDescription } }
        }
    }

    private func makeThumbnails() async {
        thumbnails = []
        guard let plan else { return }
        let project = session.project, assets = session.assets.snapshot
        let worker = Task.detached(priority: .userInitiated) { () -> [UIImage] in
            var previews: [UIImage] = []
            for region in plan.regions {
                if Task.isCancelled { break }
                let factor = 208 / max(region.width, 1)
                let size = CGSize(width: max(region.width * factor, 1), height: max(region.height * factor, 1))
                let image = autoreleasepool {
                    let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
                    return UIGraphicsImageRenderer(size: size, format: format).image { context in
                        context.cgContext.scaleBy(x: factor, y: factor)
                        context.cgContext.translateBy(x: -region.minX, y: -region.minY)
                        context.cgContext.clip(to: region)
                        CollageRenderer.shared.draw(project: project, assets: assets, canvasSize: plan.canvasSize,
                                                    preview: true, visibleRect: region, in: context.cgContext)
                    }
                }
                previews.append(image)
            }
            return previews
        }
        let images = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
        guard !Task.isCancelled else { return }
        thumbnails = images
    }

    private func saveAlbum(_ result: ExportedPages) async {
        saving = true
        defer { saving = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { message = "未获得相册权限，可使用分享或存储到文件。"; return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for file in result.files {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: file, options: nil)
                }
            }
            message = "已保存 \(result.files.count) 页到相册。"
            if let onSaved { onSaved() } else { dismiss() }
        } catch { message = "保存未完成：\(error.localizedDescription)" }
    }
}
