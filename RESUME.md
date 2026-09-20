# Where to resume

Read this first, then `IMPLEMENTATION_PLAN.md` for the full design.

## Status (Phase 1: offline workout tracking)

| Feature | State |
|---|---|
| Phase 0: tools, repo, CI, branch protection | Done |
| App shell (theme, go_router, 5 tabs) | Merged (PR #2) |
| Drift database schema | Merged (PR #3) |
| Exercise library (50 seeded exercises, search, filters, detail) | Merged (PR #4) |
| Program templates, routine repository, routine screens | Merged (PR #5) |
| Routine builder (create, edit, reorder, targets, schedule) | Merged (PR #6) |
| Workout repository (log sets, finish, discard) | Merged (PR #7) |
| Active workout screen + in-app rest timer | Merged (PR #8) |
| History (Progress tab list + workout detail + delete) | Merged (PR #9) |
| Form Coach: geometry, One Euro filter, landmark smoother (pure Dart, `lib/features/form_coach/`) | Merged (PR #10) |
| Form Coach: `RepStateMachine` and `HoldTimer` | Merged (PR #11) |
| Form Coach: `FormRule`, `RepScorer`, `CueManager` | Merged (PR #12) |
| Form Coach: `CoachSession`, `ExerciseDefinition`, squat, synthetic pose generator | Merged (PR #13) |
| Form Coach: `CoachController`, `PoseSource`/`ReplayPoseSource`, `CuePlayer`, exercise registry | Merged (PR #14) |
| Form Coach screen: skeleton overlay, live counter, score chip, cue banner, set summary, Coach tab (demo source) | Merged (PR #15) |
| Coach exercise: push-up | Merged (PR #17) |
| Coach exercise: plank (hold mode) | Merged (PR #18) |
| Coach exercise: dips (parallel bars or two chairs) | Merged (PR #19) |
| Coach exercise: pull-up | Merged (PR #20) |
| Coach exercise: lunge | Merged (PR #21) |
| Coach exercise: jumping jack (front view) | Merged (PR #22) |
| Settings: kg/lb and spoken-cue switch, Profile screen | Merged (PR #24) |
| Coached sets saved into workouts (`coach_analyses`, schema v2 migration), Start with AI Coach | Merged (PR #25) |
| Home screen (streak, today's routine, resume) | Merged (PR #26) |
| Progress: weekly volume chart, form-score chart, personal records | Merged (PR #27) |
| Custom exercises (create in the library, delete your own) | Merged (PR #28) |
| Routine builder asks before discarding unsaved changes | Merged (PR #29) |
| Spoken coach cues (`flutter_tts`, follows the Profile switch) | Merged (PR #30) |
| Squat heel-lift rule | In the latest PR (see `git log`) |

`main` is protected: PR required, checks `analyze-test` and `android-build` must pass, squash-merge only.

## Next features (one branch + PR each)

Form Coach engine (pure Dart, no phone needed; build in this order, test with synthetic pose sequences):

- The squat is the template: see `lib/features/form_coach/exercises/squat.dart` (metrics, limits, rules) and `lib/features/form_coach/demo/pose_synth.dart` (generates squat frames from joint angles; extend it with push-up, lunge, plank and jumping-jack poses).
- **All the agreed bodyweight exercises are coached** (squat, push-up, plank, dip, pull-up, lunge, jumping jack), each as one definition in `lib/features/form_coach/exercises/` with a synthetic pose generator in `lib/features/form_coach/demo/` and tests. All thresholds are starting values worked out on generated poses only; **they must be tuned with real recordings**. Known gaps: walking (alternating) lunges, side-view detection of exercises filmed at the wrong angle, and per-user calibration. Adding another exercise: definition + registry entry + `coachKey` in `assets/seed/exercises.json` (a test keeps the two in step).
- TTS is written (`tts_cue_player.dart`) but **never heard on a device**: check the voice, speed and that a new cue cuts off the old one. Possible follow-ups: speak the rep count, duck music (audio focus).
- Camera pipeline (needs the phone): `camera` image stream, ML Kit detector implementing a `PoseSource`, coordinate mapping to image-height units, permission flow.

Workout tracking leftovers:

1. `feat/p1-rest-notification`: notify when the rest timer ends while the app is in the background (`flutter_local_notifications` + `timezone`, Android 13+ notification permission, exact-alarm consideration). The in-app timer already vibrates when it ends.
3. Tag `v0.1.0` (bump `pubspec.yaml` version in a PR, then `git tag v0.1.0 && git push --tags`).
4. Phase 2 (camera + pose spike) **needs the Android phone plugged in with USB debugging on**.

## Try the app on your phone

The app has never been run on a real device yet (only tests and CI builds). To try it:

1. Easiest: open the latest green run on GitHub (Actions tab), download the `app-debug-apk` artifact, unzip it, and install `app-debug.apk` on the phone (allow installs from unknown sources).
2. Or plug the phone in (USB debugging on), then `flutter devices` and `flutter run` in `C:\Users\AhmadDzaki\gym-app`.

The Coach tab runs on a **simulated person** (demo source), not the camera. Check that the app starts, seeds the library, and that a full workout and a demo coach set work. Report anything odd; real-device problems (database, fonts, permissions) are the most likely surprises.

## How to work

```bash
cd C:\Users\AhmadDzaki\gym-app
git switch main && git pull
git switch -c feat/<name>
dart run build_runner build --delete-conflicting-outputs   # after changing drift tables
dart format . && flutter analyze && flutter test
git add -A && git commit          # Conventional Commits, end with the Co-Authored-By line
git push -u origin feat/<name>
gh pr create --fill
gh pr checks --watch              # wait for green
gh pr merge --squash --delete-branch
```

Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`; PR bodies end with the Claude Code line.

## Tooling on this PC

- Flutter `C:\src\flutter` (3.47.5), JDK 17 `C:\src\jdk`, Android SDK `C:\src\android-sdk`. Paths are saved in the user environment; open a new terminal if `flutter` is not found.
- `gh` is installed and logged in as `Dzakiki`.
- Generated `*.g.dart` files are gitignored on purpose; CI runs build_runner.

## Architecture notes and decisions

- Drift row classes are used as models (no Freezed); repositories talk to `AppDatabase` directly (no DAO layer).
- All rows have UUID ids and UTC `created_at`/`updated_at`/`deleted_at` for future sync. Deletes are soft deletes. Weights are stored in kg.
- Seeded data (`assets/seed/*.json`) has stable UUIDv5 ids derived from slugs and is inserted with `insertOrIgnore`, so it never overwrites user changes. To ship changed seed content later, add an explicit migration or upsert.
- Program templates are single routines (the "Push/Pull/Legs" split is three templates), a simplification of the plan's multi-day programs.
- Repositories take an injected `Clock` and `IdGenerator` (see `lib/core`).
- `RoutineRepository.watchDetail` uses a `StreamController` (an `async*` generator hung on cancel).
- Widget tests use `test/helpers/app_harness.dart` (`appTest`), which seeds an in-memory database and disposes the tree before closing it (Drift schedules timers on stream cancel).
- App id `com.dzakiki.formcoach` is permanent once published. Git commits use the email from git config (visible on the public repo).
- Android SDK licences were accepted during setup.

- The database is at schema version 2. Any table added later needs an `onUpgrade` step in `AppDatabase.migration` (see the v2 one) and a test like `test/data/local/migration_test.dart`.

- `coachEngineVersion` (in `coach_result.dart`) is stored with every saved analysis; bump it whenever a rule or threshold changes in a way that alters scores (it is 2 since the squat heel-lift rule).

## Gotchas

- **Keep each bash command under about 6KB.** Longer commands were cut off with "unexpected EOF" parse errors. Write big files with the Write tool or in small batches.
- Widget tests that wait on database work must use `settle(tester)` (test/helpers/app_harness.dart); `pumpAndSettle` alone returns immediately when no frame is scheduled.
- Use one-shot queries (`get()`), not `watch().first`, for reads inside actions and transactions.
- Python strings containing Windows paths need raw strings (`r"..."`).
- `isNull` clashes between drift and flutter_test: `import 'package:drift/drift.dart' hide isNull;`.
- In widget tests, `find.text('X')` also matches a search field containing X; use `widgetWithText(ListTile, 'X')`.
- The exercise list is a lazy `ListView`: search first in tests instead of assuming a row is built.
- Never commit secrets: the repo is public.

## Later phases needing you

- Phase 2: Android phone plugged in, USB debugging on.
- Phase 5: Supabase project (URL, anon key), Google/Apple sign-in setup.
- Phase 6: Play Console ($25 once), Apple Developer ($99/yr), Codemagic account, app signing keys.
