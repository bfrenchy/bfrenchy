# LiftLog

A small iPhone companion for your workouts. Track sets, weight, reps and rest time from:

- **Lock Screen and Dynamic Island** (Live Activity): rest countdown, weight and rep +/-, log set, skip rest
- **Home screen widget** (small and medium): start a routine, log sets, adjust weight and reps, start/extend/skip rest
- **Siri / Shortcuts / Action button**: "Log a set in LiftLog", "Skip rest in LiftLog", "Next exercise in LiftLog"

A "Rest over" notification fires when the timer ends, even with the phone locked.

It does not connect to Pump Club. Enter your program's exercises once in the Routines tab; weights you use are remembered for next time.

## Install on your iPhone

You need a Mac with Xcode 16 or newer and an iPhone on iOS 17 or newer.

1. Install XcodeGen: `brew install xcodegen`
2. In this folder run `xcodegen generate`, then open `LiftLog.xcodeproj`.
3. In Xcode, select the **LiftLog** target, then **Signing & Capabilities**, and pick your Team (your Apple ID works). Do the same for the **LiftLogWidget** target.
4. If Xcode says the bundle ID is unavailable, change `APP_BUNDLE_ID` in `project.yml` to something unique (for example `com.yourname.liftlog`) and run `xcodegen generate` again.
5. Plug in your iPhone, turn on Developer Mode (Settings > Privacy & Security), choose it as the run destination and press Run.
6. Allow notifications when asked. Long-press the home screen, tap **Edit > Add Widget**, and add **LiftLog**.

With a free Apple ID, apps you install this way stop launching after 7 days; press Run in Xcode again to renew. A paid developer account removes that limit.

## How it fits together

| Folder | What's in it |
| --- | --- |
| `Shared/` | Workout model, App Group storage, the App Intents every button uses, and `WorkoutEngine`, which updates the Live Activity, widgets and rest notification after each change |
| `App/` | The app: start a routine, run the workout, edit routines, view history |
| `Widget/` | Home screen widget and Live Activity UI |

Button taps on the widget and Live Activity run as `LiveActivityIntent`s, which iOS executes in the app's process in the background, so the app never needs to come to the foreground.
