import SwiftUI
import JiPinCore

struct IDPhotoCustomSpecification {
    let template: IDPhotoTemplate
    let byteLimit: Int?
    let preservesOriginal: Bool
}

struct IDPhotoCustomSizeView: View {
    private enum Field: Hashable { case width, height, name, limit }
    @Environment(\.dismiss) private var dismiss
    let template: IDPhotoTemplate
    var byteLimit: Int? = nil
    var preservesOriginal = false
    let onSelect: (IDPhotoCustomSpecification) -> Void
    @State private var name = ""
    @State private var width = ""
    @State private var height = ""
    @State private var limitKB = ""
    @State private var keepOriginal = false
    @State private var error: String?
    @State private var initialized = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    dimension("宽度", value: $width, identifier: "idphoto-custom-width", field: .width)
                    dimension("高度", value: $height, identifier: "idphoto-custom-height", field: .height)
                    Button("填写 285 × 385 px／小于 1 MB") {
                        width = "285"; height = "385"; name = "报名一寸"
                        limitKB = "1000"; keepOriginal = true; error = nil
                    }.accessibilityIdentifier("idphoto-custom-example-285")
                } header: {
                    Text("按网站要求输入像素")
                } footer: {
                    Text("以网站明确要求的像素为准。填写后，高清和压缩均保持此宽高，不会自动放大。每边 100–2048 px，总像素不超过 400 万。")
                }
                Section {
                    TextField("例如：自定义一寸、二寸报名照", text: $name)
                        .focused($focusedField, equals: .name).submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .accessibilityLabel("规格名称").accessibilityIdentifier("idphoto-custom-name")
                } header: {
                    Text("名称（可选）")
                } footer: {
                    Text("名称用于区分用途，实际输出由填写的宽高决定。")
                }
                Section {
                    HStack {
                        Text("文件大小小于")
                        TextField("不限制", text: $limitKB).keyboardType(.numberPad)
                            .focused($focusedField, equals: .limit)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("文件上限，KB").accessibilityIdentifier("idphoto-custom-byte-limit")
                        Text("KB").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("文件上限（可选）")
                } footer: {
                    Text("留空不限制；1000 KB 按 1 MB 控制。设置后优先满足上限，必要时降低 JPEG 压缩质量，像素保持不变。")
                }
                Section {
                    Toggle("保留原背景并关闭轻修", isOn: $keepOriginal)
                        .accessibilityIdentifier("idphoto-custom-original")
                } footer: {
                    Text("如果网站要求不得修饰，请使用原本符合要求的白底、免冠原片。此选项关闭换底和轻修，仅保留尺寸与构图调整；不会判断照片是否满足其他报名条件。")
                }
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("idphoto-custom-error")
                            .padding().frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial)
                    }
                }
                .navigationTitle("自定义尺寸").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成输入") { focusedField = nil }
                            .accessibilityIdentifier("idphoto-custom-keyboard-done")
                    }
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("使用", action: apply).accessibilityIdentifier("idphoto-custom-apply")
                    }
                }
        }.onAppear {
            guard !initialized else { return }
            initialized = true
            width = "\(template.width)"; height = "\(template.height)"
            name = template.isCustom ? template.title : "自定义\(template.title)"
            limitKB = byteLimit.map { String($0 / 1000) } ?? ""
            keepOriginal = preservesOriginal
        }
    }

    private func dimension(_ label: String, value: Binding<String>, identifier: String, field: Field) -> some View {
        HStack {
            Text(label)
            TextField("像素", text: value).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                .accessibilityLabel("\(label)，像素").accessibilityIdentifier(identifier)
            Text("px").foregroundStyle(.secondary)
        }
    }

    private func apply() {
        guard let w = Int(width.trimmingCharacters(in: .whitespacesAndNewlines)), let h = Int(height.trimmingCharacters(in: .whitespacesAndNewlines)) else { error = "请输入整数像素。"; return }
        do {
            let custom = try IDPhotoTemplate.custom(width: w, height: h, title: name)
            let trimmed = limitKB.trimmingCharacters(in: .whitespacesAndNewlines)
            let limit: Int?
            if trimmed.isEmpty { limit = nil }
            else {
                guard let kb = Int(trimmed), (1...20_000).contains(kb) else { throw IDPhotoValidationError.invalidFileLimit }
                limit = kb * 1000
            }
            onSelect(IDPhotoCustomSpecification(template: custom, byteLimit: limit, preservesOriginal: keepOriginal))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
