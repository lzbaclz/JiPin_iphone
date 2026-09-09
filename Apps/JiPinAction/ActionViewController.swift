import SwiftUI
import UniformTypeIdentifiers
import UIKit
import JiPinCore

@objc(ActionViewController)
final class ActionViewController: UIViewController {
    private var host: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setRoot(
            ExtensionLoadingView { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        loadInput()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        host?.view.frame = view.bounds
    }

    private func loadInput() {
        var providers: [NSItemProvider] = []
        for item in extensionContext?.inputItems as? [NSExtensionItem] ?? [] {
            providers.append(contentsOf: item.attachments ?? [])
        }
        let imageProviders = providers.filter { ExtensionIngest.isLikelyImageProvider($0) }
        Task { @MainActor in
            var items: [(filename: String, data: Data?)] = []
            for (index, provider) in imageProviders.enumerated() {
                let name = provider.suggestedName ?? "照片 \(index + 1)"
                do {
                    items.append((name, try await loadData(provider)))
                } catch {
                    items.append((name, nil))
                }
            }
            let ingested = ExtensionIngest.process(items)
            embed(photos: ingested.photos, failed: ingested.failed, overflowCount: ingested.overflowCount)
        }
    }

    private func loadData(_ provider: NSItemProvider) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                if let data = await loadUIImage(provider), !data.isEmpty { return data }
                if let data = await loadFile(provider, type: UTType.image.identifier), !data.isEmpty { return data }
                for type in [UTType.jpeg.identifier, UTType.heic.identifier, UTType.png.identifier] where provider.hasItemConformingToTypeIdentifier(type) {
                    if let data = await loadFile(provider, type: type), !data.isEmpty { return data }
                    if let data = try? await loadRepresentation(provider, type: type), !data.isEmpty { return data }
                }
                if let data = await loadFileURL(provider), !data.isEmpty { return data }
                return try await loadRepresentation(provider, type: UTType.image.identifier)
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
            }
        }
        throw lastError ?? URLError(.cannotDecodeContentData)
    }

    private func loadUIImage(_ provider: NSItemProvider) async -> Data? {
        guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else {
                    continuation.resume(returning: nil)
                    return
                }
                var cgImage = image.cgImage
                if cgImage == nil {
                    let format = UIGraphicsImageRendererFormat.default()
                    format.scale = image.scale
                    cgImage = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                        image.draw(in: CGRect(origin: .zero, size: image.size))
                    }.cgImage
                }
                guard let cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ImageIOHelpers.jpegData(from: cgImage, quality: 0.95))
            }
        }
    }

    private func loadFile(_ provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                guard let url, let data = try? Data(contentsOf: url), !data.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func loadFileURL(_ provider: NSItemProvider) async -> Data? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let value = item as? URL {
                    url = value
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                continuation.resume(returning: (try? Data(contentsOf: url)).flatMap { $0.isEmpty ? nil : $0 })
            }
        }
    }

    private func loadRepresentation(_ provider: NSItemProvider, type: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: URLError(.cannotDecodeContentData))
                }
            }
        }
    }

    private func embed(photos: [ImportedPhoto], failed: [ImportedPhoto], overflowCount: Int) {
        setRoot(
            QuickCollageView(
                photos: photos,
                failed: failed,
                overflowCount: overflowCount,
                onCancel: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                },
                onFinish: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            )
        )
    }

    private func setRoot<Content: View>(_ root: Content) {
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()
        let next = UIHostingController(rootView: root)
        addChild(next)
        next.view.frame = view.bounds
        next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(next.view)
        next.didMove(toParent: self)
        host = next
    }
}

private struct ExtensionLoadingView: View {
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView()
                Text("正在导入照片")
                    .font(.headline)
                Text("若原图还在 iCloud，正在等待下载。最多重试 3 次。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("极拼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                        .accessibilityLabel("取消快速拼图")
                        .accessibilityIdentifier("quick-cancel")
                }
            }
        }
    }
}
