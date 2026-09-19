# Gym App with a Real-Time AI Form Coach: Implementation Plan

> Status: **in development (Phase 0: environment + repo setup).**
> Working name: **FormCoach** (can be renamed later)
> Project root: `C:\Users\AhmadDzaki\gym-app`
> Repo: https://github.com/Dzakiki/gym.git (public)

---

## 0. Context & Decisions

A cross-platform mobile gym app with two parts:
1. **Workout tracking**: exercise library, program templates, custom routine builder, set logging, rest timer, history, progress charts, personal records.
2. **Real-Time AI Form Coach**: the phone camera watches the user exercise. **On-device** pose estimation counts reps, scores each rep, speaks corrections, draws a live skeleton, and shows a summary and replay after the set.

| Area | Decision |
|---|---|
| Framework | **Flutter** (one codebase for Android and iOS) |
| Form Coach v1 exercises | **Bodyweight set**: squat, push-up, lunge, plank, jumping jack |
| Feedback | Skeleton overlay · rep counter + per-rep form score · voice cues · post-set summary/replay |
| Backend | **Supabase** (Postgres + Auth + Row Level Security) |
| Product scope | Real product: accounts and cloud sync, built production-ready |
| Routines | Program templates + custom routine builder |
| Privacy | Camera frames and video **never leave the device**. Only numbers (reps, scores, fault codes) are synced. |
| Developer level | Beginner: simple architecture, explicit setup steps, one thing at a time |
| Git workflow | Feature branch per feature, pull request, squash-merge only when CI is green. Commit and push after every completed feature. |
| CI/CD | GitHub Actions (checks, tests, debug APK, releases to Play internal track) + Codemagic (iOS to TestFlight) |
| Dev machine | Windows 11. Android builds run locally. iOS builds go through a cloud Mac (Codemagic). |

---

## 1. Tech Stack

| Concern | Package / Tool | Notes |
|---|---|---|
| Language/SDK | Flutter stable 3.x, Dart 3 | |
| State management | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | Providers for controllers, repos, and services |
| Navigation | `go_router` | Auth redirect, bottom-nav shell route |
| Models | `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation` | Immutable models |
| Code gen | `build_runner` | `dart run build_runner watch -d` |
| Local DB | `drift`, `drift_flutter`, `sqlite3_flutter_libs` | Offline-first source of truth |
| Backend | `supabase_flutter` | Auth + Postgres |
| Connectivity | `connectivity_plus` | Triggers sync |
| Camera | `camera` | Image stream + optional recording |
| Pose detection | `google_mlkit_pose_detection` (+ `google_mlkit_commons`) | On-device BlazePose, 33 landmarks |
| Voice | `flutter_tts` | Offline TTS |
| Charts | `fl_chart` | Progress graphs |
| Screen awake | `wakelock_plus` | During coach sets |
| Permissions | `permission_handler` | Camera |
| Video | `video_player` | Replay clips |
| Files | `path_provider`, `path` | App-private storage |
| IDs | `uuid` | Client-generated UUIDs for offline creates |
| Notifications | `flutter_local_notifications` | Rest-timer finished |
| Env config | `flutter_dotenv` (or `--dart-define`) | Supabase URL / anon key |
| Crash reporting | `sentry_flutter` | Phase 6 |
| Testing | `flutter_test`, `mocktail`, `integration_test` | |
| Lints | `flutter_lints` (or `very_good_analysis`) | |
| CI | GitHub Actions (analyze + test), **Codemagic** (iOS builds, TestFlight) | |
| Later | `purchases_flutter` (RevenueCat), PostHog analytics | Phase 7 |

**Fallback plan for pose detection:** everything goes through a `PoseDetectorService` interface. If ML Kit accuracy or speed is not good enough, swap in MediaPipe **Pose Landmarker** (3D world landmarks) through a platform channel without touching the engine.

---

## 2. Architecture

```
┌─────────────────────────── Flutter App ────────────────────────────┐
│ UI (screens/widgets) ◀──▶ Riverpod controllers (AsyncNotifier etc.)│
│        │                                                           │
│ ┌──────▼──────────── Form Coach Engine (pure Dart) ─────────────┐  │
│ │ CameraImage → FrameConverter → PoseDetectorService            │  │
│ │ → LandmarkSmoother (One Euro) → FeatureExtractor              │  │
│ │ → RepStateMachine → FormRules → RepScorer                     │  │
│ │ → CueManager → { TtsService, SkeletonPainter, SetSummary }    │  │
│ └───────────────────────────────────────────────────────────────┘  │
│        │                                                           │
│ Repositories ─▶ drift (SQLite: source of truth) ─▶ SyncService     │
└──────────────────────────────────┬─────────────────────────────────┘
                                   ▼
                     Supabase: Auth · Postgres + RLS
```

**Principles**
1. **All AI runs on the device.** No network needed in the gym, and no privacy risk.
2. **The engine is pure Dart.** Only the camera and detector adapters touch plugins, so every rule can be unit-tested with recorded landmark data.
3. **Exercises are data.** Adding an exercise means adding one definition file (signal, thresholds, rules), not engine changes.
4. **Offline-first.** The UI reads and writes drift only. The sync service pushes and pulls in the background.
5. **Feature-first folders.** Each feature owns its screens, controllers, and widgets.

---

## 3. Project Structure

```
gym-app/
├─ IMPLEMENTATION_PLAN.md
├─ README.md
├─ pubspec.yaml
├─ analysis_options.yaml
├─ .env.example                      SUPABASE_URL=, SUPABASE_ANON_KEY=
├─ android/  ios/                    (flutter create output + permission edits)
├─ assets/
│  ├─ images/exercises/              setup illustrations (side/front view)
│  └─ seed/exercises.json            local seed for exercise library + templates
├─ lib/
│  ├─ main.dart                      init Supabase, drift, Sentry, runApp(ProviderScope)
│  ├─ app/
│  │  ├─ app.dart                    MaterialApp.router
│  │  ├─ router.dart                 go_router config + auth redirect
│  │  ├─ theme.dart                  colors, typography (large, gym-readable)
│  │  └─ env.dart
│  ├─ core/
│  │  ├─ logger.dart  result.dart  extensions/  constants.dart
│  │  └─ widgets/                    shared buttons, cards, empty states
│  ├─ data/
│  │  ├─ local/
│  │  │  ├─ app_database.dart        drift @DriftDatabase
│  │  │  ├─ tables/                  profiles, exercises, routines, routine_exercises,
│  │  │  │                           workout_sessions, set_logs, coach_analyses,
│  │  │  │                           personal_records, outbox, sync_state
│  │  │  └─ daos/
│  │  ├─ remote/supabase_api.dart
│  │  ├─ sync/sync_service.dart  outbox_writer.dart
│  │  └─ repositories/               exercise_repo, routine_repo, workout_repo,
│  │                                 coach_repo, profile_repo, progress_repo
│  ├─ domain/models/                 freezed models
│  └─ features/
│     ├─ auth/          sign_in_screen, auth_controller
│     ├─ onboarding/    goal/experience/days/equipment steps → program suggestion
│     ├─ shell/         bottom nav (Home, Workouts, Coach, Progress, Profile)
│     ├─ home/          today's workout card, streak, quick start
│     ├─ exercises/     library list, search/filter, detail
│     ├─ routines/      template list, routine builder, routine detail
│     ├─ workout/       active_workout_screen, set_row, rest_timer, finish flow
│     ├─ history/       calendar/list, session detail
│     ├─ progress/      charts, PRs, form-score trends
│     ├─ settings/      units, voice, cue frequency, camera default, clip retention
│     └─ form_coach/
│        ├─ camera/     coach_camera_controller.dart, frame_converter.dart
│        ├─ pose/       pose.dart (Landmark, Pose types), pose_detector_service.dart,
│        │              mlkit_pose_detector.dart, fake_pose_detector.dart (fixtures)
│        ├─ engine/     geometry.dart, one_euro_filter.dart, landmark_smoother.dart,
│        │              features.dart, rep_state_machine.dart, hold_timer.dart,
│        │              form_rule.dart, rep_scorer.dart, cue_manager.dart,
│        │              coach_session.dart, exercise_definition.dart
│        ├─ exercises/  squat.dart, pushup.dart, lunge.dart, plank.dart,
│        │              jumping_jack.dart, registry.dart
│        ├─ recording/  keypoint_recorder.dart, clip_recorder.dart, clip_cleanup.dart
│        └─ ui/         coach_screen.dart, setup_guide_screen.dart,
│                       skeleton_painter.dart, hud.dart, set_summary_screen.dart,
│                       replay_screen.dart, debug_overlay.dart
├─ test/
│  ├─ form_coach/
│  │  ├─ fixtures/                   *.json recorded landmark sequences
│  │  ├─ geometry_test.dart  one_euro_test.dart  rep_state_machine_test.dart
│  │  ├─ cue_manager_test.dart  rep_scorer_test.dart
│  │  └─ exercises/                  squat_test.dart … (fixture-driven)
│  ├─ data/                          dao + sync tests (in-memory drift)
│  └─ features/                      widget tests
├─ integration_test/                 on-device flows
├─ supabase/
│  ├─ config.toml
│  ├─ migrations/0001_init.sql  0002_rls.sql
│  ├─ seed.sql
│  └─ tests/rls_test.sql
└─ .github/
   ├─ workflows/{ci.yml, release-android.yml, supabase-deploy.yml}
   ├─ pull_request_template.md
   └─ dependabot.yml
(also: codemagic.yaml; android/key.properties is gitignored)
```

---

## 4. The AI Form Coach: Detailed Design

### 4.1 Core types (pure Dart)
```dart
enum LM { nose, leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist,
          leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle, leftHeel, rightHeel,
          leftFootIndex, rightFootIndex /* …all 33 */ }

class Landmark { final double x, y, z, likelihood; }        // normalized 0..1 image space
class PoseFrame { final Map<LM, Landmark> lm; final Duration t; }

abstract class PoseDetectorService {
  Future<PoseFrame?> process(CameraImage img, CameraDescription cam, int sensorOrientation);
  Future<void> dispose();
}
```

### 4.2 Camera & frame pipeline
- `CameraController(camera, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888)`.
- `startImageStream(onFrame)`: if `_busy` is true, **drop the frame**. Otherwise set `_busy`, convert, detect, push the result into the engine, and clear `_busy`.
- `FrameConverter`: build an ML Kit `InputImage.fromBytes` with the right rotation (from `sensorOrientation` and device orientation) and format.
- Detector: `PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base))`. Run a quick benchmark on first launch and use `accurate` if the device holds ≥20 fps with it.
- Coordinate mapping for the overlay: image to preview size, accounting for rotation and **mirroring when using the front camera**.
- Performance targets: **≥15 analyzed fps** on mid-range Android, **≥25** on recent iPhones, **<150 ms** from movement to on-screen feedback.

### 4.3 Setup / calibration flow (before every coached set)
1. Show the **required camera view** with an illustration: *side* for squat, push-up, lunge and plank; *front* for jumping jack. Suggest a phone position, e.g. "Place phone on the floor, 2–3 m away, at hip height".
2. **In-frame check**: all required landmarks have likelihood > 0.6 for 1 s continuously, and the outline turns green.
3. **Distance check**: body bounding-box height is between 50% and 90% of frame height. Otherwise say "Step back" or "Come closer".
4. **Side check** (side-view exercises): pick the body side (left/right) with the higher average visibility and lock it for the set.
5. Say "Ready", with an optional 3-2-1 countdown. Counting starts at the first valid movement.

### 4.4 Signal processing
- **Visibility gating**: ignore landmarks with likelihood < 0.5. If key joints stay missing for > 0.5 s, pause the engine, show a banner, and say "Step back into view".
- **Smoothing**: a One Euro filter per landmark coordinate (starting values `minCutoff=1.0, beta=0.007, dCutoff=1.0`, then tune).
- **Features** per frame, in `features.dart`:
  - `angle(a,b,c)`: the 3-point joint angle in degrees, e.g. knee = angle(hip, knee, ankle)
  - `segmentAngleFromVertical(a,b)`: torso lean
  - `normalizedDist(a,b)`: distance divided by torso length (shoulder-mid to hip-mid), so camera distance doesn't matter
  - `isBelow(a,b)`: y comparison with a margin
  - velocities of primary signals (for tempo)
- **Engine version** constant (`kEngineVersion = 1`), saved with each analysis so later scores stay comparable.

### 4.5 Rep counting: a generic state machine with hysteresis
```
          signal < downThreshold              reached bottom
  TOP ─────────────────────────▶ DESCENDING ──────────────▶ BOTTOM
   ▲                                                          │
   └───────── signal > upThreshold (rep complete) ◀── ASCENDING
```
- Separate down and up thresholds, so jitter can't double-count.
- `minRepDuration = 0.4 s`, `maxRepDuration = 10 s`.
- **Partial rep**: the movement started (the signal dropped by more than 25% of the range) but never reached `downThreshold` before going back up. It is logged as a partial, is **not counted**, and triggers a cue.
- During each rep, collect `RepTrace`: min/max of every feature, the frames where each rule fired, and eccentric/concentric durations.
- **`HoldTimer`** handles time-based exercises (plank): it counts only while all hold rules pass.

### 4.6 Exercise definitions (v1)

```dart
class ExerciseDefinition {
  final String id; final CameraView view; final List<LM> requiredLandmarks;
  final ExerciseMode mode;                       // reps | hold
  final double Function(Features f)? primarySignal;
  final double? downThreshold, upThreshold;
  final List<FormRule> rules;
}
abstract class FormRule {
  String get code; String get cue; double get weight; RulePhase get phase; bool get safety;
  RuleResult evaluate(Features f, RepPhase phase);   // pass / fault(severity 0..1)
}
```

| Exercise | View | Primary signal | Down / Up | Form rules → cue |
|---|---|---|---|---|
| **Squat** | Side | Knee angle (hip-knee-ankle) | <100° / >160° | `squat_depth`: hip never at or below knee → *"Go deeper"* (−30) · `squat_torso_lean`: torso >45° from vertical at bottom → *"Chest up"* (−20) · `squat_knee_forward`: knee far past toe (normalized >0.35) → *"Sit back into your hips"* (−15) · `squat_heel_lift`: heel rises from baseline → *"Keep heels down"* (−15) · `squat_tempo`: descent <0.8 s → *"Slow down on the way down"* (−10) |
| **Push-up** | Side | Elbow angle (shoulder-elbow-wrist) | <90° / >160° | `pushup_hip_sag`: shoulder-hip-ankle <160° with hips below the line → *"Tighten your core, hips up"* (−25, safety) · `pushup_hip_pike`: hips above the line → *"Lower your hips"* (−15) · `pushup_depth`: min elbow angle >100° → *"Go lower"* (−25) · `pushup_lockout`: max elbow angle <155° → *"Push all the way up"* (−10) · `pushup_neck`: nose well below the shoulder-hip line → *"Keep your neck neutral"* (−10) |
| **Lunge** | Side | Front knee angle | <105° / >155° | detect the forward leg each rep (count per leg) · `lunge_depth`: back knee not near floor level → *"Lower your back knee"* (−25) · `lunge_torso`: lean >25° → *"Stay upright"* (−20) · `lunge_knee_forward`: front knee far past toe → *"Take a longer step"* (−15) |
| **Plank** | Side | hold (no reps) | — | valid while shoulder-hip-ankle is 165–185° · `plank_sag` → *"Hips up"* · `plank_pike` → *"Lower your hips"* · `plank_shoulder`: shoulder not over elbow → *"Shoulders over elbows"* · the timer pauses while form is invalid · encouragement at halfway and 10 s left |
| **Jumping jack** | Front | Arm elevation + ankle spread / shoulder width | Open: wrists above shoulders AND ankles >1.5× shoulder width · Closed: wrists below hips AND ankles <1.1× | `jj_arms`: wrists never above head → *"Arms all the way up"* (−20) · `jj_feet`: feet not wide enough → *"Jump wider"* (−15) · `jj_symmetry`: L/R arm height difference >15% → *"Even on both sides"* (−10) · track pace (reps/min) |

All thresholds are **starting values** and get tuned in Phase 3 using recordings.

### 4.7 Rep scoring
- Each rep starts at **100**. Each fault deducts `weight × severity`, where severity (0 to 1) is how far past the threshold the rep went. The score never drops below 0.
- Labels: 90+ **Excellent**, 75–89 **Good**, 50–74 **Needs work**, <50 **Poor**.
- **Set score** = mean rep score. Also record ROM consistency (std-dev of min primary signal) and tempo consistency.
- Plank: score = % of the hold with valid form, minus deductions for fault time.

### 4.8 Cue manager
- Priority: **safety > ROM/depth > posture > tempo > encouragement**.
- Only cue a fault if it appeared in **2 of the last 3 reps**. Safety faults are cued immediately.
- Cooldowns: the same cue at most once per 6 s (or once per 3 reps), with at least 2 s between any spoken cues.
- The rep number is spoken on completion. Setting options: every rep, every 5, or off.
- TTS: set the language, `setSpeechRate(0.5)`, and on iOS set the audio session to duck other audio so the user's music keeps playing.
- Visual cues: the text banner stays for 2 s, and the faulty joints/segments turn red on the skeleton.

### 4.9 Live coach screen (HUD)
- Full-screen camera preview with `SkeletonPainter` on top: white bones, red for faulty ones, and an angle arc on the primary joint.
- Top: exercise name, set number, fps (dev only). Center-top: **big rep counter**. After each rep, a score chip (e.g. "92 Excellent") flashes.
- Bottom: current cue banner, pause/stop buttons, camera flip.
- Works in portrait and landscape. Large fonts so it is readable from 2–3 m.
- `WakelockPlus.enable()` while active. Stop the camera and disable the wakelock when the screen closes.
- Show a thermal/battery warning if fps stays below 10 for more than 5 s.

### 4.10 Post-set summary & replay
- **Summary screen**: reps counted, partials, set score, a per-rep score bar chart, the top 2 faults with "why it matters" and "how to fix" text, and a Save to workout button.
- **Keypoint replay (always available)**: `KeypointRecorder` stores smoothed landmarks per frame, quantized and gzipped (~30 KB/min), in app-private storage. The replay screen animates the skeleton with a scrubber and "jump to worst rep".
- **Video clip (optional setting, on-device only)**: `startVideoRecording(onAvailable: …)` keeps the image stream running while recording. **Verify in the Phase 2 spike** on real devices. If it's unreliable, turn the feature off for that device and keep keypoint replay. `ClipCleanup` deletes clips older than N days (default 7).
- The only data synced is the `coach_analyses` row (numbers and fault codes).

### 4.11 Safety & legal
- First-use disclaimer: this is not medical advice; stop if you feel pain; the coach is an aid, not a trainer.
- A privacy statement on the permission explainer screen: "Video is processed on your phone and never uploaded."

---

## 5. Workout Tracking Features

| Feature | Details |
|---|---|
| Exercise library | ~60 seeded exercises (bodyweight + common gym): name, category, primary/secondary muscles, equipment, instructions, `coach_supported` flag + "AI Coach" badge. Search and filter. Users can add custom exercises. |
| Program templates | Beginner Full Body (3×/wk), Home Bodyweight (4×/wk), Push/Pull/Legs (6×/wk), 30-Day Squat & Push-up Challenge. "Copy to my routines". |
| Routine builder | Name → add exercises → per exercise: sets, reps **or** seconds, weight (optional), rest seconds. Drag to reorder. Pick weekdays for the schedule. |
| Active workout | Start from a routine or empty. One card per exercise with set rows (target vs actual, a check to complete). The rest timer starts automatically after a set is checked, with a local notification when done. Coach-supported exercises get a **"Start with AI Coach"** button that opens the setup, then the coach, then the summary, and fills actual reps and form score into the set. Finish flow: duration, total volume, PRs hit. |
| History | Calendar with workout days marked, plus a list. Session detail shows sets and coach scores (tap to see the summary/replay if it's still on the device). |
| Progress | Charts: weekly volume, reps per exercise over time, **form score trend per exercise**, weekly streak, personal records (max reps, max weight, best form score, longest plank). |
| Profile & settings | Units kg/lb, height, voice on/off, cue frequency, rep count voice, default camera, video clip saving on/off + retention days, sign out, delete account. |

---

## 6. Data Model

All user tables have: `id uuid` (**generated on the client**), `user_id uuid`, `created_at`, `updated_at`, `deleted_at` (soft delete for sync).

### 6.1 Supabase migration `supabase/migrations/0001_init.sql` (outline)
```sql
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text, units text default 'kg', height_cm numeric,
  goal text, experience text, days_per_week int,
  settings jsonb default '{}'::jsonb,
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create table exercises (
  id uuid primary key, user_id uuid references auth.users,  -- null = global
  name text not null, category text, primary_muscles text[], secondary_muscles text[],
  equipment text, instructions text, coach_supported boolean default false,
  coach_key text,                         -- 'squat' | 'pushup' | ... maps to engine
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table routines (
  id uuid primary key, user_id uuid references auth.users,  -- null = global template
  name text not null, description text, is_template boolean default false,
  schedule_days int[] default '{}',
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table routine_exercises (
  id uuid primary key, user_id uuid references auth.users,
  routine_id uuid references routines on delete cascade,
  exercise_id uuid references exercises, position int not null,
  target_sets int, target_reps int, target_seconds int, target_weight numeric,
  rest_seconds int default 90,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table workout_sessions (
  id uuid primary key, user_id uuid not null references auth.users,
  routine_id uuid references routines, started_at timestamptz not null,
  ended_at timestamptz, notes text,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table set_logs (
  id uuid primary key, user_id uuid not null references auth.users,
  session_id uuid references workout_sessions on delete cascade,
  exercise_id uuid references exercises, set_index int not null,
  reps int, weight numeric, duration_s int, rpe numeric, coached boolean default false,
  completed_at timestamptz,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table coach_analyses (
  id uuid primary key, user_id uuid not null references auth.users,
  set_log_id uuid references set_logs on delete cascade,
  exercise_key text not null, engine_version int not null,
  set_score numeric, reps_counted int, partial_reps int, hold_seconds numeric,
  faults jsonb,          -- {"squat_depth": 3, "squat_torso_lean": 1}
  per_rep jsonb,         -- [{"score":92,"faults":[],"ecc":1.2,"con":0.8}, ...]
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table personal_records (
  id uuid primary key, user_id uuid not null references auth.users,
  exercise_id uuid references exercises, type text,  -- max_reps|max_weight|best_form|longest_hold
  value numeric, achieved_at timestamptz, set_log_id uuid references set_logs,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  deleted_at timestamptz
);

-- index updated_at on every table for incremental pull
-- trigger: set updated_at = now() on update
-- trigger: on auth.users insert → create profiles row
```

### 6.2 RLS `0002_rls.sql`
- Enable RLS on every table.
- User tables: `select/insert/update/delete using (user_id = auth.uid()) with check (user_id = auth.uid())`.
- `exercises`, `routines`, `routine_exercises`: also allow `select` where `user_id is null` (global library and templates). Only the service role can write global rows.
- `profiles`: `id = auth.uid()`.

### 6.3 Local drift schema
The same tables mirrored in drift, plus:
- `outbox(id, table_name, row_id, op, payload_json, created_at, attempts)`
- `sync_state(table_name, last_pulled_at)`

### 6.4 Sync algorithm (`SyncService`)
1. Every repository write is **one drift transaction**: it writes the row and inserts an `outbox` entry.
2. Sync runs on app start, on resume, when connectivity is regained, after a workout finishes, and every 5 min while in the foreground.
3. **Push**: read the outbox in order, `upsert` each row to Supabase by id, delete the outbox entry on success, and retry with exponential backoff on failure.
4. **Pull**: for each table, `select * where updated_at > last_pulled_at order by updated_at`, upsert into drift, and advance `last_pulled_at`.
5. Conflicts are **last-write-wins** on `updated_at` (single user, few conflicts).
6. First sign-in on a new device does a full pull. Signing in after using the app anonymously/offline assigns `user_id` to local rows, then pushes.

---

## 7. Auth & Onboarding
- Supabase Auth: **email magic link**, **Google**, and **Sign in with Apple** (required on iOS when Google is offered).
- `go_router` redirect: not signed in → `/sign-in`; signed in without a finished profile → `/onboarding`.
- Onboarding steps: goal (strength / fat loss / general fitness), experience, days per week, equipment (none / dumbbells / full gym). The result suggests a template program, and the user can adopt it with one tap.
- The camera permission is requested **only** when the Form Coach is first opened, after an explainer screen.
- Account deletion (App Store requirement): a Supabase Edge Function deletes the user's data and auth user.

---

## 8. Platform Configuration
- **Android** (`android/app/build.gradle`): `minSdkVersion 21` (ML Kit), `compileSdk` latest. `AndroidManifest.xml` gets `<uses-permission android:name="android.permission.CAMERA"/>`, `POST_NOTIFICATIONS`, and `<uses-feature android:name="android.hardware.camera" android:required="false"/>`.
- **iOS** (`ios/Podfile`): `platform :ios, '15.5'` (ML Kit minimum). `Info.plist` gets `NSCameraUsageDescription` ("Used to analyze your exercise form on your device. Video is never uploaded."). Portrait and landscape orientations enabled.
- Deep links for magic-link auth: Android intent filter and iOS URL scheme (`io.formcoach://login-callback`).

---

## 9. Phased Roadmap with Task Checklists (~16–20 weeks at a beginner pace)

> Each checklist group below = one feature branch, then PR, CI green, squash merge (section 10.1).

### Phase 0: Environment setup (week 1)
- [ ] Install Git, the Flutter SDK (add to PATH), Android Studio (SDK, platform-tools, cmdline-tools), and VS Code with the Flutter/Dart extensions
- [ ] `flutter doctor` passes for Android; accept licenses (`flutter doctor --android-licenses`)
- [ ] Enable USB debugging on a **real Android phone** (emulator cameras aren't good enough for pose work)
- [ ] `flutter create --org com.<yourname> --project-name formcoach .` inside `gym-app`
- [ ] Add dependencies, `analysis_options.yaml`, and `.gitignore` for `.env`
- [ ] Install GitHub CLI (`winget install GitHub.cli`), `gh auth login`; `git init -b main`, add remote, first commit + push
- [ ] CI workflow (`flutter analyze`, `flutter test`, debug APK), PR template, Dependabot, branch protection, secret scanning (see section 10)
- [ ] Create a Supabase project; install the Supabase CLI; `supabase init`
- [ ] (Later) Codemagic account connected to the repo for iOS builds
- **Done when:** the counter app runs on your phone and CI is green.

### Phase 1: App skeleton + offline tracking (weeks 2–4)
- [ ] Theme, `go_router` shell with 5 tabs, placeholder screens
- [ ] freezed domain models
- [ ] drift database, tables, DAOs, and a seed loader from `assets/seed/exercises.json`
- [ ] Exercise library (list, search, filter, detail)
- [ ] Routine builder (create/edit, reorder, targets, schedule)
- [ ] Active workout (sets, check-off, rest timer + notification, finish summary)
- [ ] History list and session detail
- [ ] Unit tests for DAOs, widget tests for the builder and workout screens
- **Done when:** you can build a routine, do a full workout, and see it in history, all offline.

### Phase 2: Form Coach foundation (weeks 5–7)
- [ ] **Spike (first 3 days)**: camera preview + image stream + ML Kit + raw landmark dots. Measure fps. Test recording while streaming.
- [ ] `PoseDetectorService` + `MlkitPoseDetector` + `FrameConverter` (rotation, formats)
- [ ] Coordinate mapping + mirroring; `SkeletonPainter`
- [ ] `geometry.dart`, `OneEuroFilter`, `LandmarkSmoother`, visibility gating, `Features`
- [ ] Debug overlay (live angles, fps, visibility)
- [ ] **Fixture recorder** (dev menu): save smoothed landmark sequences to JSON and share them to your PC
- [ ] `FakePoseDetector` that replays fixtures (for tests and demo mode)
- **Done when:** a smooth live skeleton runs at ≥15 fps with correct angles, and you can record fixtures.

### Phase 3: Exercises, reps, scoring, cues (weeks 8–11)
- [ ] `RepStateMachine`, `HoldTimer`, `FormRule`, `RepScorer`, `CueManager`, `CoachSession`
- [ ] `TtsService`; setup/calibration screen; HUD
- [ ] Record fixtures: you plus 3–5 people of different heights, good form plus each fault, in two lighting conditions
- [ ] Implement and test, in order: **squat → push-up → lunge → plank → jumping jack**
- [ ] Tune thresholds against the fixtures and write the final values into the definitions
- **Done when:** the fixture suite shows **≥95% rep-count accuracy**, major faults detected in **≥85%** of faulty clips, and **<10% false cues** on good-form clips.

### Phase 4: Summary, replay, workout integration (weeks 12–13)
- [ ] Set summary screen with per-rep chart and fault explanations
- [ ] `KeypointRecorder` + replay screen (scrubber, jump to worst rep)
- [ ] Optional `ClipRecorder` + `ClipCleanup` (if the spike passed)
- [ ] "Start with AI Coach" from active workout, with automatic set log + `coach_analyses` saved
- [ ] PR detection including best form score and longest plank
- **Done when:** a coached set flows from the routine to the coach, the summary, and saved history.

### Phase 5: Accounts & cloud sync (weeks 14–15)
- [ ] Write the migrations (0001, 0002), seed global exercises and templates, `supabase db push`
- [ ] RLS SQL tests
- [ ] Auth screens (magic link, Google, Apple) + deep links + router redirect
- [ ] Onboarding flow + program suggestion
- [ ] Outbox writes in every repository; `SyncService` push/pull; connectivity triggers
- [ ] Account deletion Edge Function
- **Done when:** a workout logged offline on phone A appears on phone B after reconnecting, and user B can't see user A's data.

### Phase 6: Polish, hardening & beta (weeks 16–18)
- [ ] Progress charts, streaks, templates UI polish, empty states, loading and error states
- [ ] Settings screen complete; accessibility (text scaling, contrast, semantics labels)
- [ ] Sentry; privacy policy + terms pages; disclaimer
- [ ] Performance pass on a low-end Android (480p fallback, frame dropping); 10-minute thermal test
- [ ] App icons, splash, store screenshots
- [ ] Play Console internal testing + TestFlight via Codemagic; 10–20 beta testers; feedback form
- **Done when:** beta testers complete coached workouts with no crashes and cue accuracy feels trustworthy.

### Phase 7: Post-launch roadmap
- Gym lifts (bench, overhead press, row, pull-up) with bar/implement handling
- Front-view squat mode (knee valgus, stance width)
- Automatic exercise recognition (a small classifier on keypoint windows)
- Per-user calibration rep (personal thresholds by limb proportions)
- AI-generated plans and weekly coaching summaries (LLM through a Supabase Edge Function, using only aggregated numbers)
- Subscriptions with RevenueCat (Free: 2 coached exercises; Pro: all exercises, replay history, advanced analytics)
- Social: share a workout card, friends' streaks

---

## 10. Git Workflow & CI/CD

Repo: `https://github.com/Dzakiki/gym.git` (public, so branch protection and Actions minutes are free, and **no secret may ever be committed**).

### 10.1 Workflow for every feature
1. `git switch main && git pull`, then `git switch -c feat/<phase>-<short-name>` (e.g. `feat/p1-routine-builder`). Other prefixes: `fix/`, `chore/`, `ci/`, `docs/`.
2. Build the feature together with its tests. Locally run `dart format .`, `flutter analyze`, `flutter test`.
3. Commit with Conventional Commits (`feat(routines): add drag-to-reorder`, `fix(coach): ...`, `test: ...`, `ci: ...`). Small logical commits.
4. `git push -u origin <branch>`, then open a pull request using the PR template.
5. Wait for CI. If it fails: fix, push, wait again.
6. Squash-merge once green, delete the branch, update local `main`.
7. A "feature" is one checklist group in section 9 (e.g. "Rest timer", "Squat rules + fixtures").
8. The very first commit (this plan) goes straight to `main`, because the empty repo needs a base branch.

### 10.2 Security rules (public repo)
- Never committed (all in `.gitignore` from the first commit): `.env*` (except `.env.example`), `android/key.properties`, `*.jks`, `*.keystore`, Play service-account JSON, Apple keys/certs, `*.p12`, `*.mobileprovision`, recorded coach clips, `google-services.json` with real keys.
- Secrets live in GitHub Actions secrets / Codemagic env groups only. Workflows use least-privilege `permissions:` (default `contents: read`) and pin third-party actions to a version.
- The Supabase **anon key** is public by design; safety comes from **RLS on every table**. The **service-role key is never in the app or the repo**.
- Secret scanning + push protection enabled on the repo; Dependabot for `pub` and `github-actions`.
- Workflows never run untrusted PR code with secrets (`pull_request`, not `pull_request_target`).
- Release builds use `--obfuscate --split-debug-info`; TLS only; no logging of tokens or health data.

### 10.3 Branch protection on `main`
Require a PR and the `ci` checks to pass, block force-pushes and deletion, squash merge only, delete branches after merge. Applied once with `gh api` (or in Settings > Branches).

### 10.4 CI: `.github/workflows/ci.yml`
Runs on every `pull_request` and push to `main`; `concurrency` cancels outdated runs:
- **analyze-test** (ubuntu): checkout, Flutter (pinned version, cached), `pub get`, `build_runner`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test --coverage` (includes the Form Coach fixture regression suite), upload coverage.
- **android-build** (needs analyze-test): Java 17, `flutter build apk --debug`, upload APK artifact (installable on your phone from every PR).
- **supabase-check** (only when `supabase/**` changes): `supabase start`, `db reset`, `supabase test db` (RLS tests).

### 10.5 CD
- `release-android.yml`: on tag `v*.*.*`, decode the keystore from secrets, `flutter build appbundle --release`, upload to the **Play internal testing** track, create a GitHub Release.
- `codemagic.yaml`: same tag triggers `flutter build ipa`, automatic signing via App Store Connect API key, publish to **TestFlight**.
- `supabase-deploy.yml`: on `main` when `supabase/**` changes, `db push` and `functions deploy`, behind a GitHub environment `production` that needs manual approval.
- Versions: bump `pubspec.yaml` in a PR, then `git tag vX.Y.Z && git push --tags`. End of Phase 1 = `v0.1.0`, beta = `v0.9.0`, launch = `v1.0.0`.

### 10.6 Secrets (added in the phase that first needs them)
| Secret | From |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` (via `--dart-define`) | Phase 5 |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF` | Phase 5 |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Phase 6 |
| `PLAY_SERVICE_ACCOUNT_JSON` (Play Console, $25 once) | Phase 6 |
| App Store Connect API key in Codemagic (Apple Developer, $99/yr) | Phase 6 |
| `SENTRY_DSN`, `SENTRY_AUTH_TOKEN` | Phase 6 |

### 10.7 Pipeline rollout
Phase 0: `ci.yml`, PR template, Dependabot, branch protection. Phase 5: `supabase-check`, `supabase-deploy.yml`. Phase 6: `release-android.yml`, `codemagic.yaml`, signing, store secrets, first tagged release.

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Landmark jitter or occlusion causes false cues | One Euro smoothing, visibility gating, "2 of 3 reps" rule, enforced camera angle during setup |
| Low fps on budget Androids | Drop frames, `base` model, 480p fallback, first-run benchmark |
| Thresholds don't suit all body types | Normalize by segment lengths; diverse fixtures; per-user calibration later |
| Recording while streaming unsupported on some devices | Phase 2 spike; keypoint replay always works |
| No Mac for iOS | Codemagic cloud builds + TestFlight; borrow an iPhone for testing |
| Scope creep for a beginner | Strict phase "done when" gates; build the risky part (camera + pose spike) early |
| Liability for injury | Disclaimers, conservative cues, no medical claims |
| Sync bugs and data loss | Local DB is the source of truth, idempotent upserts, client UUIDs, sync tests |

---

## 12. Testing & Verification Strategy
1. **Unit tests** (`flutter test`): geometry (known triangles give known angles), One Euro filter, state machine transitions (including partial reps and hysteresis), each `FormRule`, `RepScorer` math, `CueManager` priority and cooldowns.
2. **Fixture regression suite**: each JSON in `test/form_coach/fixtures/` has an expected-result file, e.g. `squat_good_10.json` → `{reps:10, partials:0, faults:{}}` and `squat_shallow_8.json` → `{reps:8, faults:{squat_depth:>=6}}`. The files are fed through `CoachSession` via `FakePoseDetector`. Every engine change must keep this suite green.
3. **Data tests**: in-memory drift for DAOs; `SyncService` against a mocked Supabase API (outbox push, pull, conflicts).
4. **Widget tests**: routine builder, active workout, set summary, settings.
5. **Integration tests** (`integration_test/`, real device): full offline workout; coached set with demo-mode fixture playback; sign-in → sync → second device.
6. **Supabase RLS tests**: `supabase/tests/rls_test.sql`. User B cannot select, update or delete user A's rows.
7. **Manual device matrix** before beta: low-end Android, mid Android, iPhone × (front/back camera) × (bright/dim) × (portrait/landscape). Log fps and rep accuracy against a manual count.
8. **CI**: every push runs `flutter analyze` + `flutter test`; tags trigger Codemagic builds.

---

## 13. Definition of Done for v1
- Users can sign up, onboard, pick or build routines, log workouts offline, and sync across devices.
- The AI Coach supports squat, push-up, lunge, plank and jumping jack with live skeleton, rep count, per-rep score, voice cues, summary and replay.
- ≥95% rep-count accuracy on the fixture suite, ≥15 fps on a mid-range Android, no frames or video leave the device.
- Builds are live on Play internal testing and TestFlight.

---

## 14. First Steps When Execution Starts
1. Walk through Phase 0 setup on this Windows machine (`flutter doctor`, phone connected).
2. Scaffold the Flutter project inside `C:\Users\AhmadDzaki\gym-app` with the folder structure and `pubspec.yaml` above.
3. Build the **camera + pose spike** first to reduce risk in the core feature, then continue with Phase 1.
