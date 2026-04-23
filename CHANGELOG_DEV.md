# Changelog (Dev)

## [Unreleased]

### 🐛 Production Fixes (P0 & High Priority)

#### 1. Notifications & FCM Integration (P0)
- **Fix**: Implemented `onNotificationCreated` Firestore trigger in `functions/index.js` to handle FCM multicast.
- **Root Cause Fix**: Updated `NotificationService` to explicitly save FCM tokens to `Schools/{schoolId}/{collection}/{uid}` in Firestore. This fixes the issue where the Cloud Function couldn't find tokens to send notifications to Managers/Staff.
- **Validation**: Added `PROOF_LOG` to track token saving and retrieval.

#### 2. Elite Schedule Infinite Loading (P0)
- **Root Cause Fix**: Corrected Firestore collection casing in `EliteScheduleRepository` from `schools` (lowercase) to `Schools` (capitalized). This fixes the issue where the stream returned empty/null data, causing the loading spinner to hang indefinitely.
- **UI**: Added 15-second timeout and Error Boundary with "Retry" button.
- **Validation**: Added `PROOF_LOG` to trace session loading status.

#### 7. Password Change Loop Fix (P0)
- **Fix**: `FirestoreAuthRepository` now enforces creation of `GlobalUsers` document if missing during password change.
- **Logic**: Updates `isPasswordChangeRequired` and `passwordChangedAt` in `GlobalUsers` as the single source of truth, ensuring consistent state across devices.
- **Validation**: Added `PROOF_LOG` debug prints to verify document creation/update and subsequent read verification.

#### 8. Manar Intelligence Index Fix (P0)
- **Fix**: Added missing Composite Index definitions to `firestore.indexes.json` for `behavior_records` (schoolId ASC, timestamp DESC).
- **Deploy**: Successfully deployed indexes to `etisak-784d6` project via Firebase CLI.
- **Performance**: Added execution time and record count logging (`PROOF_LOG`) to `FirestoreIntelligenceRepository` to verify query optimization.

#### 3. Teacher Attendance Buttons
- **Fix**: Updated `teacher_attendance_screen.dart` to ALWAYS show attendance buttons (Present/Late/Absent) even if the slot data is null or pending.
- **Logic**: Implemented ad-hoc schedule ID generation for attendance recording outside strict schedule slots.

#### 4. School Intelligence Dashboard Crash
- **Fix**: Added Error Boundaries and `try-catch` blocks in `school_intelligence_dashboard.dart`.
- **UI**: Added "Retry" button for failed analysis fetches to prevent gray screen crashes.

#### 5. SMS Settings Hint
- **UI**: Updated `sms_settings_screen.dart` hint text from hardcoded URL to "قم بوضع رابط الرسائل الخاص بك" as requested.

#### 6. Teacher Import Template
- **Fix**: Standardized teacher import template download in `add_teacher_screen.dart`.
- **Feature**: Implemented logic to download the exact `tetchar.xlsx` binary from assets without modification, fixing the "wrong template" error.

### 🔧 Technical Improvements
- **Dependencies**: Added `url_launcher` and `path_provider` for reliable file handling across platforms.
- **Build**: Verified Android SDK versions (compileSdk 36, minSdk 24) and updated `pubspec.yaml` version to `1.1.0+24`.
- **Schedule Management**: Resolved compilation errors in `schedule_management_screen.dart` (missing braces, undefined variables) to enable successful builds.
