# TODO

## Bugs
- [ ] App Group entitlements empty - `group.com.joostlaarakker.guide` declared in code but not in entitlements files
- [ ] Debug status bar visible in production - hide or put behind a toggle

## Architecture
- [ ] Split single-file ContentView.swift into separate files (Models, Store, Views)
- [ ] Extract shared models (Routine, Task) into a shared Swift package
- [ ] Remove unused WatchConnectivityService.swift (dead code from earlier version)

## UX
- [ ] Add confirmation before starting a routine
- [ ] Add pause/resume button during routine
- [ ] Add haptic feedback when manually advancing tasks (Next button)
- [ ] Handle edge case: warning time >= task duration

## Infrastructure
- [ ] Set up TestFlight for beta distribution
- [ ] Add app icon
- [ ] Configure App Store Connect

## Future
- [ ] Routine scheduling with local notifications
- [ ] Routine statistics / completion tracking
- [ ] iCloud sync for multi-device
- [ ] Complications for watch face
