import AppIntents
import Observation
import SwiftUI
import UIKit
import UserNotifications

@main
struct LiftLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .task { await RestNotifier.requestAuthorization() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.reload()
            // Brings the Live Activity back if it was dismissed mid-workout.
            Task { await WorkoutEngine.sync() }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show the "Rest over" banner even when the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@MainActor
@Observable
final class AppModel {
    var routines: [Routine] = []
    var active: ActiveWorkout?
    var history: [CompletedWorkout] = []
    var unit: WeightUnit = .lb

    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(forName: .workoutDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        routines = WorkoutStore.routines
        active = WorkoutStore.active
        history = WorkoutStore.history
        unit = WorkoutStore.unit
    }
}

/// Lets you say "Log a set in LiftLog" or use these from the Shortcuts app and Action button.
struct LiftLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogSetIntent(),
                    phrases: ["Log a set in \(.applicationName)"],
                    shortTitle: "Log Set", systemImageName: "checkmark.circle")
        AppShortcut(intent: SkipRestIntent(),
                    phrases: ["Skip rest in \(.applicationName)"],
                    shortTitle: "Skip Rest", systemImageName: "forward.fill")
        AppShortcut(intent: NextExerciseIntent(),
                    phrases: ["Next exercise in \(.applicationName)"],
                    shortTitle: "Next Exercise", systemImageName: "arrow.right.circle")
    }
}
