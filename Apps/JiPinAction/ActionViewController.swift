import SwiftUI
import UniformTypeIdentifiers
import UIKit
import JiPinCore

@objc(ActionViewController)
final class ActionViewController: UIViewController {
    private var host: UIViewController?
    private var loadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setRoot(
            ExtensionLoadingView { [weak self] in
                self?.loadTask?.cancel()
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        loadInput()
    }

    deinit { loadTask?.cancel() }

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
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var items: [(filename: String, data: Data?)] = []
            let accepted = Array(imageProviders.prefix(PhotoLimits.extensionRange.upperBound))
            for (index, provider) in accepted.enumerated() {
                guard !Task.isCancelled else { return }
                let name = provider.suggestedName ?? "照片 \(index + 1)"
                do {
                    items.append((name, try await loadData(provider)))
                } catch {
                    items.append((name, nil))
                }
            }
            let loaded = items
            let ingested = await Task.detached(priority: .userInitiated) { ExtensionIngest.process(loaded) }.value
            guard !Task.isCancelled else { return }
            embed(photos: ingested.photos, failed: ingested.failed, overflowCount: max(imageProviders.count - accepted.count, 0))
        }
    }

    private func loadData(_ provider: NSItemProvider) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do {
                if let data = await loadFile(provider, type: UTType.image.identifier), !data.isEmpty { return data }
                for type in [UTType.jpeg.identifier, UTType.heic.identifier, UTType.png.identifier] where provider.hasItemConformingToTypeIdentifier(type) {
                    if let data = await loadFile(provider, type: type), !data.isEmpty { return data }
                    if let data = try? await loadRepresentation(provider, type: type), !data.isEmpty { return data }
                }
                if let data = await loadFileURL(provider), !data.isEmpty { return data }
                if let data = await loadUIImage(provider), !data.isEmpty { return data }
                return try await loadRepresentation(provider, type: UTType.image.identifier)
            } catch {
                if Task.isCancelled { throw CancellationError() }
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
                continuation.resume(returning: ImageIOHelpers.sanitizedImageData(from: image))
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
