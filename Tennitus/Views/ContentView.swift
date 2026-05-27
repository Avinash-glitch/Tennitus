import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .today

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tag(AppTab.today)

            NavigationStack {
                TrendsView()
            }
            .tag(AppTab.trends)

            NavigationStack {
                SoundsView()
            }
            .tag(AppTab.sounds)

            NavigationStack {
                ReportsView()
            }
            .tag(AppTab.reports)

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.profile)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 82)
        }
        .overlay(alignment: .bottom) {
            ClinicalBottomNav(selection: $selectedTab)
        }
        .preferredColorScheme(.dark)
    }
}
