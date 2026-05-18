import SwiftData
import SwiftUI

struct EvidenceOrganizerView: View {
    let stormCase: StormCase

    @Environment(\.modelContext) private var modelContext
    @Query private var photos: [StormPhoto]
    @StateObject private var viewModel = EvidenceOrganizerViewModel()

    init(stormCase: StormCase) {
        self.stormCase = stormCase
        let caseID = stormCase.id
        _photos = Query(filter: #Predicate<StormPhoto> { $0.caseId == caseID }, sort: \StormPhoto.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Group photos by area, add captions, timestamps, before/after notes, and evidence status.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                if photos.isEmpty {
                    EmptyStateView(
                        systemImage: "square.grid.2x2",
                        title: "No evidence to organise",
                        message: "Add case photos before building the evidence log."
                    )
                } else {
                    ForEach(groupedPhotoLabels, id: \.self) { label in
                        EvidenceGroupView(
                            title: label.displayName,
                            photos: photos.filter { $0.labelValue == label }
                        )
                    }

                    Button {
                        viewModel.save(modelContext)
                    } label: {
                        Label("Save Evidence Updates", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.orange)
                }
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Evidence")
    }

    private var groupedPhotoLabels: [PhotoLabel] {
        PhotoLabel.allCases.filter { label in
            photos.contains { $0.labelValue == label }
        }
    }
}
