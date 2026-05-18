import SwiftData
import SwiftUI

struct AIScanView: View {
    let stormCase: StormCase
    let aiService: any AIService

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query private var photos: [StormPhoto]
    @Query private var findings: [DamageFinding]
    @Query(sort: \DamageFinding.createdAt, order: .reverse) private var allFindings: [DamageFinding]
    @StateObject private var viewModel = AIScanViewModel()
    @State private var showPaywall = false

    init(stormCase: StormCase, aiService: any AIService) {
        self.stormCase = stormCase
        self.aiService = aiService
        let caseID = stormCase.id
        _photos = Query(filter: #Predicate<StormPhoto> { $0.caseId == caseID }, sort: \StormPhoto.createdAt, order: .reverse)
        _findings = Query(filter: #Predicate<DamageFinding> { $0.caseId == caseID }, sort: \DamageFinding.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Damage Scan")
                        .font(.title2.bold())
                    Text("Mock AI is enabled by default. Findings use cautious language and must be reviewed before inclusion in reports.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await viewModel.scan(
                            photos: photos,
                            stormCase: stormCase,
                            existingFindings: findings,
                            modelContext: modelContext,
                            aiService: aiService,
                            maxPhotos: subscriptionManager.remainingScanAllowance(from: allFindings)
                        )
                    }
                } label: {
                    if viewModel.isScanning {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Label("Run Mock AI Scan", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.orange)
                .disabled(viewModel.isScanning || photos.isEmpty || subscriptionManager.remainingScanAllowance(from: allFindings) == 0)

                if let remaining = subscriptionManager.remainingScanAllowance(from: allFindings) {
                    Text("\(remaining) free AI photo scan(s) remaining this month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if remaining == 0 {
                        UpgradeBanner(
                            title: "AI scan limit reached",
                            subtitle: "Upgrade for higher scan limits and professional report features."
                        ) {
                            showPaywall = true
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                if photos.isEmpty {
                    EmptyStateView(
                        systemImage: "camera.metering.none",
                        title: "Photos required",
                        message: "Add photos before running AI-assisted damage documentation."
                    )
                } else if findings.isEmpty {
                    EmptyStateView(
                        systemImage: "sparkles",
                        title: "Ready to scan",
                        message: "Run the mock scan to generate visible, non-diagnostic damage suggestions."
                    )
                } else {
                    ForEach(findings) { finding in
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
        .navigationTitle("AI Scan")
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
    }
}
