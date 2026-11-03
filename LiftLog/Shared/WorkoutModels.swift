import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case lb, kg

    var id: String { rawValue }

    /// How much one tap of +/- changes the weight.
    var step: Double { self == .lb ? 5 : 2.5 }
}

struct ExercisePlan: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var targetSets: Int
    var targetReps: Int
    var weight: Double
    var restSeconds: Int
}

struct Routine: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var exercises: [ExercisePlan]
}

struct LoggedSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: UUID
    var exerciseName: String
    var weight: Double
    var reps: Int
    var date: Date
}

struct CompletedWorkout: Codable, Identifiable, Hashable {
    var id = UUID()
    var routineName: String
    var startedAt: Date
    var endedAt: Date
    var sets: [LoggedSet]

    var volume: Double { sets.reduce(0) { $0 + $1.weight * Double($1.reps) } }
}

/// The workout currently in progress. Shared by the app, the widget and the Live Activity.
struct ActiveWorkout: Codable, Hashable {
    var routineID: UUID
    var routineName: String
    var startedAt: Date
    var exercises: [ExercisePlan]
    var currentIndex: Int
    var currentWeight: Double
    var currentReps: Int
    var sets: [LoggedSet]
    var restStartedAt: Date?
    var restEndsAt: Date?

    init(routine: Routine, now: Date = .now) {
        routineID = routine.id
        routineName = routine.name
        startedAt = now
        exercises = routine.exercises
        currentIndex = 0
        currentWeight = routine.exercises.first?.weight ?? 0
        currentReps = routine.exercises.first?.targetReps ?? 0
        sets = []
    }

    var current: ExercisePlan { exercises[min(currentIndex, exercises.count - 1)] }

    func setsDone(at index: Int) -> Int {
        let id = exercises[index].id
        return sets.filter { $0.exerciseID == id }.count
    }

    var nextSetNumber: Int { setsDone(at: currentIndex) + 1 }

    var isFinished: Bool {
        exercises.indices.allSatisfy { setsDone(at: $0) >= exercises[$0].targetSets }
    }

    func isResting(at date: Date = .now) -> Bool {
        guard let end = restEndsAt else { return false }
        return end > date
    }

    mutating func select(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentIndex = index
        currentWeight = exercises[index].weight
        currentReps = exercises[index].targetReps
    }

    mutating func logSet(now: Date = .now) {
        let exercise = current
        sets.append(LoggedSet(exerciseID: exercise.id, exerciseName: exercise.name,
                              weight: currentWeight, reps: currentReps, date: now))
        // Remember the weight you actually used for next time.
        exercises[currentIndex].weight = currentWeight

        if setsDone(at: currentIndex) >= exercise.targetSets,
           let next = exercises.indices.first(where: { $0 > currentIndex && setsDone(at: $0) < exercises[$0].targetSets }) {
            select(next)
        }
        startRest(seconds: exercise.restSeconds, now: now)
    }

    mutating func startRest(seconds: Int, now: Date = .now) {
        restStartedAt = now
        restEndsAt = now.addingTimeInterval(TimeInterval(seconds))
    }

    mutating func addRest(seconds: Int, now: Date = .now) {
        if let end = restEndsAt, end > now {
            restEndsAt = end.addingTimeInterval(TimeInterval(seconds))
        } else {
            startRest(seconds: seconds, now: now)
        }
    }

    mutating func skipRest() {
        restStartedAt = nil
        restEndsAt = nil
    }
}

// MARK: - Formatting

extension Double {
    var weightText: String { formatted(.number.precision(.fractionLength(0...1))) }
}

func restText(_ seconds: Int) -> String {
    seconds >= 60 ? String(format: "%d:%02d", seconds / 60, seconds % 60) : "\(seconds)s"
}

// MARK: - Starter routines (edit these in the app to match your program)

extension Routine {
    static let samples: [Routine] = [
        Routine(name: "Push", exercises: [
            ExercisePlan(name: "Bench Press", targetSets: 4, targetReps: 8, weight: 135, restSeconds: 120),
            ExercisePlan(name: "Overhead Press", targetSets: 3, targetReps: 8, weight: 85, restSeconds: 90),
            ExercisePlan(name: "Incline DB Press", targetSets: 3, targetReps: 10, weight: 50, restSeconds: 90),
            ExercisePlan(name: "Lateral Raise", targetSets: 3, targetReps: 15, weight: 20, restSeconds: 60),
            ExercisePlan(name: "Triceps Pushdown", targetSets: 3, targetReps: 12, weight: 50, restSeconds: 60),
        ]),
        Routine(name: "Pull", exercises: [
            ExercisePlan(name: "Barbell Row", targetSets: 4, targetReps: 8, weight: 135, restSeconds: 120),
            ExercisePlan(name: "Lat Pulldown", targetSets: 3, targetReps: 10, weight: 120, restSeconds: 90),
            ExercisePlan(name: "Seated Cable Row", targetSets: 3, targetReps: 10, weight: 110, restSeconds: 90),
            ExercisePlan(name: "Face Pull", targetSets: 3, targetReps: 15, weight: 40, restSeconds: 60),
            ExercisePlan(name: "Biceps Curl", targetSets: 3, targetReps: 12, weight: 30, restSeconds: 60),
        ]),
        Routine(name: "Legs", exercises: [
            ExercisePlan(name: "Back Squat", targetSets: 4, targetReps: 6, weight: 185, restSeconds: 150),
            ExercisePlan(name: "Romanian Deadlift", targetSets: 3, targetReps: 8, weight: 155, restSeconds: 120),
            ExercisePlan(name: "Leg Press", targetSets: 3, targetReps: 12, weight: 270, restSeconds: 90),
            ExercisePlan(name: "Leg Curl", targetSets: 3, targetReps: 12, weight: 90, restSeconds: 60),
            ExercisePlan(name: "Calf Raise", targetSets: 4, targetReps: 15, weight: 135, restSeconds: 60),
        ]),
    ]
}
