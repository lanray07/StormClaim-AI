import SwiftData
import SwiftUI

struct ReportGeneratorView: View {
    let stormCase: StormCase
    let aiService: any AIService

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query private var photos: [StormPhoto]
    @Query private var findings: [DamageFinding]
    @Query private var reports: [StormReport]
    @StateObject private var viewModel = ReportViewModel()
    @State private var shareURL: URL?
    @State private var showPaywall = false

    init(stormCase: StormCase, aiService: any AIService) {
        self.stormCase = stormCase
        self.aiService = aiService
        let caseID = stormCase.id
        _photos = Query(filter: #Predicate<StormPhoto> { $0.caseId == caseID }, sort: \StormPhoto.createdAt, order: .forward)
        _findings = Query(filter: #Predicate<DamageFinding> { $0.caseId == caseID }, sort: \DamageFinding.createdAt, order: .forward)
        _reports = Query(filter: #Predicate<StormReport> { $0.caseId == caseID }, sort: \StormReport.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReportPreviewView(stormCase: stormCase, photos: photos, findings: findings, draft: viewModel.draft)

                if subscriptionManager.plan == .free {
                    UpgradeBanner(
                        title: "Professional PDF exports",
                        subtitle: "Pro adds custom logo support. Business adds a branded cover page."
                    ) {
                        showPaywall = true
                    }
                }

                Button {
                    Task {
                        await viewModel.generateReport(
                            for: stormCase,
                            photos: photos,
                            findings: findings,
                            modelContext: modelContext,
                            aiService: aiService,
                            subscriptionPlan: subscriptionManager.plan
                        )
                    }
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Label("Generate PDF Report", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.orange)
                .disabled(viewModel.isGenerating)

                if let url = viewModel.generatedPDFURL {
                    NavigationLink {
                        PDFExportView(stormCase: stormCase, reportURL: url, draft: viewModel.draft, photos: photos, findings: findings)
                    } label: {
                        Label("Preview and Export PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }

                if let latestReport = reports.first, let url = latestReport.pdfLocalURL {
                    Button {
                        shareURL = url
                    } label: {
                        Label("Share Latest Saved PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Report sections")
                        .font(.headline)
                    ForEach([
                        "Property details",
                        "Storm event details",
                        "Inspection summary",
                        "Damage evidence",
                        "Photo log",
                        "Severity breakdown",
                        "Suggested repair priority",
                        "Contractor notes",
                        "Insurance disclaimer",
                        "Signature placeholder"
                    ], id: \.self) { section in
                        Label(section, systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Report")
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
