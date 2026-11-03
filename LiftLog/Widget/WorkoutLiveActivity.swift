import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenWorkoutView(context: context)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let rest = RestWindow(state: state, isStale: context.isStale)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.exerciseName).font(.headline).lineLimit(1)
                        Text("Set \(state.setNumber)/\(state.targetSets)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestLabel(rest: rest)
                        .font(.title3.weight(.semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityControls(state: state, resting: rest.isActive)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(.tint)
            } compactTrailing: {
                if let range = rest.range {
                    Text(timerInterval: range, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                        .foregroundStyle(.orange)
                } else {
                    Text("\(state.setNumber)/\(state.targetSets)")
                }
            } minimal: {
                if let range = rest.range {
                    ProgressView(timerInterval: range, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: "timer")
                    }
                    .progressViewStyle(.circular)
                    .tint(.orange)
                } else {
                    Image(systemName: "dumbbell.fill")
                }
            }
        }
    }
}

/// The rest period, if one is still running.
struct RestWindow {
    let range: ClosedRange<Date>?

    init(state: WorkoutActivityAttributes.ContentState, isStale: Bool) {
        if !isStale, let start = state.restStart, let end = state.restEnd, end > .now, start <= end {
            range = start...end
        } else {
            range = nil
        }
    }

    var isActive: Bool { range != nil }
}

struct RestLabel: View {
    let rest: RestWindow

    var body: some View {
        if let range = rest.range {
            Text(timerInterval: range, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.orange)
        } else {
            Text("Go")
                .foregroundStyle(.green)
        }
    }
}

struct LockScreenWorkoutView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let state = context.state
        let rest = RestWindow(state: state, isStale: context.isStale)

        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routineName.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Set \(state.setNumber) of \(state.targetSets) · Exercise \(state.exerciseNumber)/\(state.exerciseCount)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    RestLabel(rest: rest)
                        .font(.title.weight(.semibold))
                    Text(rest.isActive ? "rest" : "next set")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if let range = rest.range {
                ProgressView(timerInterval: range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(.orange)
            }

            ActivityControls(state: state, resting: rest.isActive)
        }
        .foregroundStyle(.white)
    }
}

struct ActivityControls: View {
    let state: WorkoutActivityAttributes.ContentState
    let resting: Bool

    var body: some View {
        HStack(spacing: 6) {
            stepper(value: state.weight.weightText, unit: state.unit,
                    minus: AdjustWeightIntent(steps: -1), plus: AdjustWeightIntent(steps: 1))
            stepper(value: "\(state.reps)", unit: "reps",
                    minus: AdjustRepsIntent(steps: -1), plus: AdjustRepsIntent(steps: 1))
            if resting {
                pill(SkipRestIntent(), systemImage: "forward.fill", tint: .orange)
            }
            Button(intent: LogSetIntent()) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 36)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ intent: some AppIntent, systemImage: String, tint: Color) -> some View {
        Button(intent: intent) {
            Image(systemName: systemImage)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    private func stepper(value: String, unit: String, minus: some AppIntent, plus: some AppIntent) -> some View {
        HStack(spacing: 0) {
            Button(intent: minus) {
                Image(systemName: "minus").frame(width: 26, height: 36)
            }
            .buttonStyle(.plain)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(.subheadline, design: .rounded).weight(.bold)).monospacedDigit()
                Text(unit).font(.caption2).opacity(0.6)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            Button(intent: plus) {
                Image(systemName: "plus").frame(width: 26, height: 36)
            }
            .buttonStyle(.plain)
        }
        .font(.caption.weight(.bold))
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
    }
}
