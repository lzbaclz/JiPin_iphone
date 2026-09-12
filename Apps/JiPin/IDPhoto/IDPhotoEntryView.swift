import SwiftUI
import PhotosUI
import JiPinCore

struct IDPhotoEntryView: View {
    var initialDraftID: UUID? = nil
    var onClose: () -> Void
    @State private var selectedTemplate = IDPhotoTemplateCatalog.defaultTemplate
    @State private var selection: PhotosPickerItem?
    @State private var showPicker = false
    @State private var showCustomSize = false
    @State private var session: IDPhotoSession?
    @State private var drafts: [IDPhotoDraftSummary] = []
    @State private var pendingDelete: IDPhotoDraftSummary?
    @State private var loadTask: Task<Void, Never>?
    @State private var loadID = UUID()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var initialized = false

    var body: some View {
        ZStack {
            if let session {
                IDPhotoEditorView(session: session) {
                    self.session = nil
                    if initialDraftID != nil { onClose() } else { refreshDrafts() }
                }
            } else {
                entry
            }
        }
        .task {
            guard !initialized else { return }
            initialized = true
            refreshDrafts()
            if let initialDraftID { openDraft(initialDraftID); return }
            #if DEBUG
            openDebugSample()
            #endif
        }
        .onDisappear { cancelLoading(); session?.stop() }
    }

    private var entry: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选个尺寸，制作你的照片").font(.title2.bold())
                        Text("导入一张清晰单人照，在本机换底与轻修。Live 照片仅使用静态画面。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    IDPhotoTemplateGrid(selection: selectedTemplate) { selectedTemplate = $0 }
                    Button { showCustomSize = true } label: {
                        Label("自定义像素", systemImage: "ruler")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered).accessibilityIdentifier("idphoto-custom")
                    Text("当前尺寸：\(selectedTemplate.title) · \(selectedTemplate.width) × \(selectedTemplate.height) px")
                        .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("idphoto-selected-size")
                    Button { selection = nil; showPicker = true } label: {
                        Label("导入一张照片", systemImage: "photo.badge.plus")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("idphoto-import")
                    Text("用于正式证件或考试时，请以办理方要求为准；部分用途不允许换底或美颜。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Divider()
                    Text("证件照草稿").font(.title3.bold())
                    if drafts.isEmpty {
                        Text("制作后会自动保存在这里。原照片不会被覆盖。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(drafts) { draft in draftRow(draft) }
                }.padding()
            }
            .background(JiPinTheme.canvas.ignoresSafeArea())
            .navigationTitle("证件照")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { cancelLoading(); onClose() }.accessibilityIdentifier("idphoto-entry-close")
                }
            }
            .photosPicker(isPresented: $showPicker, selection: $selection, matching: PhotoImporter.stillImages)
            .onChange(of: selection) { _, item in if let item { importPhoto(item) } }
            .sheet(isPresented: $showCustomSize) {
                IDPhotoCustomSizeView(template: selectedTemplate) { selectedTemplate = $0 }
            }
            .alert("暂时无法完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .alert("删除这份证件照草稿？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("取消", role: .cancel) { pendingDelete = nil }
                Button("删除草稿", role: .destructive) { deleteDraft() }
            } message: { Text("只删除极拼中的草稿，不影响相册原照片或已导出的照片。") }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("正在读取照片…").font(.headline)
                            Text("iCloud 原片可能需要系统下载。")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("取消读取", action: cancelLoading).accessibilityIdentifier("idphoto-import-cancel")
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
    }

    private func draftRow(_ draft: IDPhotoDraftSummary) -> some View {
        HStack(spacing: 14) {
            Button { openDraft(draft.id) } label: {
                HStack(spacing: 14) {
                    IDPhotoDraftThumbnail(path: draft.thumbnailPath)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.name).font(.headline).foregroundStyle(.primary)
                        Text("\(draft.template.title) · \(draft.template.width)×\(draft.template.height) px")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(draft.updatedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }.buttonStyle(.plain).accessibilityIdentifier("idphoto-draft-\(draft.id.uuidString)")
            Button { pendingDelete = draft } label: { Image(systemName: "trash") }
                .accessibilityLabel("删除\(draft.name)草稿").accessibilityIdentifier("idphoto-draft-delete-\(draft.id.uuidString)")
        }.padding(12).background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func refreshDrafts() {
        Task {
            let result = await Task.detached(priority: .utility) { IDPhotoDraftStore.shared.listDrafts() }.value
            drafts = result
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        cancelLoading()
        let token = UUID(), template = selectedTemplate
        loadID = token; isLoading = true
        loadTask = Task {
            let result = await PhotoImporter.load([item], preserveLive: false)
            guard !Task.isCancelled, loadID == token else { return }
            isLoading = false
            guard let photo = result.ok.first else {
                errorMessage = result.failed.first?.failureReason ?? "未能读取这张照片，请重新选择。"
                return
            }
            let editor = IDPhotoSession(sourceData: photo.data, template: template)
            session = editor
            editor.start()
        }
    }

    private func openDraft(_ id: UUID) {
        cancelLoading()
        let token = UUID(); loadID = token; isLoading = true
        loadTask = Task {
            do {
                let draft = try await Task.detached(priority: .userInitiated) { try IDPhotoDraftStore.shared.load(id: id) }.value
                guard !Task.isCancelled, loadID == token else { return }
                isLoading = false
                let editor = IDPhotoSession(draft: draft)
                session = editor
                editor.start(reanalyze: false)
            } catch {
                guard !Task.isCancelled, loadID == token else { return }
                isLoading = false
                errorMessage = "草稿未能打开：\(error.localizedDescription)"
            }
        }
    }

    private func deleteDraft() {
        guard let id = pendingDelete?.id else { return }
        pendingDelete = nil
        Task {
            do {
                try await Task.detached(priority: .utility) { try IDPhotoDraftStore.shared.delete(id: id) }.value
                refreshDrafts()
            } catch { errorMessage = "删除失败：\(error.localizedDescription)" }
        }
    }

    private func cancelLoading() {
        loadTask?.cancel(); loadID = UUID(); isLoading = false
    }

    #if DEBUG
    private func openDebugSample() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-idPhotoSample") else { return }
        let path = ProcessInfo.processInfo.environment["JIPIN_IDPHOTO_SAMPLE_PATH"] ?? args.firstIndex(of: "-idPhotoSamplePath").flatMap {
            $0 + 1 < args.count ? args[$0 + 1] : nil
        }
        loadTask = Task {
            do {
                let data: Data
                if let path {
                    data = try await Task.detached { try Data(contentsOf: URL(fileURLWithPath: path)) }.value
                } else {
                    guard let sample = SamplePhotos.make(1).first else { return }
                    data = sample.data
                }
                guard !Task.isCancelled else { return }
                if let maskPath = ProcessInfo.processInfo.environment["JIPIN_IDPHOTO_MASK_PATH"] {
                    let facePath = ProcessInfo.processInfo.environment["JIPIN_IDPHOTO_FACES_PATH"]
                    let template = selectedTemplate
                    let loaded = try await Task.detached(priority: .userInitiated) {
                        let mask = try Data(contentsOf: URL(fileURLWithPath: maskPath))
                        let regions: [IDPhotoFaceRegion]
                        if let facePath {
                            regions = try JSONDecoder().decode([IDPhotoFaceRegion].self, from: Data(contentsOf: URL(fileURLWithPath: facePath)))
                        } else { regions = [] }
                        let project = IDPhotoProject(name: "证件照测试样本", template: template)
                        try IDPhotoDraftStore.shared.save(project: project, sourceData: data, maskData: mask,
                                                          faceRegions: regions, algorithmVersion: "debug-explicit-fixture")
                        return try IDPhotoDraftStore.shared.load(id: project.id)
                    }.value
                    guard !Task.isCancelled else { return }
                    let editor = IDPhotoSession(draft: loaded)
                    session = editor; editor.start(reanalyze: false)
                } else {
                    let editor = IDPhotoSession(sourceData: data, template: selectedTemplate)
                    session = editor; editor.start()
                }
            } catch { errorMessage = "调试样本读取失败：\(error.localizedDescription)" }
        }
    }
    #endif
}

struct IDPhotoDraftThumbnail: View {
    let path: URL?
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "person.crop.rectangle").font(.title2).foregroundStyle(.secondary) }
        }.frame(width: 48, height: 64)
            .task(id: path) {
                let file = path
                image = await Task.detached(priority: .utility) { file.flatMap { UIImage(contentsOfFile: $0.path) } }.value
            }
    }
}

struct IDPhotoTemplateGrid: View {
    let selection: IDPhotoTemplate
    let select: (IDPhotoTemplate) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(IDPhotoTemplateCatalog.all) { template in
                Button { select(template) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(template.title).font(.headline)
                            Spacer(minLength: 3)
                            if selection.id == template.id { Image(systemName: "checkmark.circle.fill") }
                        }
                        Text("\(template.widthMM, specifier: "%.0f") × \(template.heightMM, specifier: "%.0f") mm")
                            .font(.subheadline)
                        Text("\(template.width) × \(template.height) px").font(.caption).foregroundStyle(.secondary)
                    }.foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(selection.id == template.id ? JiPinTheme.accent.opacity(0.12) : JiPinTheme.surface,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selection.id == template.id ? JiPinTheme.accent : .clear, lineWidth: 2))
                }.buttonStyle(.plain).accessibilityIdentifier("idphoto-template-\(template.id)")
                    .accessibilityAddTraits(selection.id == template.id ? [.isSelected] : [])
            }
        }
    }
}

struct IDPhotoCustomSizeView: View {
    @Environment(\.dismiss) private var dismiss
    let template: IDPhotoTemplate
    let onSelect: (IDPhotoTemplate) -> Void
    @State private var width = ""
    @State private var height = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("按办理页面的像素要求输入") {
                    HStack {
                        Text("宽度")
                        TextField("像素", text: $width).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("宽度，像素").accessibilityIdentifier("idphoto-custom-width")
                        Text("px").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("高度")
                        TextField("像素", text: $height).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("高度，像素").accessibilityIdentifier("idphoto-custom-height")
                        Text("px").foregroundStyle(.secondary)
                    }
                    Text("每边 100–2048 px，总像素不超过 400 万。导出保持输入像素，不会擅自放大。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("idphoto-custom-error") }
                }
            }.navigationTitle("自定义尺寸").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("使用") {
                            guard let w = Int(width), let h = Int(height) else { error = "请输入整数像素。"; return }
                            do { onSelect(try IDPhotoTemplate.custom(width: w, height: h)); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.accessibilityIdentifier("idphoto-custom-apply")
                    }
                }
        }.onAppear { width = "\(template.width)"; height = "\(template.height)" }
    }
}
