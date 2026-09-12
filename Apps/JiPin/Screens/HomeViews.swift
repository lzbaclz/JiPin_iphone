import PhotosUI
import SwiftUI
import JiPinCore

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var didInitialize = false
    @State private var launchError: String?

    var body: some View {
        Group {
            if let editor = appState.editor {
                EditorView(session: editor) {
                    appState.closeEditor()
                }
                .id(editor.project.id)
            } else {
                mainTabs
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $appState.showIDPhoto) {
            IDPhotoEntryView { appState.showIDPhoto = false }
        }
        .fullScreenCover(item: $appState.quickCollage) { launch in
            QuickCollageView(
                photos: launch.photos,
                failed: launch.failed,
                overflowCount: launch.overflowCount,
                onCancel: { appState.quickCollage = nil },
                onFinish: { appState.quickCollage = nil }
            )
        }
        .sheet(item: $appState.modePickerLaunch) { launch in
            ModePickerSheet(photos: launch.photos) { mode, layoutID, posterID, photos in
                appState.modePickerLaunch = nil
                let session = EditorSession(
                    project: ProjectFactory.make(mode: mode, photos: photos, layoutID: layoutID, posterID: posterID),
                    assets: AssetLibrary(photos: photos)
                )
                appState.openEditor(session)
                Task { await session.persistNow() }
            }
        }
        .alert("示例未能打开", isPresented: Binding(get: { launchError != nil }, set: { if !$0 { launchError = nil } })) {
            Button("好") { launchError = nil }
        } message: { Text(launchError ?? "") }
        .onAppear {
            guard !didInitialize else { return }
            didInitialize = true
            try? appState.drafts.prepare()
            openLiveSampleIfNeeded()
            openSampleEditorIfNeeded()
            openQuickCollageIfNeeded()
            openSampleModePickerIfNeeded()
            openSettingsIfNeeded()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-idPhotoSample") {
                appState.showIDPhoto = true
            }
            #endif
        }
    }

    private func openLiveSampleIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-sampleLiveEditor") || args.contains("-quickLiveCollage") else { return }
        Task {
            do {
                var photos = try await LivePhotoSamples.make(count: args.contains("-mixedLiveSample") ? 3 : 2)
                if args.contains("-mixedLiveSample") { photos += SamplePhotos.make(2) }
                if args.contains("-quickLiveCollage") {
                    appState.quickCollage = QuickCollageLaunch(photos: photos, failed: [], overflowCount: 0)
                } else {
                    let mode = args.firstIndex(of: "-sampleMode").flatMap { index in
                        index + 1 < args.count ? CollageMode(rawValue: args[index + 1]) : nil
                    } ?? .template
                    let session = EditorSession(project: ProjectFactory.make(mode: mode, photos: photos), assets: AssetLibrary(photos: photos))
                    session.project.name = "会动的小日常"
                    session.activeTool = .livePhoto
                    appState.openEditor(session)
                }
            } catch { launchError = error.localizedDescription }
        }
    }

    private func openSampleEditorIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-sampleEditor") else { return }
        var mode = CollageMode.template
        if let index = args.firstIndex(of: "-sampleMode"), index + 1 < args.count,
           let parsed = CollageMode(rawValue: args[index + 1]) {
            mode = parsed
        }
        let count: Int
        switch mode {
        case .template, .freeform, .longStrip: count = 4
        case .poster: count = 3
        }
        let photos = SamplePhotos.make(count)
        let sampleLayout = args.firstIndex(of: "-sampleLayout").flatMap { index in
            index + 1 < args.count ? args[index + 1] : nil
        }
        appState.openEditor(
            EditorSession(
                project: ProjectFactory.make(mode: mode, photos: photos, layoutID: sampleLayout),
                assets: AssetLibrary(photos: photos)
            )
        )
    }

    private func openQuickCollageIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-quickCollage") else { return }
        var count = 4
        var overflow = 0
        var failed: [ImportedPhoto] = []
        if args.contains("-quickCollageTooFew") { count = 1 }
        if args.contains("-quickCollageOverflow") { overflow = 3 }
        if args.contains("-quickCollageFailed") {
            failed = [
                ImportedPhoto(
                    filename: "云端照片",
                    data: Data(),
                    pixelSize: .zero,
                    utType: "public.image",
                    loadFailed: true,
                    failureReason: "这张照片尚未下载到本机。请等待系统下载完成后重试。"
                )
            ]
        }
        appState.quickCollage = QuickCollageLaunch(
            photos: SamplePhotos.make(count),
            failed: failed,
            overflowCount: overflow
        )
    }

    private func openSampleModePickerIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-sampleModePicker") else { return }
        var count = 4
        if let index = args.firstIndex(of: "-samplePhotoCount"), index + 1 < args.count,
           let parsed = Int(args[index + 1]) {
            count = parsed
        }
        appState.modePickerLaunch = ModePickerLaunch(
            photos: count > 0 ? SamplePhotos.make(count) : []
        )
    }

    private func openSettingsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-showSettings") else { return }
        appState.showSettings = true
    }

    private var mainTabs: some View {
        TabView(selection: $appState.selectedTab) {
            CreateHomeView()
                .tabItem { Label("创作", systemImage: "plus.square.on.square") }
                .tag(AppState.AppTab.create)
            DraftsView()
                .tabItem { Label("草稿", systemImage: "rectangle.stack") }
                .tag(AppState.AppTab.drafts)
        }
    }
}

struct CreateHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var lastPickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var failedPhotos: [ImportedPhoto] = []
    @State private var imported: [ImportedPhoto] = []
    @State private var showModePicker = false
    @State private var presetMode: CollageMode?
    @State private var loadError: String?
    @State private var pendingLayoutID: String?
    @State private var pendingPosterID: String?
    @State private var showPhotoPicker = false
    @State private var importTask: Task<Void, Never>?
    @State private var importID = UUID()
    @State private var importedCount = 0
    @State private var importingCount = 0
    @State private var sampleProgress: Double?
    @State private var pickingLiveOnly = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Button { beginPick(mode: nil) } label: {
                        Label("选择照片", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(JiPinTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .accessibilityIdentifier("home-pick-photos")
                    Button {
                        imported = SamplePhotos.make(4)
                        presetMode = nil
                        showModePicker = true
                    } label: {
                        Label("用示例插画体验", systemImage: "sparkles.rectangle.stack")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .foregroundStyle(JiPinTheme.ink)
                    }
                    .accessibilityHint("使用内置原创插画，无需打开相册即可试用四种模式")

                    Text("拼图模式")
                        .font(.title3.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(CollageMode.allCases) { mode in
                            Button {
                                beginPick(mode: mode)
                            } label: {
                                modeCard(mode)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Image(systemName: "livephoto").font(.system(size: 38, weight: .light))
                                .foregroundStyle(JiPinTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("回忆，可以一起动").font(.title3.weight(.semibold))
                                Text("Live 照片拼图 · 保存后在相册长按播放")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Button("选择 Live 照片") { beginPick(mode: nil, liveOnly: true) }
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("home-pick-live")
                            Button("试试动态示例") { openLiveSample() }
                                .buttonStyle(.bordered).accessibilityIdentifier("home-try-live")
                        }
                        Text("每份最多 9 张 Live；与普通照片混拼请用上方「选择照片」。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 20))

                    Button {
                        let photos = SamplePhotos.make(4)
                        let session = EditorSession(project: StyleRecipeCatalog.all[0].applying(to: ProjectFactory.make(mode: .freeform, photos: photos)),
                                                    assets: AssetLibrary(photos: photos))
                        session.project.name = "我的贴纸日记"
                        session.addSticker("cute-bunny")
                        session.setDecorationFrame(DecorationFrameCatalog.all[0])
                        session.activeTool = .sticker
                        appState.openEditor(session)
                    } label: {
                        HStack(spacing: 16) {
                            Image(uiImage: StudioPreviewCache.sticker(StickerCatalog.sticker(id: "cute-bunny")!))
                                .resizable().scaledToFit().frame(width: 74, height: 74)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("把小可爱，贴进日常").font(.headline)
                                Text("\(OriginalStickerArt.names.count) 个原创贴图 · 6 款可爱边框").font(.caption).foregroundStyle(.secondary)
                                Text("试贴一下 →").font(.subheadline.weight(.semibold)).foregroundStyle(JiPinTheme.accent)
                            }
                            Spacer(minLength: 0)
                        }.padding(16).foregroundStyle(JiPinTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).accessibilityIdentifier("home-try-stickers")
                        .accessibilityHint("打开可编辑的示例插画拼图，可替换为自己的照片")

                    Button { appState.showIDPhoto = true } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 34)).foregroundStyle(JiPinTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("证件照").font(.headline)
                                Text("常用尺寸 · 五色换底 · 自然轻修")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("制作照片或继续证件照草稿 →")
                                    .font(.caption).foregroundStyle(JiPinTheme.accent)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).accessibilityIdentifier("idphoto-open")
                    favoritesSection
                    recentDrafts
                }
                .padding()
            }
            .background(JiPinTheme.canvas.ignoresSafeArea())
            .navigationTitle("极拼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appState.showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showModePicker) {
                ModePickerSheet(
                    photos: imported,
                    preset: presetMode,
                    preferredLayoutID: pendingLayoutID,
                    preferredPosterID: pendingPosterID
                ) { mode, layoutID, posterID, chosen in
                    startEditor(mode: mode, layoutID: layoutID, posterID: posterID, photos: chosen)
                }
            }
            .alert("有照片未能导入", isPresented: Binding(
                get: { !failedPhotos.isEmpty },
                set: { if !$0 { failedPhotos = [] } }
            )) {
                Button("继续已成功的照片") { showModePicker = !imported.isEmpty }
                Button("重试") {
                    beginImport(lastPickerItems)
                }
                Button("取消", role: .cancel) {
                    imported = []
                    failedPhotos = []
                }
            } message: {
                Text(
                    failedPhotos.map { $0.failureReason ?? $0.filename }.joined(separator: "\n")
                    + "\n不会静默少一张。iCloud 原图未在本机时会等待下载；仍失败请联网后点重试。"
                )
            }
            .alert("无法开始", isPresented: Binding(
                get: { loadError != nil },
                set: { if !$0 { loadError = nil } }
            )) {
                Button("好", role: .cancel) { loadError = nil }
            } message: {
                Text(loadError ?? "")
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView(value: sampleProgress ?? Double(importedCount) / Double(max(importingCount, 1)))
                            Text(sampleProgress.map { "正在准备本地示例 \(Int($0 * 100))%" }
                                 ?? "正在导入照片 \(importedCount)/\(importingCount)")
                                .font(.headline)
                            Text(sampleProgress == nil ? "云端原图可能需要下载，请稍候。" : "示例已随 App 保存，无需联网。")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("取消导入", action: cancelImport)
                                .accessibilityIdentifier("cancel-import")
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: 300)
                    }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItems,
                          maxSelectionCount: pickingLiveOnly ? LivePhotoPolicy.maxSources : (presetMode.map { PhotoLimits.range(for: $0).upperBound } ?? PhotoLimits.pickerWithoutMode),
                          selectionBehavior: .ordered, matching: pickingLiveOnly ? .livePhotos : PhotoImporter.stillImages)
            .onChange(of: pickerItems) { _, items in beginImport(items) }
            .onDisappear { importTask?.cancel() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("把多张照片做成一张图")
                .font(.title2.weight(.bold))
            Text("选照片，挑效果，保存到相册。无需登录。")
                .foregroundStyle(JiPinTheme.muted)
        }
    }

    private func modeCard(_ mode: CollageMode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: mode.systemImage)
                .font(.title2)
                .foregroundStyle(JiPinTheme.accent)
            Text(mode.title).font(.headline)
            Text(mode.subtitle).font(.caption).foregroundStyle(JiPinTheme.muted)
            Text("\(PhotoLimits.range(for: mode).lowerBound)–\(PhotoLimits.range(for: mode).upperBound) 张")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(JiPinTheme.accent.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(JiPinTheme.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title)，\(mode.subtitle)，\(PhotoLimits.range(for: mode).lowerBound)到\(PhotoLimits.range(for: mode).upperBound)张")
        .accessibilityIdentifier("mode-\(mode.rawValue)")
        .accessibilityAddTraits(.isButton)
    }

    private var recentDrafts: some View {
        let drafts = appState.drafts.listDrafts().prefix(4)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近草稿").font(.title3.weight(.semibold))
                Spacer()
                Button("全部") { appState.selectedTab = .drafts }
            }
            if drafts.isEmpty {
                Text("还没有草稿。选几张照片开始即可自动保存。")
                    .foregroundStyle(JiPinTheme.muted)
            } else {
                ForEach(Array(drafts)) { draft in
                    DraftRow(summary: draft) {
                        openDraft(draft.id)
                    }
                }
            }
        }
    }

    private var favoritesSection: some View {
        let layouts = appState.favorites.templates.compactMap(CollageGridLayoutCatalog.layout(id:))
        let posters = appState.favorites.posters.compactMap(PosterTemplateCatalog.template(id:))
        let stickers = appState.favorites.stickers.compactMap(StickerCatalog.sticker(id:))
        return VStack(alignment: .leading, spacing: 12) {
            Text("收藏").font(.title3.weight(.semibold))
            if layouts.isEmpty && posters.isEmpty && stickers.isEmpty {
                Text("在编辑器里点星号即可收藏布局、海报和贴纸，之后从这里继续用。")
                    .foregroundStyle(JiPinTheme.muted)
            } else {
                if !layouts.isEmpty {
                    Text("布局").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(layouts) { layout in
                                Button {
                                    beginPick(mode: .template, layoutID: layout.id)
                                } label: {
                                    VStack {
                                        LayoutThumb(layout: layout)
                                            .frame(width: 64, height: 64)
                                        Text(layout.name).font(.caption2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("收藏的布局 \(layout.name)，需要 \(layout.photoCount) 张照片")
                            }
                        }
                    }
                }
                if !posters.isEmpty {
                    Text("海报").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(posters) { poster in
                                Button {
                                    beginPick(mode: .poster, posterID: poster.id)
                                } label: {
                                    VStack {
                                        PosterThumb(poster: poster)
                                            .frame(width: 48, height: 64)
                                        Text(poster.name).font(.caption2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("收藏的海报 \(poster.name)，需要 \(poster.photoCount) 张照片")
                            }
                        }
                    }
                }
                if !stickers.isEmpty {
                    Text("贴纸").font(.caption).foregroundStyle(.secondary)
                    Text(stickers.map(\.name).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(JiPinTheme.muted)
                }
            }
        }
    }

    private func beginPick(mode: CollageMode?, layoutID: String? = nil, posterID: String? = nil, liveOnly: Bool = false) {
        pickingLiveOnly = liveOnly
        presetMode = mode
        pendingLayoutID = layoutID
        pendingPosterID = posterID
        showPhotoPicker = true
    }

    private func openLiveSample() {
        guard !isLoading else { return }
        isLoading = true
        sampleProgress = 0
        importedCount = 0; importingCount = 2
        let request = UUID(); importID = request
        importTask = Task {
            do {
                let photos = try await LivePhotoSamples.make { value in
                    await MainActor.run { if importID == request { sampleProgress = value } }
                }
                guard !Task.isCancelled, importID == request else { return }
                isLoading = false
                let session = EditorSession(project: ProjectFactory.make(mode: .template, photos: photos), assets: AssetLibrary(photos: photos))
                session.project.name = "会动的小日常"
                session.activeTool = .livePhoto
                appState.openEditor(session)
                Task { await session.persistNow() }
            } catch {
                guard importID == request else { return }
                isLoading = false
                if !(error is CancellationError) { loadError = error.localizedDescription }
            }
        }
    }

    private func cancelImport() {
        importTask?.cancel()
        importID = UUID()
        isLoading = false
        sampleProgress = nil
        pickerItems = []
        imported = []
        failedPhotos = []
    }

    private func beginImport(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        sampleProgress = nil
        importTask?.cancel()
        let request = UUID()
        importID = request
        lastPickerItems = items
        failedPhotos = []
        importedCount = 0
        importingCount = items.count
        isLoading = true
        importTask = Task {
            let result = await PhotoImporter.load(items) { done, _ in
                if importID == request { importedCount = done }
            }
            guard !Task.isCancelled, importID == request else { return }
            imported = result.ok
            failedPhotos = result.failed
            isLoading = false
            pickerItems = []
            if failedPhotos.isEmpty && !imported.isEmpty { showModePicker = true }
        }
    }

    private func startEditor(mode: CollageMode, layoutID: String?, posterID: String?, photos: [ImportedPhoto]) {
        let session = EditorSession(
            project: ProjectFactory.make(mode: mode, photos: photos, layoutID: layoutID, posterID: posterID),
            assets: AssetLibrary(photos: photos)
        )
        showModePicker = false
        imported = []
        presetMode = nil
        pendingLayoutID = nil
        pendingPosterID = nil
        appState.openEditor(session)
        Task { await session.persistNow() }
    }

    private func openDraft(_ id: UUID) {
        do {
            let loaded = try appState.drafts.load(id: id)
            let session = EditorSession(
                project: loaded.project,
                assets: AssetLibrary(images: loaded.assets, motions: loaded.motions)
            )
            appState.openEditor(session)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct DraftsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var drafts: [DraftSummary] = []
    @State private var renameTarget: DraftSummary?
    @State private var renameText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty {
                    ContentUnavailableView("没有草稿", systemImage: "rectangle.stack", description: Text("创作页开始的拼图会自动保存在这里。"))
                } else {
                    List {
                        ForEach(drafts) { draft in
                            DraftRow(summary: draft) {
                                open(draft.id)
                            }
                            .swipeActions {
                                Button("复制") { duplicate(draft.id) }
                                Button("重命名") {
                                    renameTarget = draft
                                    renameText = draft.name
                                }
                                Button("删除", role: .destructive) { delete(draft) }
                            }
                            .contextMenu {
                                Button("继续编辑") { open(draft.id) }
                                Button("复制") { duplicate(draft.id) }
                                Button("重命名") {
                                    renameTarget = draft
                                    renameText = draft.name
                                }
                                Button("删除", role: .destructive) { delete(draft) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("草稿")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appState.showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .onAppear { reload() }
            .alert("删除草稿", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("删除项目", role: .destructive) {
                    if let id = deleteCandidate?.id {
                        do { try appState.drafts.delete(id: id); reload() }
                        catch { errorMessage = error.localizedDescription }
                    }
                    deleteCandidate = nil
                }
                Button("取消", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("将删除“\(deleteCandidate?.name ?? "")”。仅当没有其他草稿再引用这些照片时，才会回收对应素材。已保存到系统相册的成品不会被删除。")
            }
            .alert("重命名", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("名称", text: $renameText)
                Button("保存") {
                    if let id = renameTarget?.id {
                        do { try appState.drafts.rename(id: id, to: renameText); reload() }
                        catch { errorMessage = error.localizedDescription }
                    }
                    renameTarget = nil
                }
                Button("取消", role: .cancel) { renameTarget = nil }
            }
            .alert("草稿操作未完成", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @State private var deleteCandidate: DraftSummary?

    private func reload() {
        drafts = appState.drafts.listDrafts()
    }

    private func open(_ id: UUID) {
        do {
            let loaded = try appState.drafts.load(id: id)
            appState.openEditor(EditorSession(project: loaded.project, assets: AssetLibrary(images: loaded.assets, motions: loaded.motions)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func duplicate(_ id: UUID) {
        do { _ = try appState.drafts.duplicate(id: id); reload() }
        catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ draft: DraftSummary) {
        deleteCandidate = draft
    }
}

struct DraftRow: View {
    let summary: DraftSummary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name).font(.headline).foregroundStyle(JiPinTheme.ink)
                    Text("\(summary.mode.title) · \(summary.photoCount) 张")
                        .font(.caption)
                        .foregroundStyle(JiPinTheme.muted)
                    if summary.originatedFromExtension {
                        Text("来自相册")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(JiPinTheme.accent.opacity(0.16), in: Capsule())
                            .foregroundStyle(JiPinTheme.accent)
                            .accessibilityLabel("来自系统相册扩展")
                    }
                    Text(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(byteText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts = [summary.name, summary.mode.title, "\(summary.photoCount)张"]
        if summary.originatedFromExtension { parts.append("来自相册") }
        return parts.joined(separator: "，")
    }

    private var thumbnail: some View {
        Group {
            if let url = summary.thumbnailPath, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                JiPinTheme.accent.opacity(0.15)
                    .overlay(Image(systemName: summary.mode.systemImage))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var byteText: String {
        ByteCountFormatter.string(fromByteCount: summary.byteSize, countStyle: .file)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let store = DraftStore.shared
    @State private var draftsSize: Int64 = 0
    @State private var cacheSize: Int64 = 0
    @State private var storageMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("使用说明") {
                    Text("从创作页选择照片，或在系统相册多选后通过分享菜单中的操作区打开极拼。扩展支持 2–9 张快速拼图；完整文字、贴纸、海报和超过 9 张的编辑请在主 App 中继续。")
                    Text("相册入口出现在系统分享菜单的操作区域，不是相册原生工具栏。是否显示取决于所选内容数量。")
                }
                Section("相册入口帮助") {
                    Text("1. 在系统「照片」中多选 2 到 9 张。")
                    Text("2. 点分享，在操作区选择「极拼」。主 App 不必先打开。")
                    Text("3. 扩展内可模板拼图、横竖长图、排序、裁切、背景和间距。")
                    Text("4. 保存到相册，或点「更多」保存草稿后到极拼草稿页继续。也可以直接系统分享，不必先保存到相册。取消不会改已有草稿。拒绝添加照片权限时项目仍可保存为草稿或改用分享。")
                    if store.isUsingAppGroup {
                        Text("当前安装已配置相册草稿共享。保存后可在极拼的草稿页继续编辑。")
                    } else {
                        Text("当前安装仅支持 App 内的本地草稿。相册草稿交接需要使用启用了该功能的安装包。")
                    }
                }
                Section("存储") {
                    LabeledContent("草稿占用", value: ByteCountFormatter.string(fromByteCount: draftsSize, countStyle: .file))
                    LabeledContent("导出缓存", value: ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file))
                    Button("清理导出缓存") {
                        do { try store.clearExportCache(); reload(); storageMessage = "导出缓存已清理，草稿和相册成品保留。" }
                        catch { storageMessage = "清理失败：\(error.localizedDescription)" }
                    }
                    Text("清理缓存不会删除草稿，也不会删除已经保存到系统相册的成品。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("隐私") {
                    Text("核心编辑、素材和草稿都在本机处理，首版不上传照片，也不接入账号、广告或行为分析。保存到相册时才会申请添加照片权限。导出成品不复制原图 GPS 等隐私元数据。")
                    NavigationLink("隐私政策") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("支持与帮助") {
                        SupportView()
                    }
                }
                Section("版本") {
                    LabeledContent("极拼", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("构建", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { reload() }
            .alert("存储", isPresented: Binding(get: { storageMessage != nil }, set: { if !$0 { storageMessage = nil } })) {
                Button("好", role: .cancel) { storageMessage = nil }
            } message: { Text(storageMessage ?? "") }
        }
    }

    private func reload() {
        draftsSize = store.draftsSize()
        cacheSize = store.cacheSize()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("极拼只在你的设备上处理照片、文字、贴纸和草稿。首版不注册账号、不上传照片、不接入广告或行为分析。")
                Text("从系统相册导入时使用系统选择器，不要求读取整个图库。只有你选择保存到相册时才会申请「添加照片」权限。权限被拒绝后，项目仍保留，可用系统分享或存储到文件。")
                Text("主 App 与相册操作扩展只在你保存图片时申请相应权限。相册扩展可通过本机共享存储交接草稿；安装包不支持交接时会明确提示，并可改用保存图片或系统分享。")
                Text("支持静态图片与原生 Live Photo 导出，不加默认品牌水印。新生成的图片和视频不复制原图的 GPS 等位置元数据。")
                Text("证件照使用 Apple 系统能力在本机定位人物和五官，仅用于构图、换底与保护五官的轻修，不识别个人身份。原片工作副本、人物轮廓及五官位置随证件照草稿保存在本机，不上传服务器；删除该草稿会一并删除这些文件。")
                Text("草稿和工作副本保存在本机并排除云备份。静态工作图去除元数据并限制解码尺寸；Live 草稿还会保存所选动态视频的本机副本，其中可能包含原始元数据和声音，仅供编辑使用。系统相册原图保持不变。删除最后一份引用素材的草稿后会回收共享文件；清理导出缓存不会删除草稿或相册成品。卸载应用会删除本机草稿。")
                Text("极拼面向一般用户，不专为儿童设计，也不收集年龄或联系方式。如需了解相册入口，请查看设置中的支持与帮助。")
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SupportView: View {
    var body: some View {
        List {
            Section("从相册进入") {
                Text("在系统「照片」中多选 2 到 9 张，点分享，在操作区选择「极拼」。不必先打开主 App。")
                Text("扩展内可做模板拼图、横竖长图、排序、裁切、背景和间距。文字、贴纸和海报请保存草稿后到主 App 继续。")
            }
            Section("Live 照片拼图") {
                Text("选择 Live 照片后会保留动态，最多 9 张，可与普通照片混拼。选择 1.5、2 或 3 秒，默认静音，也可保留其中一张的原声。布局、裁切、滤镜和装饰会应用到动态。")
                Text("导出时先生成预览，再点「保存 Live 到相册」。在系统相册长按播放。分享视频会发送 MOV 文件；需要分享 Live 时，请保存后从系统相册分享。")
                Text("从相册扩展进入时先保存 Live 草稿，再回极拼的草稿页导出动态。若分享方只提供了静态图片，极拼无法恢复原本的动态。")
            }
            Section("保存与权限") {
                Text("保存到相册才会申请添加照片权限。拒绝后仍可保存草稿，或用系统分享、存储到文件。")
                Text("取消快拼不会修改已有草稿。相册扩展提示交接成功后，请到极拼的草稿页继续；不支持交接的安装包会明确提示。")
            }
            Section("证件照") {
                Text("首页打开「证件照」，选择常用尺寸或自定义像素，导入一张单人照片。可选白、红、蓝、蓝白渐变或浅灰底色，亮度、轻磨皮和色温默认关闭。")
                Text("发丝或衣领边缘不理想时，可放大后使用擦除／恢复修边。完成后按所选像素保存高质量 JPEG；证件照草稿在该工具内继续编辑。Live 照片只使用静态画面。")
                Text("用于正式证件或考试时，以办理方要求为准；部分用途不允许换底或美颜。")
            }
            Section("草稿与素材") {
                Text("编辑后约 0.5 秒自动保存。删除草稿前会说明将删除该项目。收藏的布局、海报和贴纸只存在本机，无需登录。")
                Text("导出缓存可随时清理，不会动草稿和已经保存到相册的成品。")
            }
        }
        .navigationTitle("支持与帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}
