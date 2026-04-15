import SwiftUI
import BackgroundTasks
import WidgetKit

@main
struct FuelTrackerApp: App {
    let persistence = PersistenceController.shared

    @StateObject private var stationsVM = StationsViewModel()
    @StateObject private var settingsVM = SettingsViewModel()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .environmentObject(stationsVM)
                .environmentObject(settingsVM)
                .preferredColorScheme(.dark)
                .task {
                    // Kick off an initial refresh when the app first appears.
                    await stationsVM.refresh(settings: settingsVM.currentSettings)
                }
        }
    }

    // MARK: - Background refresh

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Config.backgroundRefreshTaskID,
            using: nil
        ) { [self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(task: refreshTask)
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleNextBackgroundRefresh()

        let handle = Task {
            do {
                guard let coord = AppGroupStore.lastKnownCoordinate else {
                    task.setTaskCompleted(success: false)
                    return
                }
                let settings = UserSettings(
                    carMPG:            AppGroupStore.userMPG,
                    fillUpLitres:      AppGroupStore.userFillLitres,
                    essoDiscountPence: AppGroupStore.nearestEssoDiscountPence
                )
                _ = try await FuelPriceService.shared.refreshPrices(for: coord, settings: settings)
                WidgetCenter.shared.reloadAllTimelines()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = { handle.cancel() }
    }

    func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Config.backgroundRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
