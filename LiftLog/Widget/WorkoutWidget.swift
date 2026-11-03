import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let workout: ActiveWorkout?
    let routines: [Routine]
    let unit: WeightUnit
}

struct WorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: .now, workout: ActiveWorkout(routine: Routine.samples[0]),
                     routines: Routine.samples, unit: .lb)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let now = Date.now
        var entries = [currentEntry(at: now)]
        // Add a second entry for the moment rest ends so the widget flips to "Go".
        if let end = WorkoutStore.active?.restEndsAt, end > now {
            entries.append(currentEntry(at: end))
        }
        completion(Timeline(entries: entries, policy: .never))
    }

    private func currentEntry(at date: Date) -> WorkoutEntry {
        WorkoutEntry(date: date, workout: WorkoutStore.active,
                     routines: WorkoutStore.routines, unit: WorkoutStore.unit)
    }
}

struct WorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorkoutWidget", provider: WorkoutProvider()) { entry in
            WorkoutWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Workout")
        .description("Log sets, adjust weight and reps, and run your rest timer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WorkoutWidgetView: View {
    let entry: WorkoutEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let w = entry.workout {
            if family == .systemSmall { small(w) } else { medium(w) }
        } else {
            idle
        }
    }

    // MARK: Idle: start a routine

    private var idle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Start workout", systemImage: "dumbbell.fill")
                .font(.headline)
            Spacer(minLength: 0)
            ForEach(entry.routines.prefix(family == .systemSmall ? 2 : 3)) { routine in
                Button(intent: StartWorkoutIntent(routineID: routine.id)) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(routine.name).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Small

    private func small(_ w: ActiveWorkout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(w.current.name)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("Set \(w.nextSetNumber)/\(w.current.targetSets) · \(w.currentWeight.weightText)\(entry.unit.rawValue) × \(w.currentReps)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let start = w.restStartedAt, let end = w.restEndsAt, end > entry.date {
                Button(intent: SkipRestIntent()) {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            logButton
        }
    }

    // MARK: Medium

    private func medium(_ w: ActiveWorkout) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(w.current.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("Set \(w.nextSetNumber)/\(w.current.targetSets)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                stepper(value: w.currentWeight.weightText, label: entry.unit.rawValue,
                        minus: AdjustWeightIntent(steps: -1), plus: AdjustWeightIntent(steps: 1))
                stepper(value: "\(w.currentReps)", label: "reps",
                        minus: AdjustRepsIntent(steps: -1), plus: AdjustRepsIntent(steps: 1))
            }

            HStack(spacing: 8) {
                restControl(w)
                logButton
            }
        }
    }

    @ViewBuilder
    private func restControl(_ w: ActiveWorkout) -> some View {
        if let start = w.restStartedAt, let end = w.restEndsAt, end > entry.date {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(timerInterval: start...end, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(intent: AddRestIntent(seconds: 30)) {
                    Text("+30").font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                Button(intent: SkipRestIntent()) {
                    Image(systemName: "forward.fill").font(.caption)
                }
                .buttonStyle(.plain)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        } else {
            Button(intent: StartRestIntent()) {
                Label("Rest \(restText(w.current.restSeconds))", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var logButton: some View {
        Button(intent: LogSetIntent()) {
            Label("Log set", systemImage: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(.tint, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func stepper(value: String, label: String, minus: some AppIntent, plus: some AppIntent) -> some View {
        HStack(spacing: 0) {
            Button(intent: minus) {
                Image(systemName: "minus").frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(.body, design: .rounded).weight(.bold)).monospacedDigit()
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            Button(intent: plus) {
                Image(systemName: "plus").frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline.weight(.semibold))
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview(as: .systemMedium) {
    WorkoutWidget()
} timeline: {
    WorkoutEntry(date: .now, workout: ActiveWorkout(routine: Routine.samples[0]),
                 routines: Routine.samples, unit: .lb)
    WorkoutEntry(date: .now, workout: nil, routines: Routine.samples, unit: .lb)
}
