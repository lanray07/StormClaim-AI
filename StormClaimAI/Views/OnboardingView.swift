import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("StormClaim AI")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.navy)
                        Text("Storm damage documentation for contractors, property teams, homeowners, and claim-support workflows.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose user type")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            ForEach(UserType.allCases) { userType in
                                Button {
                                    viewModel.selectedUserType = userType
                                } label: {
                                    Text(userType.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                }
                                .buttonStyle(.bordered)
                                .tint(viewModel.selectedUserType == userType ? AppTheme.orange : .secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Safety and insurance disclaimer", systemImage: "exclamationmark.shield.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.orange)

                        ForEach(SafetyCopy.disclaimers, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Toggle("I understand and accept these limitations.", isOn: $viewModel.acceptedSafetyDisclaimer)
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 8)
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        onComplete()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.orange)
                    .disabled(!viewModel.acceptedSafetyDisclaimer)
                }
                .padding()
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
        }
    }
}
