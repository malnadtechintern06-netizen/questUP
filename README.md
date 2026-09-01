# QuestUP – Real World Quest Game 🗺️⚡

> A real-world adventure game where users discover and complete quests, explore locations, earn rewards, and level up.

Built with **Flutter & Dart** following the **Flutter Production Architecture Standard** (Clean Architecture + Feature-First + Riverpod + GoRouter + Offline-First Local Persistence).

---

## 🎮 Core Features

- 🌍 **Real-World Quests Discovery**: Explore nearby landmarks, nature trails, historical monuments, cultural spots, and urban mysteries.
- 📍 **GPS Geofence Verification**: Proximity calculations using the Haversine formula ensuring players physically reach the target location.
- 📷 **Camera Proof Capture**: Capture photos of the destination or submit verification proof.
- ⭐ **XP, Levels & Rewards**: Level up from Novice to Master with dynamic XP curve calculations, coin bounties, and reward celebrations.
- 🏆 **Leaderboard & Ranks**: Compete on the Top 3 Podium and global rankings.
- 🎖️ **Achievements & Trophy Vault**: Unlock achievements based on quest completions, level milestones, and coin milestones.
- 🧙 **Explorer Profile & Personas**: Customize your persona avatar and monitor your adventure stats.
- 🛰️ **GPS Waypoint Simulation Tool**: Built-in simulator tool on the Radar to test proximity geofences from any simulator or browser.

---

## 🏗️ Architecture Overview

```
Presentation Layer (Screens, Widgets, Riverpod StateNotifiers)
                     │
                     ▼
Domain Layer (Entities, Use Cases, Repository Interfaces)
                     │
                     ▲
Data Layer (DataSources, Models, Repository Implementations)
```

- **Feature-First Organization**:
  - `lib/features/profile/`
  - `lib/features/quests/`
  - `lib/features/verification/`
  - `lib/features/achievements/`
  - `lib/features/leaderboard/`
- **Design System**: Dark fantasy & cyber-adventure aesthetic (Deep obsidian, Quest Emerald, Radiant Gold, Luminous Sapphire, Mystical Purple).

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13+ or higher)
- Chrome, Android Emulator, iOS Simulator, or physical device

### Run the App
```bash
# 1. Get dependencies
flutter pub get

# 2. Run static analysis
flutter analyze

# 3. Run automated tests
flutter test

# 4. Launch the application
flutter run -d chrome
```

---

## 🧪 Testing
Run the automated test suite covering Haversine distance calculations, geofence validations, XP & level progressions, and data serialization:
```bash
flutter test
```

---

## 📄 Documentation
- [Architecture Details](docs/architecture.md)
- [Requirements Specification](docs/requirements.md)
- [Architectural Decisions](docs/decisions.md)
