import Foundation
import UIKit

extension MigratedDataStore {

    var paddockCentroidLatitude: Double? {
        let coords = paddocks.flatMap { $0.polygonPoints }
        guard !coords.isEmpty else { return nil }
        let sum = coords.reduce(0.0) { $0 + $1.latitude }
        return sum / Double(coords.count)
    }

    private var customELImagesDir: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("CustomELStageImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func customELImageURL(for code: String) -> URL? {
        let safe = code.replacingOccurrences(of: "/", with: "_")
        return customELImagesDir?.appendingPathComponent("\(safe).jpg")
    }

    func hasCustomELStageImage(for code: String) -> Bool {
        guard let url = customELImageURL(for: code) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func saveCustomELStageImage(_ image: UIImage, for code: String) {
        guard let url = customELImageURL(for: code), let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func removeCustomELStageImage(for code: String) {
        guard let url = customELImageURL(for: code) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func resolvedELStageImage(for stage: GrowthStage) -> UIImage? {
        if let url = customELImageURL(for: stage.code),
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        if let name = stage.imageName, let bundled = UIImage(named: name) {
            return bundled
        }
        return nil
    }
}
