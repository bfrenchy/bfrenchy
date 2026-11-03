import Foundation

/// Persists everything in an App Group so the app, widget and Live Activity all see the same data.
enum WorkoutStore {
    static let groupID: String =
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? "group.com.benfrench.liftlog"

    static let defaults: UserDefaults = UserDefaults(suiteName: groupID) ?? .standard

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static var routines: [Routine] {
        get { load("routines") ?? Routine.samples }
        set { save(newValue, "routines") }
    }

    static var active: ActiveWorkout? {
        get { load("active") }
        set { save(newValue, "active") }
    }

    static var history: [CompletedWorkout] {
        get { load("history") ?? [] }
        set { save(newValue, "history") }
    }

    static var unit: WeightUnit {
        get { WeightUnit(rawValue: defaults.string(forKey: "unit") ?? "") ?? .lb }
        set { defaults.set(newValue.rawValue, forKey: "unit") }
    }
}

extension Notification.Name {
    static let workoutDidChange = Notification.Name("LiftLogWorkoutDidChange")
}
