import Foundation
import SwiftData
import SwiftUI

@main
struct StormClaimAIApp: App {
    @StateObject private var subscriptionManager: SubscriptionManager

    private let modelContainer: ModelContainer
    private let aiService: any AIService

    init() {
        #if DEBUG
        let mockSubscriptions = ProcessInfo.processInfo.arguments.contains("-MockSubscriptions")
        #else
        let mockSubscriptions = false
        #endif

        _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(mockMode: mockSubscriptions))
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
