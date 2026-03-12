# Changelog

All notable changes to Guide are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## [0.1.0] - 2026-03-12

### Added
- iPhone app with routine management (create, edit, delete, reorder)
- Four time-of-day categories: Morning, Midday, Evening, Night
- Per-task duration and warning time configuration
- Apple Watch companion app with routine list
- Watch: "Now" card showing active or next upcoming routine
- Watch: step-by-step routine runner with countdown timer
- Watch: haptic feedback at start, warning, and completion
- WatchConnectivity sync (applicationContext + transferUserInfo + sendMessage)
- Watch requests routines from iPhone on first launch
- Local persistence via UserDefaults
- Debug status bar on iPhone showing WC session state

### Fixed
- Watch app not recognized as companion (missing Embed Watch Content build phase in iPhone target)
- Watch scheme not included in iPhone build action
- Timer freeze on watch when tapping Next button (thread safety - dispatched to main queue)
