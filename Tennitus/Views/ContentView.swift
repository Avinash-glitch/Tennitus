import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "checkmark.circle")
            }

            NavigationStack {
                TrendsView()
            }
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SoundsView()
            }
            .tabItem {
                Label("Sounds", systemImage: "waveform")
            }

            NavigationStack {
                ReportsView()
            }
            .tabItem {
                Label("Reports", systemImage: "doc.text")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(TennitusStyle.primary)
        .preferredColorScheme(.light)
    }
}
