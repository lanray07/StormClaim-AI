import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var selectedUserType: UserType = .roofer
    @Published var acceptedSafetyDisclaimer = false
}

@MainActor
final class DashboardViewModel: ObservableObject {
    func urgentDamageCount(from findings: [DamageFinding]) -> Int {
        findings.filter { $0.severityValue == .urgent && $0.userApproved }.count
    }

    func recentCases(from cases: [StormCase]) -> [StormCase] {
        Array(cases.prefix(5))
    }
}

@MainActor
final class NewCaseViewModel: ObservableObject {
    @Published var propertyAddress = ""
    @Published var clientName = ""
    @Published var stormDate = Date()
    @Published var stormType: StormType = .unknown
    @Published var insuranceCompany = ""
    @Published var policyReference = ""
    @Published var notes = ""
    @Published var errorMessage: String?

    var canSave: Bool {
        !propertyAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createCase(in modelContext: ModelContext) -> StormCase? {
        guard canSave else {
            errorMessage = "Property address and client name are required."
            return nil
        }

        let stormCase = StormCase(
            propertyAddress: propertyAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            clientName: clientName.trimmingCharacters(in: .whitespacesAndNewlines),
            stormDate: stormDate,
            stormType: stormType,
            insuranceCompany: insuranceCompany.trimmingCharacters(in: .whitespacesAndNewlines),
            policyReference: policyReference.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(stormCase)
        save(modelContext)
        return stormCase
    }

    private func save(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class PhotoCaptureViewModel: ObservableObject {
    @Published var selectedLabel: PhotoLabel = .roofSurface
    @Published var caption = ""
    @Published var isCameraPresented = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let storage = PhotoStorageService()

    func addImageData(_ data: Data, to stormCase: StormCase, modelContext: ModelContext) {
        do {
            let savedURL = try storage.savePhotoData(data)
            let photo = StormPhoto(
                caseId: stormCase.id,
                imageData: data,
                localImageURL: savedURL,
                label: selectedLabel,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            stormCase.statusValue = .photosAdded
            modelContext.insert(photo)
            try modelContext.save()
            caption = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addUIImage(_ image: UIImage, to stormCase: StormCase, modelContext: ModelContext) {
        do {
            let data = try storage.jpegData(from: image)
            addImageData(data, to: stormCase, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPhotoItems(_ items: [PhotosPickerItem], to stormCase: StormCase, modelContext: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    addImageData(data, to: stormCase, modelContext: modelContext)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
final class AIScanViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var errorMessage: String?

    func scan(
        photos: [StormPhoto],
        stormCase: StormCase,
        existingFindings: [DamageFinding],
        modelContext: ModelContext,
        aiService: any AIService,
        maxPhotos: Int? = nil
    ) async {
        guard !photos.isEmpty else {
            errorMessage = "Add at least one photo before running an AI scan."
            return
        }

        let photosToScan = photos.filter { photo in
            !existingFindings.contains { $0.photoId == photo.id }
        }

        guard !photosToScan.isEmpty else {
            errorMessage = "All photos already have AI-assisted findings."
            return
        }

        let allowedPhotos = maxPhotos.map { Array(photosToScan.prefix($0)) } ?? photosToScan
        guard !allowedPhotos.isEmpty else {
            errorMessage = "The free monthly AI photo scan limit has been reached."
            return
        }

        isScanning = true
        defer { isScanning = false }

        do {
            for photo in allowedPhotos {
                let request = StormPhotoScanRequest(
                    stormType: stormCase.stormTypeValue,
                    stormDate: stormCase.stormDate,
                    photoLabel: photo.labelValue,
                    userNotes: [stormCase.notes, photo.caption].filter { !$0.isEmpty }.joined(separator: "\n"),
                    imageData: photo.imageData
                )
                let response = try await aiService.scanStormPhoto(request)

                for scanned in response.findings {
                    let finding = DamageFinding(
                        caseId: stormCase.id,
                        photoId: photo.id,
                        title: scanned.title,
                        description: scanned.description,
                        category: scanned.category,
                        severity: scanned.severity,
                        confidence: scanned.confidence,
                        suggestedAction: scanned.suggestedAction
                    )
                    modelContext.insert(finding)
                }
            }

            stormCase.statusValue = .scanned
            try modelContext.save()

            if allowedPhotos.count < photosToScan.count {
                errorMessage = "Scanned \(allowedPhotos.count) photo(s). Upgrade to scan the remaining photos this month."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class EvidenceOrganizerViewModel: ObservableObject {
    @Published var errorMessage: String?

    func save(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var draft: StormReportDraft?
    @Published var generatedPDFURL: URL?

    private let generator = PDFReportGenerator()

    func generateReport(
        for stormCase: StormCase,
        photos: [StormPhoto],
        findings: [DamageFinding],
        modelContext: ModelContext,
        aiService: any AIService,
        subscriptionPlan: SubscriptionPlan
    ) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let approvedFindings = findings.filter(\.userApproved)
            let draft = try await aiService.generateReportText(for: stormCase, photos: photos, findings: approvedFindings)
            let pdfURL = try generator.generatePDF(
                for: stormCase,
                photos: photos,
                findings: approvedFindings,
                draft: draft,
                includeLogo: subscriptionPlan == .pro || subscriptionPlan == .business,
                brandedCover: subscriptionPlan == .business
            )

            let report = StormReport(
                caseId: stormCase.id,
                title: draft.title,
                summary: draft.summary,
                pdfLocalURL: pdfURL
            )
            stormCase.statusValue = .reportReady
            modelContext.insert(report)
            try modelContext.save()

            self.draft = draft
            generatedPDFURL = pdfURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class SavedCasesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var severityFilter: DamageSeverity?
    @Published var errorMessage: String?

    func filteredCases(_ cases: [StormCase], findings: [DamageFinding]) -> [StormCase] {
        cases.filter { stormCase in
            let caseFindings = findings.filter { $0.caseId == stormCase.id }
            let matchesSearch = searchText.isEmpty ||
                stormCase.propertyAddress.localizedCaseInsensitiveContains(searchText) ||
                stormCase.clientName.localizedCaseInsensitiveContains(searchText) ||
                stormCase.stormType.localizedCaseInsensitiveContains(searchText) ||
                StormDateFormatter.dateOnly.string(from: stormCase.stormDate).localizedCaseInsensitiveContains(searchText)

            let matchesSeverity = severityFilter == nil ||
                caseFindings.contains { $0.severityValue == severityFilter }

            return matchesSearch && matchesSeverity
        }
    }

    func duplicate(_ stormCase: StormCase, in modelContext: ModelContext) {
        let copy = StormCase(
            propertyAddress: stormCase.propertyAddress,
            clientName: "\(stormCase.clientName) Copy",
            stormDate: stormCase.stormDate,
            stormType: stormCase.stormTypeValue,
            insuranceCompany: stormCase.insuranceCompany,
            policyReference: stormCase.policyReference,
            notes: stormCase.notes,
            status: .draft
        )
        modelContext.insert(copy)
        save(modelContext)
    }

    func delete(_ stormCase: StormCase, in modelContext: ModelContext) {
        modelContext.delete(stormCase)
        save(modelContext)
    }

    private func save(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
