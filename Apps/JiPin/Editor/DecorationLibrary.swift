import SwiftUI
import JiPinCore

struct StickerLibrary: View {
    @ObservedObject var session: EditorSession
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var category = StickerCategory.cute
    @State private var query = ""
    @State private var favoritesOnly = false
    @FocusState private var searchFocused: Bool

    private var items: [StickerDefinition] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return StickerCatalog.all.filter { item in
            let matches = query.isEmpty ? item.category == category : item.name.localizedCaseInsensitiveContains(query)
                || item.id.localizedCaseInsensitiveContains(query) || item.category.title.localizedCaseInsensitiveContains(query)
            return matches && (!favoritesOnly || appState.favorites.stickers.contains(item.id))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("把小可爱，贴进日常").font(.title2.bold())
                            Text("16 个甜甜贴图 · 2 个酷感点缀")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(uiImage: StudioPreviewCache.sticker(StickerCatalog.sticker(id: "cute-bunny")!))
                            .resizable().scaledToFit().frame(width: 70, height: 70).accessibilityHidden(true)
                    }
                    TextField("搜索兔、蝴蝶结、星际…", text: $query)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("sticker-library-search")
                        .focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(StickerCategory.allCases) { value in
                                Button(value.title) { category = value; query = "" }
                                    .buttonStyle(.bordered).tint(category == value ? JiPinTheme.accent : .secondary)
                                    .accessibilityIdentifier("sticker-category-\(value.id)")
                            }
                        }
                    }
                    Toggle("只看收藏", isOn: $favoritesOnly).font(.subheadline)
                        .accessibilityIdentifier("sticker-favorites-only")
                    if items.isEmpty {
                        ContentUnavailableView("还没有找到贴纸", systemImage: "magnifyingglass", description: Text("换个关键词，或关闭只看收藏试试。"))
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(items) { item in
                            VStack(spacing: 4) {
                                Button {
                                    session.addSticker(item.id)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 10) {
                                        Image(uiImage: StudioPreviewCache.sticker(item))
                                            .resizable().scaledToFit().frame(height: 94)
                                        Text(item.name).font(.caption.weight(.medium)).foregroundStyle(JiPinTheme.ink)
                                            .lineLimit(2).frame(minHeight: 30)
                                    }.frame(maxWidth: .infinity).padding(.top, 8)
                                }.buttonStyle(.plain).disabled(!session.canAddObject)
                                    .accessibilityLabel("添加\(item.name)")
                                    .accessibilityIdentifier("sticker-add-\(item.id)")
                                Button {
                                    appState.favorites.toggleSticker(item.id)
                                } label: {
                                    Label("收藏", systemImage: appState.favorites.stickers.contains(item.id) ? "star.fill" : "star")
                                        .font(.caption2).padding(8)
                                }.accessibilityLabel("收藏\(item.name)")
                                    .accessibilityValue(appState.favorites.stickers.contains(item.id) ? "已收藏" : "未收藏")
                            }
                            .background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    Text("添加后可移动、缩放、旋转、翻转；从图层中也能找到它。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(18)
            }
            .background(JiPinTheme.canvas)
            .navigationTitle("贴纸册").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }

        }
    }
}

struct FrameGallery: View {
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("给回忆，镶一道温柔的边").font(.title2.bold())
                    Text("6 款原创装饰边框 · 中间保留你的画面")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("不使用装饰边框") { session.setDecorationFrame(nil); dismiss() }
                        .accessibilityIdentifier("frame-remove")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(DecorationFrameCatalog.all) { frame in
                            Button {
                                session.setDecorationFrame(frame)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ProjectThumbnail(project: preview(frame), assets: session.assets, side: 400)
                                        .frame(height: 200).frame(maxWidth: .infinity)
                                    Text(frame.name).font(.headline).foregroundStyle(JiPinTheme.ink)
                                    Text(frame.subtitle).font(.caption).foregroundStyle(.secondary)
                                }.padding(10)
                                    .background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain).accessibilityIdentifier("frame-apply-\(frame.id)")
                                .accessibilityLabel("套用\(frame.name)")
                        }
                    }
                    Text("边框装饰画布边缘，不改变照片位置。套用后可调粗细，也可撤销。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(18)
            }
            .background(JiPinTheme.canvas)
            .navigationTitle("可爱边框").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        }
    }
    private func preview(_ frame: DecorationFrame) -> CollageProject {
        var project = session.project
        project.decorationFrame = CanvasDecoration(frameID: frame.id)
        return project
    }
}
