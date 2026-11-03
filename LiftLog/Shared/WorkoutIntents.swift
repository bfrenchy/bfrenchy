import AppIntents
import Foundation

// LiveActivityIntent makes iOS run these in the app's process, so a tap on the
// widget or Live Activity can update the Live Activity without opening the app.

struct StartWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var isDiscoverable = false

    @Parameter(title: "Routine ID") var routineID: String

    init() {}
    init(routineID: UUID) { self.routineID = routineID.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: routineID) { await WorkoutEngine.start(routineID: id) }
        return .result()
    }
}

struct LogSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set"
    static var description = IntentDescription("Logs the current set and starts the rest timer.")

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.logSet()
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.skipRest()
        return .result()
    }
}

struct StartRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Rest Timer"

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.startRest()
        return .result()
    }
}

struct AddRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add Rest Time"
    static var isDiscoverable = false

    @Parameter(title: "Seconds") var seconds: Int

    init() {}
    init(seconds: Int) { self.seconds = seconds }

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.addRest(seconds: seconds)
        return .result()
    }
}

struct AdjustWeightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Weight"
    static var isDiscoverable = false

    @Parameter(title: "Steps") var steps: Int

    init() {}
    init(steps: Int) { self.steps = steps }

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.adjustWeight(steps: steps)
        return .result()
    }
}

struct AdjustRepsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Reps"
    static var isDiscoverable = false

    @Parameter(title: "Steps") var steps: Int

    init() {}
    init(steps: Int) { self.steps = steps }

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.adjustReps(steps: steps)
        return .result()
    }
}

struct NextExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next Exercise"

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.nextExercise()
        return .result()
    }
}

struct EndWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Workout"

    func perform() async throws -> some IntentResult {
        await WorkoutEngine.end()
        return .result()
    }
}
