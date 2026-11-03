import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setNumber: Int
        var targetSets: Int
        var exerciseNumber: Int
        var exerciseCount: Int
        var weight: Double
        var reps: Int
        var unit: String
        var setsLogged: Int
        var restStart: Date?
        var restEnd: Date?
    }

    var routineName: String
    var startedAt: Date
}

extension WorkoutActivityAttributes.ContentState {
    init(_ w: ActiveWorkout, unit: WeightUnit) {
        exerciseName = w.current.name
        setNumber = w.nextSetNumber
        targetSets = w.current.targetSets
        exerciseNumber = w.currentIndex + 1
        exerciseCount = w.exercises.count
        weight = w.currentWeight
        reps = w.currentReps
        self.unit = unit.rawValue
        setsLogged = w.sets.count
        if w.isResting() {
            restStart = w.restStartedAt
            restEnd = w.restEndsAt
        }
    }
}
