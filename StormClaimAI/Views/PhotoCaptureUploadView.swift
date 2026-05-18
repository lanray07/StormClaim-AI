import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PhotoCaptureUploadView: View {
    let stormCase: StormCase

    @Environment(\.modelContext) private var modelContext
    @Query private var photos: [StormPhoto]
    @StateObject private var viewModel = PhotoCaptureViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCameraUnavailable = false

    init(stormCase: StormCase) {
        self.stormCase = stormCase
        let caseID = stormCase.id
        _photos = Query(filter: #Predicate<StormPhoto> { $0.caseId == caseID }, sort: \StormPhoto.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Photo label", selection: $viewModel.selectedLabel) {
                        ForEach(PhotoLabel.allCases) { label in
                            Text(label.displayName).tag(label)
                        }
                    }

                    TextField("Caption or location note", text: $viewModel.caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2, reservesSpace: true)

                    HStack {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                            Label("Upload Photos", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.orange)

                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                viewModel.isCameraPresented = true
                            } else {
                                showCameraUnavailable = true
                            }
                        } label: {
                            Image(systemName: "camera.fill")
                                .frame(width: 48, height: 36)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if viewModel.isLoading {
                    ProgressView("Importing photos...")
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                if photos.isEmpty {
                    EmptyStateView(
                        systemImage: "photo.badge.plus",
                        title: "No photos yet",
                        message: "Upload or capture photos, then tag the damage type and location before running the AI scan."
                    )
                } else {
                    ForEach(photos) { photo in
                        StormPhotoCard(photo: photo)
                    }
                }

                Text("Do not climb roofs or take unsafe photos. Use ground-level, interior, or professional inspection imagery where appropriate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Photos")
        .sheet(isPresented: $viewModel.isCameraPresented) {
            CameraPicker { image in
                viewModel.addUIImage(image, to: stormCase, modelContext: modelContext)
            }
            .ignoresSafeArea()
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use photo upload on this device or simulator.")
        }
        .onChange(of: pickerItems) { _, newItems in
            Task {
                await viewModel.loadPhotoItems(newItems, to: stormCase, modelContext: modelContext)
                pickerItems = []
            }
        }
    }
}
