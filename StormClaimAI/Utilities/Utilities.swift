import PhotosUI
import SwiftUI
import UIKit

enum StormDateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

enum SafetyCopy {
    static let shortDisclaimer = "Documentation support only. Not insurance, legal, structural, engineering, or certified inspection advice."

    static let disclaimers = [
        "Not insurance advice.",
        "Not legal advice.",
        "Not a claim approval tool.",
        "Not a certified roof inspection.",
        "Not structural engineering advice.",
        "Does not replace licensed roofers, surveyors, adjusters, engineers, or insurance professionals.",
        "AI findings must be reviewed by qualified professionals.",
        "Do not climb roofs or take unsafe photos.",
        "Emergency issues should be handled by professionals immediately."
    ]
}

enum AppLinks {
    static let privacyPolicy = URL(string: "https://github.com/lanray07/StormClaim-AI/blob/main/PRIVACY.md")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

enum AppTheme {
    static let navy = Color(red: 0.04, green: 0.12, blue: 0.24)
    static let slate = Color(red: 0.31, green: 0.36, blue: 0.43)
    static let orange = Color(red: 0.91, green: 0.36, blue: 0.13)
    static let lightGrey = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let success = Color(red: 0.1, green: 0.48, blue: 0.32)

    static var cardBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    static var pageBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }
}

extension DamageSeverity {
    var badgeColor: Color {
        switch self {
        case .low: .green
        case .medium: .yellow
        case .high: .orange
        case .urgent: .red
        }
    }
}

extension Sequence where Element == DamageFinding {
    var highestSeverity: DamageSeverity? {
        map(\.severityValue).max { $0.rank < $1.rank }
    }
}

extension FileManager {
    func stormClaimReportsDirectory() throws -> URL {
        let directory = try url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("StormClaim Reports", isDirectory: true)
        try createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func stormClaimPhotosDirectory() throws -> URL {
        let directory = try url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("StormClaim Photos", isDirectory: true)
        try createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ImageDataView: View {
    var imageData: Data?
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(AppTheme.lightGrey)
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
