import SwiftData
import SwiftUI

struct NewCaseView: View {
    let aiService: any AIService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \StormCase.createdAt, order: .reverse) private var cases: [StormCase]
    @StateObject private var viewModel = NewCaseViewModel()
    @State private var showPaywall = false

    var body: some View {
        Form {
            if !subscriptionManager.canCreateCase(existingCases: cases) {
                Section {
                    UpgradeBanner(
                        title: "Free case limit reached",
                        subtitle: "Free includes 2 cases per month. Upgrade for unlimited storm cases."
                    ) {
                        showPaywall = true
                    }
                }
            }

            Section("Property and client") {
                TextField("Property address", text: $viewModel.propertyAddress, axis: .vertical)
                TextField("Client name", text: $viewModel.clientName)
            }

            Section("Storm event") {
                DatePicker("Storm date", selection: $viewModel.stormDate, displayedComponents: [.date])
                Picker("Storm type", selection: $viewModel.stormType) {
                    ForEach(StormType.allCases) { stormType in
                        Text(stormType.displayName).tag(stormType)
                    }
                }
            }

            Section("Insurance reference") {
                TextField("Insurance company", text: $viewModel.insuranceCompany)
                TextField("Policy/reference number optional", text: $viewModel.policyReference)
            }

            Section("Case notes") {
                TextField("Access notes, observed damage, safety limitations", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section {
                Label(SafetyCopy.shortDisclaimer, systemImage: "exclamationmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("New Case")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.createCase(in: modelContext) != nil {
                        dismiss()
                    }
                }
                .disabled(!viewModel.canSave || !subscriptionManager.canCreateCase(existingCases: cases))
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
    }
}
