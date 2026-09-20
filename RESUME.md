# Where to resume

Last updated: 2026-09-20. Read this first, then `IMPLEMENTATION_PLAN.md` for the full design.

## Status

| Item | State |
|---|---|
| Phase 0 (tools, repo, CI, branch protection) | Done |
| PR #1 Flutter scaffold + strict lints + CI | Merged |
| PR #2 App shell (theme, go_router, 5 tabs) | Merged |
| Drift database schema, PR #3 (`feat/p1-data-layer`) | **Open on GitHub. `analyze-test` passed; `android-build` was still running when work stopped. Not merged.** One extra local commit (this file) is not pushed. |
| Phone connected for testing | Not yet (not needed until Phase 2) |

`main` is protected: PR required, checks `analyze-test` and `android-build` must pass, squash-merge only.

## First thing to do when resuming

Finish PR #3 (the data layer):

```bash
cd C:\Users\AhmadDzaki\gym-app
gh pr checks 3                  # both checks must be green; re-run from the Actions tab if one failed
git switch feat/p1-data-layer
git push                        # pushes the local RESUME.md commit; CI runs again
gh pr checks 3 --watch          # wait for green
gh pr merge 3 --squash --delete-branch
git switch main && git pull
```

If a check fails, read the log with `gh run view --log-failed`, fix on the branch, push, and wait again.
Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`; PR bodies end with the Claude Code line.

## Next features (one branch + PR each, Phase 1)

1. `feat/p1-exercise-library`: `assets/seed/exercises.json` (about 60 exercises, deterministic UUIDv5 ids from a slug), seed loader, `ExerciseRepository`, library screen with search and filter, detail screen. Add `core/clock.dart` and an id-generator provider for repositories.
2. `feat/p1-routines`: `RoutineRepository`, the 4 program templates ("copy to my routines"), routine builder (add, reorder, targets, schedule days).
3. `feat/p1-active-workout`: workout session flow, set logging, rest timer with local notification, finish summary.
4. `feat/p1-history`: history list and session detail.
5. Tag `v0.1.0` after Phase 1. Then Phase 2 (camera + pose spike), which **needs the Android phone plugged in with USB debugging on**.

## Tooling on this PC

- Flutter `C:\src\flutter` (3.47.5), JDK 17 `C:\src\jdk`, Android SDK `C:\src\android-sdk`. Paths are saved in the user environment, so a new terminal has them. If a shell cannot find `flutter`, open a new terminal.
- `gh` is installed and logged in as `Dzakiki`.
- Run code generation after pulling or editing tables: `dart run build_runner build --delete-conflicting-outputs`. Generated `*.g.dart` files are gitignored on purpose; CI generates them.
- Before every commit: `dart format .`, `flutter analyze`, `flutter test`.

## Decisions and deviations from the plan

- Drift row classes are used as models (no Freezed) and there is no separate DAO layer; repositories talk to `AppDatabase` directly.
- Weights are stored in kg (`weight_kg`), timestamps as UTC text with millisecond precision.
- App id: `com.dzakiki.formcoach`. Permanent once published to the Play Store.
- Git commits use `ahmad.dzaki99@gmail.com` from git config (visible on the public repo). GitHub noreply addresses are an option.
- Android SDK licences were accepted during setup.

## Gotchas

- Very long single bash commands with many heredocs failed to parse twice. Write files in small batches.
- The `isNull` name clashes between drift and flutter_test: `import 'package:drift/drift.dart' hide isNull;` in tests.
- Never commit secrets: the repo is public. `.gitignore` already covers `.env`, keystores and keys.
- Actions in `ci.yml` are pinned to commit SHAs; Dependabot will propose updates.

## Later phases needing you

- Phase 2: Android phone plugged in, USB debugging on.
- Phase 5: Supabase project (URL, anon key) and Google/Apple sign-in setup.
- Phase 6: Play Console ($25 once), Apple Developer ($99/yr), Codemagic account, app signing keys.
