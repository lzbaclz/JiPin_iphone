import SwiftUI
import JiPinCore

struct ProjectThumbnail: View {
    var project: CollageProject
    @ObservedObject var assets: AssetLibrary
    var side: CGFloat = 300
    @State private var image: UIImage?

    var body: some View {
        let size = thumbnailSize
        let request = PreviewRequest(project: project, displaySize: size, displayScale: 1, assetRevision: assets.revision)
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Rectangle().fill(JiPinTheme.canvas).overlay { ProgressView() } }
        }
        .task(id: request) {
            let rendered = await PreviewRendering.shared.render(request, assets: assets.snapshot)
            guard !Task.isCancelled else { return }
            image = rendered
        }
        .accessibilityHidden(true)
    }

    private var thumbnailSize: CGSize {
        guard project.mode == .longStrip else { return project.canvas.size(maxLongSide: side) }
        let full: CGSize
        switch ExportGeometry.outputSize(for: project, assets: assets.snapshot) {
        case .ok(let value), .needsChoice(_, let value): full = value
        }
        let scale = side / max(full.width, full.height, 1)
        return CGSize(width: max(full.width * scale, 2), height: max(full.height * scale, 2))
    }
}

struct StyleTools: View {
    @ObservedObject var session: EditorSession
    @State private var showGallery = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("轻点换个风格").font(.headline)
                Spacer()
                Button("全部 · 我的风格") { showGallery = true }
                    .font(.subheadline).accessibilityIdentifier("style-gallery-open")
            }
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(StyleRecipeCatalog.all) { recipe in
                        Button { session.applyStyle(recipe) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ProjectThumbnail(project: recipe.applying(to: session.project), assets: session.assets, side: 220)
                                    .frame(width: 108, height: 112)
                                    .background(Color(hex: recipe.background.colorHex), in: RoundedRectangle(cornerRadius: 10))
                                Text(recipe.name).font(.caption.weight(.medium))
                            }
                        }.buttonStyle(.plain)
                            .accessibilityLabel("套用\(recipe.name)")
                            .accessibilityIdentifier("style-inline-\(recipe.id)")
                    }
                }
            }
            Text("用你的照片预览 · 套用后可以撤销")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showGallery) { StyleGallery(session: session) }
    }
}

struct StyleGallery: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var saved: [StyleRecipe] = []
    @State private var loaded = false
    @State private var showName = false
    @State private var name = "我的日常风格"
    @State private var error: String?
    @State private var lastSavedID: String?
    private var store: StyleRecipeStore { StyleRecipeStore(directory: session.store.containerURL.appendingPathComponent("StyleRecipes")) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("今天，想拼出什么心情？").font(.title2.bold())
                    Text("用你的照片预览，点一下即可套用。")
                        .foregroundStyle(.secondary)
                    cards(StyleRecipeCatalog.all)
                    HStack {
                        Text("我的风格").font(.title3.bold())
                        Spacer()
                        Button("保存当前搭配") { showName = true }
                            .disabled(!loaded || saved.count >= 30)
                            .accessibilityIdentifier("style-save-current")
                    }.id("personal-styles")
                    if lastSavedID != nil {
                        Text("新风格已保存，点下方预览即可套用。")
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("style-saved-notice")
                    }
                    Text("保存配色、边距、圆角和所选照片效果，不包含照片、文字、装饰与布局。最多保存 30 套。")
                        .font(.caption).foregroundStyle(.secondary)
                    if saved.isEmpty { Text("把喜欢的搭配留下，下次选好照片就能用。").font(.subheadline).foregroundStyle(.secondary) }
                    cards(saved, removable: true)
                }.padding(20)
            }
            .background(JiPinTheme.canvas)
            .onChange(of: lastSavedID) { _, id in
                guard id != nil else { return }
                DispatchQueue.main.async {
                    withAnimation { scroll.scrollTo("personal-styles", anchor: .top) }
                }
            }
            }
            .navigationTitle("风格工作室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
            .task {
                do { saved = try store.load(); loaded = true }
                catch { self.error = "暂时无法读取我的风格：\(error.localizedDescription)" }
            }
            .alert("保存风格", isPresented: $showName) {
                TextField("风格名称", text: $name)
                Button("保存") { saveCurrent() }
                Button("取消", role: .cancel) {}
            }
            .alert("提示", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func cards(_ recipes: [StyleRecipe], removable: Bool = false) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(recipes) { recipe in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        session.applyStyle(recipe)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            ProjectThumbnail(project: recipe.applying(to: session.project), assets: session.assets)
                                .frame(height: 160).frame(maxWidth: .infinity)
                                .background(Color(hex: recipe.background.colorHex))
                            Text(recipe.name).font(.headline)
                            Text(recipe.subtitle).font(.caption).foregroundStyle(.secondary)
                        }.padding(10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("套用\(recipe.name)")
                    .accessibilityIdentifier("style-apply-\(recipe.id)")
                    if removable {
                        Button("删除风格", role: .destructive) {
                            let next = saved.filter { $0.id != recipe.id }
                            do { try store.save(next); saved = next }
                            catch { self.error = "删除失败：\(error.localizedDescription)" }
                        }.font(.caption).padding([.horizontal, .bottom], 12)
                    }
                }
                .background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func saveCurrent() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "请给风格起个名字。"; return }
        let recipe = StyleRecipe(name: trimmed, project: session.project, photo: session.selected?.photo)
        do { let next = [recipe] + saved; try store.save(next); saved = next; lastSavedID = recipe.id }
        catch { self.error = "保存失败：\(error.localizedDescription)" }
    }
}

struct LayoutRecommendationsView: View {
    @ObservedObject var session: EditorSession
    @State private var recommended = true
    @State private var showDividers = false
    @EnvironmentObject private var appState: AppState

    private var ranked: [LayoutRecommendation] {
        let sizes = session.recommendationProject.photoLayers.map { layer -> CGSize in
            guard let photo = layer.photo else { return .zero }
            return LayoutEngine.croppedSize(session.assets.pixelSizes[photo.assetID] ?? .zero, crop: photo.crop)
        }
        return LayoutRecommender.ranked(photoSizes: sizes, canvas: session.recommendationProject.canvas,
                                        spacing: session.recommendationProject.spacing, margin: session.recommendationProject.outerMargin)
    }
    private var layouts: [CollageGridLayout] {
        recommended ? ranked.prefix(3).map(\.layout) : CollageGridLayoutCatalog.layouts(forPhotoCount: session.project.photoOrder.count)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("布局列表", selection: $recommended) {
                    Text("少裁切推荐").tag(true)
                    Text("全部").tag(false)
                }.pickerStyle(.segmented)
                Button("调分隔线") { showDividers = true }
                    .font(.caption).accessibilityIdentifier("layout-dividers-open")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(layouts) { layout in
                        VStack(spacing: 4) {
                            Button { session.changeLayout(layout) } label: {
                                VStack(spacing: 4) {
                                    ProjectThumbnail(project: candidate(layout), assets: session.assets, side: 200)
                                        .frame(width: 94, height: 76)
                                    Text(layout.name).font(.caption2)
                                }.padding(6)
                                    .background(session.project.layoutID == layout.id ? JiPinTheme.accent.opacity(0.15) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityIdentifier("layout-apply-\(layout.id)")
                            Button { appState.favorites.toggleTemplate(layout.id) } label: {
                                Label("收藏", systemImage: appState.favorites.templates.contains(layout.id) ? "star.fill" : "star")
                                    .font(.caption2)
                            }.accessibilityLabel("收藏布局 \(layout.name)")
                        }
                    }
                }
            }
            Text("按横竖比例推荐，保留照片顺序；主体位置可继续手动调整。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showDividers) { DividerEditor(session: session) }
    }
    private func candidate(_ layout: CollageGridLayout) -> CollageProject {
        var project = session.recommendationProject
        project.layoutID = layout.id; project.customLayoutCells = nil
        return project
    }
}

struct DividerEditor: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProjectThumbnail(project: session.project, assets: session.assets, side: 600)
                        .frame(maxWidth: .infinity).frame(height: 280)
                }
                Section("调整分隔线") {
                    ForEach(LayoutDividerEngine.dividers(in: session.project.resolvedGridLayout?.cells ?? [])) { divider in
                        VStack(alignment: .leading) {
                            HStack { Text(divider.title); Spacer(); Text("\(Int(divider.position * 100))%").monospacedDigit() }
                            Slider(value: Binding(get: { divider.position }, set: { session.moveDivider(divider, to: $0) }),
                                   in: divider.lower...divider.upper) { editing in
                                if editing { session.beginGesture() } else { session.endGesture() }
                            }.accessibilityLabel(divider.title).accessibilityIdentifier("divider-\(divider.id)")
                        }
                    }
                    Button("恢复原布局") { session.updateProject { $0.customLayoutCells = nil } }
                        .accessibilityIdentifier("layout-dividers-reset")
                        .disabled(session.project.customLayoutCells == nil)
                }
                Text("同一条线上的格子会一起调整，照片顺序保持不变。关闭后可用撤销恢复。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("分隔线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .onDisappear { session.endGesture() }
        }
    }
}
