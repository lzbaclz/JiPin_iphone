import UIKit
import AVFoundation
import CoreImage
import Photos
import JiPinCore

@main final class ShanheGenerator: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.isIdleTimerDisabled = true
        let view = UIViewController()
        view.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 24, y: 120, width: 330, height: 240))
        label.numberOfLines = 0; label.text = "Generating native landscape Live Photos…"
        view.view.addSubview(label)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = view; window.makeKeyAndVisible(); self.window = window
        Task.detached(priority: .userInitiated) {
            do {
                let message = try await generate()
                await MainActor.run { label.text = message }
            } catch {
                let message = "FAILED: \(error)"
                let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                try? message.write(to: out.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
                await MainActor.run { label.text = message }
            }
        }
        return true
    }
}

private func generate() async throws -> String {
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Shanhe-Web")
    if FileManager.default.fileExists(atPath: folder.appendingPathComponent("SUCCESS.txt").path) { try renderModes(in: folder); return "Native samples validated; static compositions refreshed." }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let names = ["lijiang-karst", "huangshan-clouds", "three-gorges-river"]
    let width: CGFloat = 720, height: CGFloat = 900
    let extent = CGRect(x: 0, y: 0, width: width, height: height)
    let ci = CIContext(options: [.cacheIntermediates: false])
    // Generated stills receive subtle camera motion. Only the Li River water is
    // locally animated; its shoreline stays fixed. This is a synthetic sample,
    // never described as documentary footage or motion captured at these sites.
    let ripple = CIWarpKernel(source: """
    kernel vec2 riverRipple(float w, float h, float phase) {
        vec2 p = destCoord();
        float topY = 1.0 - p.y / h;
        float water = smoothstep(0.552, 0.60, topY);
        float depth = clamp((topY - 0.55) / 0.45, 0.0, 1.0);
        float dx = water * (0.6 + 2.1 * depth) * sin(topY * 205.0 - phase * 2.0 + p.x / w * 5.0);
        float dy = water * depth * 0.55 * sin(topY * 139.0 + phase * 2.0);
        return p + vec2(dx, dy);
    }
    """
    )!
    var photos: [ImportedPhoto] = []
    var report: [[String: Any]] = []
    func keep(_ result: LivePhotoExport, name: String) throws {
        try FileManager.default.copyItem(at: result.imageURL, to: folder.appendingPathComponent("\(name).jpg"))
        try FileManager.default.copyItem(at: result.videoURL, to: folder.appendingPathComponent("\(name).mov"))
        report.append(["name": name, "identifier": result.identifier, "width": result.size.width,
                       "height": result.size.height, "duration": result.duration, "coverTime": result.coverTime,
                       "nativePhotoKitValidated": true])
    }
    for (index, name) in names.enumerated() {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            throw NSError(domain: "Shanhe.MissingResource", code: 1, userInfo: [NSLocalizedDescriptionKey: name])
        }
        let original = CIImage(contentsOf: url)!
        let scale = max(width / original.extent.width, height / original.extent.height)
        let base = original.transformed(by: CGAffineTransform(scaleX: scale, y: scale)).cropped(to: extent)
        let pair = try await LivePhotoWriter.write(size: extent.size, duration: 3) { _, time in
            let phase = time / 3 * Double.pi * 2
            let zoom = 1.014 + 0.004 * sin(phase + Double(index))
            let dx = 2.5 * sin(phase), dy = 1.6 * cos(phase)
            let transform = CGAffineTransform(translationX: width / 2 + dx, y: height / 2 + dy)
                .scaledBy(x: zoom, y: zoom).translatedBy(x: -width / 2, y: -height / 2)
            var frame = base.clampedToExtent().transformed(by: transform)
            if index == 0 {
                frame = ripple.apply(extent: extent, roiCallback: { _, rect in rect.insetBy(dx: -5, dy: -5) },
                                     image: frame, arguments: [width, height, phase])!
            }
            guard let cg = ci.createCGImage(frame, from: extent) else { throw NSError(domain: "Shanhe", code: 1) }
            UIImage(cgImage: cg).draw(in: extent)
        }
        let native = try await LivePhotoMedia.request(imageURL: pair.imageURL, videoURL: pair.videoURL)
        guard native.size == pair.size else { throw NSError(domain: "Shanhe", code: 2) }
        photos.append(try await LivePhotoMedia.importPhoto(native, name: name))
        try keep(pair, name: name)
    }
    let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                 motions: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.liveClip!) }))
    var collage = ProjectFactory.make(mode: .template, photos: photos, layoutID: "g3-left-one")
    collage.canvas = CanvasSpec(aspectWidth: 6, aspectHeight: 5)
    collage.spacing = 0.008; collage.outerMargin = 0
    collage.background = BackgroundSpec(colorHex: "#FFFFFF")
    collage.livePhotoSettings = LivePhotoSettings(duration: 3)
    let result = try await LivePhotoExporter.render(project: collage, assets: assets, maxSide: 1440)
    try keep(result, name: "shanhe-collage")
    try renderModes(in: folder)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(collage).write(to: folder.appendingPathComponent("collage-project.json"))
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("validation.json"))
    try "SUCCESS: 4 native Live Photo pairs validated by PhotoKit, composed with JiPinCore.".write(to: folder.appendingPathComponent("SUCCESS.txt"), atomically: true, encoding: .utf8)
    return "Generated and validated 4 Live Photo pairs."
}

private func renderModes(in folder: URL) throws {
    let names = ["lijiang-karst", "huangshan-clouds", "three-gorges-river"]
    let photos = try names.map { name in
        let data = try Data(contentsOf: folder.appendingPathComponent("\(name).jpg"))
        return ImportedPhoto(filename: name, data: data, pixelSize: ImageIOHelpers.pixelSize(of: data), utType: "public.jpeg")
    }
    let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
    for mode in CollageMode.allCases {
        var project = ProjectFactory.make(mode: mode, photos: photos, layoutID: mode == .template ? "g3-left-one" : nil)
        if mode == .template {
            project.canvas = CanvasSpec(aspectWidth: 6, aspectHeight: 5)
            project.spacing = 0.008; project.outerMargin = 0
        }
        if mode != .poster { project.background = BackgroundSpec(colorHex: "#F7F8F4") }
        if mode == .poster {
            var next = 0
            let captions = ["山河志 / 01", "沿途，皆是风景", "漓江 · 黄山 · 三峡"]
            for index in project.objects.indices where project.objects[index].kind == .text {
                project.objects[index].text?.text = captions[min(next, captions.count - 1)]
                next += 1
            }
        }
        let size = mode == .longStrip ? CGSize(width: 720, height: 2700)
            : CGSize(width: 1080, height: 1080 * project.canvas.aspectHeight / project.canvas.aspectWidth)
        if let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size) {
            try data.write(to: folder.appendingPathComponent("mode-\(mode.rawValue).jpg"))
        }
    }
    try "Static output refreshed".write(to: folder.appendingPathComponent("STATIC-SUCCESS.txt"), atomically: true, encoding: .utf8)
}
