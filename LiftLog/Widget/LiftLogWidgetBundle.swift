import SwiftUI
import WidgetKit

@main
struct LiftLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutWidget()
        WorkoutLiveActivity()
    }
}
