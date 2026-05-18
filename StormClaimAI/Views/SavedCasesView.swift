import SwiftData
import SwiftUI

struct SavedCasesView: View {
    let aiService: any AIService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StormCase.createdAt, order: .reverse) private var cases: [StormCase]
    @Query(sort: \DamageFinding.createdAt, order: .reverse) private var findings: [DamageFinding]
    @Query(sort: \StormReport.createdAt, order: .reverse) private var reports: [StormReport]
    @StateObject private var viewModel = SavedCasesViewModel()
    @State private var shareURL: URL?

    var body: some View {
        List {
            Section {
                Picker("Severity", selection: $viewModel.severityFilter) {
                    Text("All severities").tag(DamageSeverity?.none)
                    ForEach(DamageSeverity.allCases) { severity in
                        Text(severity.displayName).tag(DamageSeverity?.some(severity))
                    }
                }
            }

            let filtered = viewModel.filteredCases(cases, findings: findings)
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "folder",
                    title: "No matching cases",
                    message: "Search by property, client, date, or storm type, or clear the severity filter."
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { stormCase in
                    NavigationLink {
                        CaseDetailView(stormCase: stormCase, aiService: aiService)
                    } label: {
                        StormCaseCard(
                            stormCase: stormCase,
                            highestSeverity: findings.filter { $0.caseId == stormCase.id }.highestSeverity
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.delete(stormCase, in: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            viewModel.duplicate(stormCase, in: modelContext)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        .tint(AppTheme.orange)
                    }
                    .swipeActions(edge: .leading) {
                        if let url = reports.first(where: { $0.caseId == stormCase.id })?.pdfLocalURL {
                            Button {
                                shareURL = url
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(AppTheme.navy)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Saved Cases")
        .searchable(text: $viewModel.searchText, prompt: "Property, client, date, storm type")
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
        }
    }
}
