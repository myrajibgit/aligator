# StudyCompete ⚔️ 📚

[![Flutter Build & Release](https://github.com/your-username/studycompete/actions/workflows/ci.yml/badge.svg)](https://github.com/your-username/studycompete/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase)](https://firebase.google.com)
[![TypeScript](https://img.shields.io/badge/Cloud%20Functions-TypeScript-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **StudyCompete** is a gamified, mobile-first social study and competition platform designed for middle school, high school, and college students. Combining Duolingo-style daily academic & fitness habit loops with Solo-Leveling RPG progression, verified anti-cheat missions, and institute-scoped competitive ranking duels.

---

## 🌟 Key Features

### 1. 🎮 RPG Solo-Leveling Progression System
- **Knowledge Power & Leveling**: Gain XP from daily academic tasks to increase your overall Knowledge Rank.
- **IQ & Battle IQ Ratings**: Dynamic calculation based on quiz performance and head-to-head stat duels.
- **Subject Mastery**: Individual progression bars and XP breakdown across all enrolled subjects.

### 2. 🔐 4-Step Student Onboarding Flow
- **Profile Customization**: Live avatar photo upload to Firebase Storage with instant preview.
- **Safety & Legal Compliance**: Enforced 13+ age restriction gate (COPPA / GDPR-K / DPDP compliance) and Terms & Privacy agreement.
- **Institute & Class Scoping**: School, grade, and stream selection scoping social features and leaderboards to real-world peers.

### 3. 🎯 Daily Missions & Verified Academic Habits
- **Timed Subject Quizzes**: Daily question sets with countdown timer, dynamic scoring, and answer review.
- **Physical Fitness Missions**: 30-minute workout timer with background sensor cross-verification via **Health Connect** (Android) and **Apple HealthKit** (iOS).
- **Gemini AI Syllabus Verification**: Upload photos of physical handwritten or textbook notes. Powered by Google Generative AI (`gemini-1.5-flash`), notes are compared against official textbook PDFs to calculate syllabus coverage % with anti-cheat duplicate hash caching.
- **On-Device OCR Fallback**: Integrated privacy-preserving Google ML Kit text recognition for offline environments.

### 4. 💬 Social Layer & Study Parties
- **Classmate Direct Messaging**: End-to-end moderated real-time chat with classmates.
- **Study Parties**: Create or join 2–6 student collaborative study rooms using 6-character invite codes with live roster management and dynamic leadership transfer.

### 5. ⚔️ Competitive Ranked Arena
- **Tiered Ranking Pyramid**: Real-time leaderboards scoped to **Class**, **School**, **Area/City**, and **Weekly Elite**.
- **Cross-School Scout Status**: Top 10% academic performers dynamically unlock Cross-School Scout privileges, revealing rival schools and enabling inter-school duels.
- **3-Round Stat Duels**: Asynchronous stat-based battle system (Subject XP Clash, IQ Duel, and Knowledge Power Showdown) with anti-farming limits (max 2 duels/week per pair).

---

## 🏗️ Architecture & Technology Stack

```
studycompete/
├── .github/workflows/ci.yml       # Production GitHub Actions pipeline (builds APK & AAB)
├── android/                       # Configured Android project (MinSDK 26, Health Connect)
├── ios/                           # Configured iOS project (HealthKit, Camera permissions)
├── functions/                     # Firebase Cloud Functions (Node 20 / TypeScript)
│   ├── src/triggers/              # verifyStudyNotes, onUserCreated, onBattleCreated, etc.
│   └── package.json
├── lib/
│   ├── features/
│   │   ├── auth/                  # Google Auth, user session, models
│   │   ├── onboarding/            # 4-step wizard, school/class/subject pickers
│   │   ├── missions/              # Quizzes, fitness timer, Gemini AI OCR verification
│   │   ├── social/                # 1-on-1 chat, study parties, live rosters
│   │   ├── competition/           # Multi-tier leaderboards, 3-round RPG duels
│   │   └── stats/                 # Solo-leveling stat radar & radar charts
│   ├── shared/                    # App router (GoRouter 14), theme, bottom navigation
│   └── main.dart
├── test/                          # Unit tests (validators, date utils)
├── firestore.rules                # Production security rules
├── firestore.indexes.json         # Composite indexes for leaderboards and battles
├── storage.rules                  # Storage bucket security rules
└── pubspec.yaml                   # Flutter dependencies & assets
```

- **Frontend**: Flutter 3.24+, Dart 3.3+
- **State Management**: Flutter Riverpod 2.5+ with Code Generation & StreamProviders
- **Navigation**: GoRouter 14.2+ with StatefulShellRoute
- **Backend & Database**: Firebase Auth, Cloud Firestore, Cloud Storage, Cloud Functions
- **AI & Computer Vision**: Google Generative AI (`gemini-1.5-flash`), Google ML Kit Text Recognition
- **Health Sensors**: `health` package supporting Google Health Connect and Apple HealthKit

---

## 🚀 CI/CD & Automated GitHub Builds

The repository includes an enterprise-grade GitHub Actions CI/CD pipeline (`.github/workflows/ci.yml`) that automatically builds and packages your application on every push:

### Pipeline Stages
1. **Analyze & Code Generation**:
   - Sets up Flutter 3.24 and Java 17.
   - Runs `dart run build_runner build` to generate Freezed and Riverpod code.
   - Runs `flutter analyze --no-fatal-infos` to guarantee clean code.
2. **Build Android (APK & AAB)**:
   - Compiles an **Installable Debug APK** (`app-debug.apk`) for immediate testing on physical devices.
   - Compiles a **Release App Bundle** (`app-release.aab`) ready for Google Play Store upload.
   - Automatically signs the bundle if GitHub Secrets are configured.
   - Uploads build artifacts to GitHub Actions for 1-click download.
3. **Deploy Firebase Backend & Security Configuration**:
   - Compiles and deploys Cloud Functions, Firestore rules and indexes, and Storage rules on push to `main`.

### Setting up GitHub Secrets (Optional for Signed Release)
Add these secrets in your GitHub repository under **Settings → Secrets and variables → Actions**:

| Secret Name | Description |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release `.jks` keystore file |
| `ANDROID_KEY_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key alias password |
| `ANDROID_KEY_ALIAS` | Keystore alias name |
| `FIREBASE_PROJECT_ID` | Your Firebase Project ID |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase service account key JSON for deployments |

*Note: If no keystore secrets are added, the pipeline automatically compiles a debug-signed installable APK for you!*

---

## 💻 Pushing to GitHub

To push the project to your GitHub repository and trigger the automated build:

```bash
# 1. Navigate to studycompete
cd studycompete

# 2. Initialize Git
git init

# 3. Add all files and commit
git add .
git commit -m "feat: complete production StudyCompete platform"

# 4. Link your GitHub remote repository
git remote add origin https://github.com/<YOUR_USERNAME>/<YOUR_REPO_NAME>.git

# 5. Push to GitHub
git branch -M main
git push -u origin main
```

Once pushed:
1. Go to the **Actions** tab on your GitHub repository.
2. Watch the **Flutter Build & Release** workflow run.
3. Once completed, scroll down to the **Artifacts** section to download `studycompete-android-apk` directly to your phone!

---

## 🧪 Local Development Setup

If you wish to run the app locally on a workstation with Flutter installed:

```bash
# 1. Install dependencies
flutter pub get

# 2. Run code generation
dart run build_runner build --delete-conflicting-outputs

# 3. Run unit tests
flutter test

# 4. Start local Firebase emulators (optional)
cd functions && npm install && npm run build && cd ..
firebase emulators:start

# 5. Run the mobile app
flutter run
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
