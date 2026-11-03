import SwiftUI
import WidgetKit

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutTab()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
            RoutinesTab()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }
            HistoryTab()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
    }
}

// MARK: - Workout

struct WorkoutTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            if let workout = model.active {
                ActiveWorkoutView(workout: workout, unit: model.unit)
            } else {
                List {
                    Section {
                        ForEach(model.routines) { routine in
                            Button {
                                Task { await WorkoutEngine.start(routineID: routine.id) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(routine.name).font(.headline)
                                        Text("\(routine.exercises.count) exercises")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill").font(.title2)
                                }
                            }
                            .disabled(routine.exercises.isEmpty)
                        }
                    } footer: {
                        Text("Once started, add the LiftLog widget to your home screen or use the Lock Screen Live Activity to log sets without opening the app.")
                    }
                }
                .navigationTitle("Start Workout")
            }
        }
    }
}

struct ActiveWorkoutView: View {
    let workout: ActiveWorkout
    let unit: WeightUnit
    @State private var confirmEnd = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.current.name).font(.title2.bold())
                    Text("Set \(workout.nextSetNumber) of \(workout.current.targetSets)")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    BigStepper(value: workout.currentWeight.weightText, label: unit.rawValue,
                               minus: { await WorkoutEngine.adjustWeight(steps: -1) },
                               plus: { await WorkoutEngine.adjustWeight(steps: 1) })
                    BigStepper(value: "\(workout.currentReps)", label: "reps",
                               minus: { await WorkoutEngine.adjustReps(steps: -1) },
                               plus: { await WorkoutEngine.adjustReps(steps: 1) })
                }
                Button {
                    Task { await WorkoutEngine.logSet() }
                } label: {
                    Label("Log Set", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Rest") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let start = workout.restStartedAt, let end = workout.restEndsAt, end > context.date {
                        HStack {
                            Text(timerInterval: start...end, countsDown: true)
                                .font(.largeTitle.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("+30s") { Task { await WorkoutEngine.addRest(seconds: 30) } }
                                .buttonStyle(.bordered)
                            Button("Skip") { Task { await WorkoutEngine.skipRest() } }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        HStack {
                            Text("Ready").font(.title2.weight(.semibold)).foregroundStyle(.green)
                            Spacer()
                            Button("Rest \(restText(workout.current.restSeconds))") {
                                Task { await WorkoutEngine.startRest() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Exercises") {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    let done = workout.setsDone(at: index)
                    Button {
                        Task { await WorkoutEngine.select(index) }
                    } label: {
                        HStack {
                            Image(systemName: done >= exercise.targetSets ? "checkmark.circle.fill"
                                  : index == workout.currentIndex ? "circle.inset.filled" : "circle")
                                .foregroundStyle(done >= exercise.targetSets ? .green : .accentColor)
                            Text(exercise.name)
                            Spacer()
                            Text("\(done)/\(exercise.targetSets)").foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }

            if !workout.sets.isEmpty {
                Section("Logged") {
                    ForEach(workout.sets.reversed()) { set in
                        HStack {
                            Text(set.exerciseName)
                            Spacer()
                            Text("\(set.weight.weightText) \(unit.rawValue) × \(set.reps)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.routineName)
        .toolbar {
            Button("End", role: .destructive) { confirmEnd = true }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End and save", role: .destructive) { Task { await WorkoutEngine.end() } }
        }
    }
}

struct BigStepper: View {
    let value: String
    let label: String
    let minus: () async -> Void
    let plus: () async -> Void

    var body: some View {
        HStack {
            Button { Task { await minus() } } label: {
                Image(systemName: "minus").frame(width: 36, height: 44)
            }
            VStack(spacing: 0) {
                Text(value).font(.title2.weight(.bold)).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            Button { Task { await plus() } } label: {
                Image(systemName: "plus").frame(width: 36, height: 44)
            }
        }
        // Borderless keeps each button tappable on its own inside a List row.
        .buttonStyle(.borderless)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Routines

struct RoutinesTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                ForEach($model.routines) { $routine in
                    NavigationLink {
                        RoutineEditor(routine: $routine, unit: model.unit)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(routine.name).font(.headline)
                            Text(routine.exercises.map(\.name).joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .onDelete { model.routines.remove(atOffsets: $0) }
                .onMove { model.routines.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Unit", selection: $model.unit) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.routines.append(Routine(name: "New Routine", exercises: []))
                    } label: { Image(systemName: "plus") }
                }
            }
        }
        .onChange(of: model.routines) { _, new in
            WorkoutStore.routines = new
            WidgetCenterReload.now()
        }
        .onChange(of: model.unit) { _, new in
            WorkoutStore.unit = new
            Task { await WorkoutEngine.sync() }
        }
    }
}

struct RoutineEditor: View {
    @Binding var routine: Routine
    let unit: WeightUnit

    var body: some View {
        List {
            Section("Name") {
                TextField("Routine name", text: $routine.name)
            }
            Section("Exercises") {
                ForEach($routine.exercises) { $exercise in
                    NavigationLink {
                        ExerciseEditor(exercise: $exercise, unit: unit)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            Text("\(exercise.targetSets) × \(exercise.targetReps) @ \(exercise.weight.weightText) \(unit.rawValue) · rest \(restText(exercise.restSeconds))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { routine.exercises.remove(atOffsets: $0) }
                .onMove { routine.exercises.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    routine.exercises.append(ExercisePlan(name: "New Exercise", targetSets: 3,
                                                          targetReps: 10, weight: 0, restSeconds: 90))
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
            }
        }
        .navigationTitle(routine.name)
        .toolbar { EditButton() }
    }
}

struct ExerciseEditor: View {
    @Binding var exercise: ExercisePlan
    let unit: WeightUnit

    var body: some View {
        Form {
            TextField("Exercise name", text: $exercise.name)
            Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...12)
            Stepper("Reps: \(exercise.targetReps)", value: $exercise.targetReps, in: 1...50)
            HStack {
                Text("Weight")
                Spacer()
                TextField("0", value: $exercise.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                Text(unit.rawValue).foregroundStyle(.secondary)
            }
            Stepper("Rest: \(restText(exercise.restSeconds))", value: $exercise.restSeconds, in: 15...600, step: 15)
        }
        .navigationTitle(exercise.name)
    }
}

// MARK: - History

struct HistoryTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List(model.history) { workout in
                NavigationLink {
                    WorkoutDetail(workout: workout, unit: model.unit)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.routineName).font(.headline)
                        Text("\(workout.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(durationText(workout)) · \(workout.sets.count) sets")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if model.history.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "dumbbell",
                                           description: Text("Finished workouts show up here."))
                }
            }
            .navigationTitle("History")
        }
    }

    private func durationText(_ w: CompletedWorkout) -> String {
        Duration.seconds(w.endedAt.timeIntervalSince(w.startedAt))
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

struct WorkoutDetail: View {
    let workout: CompletedWorkout
    let unit: WeightUnit

    var body: some View {
        let names = workout.sets.map(\.exerciseName).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        List {
            Section {
                LabeledContent("Total volume", value: "\(workout.volume.weightText) \(unit.rawValue)")
                LabeledContent("Sets", value: "\(workout.sets.count)")
            }
            ForEach(names, id: \.self) { name in
                Section(name) {
                    ForEach(Array(workout.sets.filter { $0.exerciseName == name }.enumerated()), id: \.element.id) { i, set in
                        HStack {
                            Text("Set \(i + 1)")
                            Spacer()
                            Text("\(set.weight.weightText) \(unit.rawValue) × \(set.reps)").monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.routineName)
    }
}

enum WidgetCenterReload {
    static func now() { WidgetCenter.shared.reloadAllTimelines() }
}
