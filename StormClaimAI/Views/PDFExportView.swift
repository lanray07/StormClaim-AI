import SwiftUI
import UIKit

struct PDFExportView: View {
    let stormCase: StormCase
    let reportURL: URL
    let draft: StormReportDraft?
    let photos: [StormPhoto]
    let findings: [DamageFinding]

    @State private var showShareSheet = false
    @State private var didCopyPath = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReportPreviewView(stormCase: stormCase, photos: photos, findings: findings, draft: draft)

                VStack(alignment: .leading, spacing: 12) {
                    Label("PDF saved locally", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.success)

                    Text(reportURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.orange)

                    Button {
                        UIPasteboard.general.string = reportURL.path
                        didCopyPath = true
                    } label: {
                        Label(didCopyPath ? "Local Path Copied" : "Copy Local PDF Path", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(SafetyCopy.shortDisclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("PDF Export")
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [reportURL])
        }
    }
}
