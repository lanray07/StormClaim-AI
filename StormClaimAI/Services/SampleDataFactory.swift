import Foundation
import SwiftData

enum SampleDataFactory {
    @MainActor
    static func createDemoCase(in modelContext: ModelContext) {
        let stormCase = StormCase(
            propertyAddress: "42 Harbour View, Cardiff",
            clientName: "Morgan Property Group",
            stormDate: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
            stormType: .wind,
            insuranceCompany: "Placeholder Mutual",
            policyReference: "POL-REF-0001",
            notes: "Ground-level inspection only. Access to rear elevation was limited by debris. No roof climbing was performed."
        )

        modelContext.insert(stormCase)

        let roofPhoto = StormPhoto(
            caseId: stormCase.id,
            label: .missingShinglesTiles,
            caption: "Rear roof slope viewed from garden. Visible roof covering disruption noted.",
            evidenceStatus: .urgent
        )
        modelContext.insert(roofPhoto)

        let interiorPhoto = StormPhoto(
            caseId: stormCase.id,
            label: .ceilingStain,
            caption: "Bedroom ceiling stain below rear roof slope.",
            evidenceStatus: .needsReview
        )
        modelContext.insert(interiorPhoto)

        modelContext.insert(DamageFinding(
            caseId: stormCase.id,
            photoId: roofPhoto.id,
            title: "Possible wind-related roof covering displacement",
            description: "Visible gaps appear consistent with possible roof covering displacement. Cause cannot be confirmed from the image alone.",
            category: .missingShinglesTiles,
            severity: .high,
            confidence: 0.74,
            suggestedAction: "Request qualified roofer review and temporary weatherproofing if water entry is possible.",
            userApproved: true
        ))

        modelContext.insert(DamageFinding(
            caseId: stormCase.id,
            photoId: interiorPhoto.id,
            title: "Visible water ingress sign",
            description: "The ceiling stain is a visible sign of possible water ingress. The source should be traced by a qualified professional.",
            category: .waterIngressSigns,
            severity: .urgent,
            confidence: 0.82,
            suggestedAction: "Escalate if active leaking, electrical risk, mould concern, or ceiling sagging is present.",
            userApproved: true
        ))

        stormCase.statusValue = .scanned

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Unable to save demo data: \(error)")
        }
    }
}
