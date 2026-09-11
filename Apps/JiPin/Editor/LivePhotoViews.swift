import JiPinCore
import Photos
import PhotosUI
import SwiftUI

struct LivePhotoTools: View {
    @ObservedObject var session: EditorSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("让这一刻，一起动起来", systemImage: "livephoto")
                .font(.headline)
            if session.project.hasLivePhotos {
                Text("\(session.project.resolvedLiveSources.count) 张 Live · 普通照片保持静止")
                    .font(.caption).foregroundStyle(.secondary)
                LivePhotoOptions(session: session)
                Button { session.wantsLivePreview = true } label: {
                    Label("预览 Live 拼图", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("live-preview-open")
            } else {
                Text("从布局工具添加 Live 照片，即可生成动态拼图。最多 9 张 Live，也可以混入普通照片。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LivePhotoOptions: View {
    @ObservedObject var session: EditorSession
    var prefix = "live"
    private var settings: LivePhotoSettings { session.project.livePhotoSettings ?? LivePhotoSettings() }
    var body: some View {
        Picker("动态时长", selection: Binding(get: { settings.safeDuration }, set: { value in
            change { $0.duration = value }
        })) {
            ForEach(LivePhotoPolicy.durations, id: \.self) { value in Text("\(value, specifier: "%g") 秒").tag(value) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("\(prefix)-duration")
        Picker("声音", selection: Binding<UUID?>(get: { settings.audioSourceID }, set: { value in
            change { $0.audioSourceID = value }
        })) {
            Text("静音").tag(UUID?.none)
            ForEach(Array(session.project.photoLayers.enumerated()), id: \.element.id) { index, object in
                if let id = object.photo?.assetID, session.project.resolvedLiveSources.contains(where: { $0.id == id && $0.hasAudio }) {
                    Text("第 \(index + 1) 张的原声").tag(Optional(id))
                }
            }
        }
        .accessibilityIdentifier("\(prefix)-audio")
    }
    private func change(_ update: (inout LivePhotoSettings) -> Void) {
        session.checkpoint()
        var value = settings; update(&value)
        session.project.livePhotoSettings = value
        session.scheduleSave()
    }
}

struct LivePhotoPreview: UIViewRepresentable {
    let photo: PHLivePhoto
    var playback: Int
    var muted: Bool
    final class Coordinator { var photo: PHLivePhoto?; var playback = -1 }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.accessibilityIdentifier = "live-native-preview"
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Live 拼图预览，长按播放动态"
        return view
    }
    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.isMuted = muted
        if context.coordinator.photo !== photo {
            view.livePhoto = photo
            context.coordinator.photo = photo
        }
        if context.coordinator.playback != playback {
            context.coordinator.playback = playback
            view.startPlayback(with: .full)
        }
    }
    static func dismantleUIView(_ view: PHLivePhotoView, coordinator: Coordinator) {
        view.stopPlayback(); view.livePhoto = nil
    }
}

struct LivePhotoExportView: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var result: LivePhotoExport?
    @State private var live: PHLivePhoto?
    @State private var renderTask: Task<Void, Never>?
    @State private var progress = 0.0
    @State private var isRendering = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var jobID = UUID()
    @State private var maxSide = 1080
    @State private var preparedSide = 0
    @State private var renderingFullSize = false
    @State private var playback = 0
    @State private var showStatic = false
    @State private var showShare = false
    private var busy: Bool { isRendering || isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground))
                        if let live {
                            LivePhotoPreview(photo: live, playback: playback, muted: session.project.livePhotoSettings?.audioSourceID == nil)
                        } else if isRendering {
                            VStack(spacing: 12) {
                                ProgressView(value: progress)
                                Text("正在合成动态 \(Int(progress * 100))%")
                                    .font(.callout.monospacedDigit())
                                Text("照片和装饰正在逐帧拼好")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(28)
                        } else {
                            Label("留住会动的回忆", systemImage: "livephoto")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 290)
                    .listRowInsets(EdgeInsets())
                    if live != nil {
                        Button { playback += 1 } label: { Label("播放动态 · 也可以长按预览", systemImage: "play.fill") }
                            .accessibilityIdentifier("live-play")
                    }
                } header: { Text("LIVE PHOTO") } footer: {
                    Text("保存后在苹果相册中长按播放。较短的 Live 会在首尾停留，普通照片保持静止。")
                }
                Section("动态设置") {
                    LivePhotoOptions(session: session, prefix: "live-export")
                    Picker("清晰度", selection: $maxSide) {
                        Text("标准 · 1080").tag(1080)
                        Text("高清 · 1440").tag(1440)
                    }.accessibilityIdentifier("live-quality")
                    let size = LivePhotoExporter.outputSize(project: session.project, assets: session.assets.snapshot, maxSide: CGFloat(maxSide))
                    LabeledContent("尺寸", value: "\(Int(size.width)) × \(Int(size.height))")
                    if let result, preparedSide == maxSide {
                        LabeledContent("文件大小", value: ByteCountFormatter.string(fromByteCount: result.byteCount, countStyle: .file))
                    }
                }.disabled(busy)
                Section {
                    if isRendering {
                        Button("取消生成", role: .cancel) { renderTask?.cancel() }
                            .accessibilityIdentifier("live-cancel-render")
                    } else {
                        Button(result == nil ? "生成动态预览" : "重新生成") { startRender() }
                            .disabled(isSaving)
                            .accessibilityIdentifier("live-generate")
                    }
                    Button("分享视频") {
                        if preparedSide == maxSide { showShare = true }
                        else { startRender(.share) }
                    }
                        .disabled(result == nil || busy)
                        .accessibilityIdentifier("live-share-video")
                    Button("导出静态图片") { showStatic = true }
                        .disabled(busy)
                        .accessibilityIdentifier("live-export-still")
                } footer: {
                    Text("分享视频会发送 MOV 视频。要把 Live 发给其他苹果设备，可保存后从系统相册分享。Live 输出不支持透明背景。")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if isRendering && renderingFullSize {
                        ProgressView(value: progress)
                        Text("正在准备 \(maxSide) 清晰度 · \(Int(progress * 100))%")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).accessibilityIdentifier("live-message")
                    }
                    Button {
                        if result == nil { startRender() } else { Task { await save() } }
                    } label: {
                        Label(isSaving ? "保存中…" : isRendering ? (renderingFullSize ? "正在准备高清成品…" : "正在生成动态预览…") : result == nil ? "生成动态预览" : "保存 Live 到相册", systemImage: "livephoto")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(busy).accessibilityIdentifier(result == nil ? "live-generate-primary" : "live-save-album")
                }.padding().background(.regularMaterial)
            }
            .navigationTitle("导出 Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { renderTask?.cancel(); dismiss() }.disabled(isSaving)
            } }
            .interactiveDismissDisabled(isSaving)
            .onAppear { if result == nil { startRender() } }
            .onDisappear { renderTask?.cancel() }
            .onChange(of: maxSide) { _, _ in invalidate() }
            .onChange(of: session.project.livePhotoSettings) { _, _ in invalidate() }
            .sheet(isPresented: $showStatic) { ExportView(session: session) }
            .sheet(isPresented: $showShare) { if let result { ShareSheet(items: [result.videoURL]) } }
        }
    }

    private func invalidate() {
        renderTask?.cancel(); result = nil; live = nil; message = nil; preparedSide = 0
    }

    private enum RenderPurpose { case preview, save, share }

    private func startRender(_ purpose: RenderPurpose = .preview) {
        guard !busy else { return }
        session.refreshWarnings()
        guard !session.missingAssetWarning, !session.missingLiveAssetWarning else { message = "有照片或 Live 动态资源缺失，请重新选择相关照片后再生成。"; return }
        guard ExportJobLock.tryBegin() else { message = "还有一份作品正在导出，请稍后重试。"; return }
        isRendering = true; progress = 0; message = nil
        renderingFullSize = purpose != .preview
        if purpose == .preview { result = nil; live = nil; preparedSide = 0 }
        let id = UUID(); jobID = id
        let project = session.project, assets = session.assets.snapshot
        // A preview never becomes a saved/shared result: those actions always prepare the chosen output size.
        let side = purpose == .preview ? 640 : maxSide
        renderTask = Task {
            defer { isRendering = false; ExportJobLock.end() }
            let worker = Task.detached(priority: .userInitiated) {
                try await LivePhotoExporter.render(project: project, assets: assets, maxSide: CGFloat(side)) { value in
                    await MainActor.run { if jobID == id { progress = value } }
                }
            }
            do {
                let rendered = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                let native = try await LivePhotoMedia.request(imageURL: rendered.imageURL, videoURL: rendered.videoURL)
                try Task.checkCancellation()
                guard jobID == id, session.project.id == project.id else { return }
                result = rendered; live = native; preparedSide = side; playback += 1
                switch purpose {
                case .preview:
                    message = "预览已就绪。保存时将生成 \(maxSide) 清晰度的成品。"
                case .save:
                    await savePair(rendered)
                case .share:
                    message = "视频已准备好。"
                    showShare = true
                }
            } catch is CancellationError {
                message = "已取消生成，照片和草稿保留。"
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func save() async {
        guard let result, !busy else { return }
        guard preparedSide == maxSide else { startRender(.save); return }
        await savePair(result)
    }

    private func savePair(_ result: LivePhotoExport) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await LivePhotoLibrary.save(result)
            message = "已保存 Live 到相册。打开系统相册，长按这张拼图即可播放。"
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
}
