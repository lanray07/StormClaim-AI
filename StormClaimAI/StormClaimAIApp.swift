import SwiftData
import SwiftUI

@main
struct StormClaimAIApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager(mockMode: true)

    private let modelContainer: ModelContainer
    private let aiService: any AIService

    init() {
        aiService = MockAIService()

        do {
            modelContainer = try ModelContainer(
                for: StormCase.self,
                StormPhoto.self,
                DamageFinding.self,
                StormReport.self,
                SubscriptionState.self,
                configurations: ModelConfiguration("StormClaimAI")
            )
        } catch {
            fatalError("Unable to initialise StormClaim AI storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(aiService: aiService)
                .environmentObject(subscriptionManager)
                .modelContainer(modelContainer)
        }
    }
}
