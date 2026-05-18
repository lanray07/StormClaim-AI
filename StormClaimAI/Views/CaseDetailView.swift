import SwiftData
import SwiftUI

struct CaseDetailView: View {
    let stormCase: StormCase
    let aiService: any AIService

    @Query private var photos: [StormPhoto]
    @Query private var findings: [DamageFinding]
    @Query private var reports: [StormReport]

    init(stormCase: StormCase, aiService: any AIService) {
        self.stormCase = stormCase
        self.aiService = aiService
        let caseID = stormCase.id
        _photos = Query(filter: #Predicate<StormPhoto> { $0.caseId == caseID }, sort: \StormPhoto.createdAt, order: .reverse)
        _findings = Query(filter: #Predicate<DamageFinding> { $0.caseId == caseID }, sort: \DamageFinding.createdAt, order: .reverse)
        _reports = Query(filter: #Predicate<StormReport> { $0.caseId == caseID }, sort: \StormReport.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(title: "Photos", value: "\(photos.count)", systemImage: "camera")
                    StatTile(title: "Findings", value: "\(findings.count)", systemImage: "sparkles")
                    StatTile(title: "Approved", value: "\(findings.filter(\.userApproved).count)", systemImage: "checkmark.circle")
                    StatTile(title: "Reports", value: "\(reports.count)", systemImage: "doc")
                }

                VStack(spacing: 12) {
                    NavigationLink {
                        PhotoCaptureUploadView(stormCase: stormCase)
                    } label: {
                        workflowRow("Photo Capture / Upload", systemImage: "camera.fill", detail: "Add roof, interior, debris, and exterior evidence")
                    }

                    NavigationLink {
                        AIScanView(stormCase: stormCase, aiService: aiService)
                    } label: {
                        workflowRow("AI Damage Scan", systemImage: "sparkles", detail: "Mock AI suggests visible, non-diagnostic findings")
                    }

                    NavigationLink {
                        EvidenceOrganizerView(stormCase: stormCase)
                    } label: {
                        workflowRow("Evidence Organizer", systemImage: "square.grid.2x2", detail: "Group photos, captions, timestamps, and status")
                    }

                    NavigationLink {
                        ReportGeneratorView(stormCase: stormCase, aiService: aiService)
                    } label: {
                        workflowRow("Report Generator & PDF Export", systemImage: "doc.richtext.fill", detail: "Preview, export, share, and save a PDF report")
                    }
                }
                .buttonStyle(.plain)

                if !findings.isEmpty {
                    Text("Latest Findings")
                        .font(.title3.bold())
                    ForEach(findings.prefix(3)) { finding in
                        DamageFindingCard(finding: finding)
                    }
                }

                Text(SafetyCopy.shortDisclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Case")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stormCase.propertyAddress)
                        .font(.title2.bold())
                    Text(stormCase.clientName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let highest = findings.highestSeverity {
                    SeverityBadge(severity: highest)
                }
            }

            HStack(spacing: 10) {
                Label(stormCase.stormTypeValue.displayName, systemImage: "cloud.bolt.rain")
                Label(StormDateFormatter.dateOnly.string(from: stormCase.stormDate), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func workflowRow(_ title: String, systemImage: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
