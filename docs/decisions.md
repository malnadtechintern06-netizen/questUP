# QuestUP Architectural Decision Records (ADR)

## ADR 1: Feature-First Clean Architecture
- **Decision**: Structure the codebase by feature (`features/profile/`, `features/quests/`, etc.) with sub-layers `domain/`, `data/`, and `presentation/`.
- **Rationale**: Isolates domain logic from UI and hardware APIs, facilitates independent feature scaling, and makes the project maintainable for multi-developer teams.

## ADR 2: Riverpod State Management
- **Decision**: Use `flutter_riverpod` with `StateNotifierProvider`, `Provider`, and `FutureProvider`.
- **Rationale**: Compile-time safety, seamless dependency injection, reactive data flow, and no requirement for BuildContext when reading pure domain use cases.

## ADR 3: GoRouter for Declarative Navigation
- **Decision**: Use `go_router` with `ShellRoute` for the 5-tab main application navigation, and pushed routes for `QuestDetailScreen` and `QuestVerificationScreen`.
- **Rationale**: Clean URL routing, deep linking readiness, declarative transitions, and separated navigation logic.

## ADR 4: Offline-First Local Persistence Strategy
- **Decision**: Store user profiles, quests, completions, achievements, and leaderboard in structured JSON key-value stores using `SharedPreferences` abstracted behind Clean Architecture repository interfaces.
- **Rationale**: Meets the V1 zero-paid-backend constraint while ensuring 100% offline usability. The domain layer depends only on abstract repositories, allowing seamless addition of Cloud Firestore / Firebase in future versions without altering presentation code.

## ADR 5: Hardware Simulation Support
- **Decision**: Provide fallback simulation mechanisms for GPS and camera capture in `LocationService` and `CameraService`.
- **Rationale**: Allows smooth execution, automated testing, and developer verification on emulators, desktop environments, and web browsers without requiring physical GPS movements.
