import SwiftUI

struct ContentView: View {
    @EnvironmentObject var stationsVM: StationsViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StationMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(0)

            BestPickView()
                .tabItem { Label("Best Pick", systemImage: "star.fill") }
                .tag(1)

            StationsListView()
                .tabItem { Label("Stations", systemImage: "fuelpump.fill") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(StationsViewModel())
        .environmentObject(SettingsViewModel())
        .preferredColorScheme(.dark)
}
