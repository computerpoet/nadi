# nadi

A small iOS timer for a daily pranayama-then-sit practice. It walks a six-week ramp from ten minutes of alternate-nostril breathing to a full hour, keeps the time with sound so the phone can stay face down, and remembers your streak.

The program follows the shape of Jason Louv's *Mastering Meditation* (magick.me): equal-length inhale, hold and exhale (the phase length is yours to set), a stressed tick at each phase change, then a silent sit with attention held gently on the point between the eyebrows, then a bell.

| Week | Breathing | Silent sit |
|---|---|---|
| 1 | 10 min | — |
| 2 | 20 min | — |
| 3 | 10 min | 20 min |
| 4 | 10 min | 30 min |
| 5 | 10 min | 40 min |
| 6+ | 10 min | 50 min |

The week advances on its own once you have practised on six of the last seven days.

## How it is built

SwiftUI + SwiftData, iOS 26, Xcode 27. The whole session's audio timeline is scheduled up front on three `AVAudioPlayerNode`s in player-relative time, so ticks and bell survive the lock screen, the silent switch, phone calls and AirPods coming and going. Sessions are recovered after a crash from a heartbeat record. Streaks, a 26-week heat map, JSON export/import.

```
nadi/Models     ProgramSchedule, AppSettings, MeditationSession, StreakCalculator
nadi/State      PhaseCalculator (pure), SessionState
nadi/Audio      AudioEngine, TickScheduler
nadi/Views      onboarding, session, history, settings
nadiTests       Swift Testing: phase maths, tick timeline, streaks, persistence
Scripts         refresh-on-device.sh (build + install on a cabled iPhone), sound and icon generation
```

## Running it

No App Store build. With a free Apple ID, Xcode signs it for seven days at a time:

```
Scripts/refresh-on-device.sh
```

builds, pairs if needed, installs on the connected iPhone and launches it. On first install, trust the developer certificate under Settings → General → VPN & Device Management.

## Status

Personal project, in daily use. Written with Claude Code.
