import SwiftData
import SwiftUI

struct SeverityBadge: View {
    var severity: DamageSeverity

    var body: some View {
        Text(severity.displayName)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(severity == .medium ? .black : .white)
            .background(severity.badgeColor.gradient, in: Capsule())
            .accessibilityLabel("Severity \(severity.displayName)")
    }
}

struct StormCaseCard: View {
    var stormCase: StormCase
    var highestSeverity: DamageSeverity?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stormCase.propertyAddress)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(stormCase.clientName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let highestSeverity {
                    SeverityBadge(severity: highestSeverity)
                }
            }

            HStack(spacing: 10) {
                Label(stormCase.stormTypeValue.displayName, systemImage: "cloud.bolt.rain")
                Label(StormDateFormatter.dateOnly.string(from: stormCase.stormDate), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text(stormCase.statusValue.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.navy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.lightGrey, in: Capsule())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StormPhotoCard: View {
    var photo: StormPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImageDataView(imageData: photo.imageData)
                .frame(height: 210)
                .clipped()

            HStack {
                Text(photo.labelValue.displayName)
                    .font(.headline)
                Spacer()
                Text(photo.evidenceStatusValue.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text(StormDateFormatter.medium.string(from: photo.timestamp))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DamageFindingCard: View {
    @Bindable var finding: DamageFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(finding.title)
                        .font(.headline)
                    Text(finding.categoryValue.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
                SeverityBadge(severity: finding.severityValue)
            }

            Text(finding.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Label(finding.suggestedAction, systemImage: "checklist")
                Label("Confidence \(Int(finding.confidence * 100))%", systemImage: "gauge.with.dots.needle.bottom.50percent")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            Toggle("User approved for report", isOn: $finding.userApproved)
                .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EvidenceGroupView: View {
    var title: String
    var photos: [StormPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(photos) { photo in
                EvidencePhotoRow(photo: photo)
            }
        }
    }
}

private struct EvidencePhotoRow: View {
    @Bindable var photo: StormPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ImageDataView(imageData: photo.imageData)
                    .frame(width: 96, height: 96)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    Text(photo.labelValue.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(StormDateFormatter.medium.string(from: photo.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Evidence status", selection: $photo.evidenceStatus) {
                        ForEach(EvidenceStatus.allCases) { status in
                            Text(status.displayName).tag(status.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            TextField("Caption", text: $photo.caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            TextField("Before/after note placeholder", text: $photo.beforeAfterNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("StormClaim AI Plans")
                        .font(.largeTitle.bold())
                    Text("Upgrade for branded reports, larger scan limits, and contractor-ready documentation workflows.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                planCard(
                    plan: .free,
                    price: "Included",
                    features: [
                        "2 cases per month",
                        "10 AI photo scans per month",
                        "Basic PDF report",
                        "StormClaim AI footer"
                    ]
                )

                planCard(
                    plan: .pro,
                    price: "£29.99 monthly / £249.99 yearly",
                    features: [
                        "Unlimited cases",
                        "250 photo scans per month",
                        "Professional PDF exports",
                        "Custom logo",
                        "Storm damage report templates",
                        "Repair priority list"
                    ]
                )

                planCard(
                    plan: .business,
                    price: "£89.99 monthly",
                    features: [
                        "Unlimited reports",
                        "Advanced branding",
                        "Claim-support report format",
                        "Contractor action lists",
                        "Team workflow placeholder"
                    ]
                )
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Subscription")
        .task {
            await subscriptionManager.loadProducts()
        }
    }

    private func planCard(plan: SubscriptionPlan, price: String, features: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName)
                        .font(.title3.bold())
                    Text(price)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.orange)
                }
                Spacer()
                if subscriptionManager.plan == plan {
                    Label("Active", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.success)
                }
            }

            ForEach(features, id: \.self) { feature in
                Label(feature, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                subscriptionManager.mockUpgrade(to: plan)
            } label: {
                Text(subscriptionManager.plan == plan ? "Current plan" : "Use mock \(plan.displayName)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(plan == .business ? AppTheme.navy : AppTheme.orange)
            .disabled(subscriptionManager.plan == plan)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ReportPreviewView: View {
    var stormCase: StormCase
    var photos: [StormPhoto]
    var findings: [DamageFinding]
    var draft: StormReportDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft?.title ?? "Storm Damage Documentation Report")
                .font(.title2.bold())
            Text(stormCase.propertyAddress)
                .font(.headline)
            Text(draft?.summary ?? "Generate a report to preview the inspection summary, approved findings, photo log, severity breakdown, and disclaimer sections.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            previewRow("Property details", value: stormCase.clientName)
            previewRow("Storm event", value: "\(stormCase.stormTypeValue.displayName), \(StormDateFormatter.dateOnly.string(from: stormCase.stormDate))")
            previewRow("Damage evidence", value: "\(findings.filter(\.userApproved).count) approved finding(s)")
            previewRow("Photo log", value: "\(photos.count) photo(s)")
            previewRow("Insurance disclaimer", value: "Included")
            previewRow("Signature placeholder", value: "Included")
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func previewRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct UpgradeBanner: View {
    var title: String = "Unlock professional reports"
    var subtitle: String = "Add branded PDFs, repair priorities, and advanced report formats."
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.orange)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color = AppTheme.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
