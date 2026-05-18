import Foundation

struct StormPhotoScanRequest {
    var stormType: StormType
    var stormDate: Date
    var photoLabel: PhotoLabel
    var userNotes: String
    var imageData: Data?
}

struct ScannedDamageFinding: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var category: DamageCategory
    var severity: DamageSeverity
    var confidence: Double
    var suggestedAction: String
}

struct StormPhotoScanResponse: Codable {
    var findings: [ScannedDamageFinding]
    var summary: String
}

struct RepairPriorityItem: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var severity: DamageSeverity
    var action: String
}

struct StormReportDraft {
    var title: String
    var summary: String
    var contractorNotes: String
    var repairPriorities: [RepairPriorityItem]
}

protocol AIService {
    func scanStormPhoto(_ request: StormPhotoScanRequest) async throws -> StormPhotoScanResponse
    func generateCaseSummary(for stormCase: StormCase, photos: [StormPhoto], findings: [DamageFinding]) async throws -> String
    func generateRepairPriorityList(for findings: [DamageFinding]) async throws -> [RepairPriorityItem]
    func generateReportText(for stormCase: StormCase, photos: [StormPhoto], findings: [DamageFinding]) async throws -> StormReportDraft
}

enum AIPromptPolicy {
    static let internalDamagePrompt = """
    You are StormClaim AI, an assistant for storm damage documentation. Review the user’s photo description, storm type, property notes, and image context. Identify visible, non-diagnostic signs of possible storm-related damage only. Do not guarantee cause, insurance coverage, claim approval, repair cost, legal outcome, or structural safety. Use cautious language such as ‘possible’, ‘visible sign of’, ‘appears consistent with’, and ‘recommend review by a qualified professional’. Return structured findings with category, severity, confidence, explanation, and suggested next action.
    """
}

struct MockAIService: AIService {
    func scanStormPhoto(_ request: StormPhotoScanRequest) async throws -> StormPhotoScanResponse {
        try await Task.sleep(nanoseconds: 450_000_000)

        let finding = mockFinding(for: request.photoLabel, stormType: request.stormType)
        let secondary = ScannedDamageFinding(
            title: "Professional review recommended",
            description: "The image should be reviewed by a qualified roofer, surveyor, adjuster, engineer, or other relevant professional before any claim-support conclusion is made.",
            category: .generalWearPossibleStormDamage,
            severity: finding.severity == .urgent ? .high : .low,
            confidence: 0.54,
            suggestedAction: "Add site notes, compare against pre-storm condition if available, and avoid unsafe roof access."
        )

        return StormPhotoScanResponse(
            findings: [finding, secondary],
            summary: "Mock AI identified visible, non-diagnostic signs that may warrant professional review. This is documentation support only, not an insurance, legal, structural, or repair decision."
        )
    }

    func generateCaseSummary(for stormCase: StormCase, photos: [StormPhoto], findings: [DamageFinding]) async throws -> String {
        try await Task.sleep(nanoseconds: 250_000_000)

        let approved = findings.filter(\.userApproved)
        let urgentCount = approved.filter { $0.severityValue == .urgent }.count
        let highCount = approved.filter { $0.severityValue == .high }.count

        return """
        Documentation case for \(stormCase.propertyAddress) following reported \(stormCase.stormTypeValue.displayName.lowercased()) conditions on \(StormDateFormatter.medium.string(from: stormCase.stormDate)). \(photos.count) photo(s) are attached and \(approved.count) user-approved AI-assisted finding(s) are included. \(urgentCount) urgent and \(highCount) high severity item(s) are flagged for prompt qualified review.
        """
    }

    func generateRepairPriorityList(for findings: [DamageFinding]) async throws -> [RepairPriorityItem] {
        try await Task.sleep(nanoseconds: 150_000_000)

        let approved = findings
            .filter(\.userApproved)
            .sorted { $0.severityValue.rank > $1.severityValue.rank }

        if approved.isEmpty {
            return [
                RepairPriorityItem(
                    title: "Review evidence before prioritising repairs",
                    severity: .low,
                    action: "Approve relevant findings or add contractor notes before issuing a client-ready report."
                )
            ]
        }

        return approved.map {
            RepairPriorityItem(
                title: $0.title,
                severity: $0.severityValue,
                action: $0.suggestedAction
            )
        }
    }

    func generateReportText(for stormCase: StormCase, photos: [StormPhoto], findings: [DamageFinding]) async throws -> StormReportDraft {
        let summary = try await generateCaseSummary(for: stormCase, photos: photos, findings: findings)
        let priorities = try await generateRepairPriorityList(for: findings)
        let contractorNotes = stormCase.notes.isEmpty
            ? "No additional contractor notes were entered. Add site observations, access limitations, weather context, and client instructions as needed."
            : stormCase.notes

        return StormReportDraft(
            title: "Storm Damage Documentation Report",
            summary: summary,
            contractorNotes: contractorNotes,
            repairPriorities: priorities
        )
    }

    private func mockFinding(for label: PhotoLabel, stormType: StormType) -> ScannedDamageFinding {
        switch label {
        case .missingShinglesTiles:
            ScannedDamageFinding(
                title: "Possible missing shingles or tiles",
                description: "Visible gaps appear consistent with possible wind-related displacement. Confirm on site from a safe position and compare with pre-event condition where possible.",
                category: .missingShinglesTiles,
                severity: stormType == .wind ? .high : .medium,
                confidence: 0.78,
                suggestedAction: "Recommend qualified roof inspection and temporary weatherproofing if water entry is possible."
            )
        case .brokenTilesSlates:
            ScannedDamageFinding(
                title: "Visible cracked or broken roof covering",
                description: "The photo appears to show cracked or broken roof material. The cause cannot be confirmed from the image alone.",
                category: .crackedBrokenTiles,
                severity: .high,
                confidence: 0.72,
                suggestedAction: "Document close-up and wider context photos, then request professional repair assessment."
            )
        case .gutterDamage:
            ScannedDamageFinding(
                title: "Possible gutter or downpipe damage",
                description: "The gutter line appears irregular in the image, which may indicate impact, wind movement, or pre-existing wear.",
                category: .gutterDownpipeDamage,
                severity: .medium,
                confidence: 0.69,
                suggestedAction: "Check drainage function from ground level and refer to a qualified contractor if loose or blocked."
            )
        case .flashingDamage, .chimneyArea:
            ScannedDamageFinding(
                title: "Possible lifted flashing or vulnerable junction",
                description: "The junction area appears to have a visible irregularity that could be consistent with lifted flashing or weathering.",
                category: .liftedFlashing,
                severity: .high,
                confidence: 0.66,
                suggestedAction: "Prioritise review by a qualified roofer, especially if interior water staining is present."
            )
        case .interiorLeak, .ceilingStain, .wallDamp:
            ScannedDamageFinding(
                title: "Visible water ingress sign",
                description: "The image appears to show staining or dampness that may be associated with water ingress. The source and cause require professional review.",
                category: label == .wallDamp ? .dampMouldSign : .waterIngressSigns,
                severity: .urgent,
                confidence: 0.8,
                suggestedAction: "Escalate if active leaking, electrical risk, mould concern, or ceiling sagging is present."
            )
        case .fallenDebris, .exteriorDamage:
            ScannedDamageFinding(
                title: "Possible debris impact evidence",
                description: "Visible debris or exterior disturbance may be consistent with storm-related impact, but causation cannot be determined from the photo alone.",
                category: .debrisImpact,
                severity: .medium,
                confidence: 0.7,
                suggestedAction: "Capture wider scene photos, note debris source if known, and arrange safe removal by professionals."
            )
        case .roofSurface:
            ScannedDamageFinding(
                title: stormType == .hail ? "Possible hail impact marks" : "Possible roof surface disturbance",
                description: "The roof surface includes visible marks or irregular areas. This may reflect storm impact, normal ageing, or prior wear.",
                category: stormType == .hail ? .hailImpactMarks : .generalWearPossibleStormDamage,
                severity: .medium,
                confidence: 0.61,
                suggestedAction: "Add close-up and elevation photos, then ask a qualified professional to assess."
            )
        case .other:
            ScannedDamageFinding(
                title: "Possible storm-related concern",
                description: "The image includes a visible condition that may be relevant to storm documentation, but the category is unclear.",
                category: .generalWearPossibleStormDamage,
                severity: .low,
                confidence: 0.5,
                suggestedAction: "Add a caption, location tag, and professional review notes before reporting."
            )
        }
    }
}

struct RemoteAIService: AIService {
    var endpoint = URL(string: "https://YOUR_BACKEND_URL.com/storm-claim-scan")!
    var session: URLSession = .shared

    func scanStormPhoto(_ request: StormPhotoScanRequest) async throws -> StormPhotoScanResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = RemoteScanRequest(
            stormType: request.stormType.rawValue,
            stormDate: ISO8601DateFormatter().string(from: request.stormDate),
            photoLabel: request.photoLabel.rawValue,
            userNotes: request.userNotes,
            imageBase64: request.imageData?.base64EncodedString() ?? ""
        )

        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }

        let remoteResponse = try JSONDecoder().decode(RemoteScanResponse.self, from: data)
        return StormPhotoScanResponse(
            findings: remoteResponse.findings.map {
                ScannedDamageFinding(
                    title: $0.title,
                    description: $0.description,
                    category: DamageCategory(rawValue: $0.category) ?? .generalWearPossibleStormDamage,
                    severity: DamageSeverity(rawValue: $0.severity) ?? .low,
                    confidence: $0.confidence,
                    suggestedAction: $0.suggestedAction
                )
            },
            summary: remoteResponse.summary
        )
    }

    func generateCaseSummary(for stormCase: StormCase, photos: [StormPhoto], findings: [DamageFinding]) async throws -> String {
        "Remote report text generation should be implemented in your backend so API keys never ship in the app."
    }

    func generateRepairPriorityList(for findings: [DamageFinding]) async throws -> [RepairPriorityItem] {
        findings
            .filter(\.userApproved)
            .sorted { $0.severityValue.rank > $1.severityValue.rank }
            .map { RepairPriorityItem(title: $0.title, severity: $0.severityValue, action: $0.suggestedAction) }
    }

    func generateReportText(for stormCase: StormCase, photos: [StormPhoto], findings: [DamageFinding]) async throws -> StormReportDraft {
        let summary = try await generateCaseSummary(for: stormCase, photos: photos, findings: findings)
        let priorities = try await generateRepairPriorityList(for: findings)
        return StormReportDraft(
            title: "Storm Damage Documentation Report",
            summary: summary,
            contractorNotes: stormCase.notes,
            repairPriorities: priorities
        )
    }
}

enum AIServiceError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The AI scan endpoint returned an invalid response."
        }
    }
}

private struct RemoteScanRequest: Encodable {
    var stormType: String
    var stormDate: String
    var photoLabel: String
    var userNotes: String
    var imageBase64: String
}

private struct RemoteScanResponse: Decodable {
    var findings: [RemoteFinding]
    var summary: String
}

private struct RemoteFinding: Decodable {
    var title: String
    var description: String
    var category: String
    var severity: String
    var confidence: Double
    var suggestedAction: String
}
