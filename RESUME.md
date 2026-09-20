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
| Form Coach: geometry, One Euro filter, landmark smoother (pure Dart, `lib/features/form_coach/`) | In the latest PR (see `git log`) |

`main` is protected: PR required, checks `analyze-test` and `android-build` must pass, squash-merge only.

## Next features (one branch + PR each)

Form Coach engine (pure Dart, no phone needed; build in this order, test with synthetic pose sequences):

- `feat/p3-rep-state-machine`: generic `RepStateMachine` (hysteresis, min rep duration, partial reps) and `HoldTimer` for plank.
- `feat/p3-coach-session`: `FormRule`, `RepScorer`, `CueManager` (priority, cooldowns, "2 of last 3 reps" rule), `CoachSession` orchestrator, a synthetic pose generator for tests, and the squat `ExerciseDefinition`. See section 4 of `IMPLEMENTATION_PLAN.md` for thresholds.
- Then push-up, lunge, plank, jumping jack definitions, one PR each.

Workout tracking leftovers:

1. `feat/p1-rest-notification`: notify when the rest timer ends while the app is in the background (`flutter_local_notifications` + `timezone`, Android 13+ notification permission, exact-alarm consideration). The in-app timer already vibrates when it ends.
2. `feat/p1-settings-units`: kg/lb setting (weights are stored in kg), custom exercise creation UI (the repository already supports it), unsaved-changes prompt in the routine builder.
3. Tag `v0.1.0` (bump `pubspec.yaml` version in a PR, then `git tag v0.1.0 && git push --tags`).
4. Phase 2 (camera + pose spike) **needs the Android phone plugged in with USB debugging on**.

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
