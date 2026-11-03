import Foundation
import WidgetKit
#if !WIDGET_EXTENSION
import ActivityKit
import UserNotifications
#endif

/// Every change to the workout goes through here, whether it comes from the app,
/// a home screen widget button, a Live Activity button or Siri.
@MainActor
enum WorkoutEngine {
    static func start(routineID: UUID) async {
        guard let routine = WorkoutStore.routines.first(where: { $0.id == routineID }),
              !routine.exercises.isEmpty else { return }
        WorkoutStore.active = ActiveWorkout(routine: routine)
        await sync()
    }

    static func logSet() async { await mutate { $0.logSet() } }
    static func adjustWeight(steps: Int) async {
        let step = WorkoutStore.unit.step
        await mutate { $0.currentWeight = max(0, $0.currentWeight + Double(steps) * step) }
    }
    static func adjustReps(steps: Int) async { await mutate { $0.currentReps = max(1, $0.currentReps + steps) } }
    static func startRest() async { await mutate { $0.startRest(seconds: $0.current.restSeconds) } }
    static func addRest(seconds: Int) async { await mutate { $0.addRest(seconds: seconds) } }
    static func skipRest() async { await mutate { $0.skipRest() } }
    static func select(_ index: Int) async { await mutate { $0.select(index) } }
    static func nextExercise() async { await mutate { $0.select(($0.currentIndex + 1) % $0.exercises.count) } }

    static func end() async {
        if let w = WorkoutStore.active {
            if !w.sets.isEmpty {
                var history = WorkoutStore.history
                history.insert(CompletedWorkout(routineName: w.routineName, startedAt: w.startedAt,
                                                endedAt: .now, sets: w.sets), at: 0)
                WorkoutStore.history = history
            }
            // Carry the weights you used back into the routine for next time.
            var routines = WorkoutStore.routines
            if let r = routines.firstIndex(where: { $0.id == w.routineID }) {
                for ex in w.exercises {
                    if let e = routines[r].exercises.firstIndex(where: { $0.id == ex.id }) {
                        routines[r].exercises[e].weight = ex.weight
                    }
                }
                WorkoutStore.routines = routines
            }
        }
        WorkoutStore.active = nil
        await sync()
    }

    private static func mutate(_ change: (inout ActiveWorkout) -> Void) async {
        guard var w = WorkoutStore.active else { return }
        change(&w)
        WorkoutStore.active = w
        await sync()
    }

    /// Push the current state to the Live Activity, rest notification and widgets.
    static func sync() async {
        let workout = WorkoutStore.active
        #if !WIDGET_EXTENSION
        await LiveActivityController.sync(workout, unit: WorkoutStore.unit)
        RestNotifier.schedule(for: workout)
        #endif
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .workoutDidChange, object: nil)
    }
}

#if !WIDGET_EXTENSION
@MainActor
enum LiveActivityController {
    static func sync(_ workout: ActiveWorkout?, unit: WeightUnit) async {
        let activities = Activity<WorkoutActivityAttributes>.activities

        guard let workout else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let state = WorkoutActivityAttributes.ContentState(workout, unit: unit)
        // Marking the content stale when rest ends lets the Live Activity switch to "Go".
        let content = ActivityContent(state: state, staleDate: state.restEnd)

        if let activity = activities.first {
            await activity.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = WorkoutActivityAttributes(routineName: workout.routineName,
                                                       startedAt: workout.startedAt)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }
}

enum RestNotifier {
    private static let id = "rest-timer"

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Buzz when the rest timer runs out, even with the phone locked.
    static func schedule(for workout: ActiveWorkout?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let workout, let end = workout.restEndsAt else { return }
        let interval = end.timeIntervalSinceNow
        guard interval > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "\(workout.current.name): set \(workout.nextSetNumber), "
            + "\(workout.currentWeight.weightText) \(WorkoutStore.unit.rawValue) x \(workout.currentReps)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
#endif
