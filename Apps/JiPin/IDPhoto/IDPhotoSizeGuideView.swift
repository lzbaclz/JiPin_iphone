import SwiftUI
import JiPinCore

struct IDPhotoSizeGuideButton: View {
    let selection: IDPhotoTemplate
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            Label("尺寸对比", systemImage: "ruler")
                .font(.subheadline)
        }.buttonStyle(.borderless).accessibilityIdentifier("idphoto-size-guide")
            .sheet(isPresented: $isPresented) {
                IDPhotoSizeGuideView(selection: selection)
            }
    }
}

struct IDPhotoSizeGuideView: View {
    @Environment(\.dismiss) private var dismiss
    let selection: IDPhotoTemplate

    private var comparison: [IDPhotoTemplate] {
        IDPhotoTemplateCatalog.all.filter { $0.id == "id-25x35" || $0.id == "id-35x49" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("一寸、二寸有多大？").font(.title2.bold())
                    VStack(alignment: .leading, spacing: 14) {
                        Text("按同一比例比较").font(.headline)
                        GeometryReader { proxy in
                            let largestWidth = comparison.map(\.widthMM).max() ?? 35
                            let largestHeight = comparison.map(\.heightMM).max() ?? 49
                            let scale = max(0, min((Double(proxy.size.width) - 36) / (largestWidth * 2),
                                                   Double(proxy.size.height) / largestHeight))
                            HStack(alignment: .bottom, spacing: 36) {
                                ForEach(comparison) { template in
                                    portrait(template, scale: scale)
                                }
                            }.frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                        }.frame(height: 180)
                        Text("示意图用于比较大小，不代表屏幕上的实际厘米数。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(18).background(JiPinTheme.surface, in: RoundedRectangle(cornerRadius: 20))

                    Text("这两种规格的长宽比例都是 5:7。二寸的宽高约为一寸的 1.4 倍，面积约为 2 倍。")
                        .font(.subheadline).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("打印规格").font(.headline)
                        ForEach(IDPhotoTemplateCatalog.all) { template in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(template.title)
                                Spacer(minLength: 8)
                                Text(template.millimeterDescription).monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(JiPinTheme.accent)
                                    .frame(width: 18).opacity(selection.id == template.id ? 1 : 0)
                                    .accessibilityLabel("当前选择").accessibilityHidden(selection.id != template.id)
                            }.font(.subheadline).padding(.vertical, 3)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("为什么预览看起来一样？").font(.headline)
                        Text("预览会把照片缩放到适合屏幕的大小，所以同样构图看起来很像。保存文件会使用所选规格和清晰度对应的像素，实际打印时请按毫米尺寸设置。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }.background(JiPinTheme.canvas.ignoresSafeArea())
                .navigationTitle("照片尺寸对比").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }.accessibilityIdentifier("idphoto-size-guide-close")
                    }
                }
        }
    }

    private func portrait(_ template: IDPhotoTemplate, scale: Double) -> some View {
        let selected = selection.id == template.id
        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(selected ? JiPinTheme.accent.opacity(0.12) : JiPinTheme.grouped)
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(selected ? JiPinTheme.accent : JiPinTheme.muted.opacity(0.45), lineWidth: 2)
            VStack(spacing: 8) {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: template.widthMM * scale * 0.3))
                    .foregroundStyle(JiPinTheme.muted)
                Text(template.title).font(.subheadline.weight(.semibold)).minimumScaleFactor(0.7)
            }.padding(8)
        }.frame(width: template.widthMM * scale, height: template.heightMM * scale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(template.title)，\(template.millimeterDescription)")
            .accessibilityIdentifier("idphoto-size-diagram-\(template.id)")
    }
}
