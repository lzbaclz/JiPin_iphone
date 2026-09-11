import UIKit
import Photos
import JiPinCore

// Build as the entry point of the temporary website asset generator.
// Bundle assets/examples/source/carrot.png as a resource named carrot.png.
@main final class CarrotExamples: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let controller = UIViewController(); controller.view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 24, y: 120, width: 320, height: 300)); label.numberOfLines = 0
        label.text = "Preparing bunny and carrot Live examples…"; controller.view.addSubview(label)
        let window = UIWindow(frame: UIScreen.main.bounds); window.rootViewController = controller
        window.makeKeyAndVisible(); self.window = window
        Task.detached {
            let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Carrot-Examples")
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                guard let spriteURL = Bundle.main.url(forResource: "carrot", withExtension: "png"),
                      let sprite = UIImage(contentsOfFile: spriteURL.path) else { throw LivePhotoError.missingResources }
                let pair = try await LivePhotoWriter.write(size: CGSize(width: 720, height: 960), duration: 3) { cg, time in
                    let wave = sin(time * .pi * 2 / 3 + 1)
                    cg.setFillColor(UIColor(red: 221/255, green: 236/255, blue: 231/255, alpha: 1).cgColor)
                    cg.fill(CGRect(x: 0, y: 0, width: 720, height: 960))
                    cg.setFillColor(UIColor(red: 1, green: 248/255, blue: 236/255, alpha: 1).cgColor)
                    cg.fillEllipse(in: CGRect(x: -80, y: 640, width: 900, height: 480))
                    OriginalStickerArt.draw("cloud", in: CGRect(x: 40 + wave * 70, y: 76, width: 240, height: 200), context: cg)
                    OriginalStickerArt.draw("rainbow", in: CGRect(x: 496, y: 188 - wave * 36, width: 140, height: 160), context: cg)
                    cg.saveGState()
                    cg.translateBy(x: 360, y: 540 + wave * 40)
                    cg.rotate(by: wave * .pi / 50)
                    sprite.draw(in: CGRect(x: -310, y: -310, width: 620, height: 620))
                    cg.restoreGState()
                    cg.setFillColor(UIColor(red: 220/255, green: 167/255, blue: 131/255, alpha: 1).cgColor)
                    for n in 0..<5 { cg.fillEllipse(in: CGRect(x: 64 + n * 136, y: 872, width: 16, height: 16)) }
                }
                let nativeCarrot = try await LivePhotoMedia.request(imageURL: pair.imageURL, videoURL: pair.videoURL)
                let carrot = try await LivePhotoMedia.importPhoto(nativeCarrot, name: "小萝卜")
                try FileManager.default.copyItem(at: pair.imageURL, to: output.appendingPathComponent("carrot-scene.jpg"))
                try FileManager.default.copyItem(at: pair.videoURL, to: output.appendingPathComponent("carrot-scene.mov"))
                var photos = try await LivePhotoSamples.make(count: 1)
                photos.append(carrot)
                let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                             motions: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.liveClip!) }))
                var report: [[String: Any]] = []
                for mode in CollageMode.allCases {
                    var project = ProjectFactory.make(mode: mode, photos: photos)
                    if mode == .template { project.canvas = CanvasSpec(aspectWidth: 6, aspectHeight: 5) }
                    project.spacing = 0.012; project.outerMargin = mode == .longStrip ? 0 : 0.02
                    if mode != .poster { project.background = BackgroundSpec(colorHex: "#FFF7EC") }
                    project.livePhotoSettings = LivePhotoSettings(duration: 3)
                    if mode == .poster {
                        var index = 0
                        let words = ["可爱日常 / 01", "今天，也很可爱", "小兔 · 小萝卜 · 好心情"]
                        for i in project.objects.indices where project.objects[i].kind == .text {
                            project.objects[i].text?.text = words[min(index, words.count - 1)]; index += 1
                        }
                    }
                    let result = try await LivePhotoExporter.render(project: project, assets: assets,
                                                                    maxSide: LivePhotoExporter.motionMaxSide(for: project))
                    let native = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL)
                    guard native.size == result.photoSize else { throw LivePhotoError.invalidPair }
                    let name = "bunny-carrot-" + (mode == .longStrip ? "long-strip" : mode.rawValue)
                    try FileManager.default.copyItem(at: result.imageURL, to: output.appendingPathComponent(name + ".jpg"))
                    try FileManager.default.copyItem(at: result.videoURL, to: output.appendingPathComponent(name + ".mov"))
                    report.append(["name": name, "photoWidth": result.photoSize.width, "photoHeight": result.photoSize.height,
                                   "videoWidth": result.size.width, "videoHeight": result.size.height, "duration": result.duration,
                                   "identifier": result.identifier, "nativePhotoKitValidated": true])
                    try name.write(to: output.appendingPathComponent("progress.txt"), atomically: true, encoding: .utf8)
                }
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("validation.json"))
                try "4 bunny and carrot native Live pairs validated".write(to: output.appendingPathComponent("SUCCESS.txt"), atomically: true, encoding: .utf8)
                await MainActor.run { label.text = "Bunny + carrot examples ready." }
            } catch {
                try? String(describing: error).write(to: output.appendingPathComponent("ERROR.txt"), atomically: true, encoding: .utf8)
                await MainActor.run { label.text = "FAILED: \(error)" }
            }
        }
        return true
    }
}
