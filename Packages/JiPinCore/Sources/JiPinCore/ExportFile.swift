import Foundation

public enum ExportFile {
    public static func write(data: Data, format: ExportFormat, directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        guard !data.isEmpty else { throw DraftStoreError.encodingFailed }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suffix = format == .png ? "png" : "jpg"
        let url = directory.appendingPathComponent("JiPin-\(UUID().uuidString).\(suffix)")
        try data.write(to: url, options: .atomic)
        return url
    }
}
