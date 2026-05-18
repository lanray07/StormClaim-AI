import Foundation
import UIKit

enum PhotoStorageError: LocalizedError {
    case invalidImageData
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            "The selected image could not be converted to JPEG data."
        case .writeFailed:
            "The photo could not be saved locally."
        }
    }
}

struct PhotoStorageService {
    func jpegData(from image: UIImage) throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw PhotoStorageError.invalidImageData
        }
        return data
    }

    func savePhotoData(_ data: Data) throws -> URL {
        let directory = try FileManager.default.stormClaimPhotosDirectory()
        let url = directory.appendingPathComponent("\(UUID().uuidString).jpg")

        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            throw PhotoStorageError.writeFailed
        }
    }
}
