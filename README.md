# The Workout Log – Workout Tracker (v1.0)

A simple, local-first iOS workout logging app built with **SwiftUI** and **UserDefaults** persistence. Track workouts, log sets in lbs, manage rest timers, and use the persistent pull-up session view for quick access during lifts.

No cloud sync, no subscriptions, no external dependencies — just pure offline tracking for your workouts.

## Features

- **Login / Signup** (mock/local for now)
- **Home Dashboard**
  - Weekly workout summary
  - List of saved workouts with swipe-to-delete and rename
- **Workout Planning**
  - Create new workouts
  - Add exercises from library with recommended sets & reps range (e.g. 3 sets × 8-12)
  - Remove exercises from workouts
- **Exercise Library**
  - Pre-loaded with 60+ common lifts
  - Add your own custom exercises locally
- **In-Workout Mode**
  - Start/stop workout
  - Persistent bottom pull-up bar showing current workout
  - Pull-up sheet with:
    - Live rest timer countdown + cancel button
    - Collapsible sections per exercise showing logged sets (weight × reps)
    - Add new sets directly (opens log form)
    - Swipe-to-delete individual sets
- **Set Logging**
  - Weight (lbs), reps, rest time
  - Sets saved per exercise in the workout session
- **Offline-First**
  - All data stored locally via UserDefaults + JSON
  - Survives app close/reopen
  ## Screenshots

TODO:
(Add screenshots here – drag images into the repo root or `images/` folder)

![Home Screen](images/home.png)  
*Home with workouts and weekly summary*

![Workout Detail](images/workout-detail.png)  
*Workout planning + recommended sets/reps*

![Pull-Up Sheet](images/pullup-sheet.png)  
*Active session pull-up view with rest timer and collapsible sets*

![Logging Set](images/log-set.png)  
*Quick set logging in lbs*

## Requirements

- Xcode 16+
- iOS 17.0+
- No external packages (pure SwiftUI + Foundation)

## How to Build & Run

1. Clone the repo:
   ```bash
   git clone https://github.com/cianfrocco4/FitLog.git
   cd FitLog

Open in Xcode:Bashopen FitLog.xcodeproj
Select a simulator or device → Build & Run (⌘R)
First launch: Login with any email/password (mock auth for now)

Known Limitations (v1.0)

No cloud sync (planned for v2.0)
No progress tracking/charts/PRs
No Apple Watch support
No photo uploads for body measurements
Rest timer is local-only (notification + live countdown, but no background persistence)

Planned for v2.0+

Firebase cloud sync
Progress charts & PR tracking
Apple Watch companion
Body measurements + photo tracking
Grok AI suggestions in-app

Contributing
Feel free to open issues or PRs for bug fixes, features, or polish.
