# QuestUP Requirements Specification

## 1. Project Overview
QuestUP is a real-world adventure game where explorers, travelers, and students discover physical points of interest, verify their presence using GPS and camera photos, earn XP, unlock achievements, and climb competitive leaderboards.

## 2. Core Functional Requirements

### 2.1 Quests & Exploration
- **FR-1.1**: Discover quests within nearby geofences categorized by Nature, Historical Landmark, Arts & Culture, Fitness Trail, and Urban Mystery.
- **FR-1.2**: Calculate real-time distance from user coordinates to quest coordinates using the Haversine formula.
- **FR-1.3**: Filter quests by category, difficulty (Easy, Medium, Hard, Legendary), status (All, Available, Completed), and search query.
- **FR-1.4**: Interactive Radar Scanner with rotating sweep and proximity markers.

### 2.2 Quest Verification
- **FR-2.1**: Require player to be within the designated quest geofence radius (e.g. 60–100m) to complete.
- **FR-2.2**: Require player to capture/attach camera photo proof of the waypoint.
- **FR-2.3**: Prevent completion of quests if player level is lower than the quest requirement.
- **FR-2.4**: Persist completion audit log with coordinates, photo path, timestamp, and rewards.

### 2.3 Game Progression & Rewards
- **FR-3.1**: Award XP and Coins upon verified quest completion.
- **FR-3.2**: Dynamic level progression algorithm with scaling XP thresholds ($500 \times 1.25^{\text{level}-1}$).
- **FR-3.3**: Unlockable badges with criteria (First Discovery, Trail Blazer, Bounty Hunter, Adept Explorer, Master of the Realm).

### 2.4 Leaderboard
- **FR-4.1**: Display top 3 podium (1st Gold, 2nd Silver, 3rd Bronze).
- **FR-4.2**: Rank players globally and weekly by total earned XP.
- **FR-4.3**: Dynamically compute active player rank and highlight in rankings.

## 3. Non-Functional Requirements
- **NFR-1**: Offline-first local data persistence with zero network latency dependency.
- **NFR-2**: Sub-second UI state updates with zero jank on mobile and web.
- **NFR-3**: Dark fantasy adventure aesthetic with high-contrast accessibility.
