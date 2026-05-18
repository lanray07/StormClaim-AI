import SwiftUI

struct RootView: View {
    let aiService: any AIService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView(aiService: aiService)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

private struct MainTabView: View {
    let aiService: any AIService

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(aiService: aiService)
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            NavigationStack {
                SavedCasesView(aiService: aiService)
            }
            .tabItem {
                Label("Cases", systemImage: "folder.fill")
            }

            NavigationStack {
                PaywallView()
            }
            .tabItem {
                Label("Plan", systemImage: "creditcard.fill")
            }
        }
        .tint(AppTheme.orange)
    }
}
