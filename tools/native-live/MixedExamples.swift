import UIKit
import Photos
import JiPinCore

@main final class WebsiteExamples: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let controller = UIViewController(); controller.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 24, y: 120, width: 320, height: 300)); label.numberOfLines = 0
        label.text = "Generating native Live examples…"; controller.view.addSubview(label)
        let window = UIWindow(frame: UIScreen.main.bounds); window.rootViewController = controller
        window.makeKeyAndVisible(); self.window = window
        Task.detached {
            let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Examples")
            do {
                try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
                let cute = try await LivePhotoSamples.make()
                var shanhe: [ImportedPhoto] = []
                for name in ["lijiang-karst", "huangshan-clouds", "three-gorges-river"] {
                    let still = Bundle.main.url(forResource: name, withExtension: "jpg")!
                    let movie = Bundle.main.url(forResource: name, withExtension: "mov")!
                    let native = try await LivePhotoMedia.request(imageURL: still, videoURL: movie)
                    shanhe.append(try await LivePhotoMedia.importPhoto(native, name: name))
                }
                var report: [[String: Any]] = []
                for (theme, photos) in [("cute", cute), ("shanhe", shanhe)] {
                    let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                                 motions: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.liveClip!) }))
                    for mode in CollageMode.allCases {
                        var project = ProjectFactory.make(mode: mode, photos: photos, layoutID: theme == "shanhe" && mode == .template ? "g3-left-one" : nil)
                        if mode == .template { project.canvas = CanvasSpec(aspectWidth: 6, aspectHeight: 5) }
                        project.spacing = 0.012; project.outerMargin = mode == .longStrip ? 0 : 0.02
                        if mode != .poster { project.background = BackgroundSpec(colorHex: theme == "cute" ? "#FFF7EC" : "#F7F8F4") }
                        project.livePhotoSettings = LivePhotoSettings(duration: 3)
                        if mode == .poster {
                            var textIndex = 0
                            let words = theme == "cute" ? ["可爱日常 / 01", "今天，也很可爱", "小兔 · 小熊 · 好心情"] : ["山河旅行 / 01", "沿途，皆是风景", "漓江 · 黄山 · 三峡"]
                            for i in project.objects.indices where project.objects[i].kind == .text {
                                project.objects[i].text?.text = words[min(textIndex, words.count - 1)]; textIndex += 1
                            }
                        }
                        let result = try await LivePhotoExporter.render(project: project, assets: assets,
                                                                        maxSide: LivePhotoExporter.motionMaxSide(for: project))
                        let native = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL)
                        guard native.size == result.photoSize else { throw LivePhotoError.invalidPair }
                        let name = theme + "-" + (mode == .longStrip ? "long-strip" : mode.rawValue)
                        try FileManager.default.copyItem(at: result.imageURL, to: out.appendingPathComponent(name + ".jpg"))
                        try FileManager.default.copyItem(at: result.videoURL, to: out.appendingPathComponent(name + ".mov"))
                        report.append(["name": name, "photoWidth": result.photoSize.width, "photoHeight": result.photoSize.height,
                                       "videoWidth": result.size.width, "videoHeight": result.size.height,
                                       "duration": result.duration, "identifier": result.identifier, "nativePhotoKitValidated": true])
                        try name.write(to: out.appendingPathComponent("progress.txt"), atomically: true, encoding: .utf8)
                    }
                }
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("validation.json"))
                try "8 original-size Live Photo pairs validated".write(to: out.appendingPathComponent("SUCCESS.txt"), atomically: true, encoding: .utf8)
                await MainActor.run { label.text = "All 8 native Live examples are ready." }
            } catch {
                try? String(describing: error).write(to: out.appendingPathComponent("ERROR.txt"), atomically: true, encoding: .utf8)
                await MainActor.run { label.text = "FAILED: \(error)" }
            }
        }
        return true
    }
}
