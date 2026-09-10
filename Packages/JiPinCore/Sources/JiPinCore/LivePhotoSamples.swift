import UIKit

/// Original moving illustrations for trying Live collage without opening the photo library.
public enum LivePhotoSamples {
    public static func make(count: Int = 2) async throws -> [ImportedPhoto] {
        var photos: [ImportedPhoto] = []
        for index in 0..<min(max(count, 0), LivePhotoPolicy.maxSources) {
            try Task.checkCancellation()
            let pair = try await LivePhotoWriter.write(size: CGSize(width: 720, height: 960), duration: 3) { cg, time in
                cg.scaleBy(x: 2, y: 2)
                let colors = ["#F9DDD9", "#DDECE7", "#E3E1F2"]
                cg.setFillColor(OriginalStickerArt.color(colors[index % colors.count]))
                cg.fill(CGRect(x: 0, y: 0, width: 360, height: 480))
                cg.setFillColor(OriginalStickerArt.color("#FFF8EC"))
                cg.fillEllipse(in: CGRect(x: -40, y: 320, width: 450, height: 240))
                let wave = sin(time * .pi * 2 / 3 + Double(index))
                OriginalStickerArt.draw("cloud", in: CGRect(x: 20 + wave * 35, y: 38, width: 120, height: 100), context: cg)
                OriginalStickerArt.draw(index.isMultiple(of: 2) ? "bunny" : "bear",
                                        in: CGRect(x: 75, y: 170 + wave * 30, width: 210, height: 210), context: cg)
                OriginalStickerArt.draw(index.isMultiple(of: 2) ? "daisy" : "rainbow",
                                        in: CGRect(x: 248, y: 94 - wave * 18, width: 70, height: 80), context: cg)
                cg.setFillColor(OriginalStickerArt.color("#DCA783"))
                for n in 0..<5 { cg.fillEllipse(in: CGRect(x: 32 + n * 68, y: 436, width: 8, height: 8)) }
            }
            let native = try await LivePhotoMedia.request(imageURL: pair.imageURL, videoURL: pair.videoURL)
            photos.append(try await LivePhotoMedia.importPhoto(native, name: "会动的小日常 \(index + 1)"))
        }
        return photos
    }
}
