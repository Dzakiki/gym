# FormCoach

A gym app for planning and tracking workouts, with a **real-time AI form coach**. Point the phone camera at yourself and on-device pose detection counts your reps, scores each one and tells you what to fix. Video never leaves the phone.

[![ci](https://github.com/Dzakiki/gym/actions/workflows/ci.yml/badge.svg)](https://github.com/Dzakiki/gym/actions/workflows/ci.yml)

## Status

Work in progress. The workout tracker is complete and offline-first. The form coach works end to end on a **simulated person**; connecting the real camera is the next big step.

| Area | State |
|---|---|
| Workout tracking (exercises, routines, logging, history) | Done |
| Form coach engine for 7 bodyweight exercises | Done, tested on generated poses only |
| Coach screen (skeleton overlay, live counter, cues, summary) | Done, runs on a demo source |
| Camera and pose detection (ML Kit) | Not started (needs a phone) |
| Spoken cues, saving coached sets, kg/lb setting | Not started |
| Accounts and cloud sync (Supabase), store releases | Planned |

See [RESUME.md](RESUME.md) for the exact state and next steps, and [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the full design.

## Features

**Workout tracking**
- 51 built-in exercises with search and filters, plus 5 program templates you can copy
- Routine builder: reorder exercises, set sets, reps or time, rest and weekdays
- Active workout: log weight and reps, tick sets off, in-app rest timer, finish summary
- History with per-set detail on the Progress tab

**AI form coach** (side view unless noted)

| Exercise | Checks |
|---|---|
| Squat | depth, chest lean, knees past toes, speed down |
| Push-up | hips sagging or piking, lockout |
| Plank | time held with good form, hips, shoulders over elbows |
| Dips (bars or chairs) | shoulder to elbow height, not too deep, lockout, speed |
| Pull-up | head to bar height, full hang, swinging, controlled lowering |
| Lunge | back knee depth, upright torso, front knee |
| Jumping jack (front) | arms up, feet wide, both arms even |

The coach only speaks up when a fault repeats (2 of the last 3 reps), except safety issues, and it never repeats the same cue too soon.

## Tech stack

Flutter (Android and iOS) with Riverpod, go_router and Drift (SQLite). The coach engine is pure Dart and takes pose landmarks from any source. Planned: `camera` and Google ML Kit pose detection on the device, Supabase for accounts and sync.

## Getting started

Requirements: Flutter 3.47.5 (stable), JDK 17 and the Android SDK.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates the Drift code
flutter run                                                # phone plugged in, USB debugging on
```

Before every commit:

```bash
dart format .
flutter analyze
flutter test
```

Every push to a pull request also runs these in CI and builds a debug APK (download it from the run's artifacts to try the app on a phone).

## Project layout

```
lib/
  app/            theme, routes, tab shell
  core/           clock, ids, shared widgets
  data/           Drift database, repositories, seed data loading
  domain/         enums and labels
  features/       exercises, routines, workout, history, coach, form_coach
    form_coach/   engine (pure Dart), exercises, demo pose generators, UI
assets/seed/      exercise library and program templates (JSON)
test/             unit and widget tests, including synthetic pose sets
```

## Contributing

One feature per branch, one pull request each, squash-merged when CI is green. Commits follow Conventional Commits. `main` is protected.

## Privacy and security

Camera frames are processed on the phone and never uploaded; only numbers (reps, scores, fault codes) are meant to sync. This repository is public: never commit secrets, keys or keystores (they are gitignored).

The form coach is a training aid, not medical advice. Stop if you feel pain.
