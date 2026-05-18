import Foundation
import SwiftData

enum UserType: String, CaseIterable, Codable, Identifiable {
    case roofer
    case contractor
    case homeowner
    case propertyManager
    case landlord
    case insuranceClaimAssistant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roofer: "Roofer"
        case .contractor: "Contractor"
        case .homeowner: "Homeowner"
        case .propertyManager: "Property manager"
        case .landlord: "Landlord"
        case .insuranceClaimAssistant: "Insurance claim assistant"
        }
    }
}

enum StormType: String, CaseIterable, Codable, Identifiable {
    case wind
    case hail
    case heavyRain = "heavy rain"
    case fallenTreeDebris = "fallen tree/debris"
    case flooding
    case unknown

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum CaseStatus: String, CaseIterable, Codable, Identifiable {
    case draft
    case photosAdded = "photos added"
    case scanned
    case reportReady = "report ready"
    case exported
    case archived

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum PhotoLabel: String, CaseIterable, Codable, Identifiable {
    case roofSurface = "roof surface"
    case missingShinglesTiles = "missing shingles/tiles"
    case brokenTilesSlates = "broken tiles/slates"
    case gutterDamage = "gutter damage"
    case flashingDamage = "flashing damage"
    case chimneyArea = "chimney area"
    case interiorLeak = "interior leak"
    case ceilingStain = "ceiling stain"
    case wallDamp = "wall damp"
    case fallenDebris = "fallen debris"
    case exteriorDamage = "exterior damage"
    case other

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum DamageCategory: String, CaseIterable, Codable, Identifiable {
    case windDamage = "wind damage"
    case hailImpactMarks = "hail impact marks"
    case missingShinglesTiles = "missing shingles/tiles"
    case crackedBrokenTiles = "cracked/broken tiles"
    case liftedFlashing = "lifted flashing"
    case gutterDownpipeDamage = "gutter/downpipe damage"
    case waterIngressSigns = "water ingress signs"
    case ceilingStain = "ceiling stain"
    case dampMouldSign = "damp/mould sign"
    case debrisImpact = "debris impact"
    case rooflineConcern = "roofline concern"
    case generalWearPossibleStormDamage = "general wear vs possible storm damage"

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum DamageSeverity: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .urgent: 3
        }
    }
}

enum EvidenceStatus: String, CaseIterable, Codable, Identifiable {
    case relevant
    case needsReview = "needs review"
    case urgent
    case excluded

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum SubscriptionPlan: String, CaseIterable, Codable, Identifiable {
    case free
    case pro
    case business

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        case .business: "Business"
        }
    }
}

@Model
final class StormCase {
    @Attribute(.unique) var id: UUID
    var propertyAddress: String
    var clientName: String
    var stormDate: Date
    var stormType: String
    var insuranceCompany: String
    var policyReference: String
    var notes: String
    var status: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        propertyAddress: String,
        clientName: String,
        stormDate: Date,
        stormType: StormType,
        insuranceCompany: String = "",
        policyReference: String = "",
        notes: String = "",
        status: CaseStatus = .draft,
        createdAt: Date = .now
    ) {
        self.id = id
        self.propertyAddress = propertyAddress
        self.clientName = clientName
        self.stormDate = stormDate
        self.stormType = stormType.rawValue
        self.insuranceCompany = insuranceCompany
        self.policyReference = policyReference
        self.notes = notes
        self.status = status.rawValue
        self.createdAt = createdAt
    }

    var stormTypeValue: StormType {
        get { StormType(rawValue: stormType) ?? .unknown }
        set { stormType = newValue.rawValue }
    }

    var statusValue: CaseStatus {
        get { CaseStatus(rawValue: status) ?? .draft }
        set { status = newValue.rawValue }
    }
}

@Model
final class StormPhoto {
    @Attribute(.unique) var id: UUID
    var caseId: UUID
    var imageData: Data?
    var localImageURL: URL?
    var label: String
    var caption: String
    var createdAt: Date
    var evidenceStatus: String
    var timestamp: Date
    var beforeAfterNote: String

    init(
        id: UUID = UUID(),
        caseId: UUID,
        imageData: Data? = nil,
        localImageURL: URL? = nil,
        label: PhotoLabel,
        caption: String = "",
        createdAt: Date = .now,
        evidenceStatus: EvidenceStatus = .relevant,
        timestamp: Date = .now,
        beforeAfterNote: String = ""
    ) {
        self.id = id
        self.caseId = caseId
        self.imageData = imageData
        self.localImageURL = localImageURL
        self.label = label.rawValue
        self.caption = caption
        self.createdAt = createdAt
        self.evidenceStatus = evidenceStatus.rawValue
        self.timestamp = timestamp
        self.beforeAfterNote = beforeAfterNote
    }

    var labelValue: PhotoLabel {
        get { PhotoLabel(rawValue: label) ?? .other }
        set { label = newValue.rawValue }
    }

    var evidenceStatusValue: EvidenceStatus {
        get { EvidenceStatus(rawValue: evidenceStatus) ?? .relevant }
        set { evidenceStatus = newValue.rawValue }
    }
}

@Model
final class DamageFinding {
    @Attribute(.unique) var id: UUID
    var caseId: UUID
    var photoId: UUID
    var title: String
    var description: String
    var category: String
    var severity: String
    var confidence: Double
    var suggestedAction: String
    var userApproved: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        photoId: UUID,
        title: String,
        description: String,
        category: DamageCategory,
        severity: DamageSeverity,
        confidence: Double,
        suggestedAction: String,
        userApproved: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.photoId = photoId
        self.title = title
        self.description = description
        self.category = category.rawValue
        self.severity = severity.rawValue
        self.confidence = confidence
        self.suggestedAction = suggestedAction
        self.userApproved = userApproved
        self.createdAt = createdAt
    }

    var categoryValue: DamageCategory {
        get { DamageCategory(rawValue: category) ?? .generalWearPossibleStormDamage }
        set { category = newValue.rawValue }
    }

    var severityValue: DamageSeverity {
        get { DamageSeverity(rawValue: severity) ?? .low }
        set { severity = newValue.rawValue }
    }
}

@Model
final class StormReport {
    @Attribute(.unique) var id: UUID
    var caseId: UUID
    var title: String
    var summary: String
    var pdfLocalURL: URL?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        title: String,
        summary: String,
        pdfLocalURL: URL? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.title = title
        self.summary = summary
        self.pdfLocalURL = pdfLocalURL
        self.createdAt = createdAt
    }
}

@Model
final class SubscriptionState {
    @Attribute(.unique) var id: UUID
    var plan: String
    var isActive: Bool
    var renewsAt: Date?

    init(
        id: UUID = UUID(),
        plan: SubscriptionPlan = .free,
        isActive: Bool = false,
        renewsAt: Date? = nil
    ) {
        self.id = id
        self.plan = plan.rawValue
        self.isActive = isActive
        self.renewsAt = renewsAt
    }

    var planValue: SubscriptionPlan {
        get { SubscriptionPlan(rawValue: plan) ?? .free }
        set { plan = newValue.rawValue }
    }
}
