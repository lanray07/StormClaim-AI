import SwiftData
import SwiftUI

struct DashboardView: View {
    let aiService: any AIService

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \StormCase.createdAt, order: .reverse) private var cases: [StormCase]
    @Query(sort: \DamageFinding.createdAt, order: .reverse) private var findings: [DamageFinding]
    @Query(sort: \StormReport.createdAt, order: .reverse) private var reports: [StormReport]
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("StormClaim AI")
                        .font(.largeTitle.bold())
                    Text(SafetyCopy.shortDisclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    NewCaseView(aiService: aiService)
                } label: {
                    Label("New Storm Claim Case", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.orange)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(title: "Recent Cases", value: "\(cases.count)", systemImage: "folder")
                    StatTile(title: "Urgent Damage", value: "\(viewModel.urgentDamageCount(from: findings))", systemImage: "exclamationmark.triangle.fill", tint: .red)
                    StatTile(title: "Reports Generated", value: "\(reports.count)", systemImage: "doc.richtext")
                    StatTile(title: "Subscription Status", value: subscriptionManager.plan.displayName, systemImage: "checkmark.seal")
                }

                if subscriptionManager.plan == .free {
                    UpgradeBanner {
                        showPaywall = true
                    }
                }

                Text("Recent Cases")
                    .font(.title3.bold())

                if cases.isEmpty {
                    EmptyStateView(
                        systemImage: "cloud.bolt.rain",
                        title: "No storm cases yet",
                        message: "Create a case, add property details, upload photos, and generate a professional documentation report."
                    )
                } else {
                    ForEach(viewModel.recentCases(from: cases)) { stormCase in
                        NavigationLink {
                            CaseDetailView(stormCase: stormCase, aiService: aiService)
                        } label: {
                            StormCaseCard(
                                stormCase: stormCase,
                                highestSeverity: findings.filter { $0.caseId == stormCase.id }.highestSeverity
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    SampleDataFactory.createDemoCase(in: modelContext)
                } label: {
                    Image(systemName: "shippingbox.fill")
                }
                .accessibilityLabel("Add demo case")
            }
            #endif
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
    }
}
