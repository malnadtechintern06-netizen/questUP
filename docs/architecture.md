# QuestUP Architecture Documentation

## Architectural Pattern
QuestUP is engineered using **Feature-First Clean Architecture** with the **Repository Pattern**, **Riverpod State Management**, and **GoRouter Navigation**.

### Dependency Direction
```
Presentation Layer  ──>  Domain Layer  <──  Data Layer
     (UI & State)         (Entities &        (DataSources &
                          UseCases)          Repository Impls)
```
- **Rule**: The Presentation layer never accesses Data Sources or Infrastructure directly.
- **Rule**: Domain entities and use cases are pure Dart objects independent of Flutter UI and third-party database frameworks.

---

## Directory Organization
```
lib/
├── app/
│   ├── config/              # App constants, game rules, storage keys
│   ├── router/              # GoRouter configuration, route paths, route names
│   ├── theme/               # Dark fantasy/adventure palette, typography, ThemeData
│   └── app.dart             # Root MaterialApp.router widget
├── core/
│   ├── constants/           # Core constants
│   ├── errors/              # Custom Exceptions & Failures
│   ├── services/            # Hardware wrappers (LocationService, CameraService)
│   ├── storage/             # LocalStorageService (SharedPreferences / JSON cache)
│   ├── utils/               # DistanceCalculator (Haversine geofence formula)
│   └── widgets/             # Reusable UI components (CustomButton, AnimatedXpBar, RewardDialog, etc.)
└── features/
    ├── profile/             # Player profile, avatar customization, stats
    ├── quests/              # Quests catalogue, radar scanner, details & filters
    ├── verification/        # Geofence checker, camera proof capture, reward engine
    ├── achievements/        # Badges vault & automatic unlock rule engine
    └── leaderboard/         # Global rankings, weekly leagues, top 3 podium
```

---

## Key Design Patterns & Subsystems

1. **State Management (Riverpod)**:
   - `userProfileNotifierProvider`: Reactive player profile with level up calculations.
   - `questsNotifierProvider`: Live nearby quests list with GPS proximity calculations.
   - `verificationNotifierProvider`: GPS geofence verifier and camera proof evaluator.
   - `achievementsNotifierProvider`: Trophy gallery and unlock state tracker.
   - `leaderboardEntriesProvider`: Real-time player rankings with dynamic user positioning.

2. **Hardware Integration & Simulators**:
   - `LocationService`: Connects to hardware GPS via `geolocator` with waypoint simulation tool for test environments.
   - `CameraService`: Connects to camera viewfinder via `image_picker` with sample photo proof generation.

3. **Offline-First Persistence**:
   - `LocalStorageService`: Persists player state, completions log, unlocked achievements, and quest status offline.
   - Decoupled via Repository interfaces to easily support a Firebase / Cloud Firestore remote backend without rewriting the UI.
