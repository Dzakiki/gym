# FormCoach

A gym app for workout planning and tracking with a **real-time AI form coach**. The phone camera watches you exercise, and on-device pose detection counts reps, scores each rep and gives spoken corrections. Video never leaves the device.

- **App:** Flutter (Android + iOS)
- **Backend:** Supabase (Postgres, Auth, Row Level Security)
- **AI:** Google ML Kit pose detection running fully on-device

Full design, roadmap and workflow: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

## Status
Phase 0: environment and repository setup. See the plan for the roadmap.

## Contributing workflow
One feature per branch, a pull request for each, squash-merged when CI is green (see section 10 of the plan). Never commit secrets: `.env`, keystores and API keys are gitignored, and this repository is public.
