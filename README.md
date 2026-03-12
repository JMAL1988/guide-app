# Guide

Personal routine timer for iPhone + Apple Watch.

## What it does

Guide helps you structure your day with timed routines. Define routines on your iPhone, run them on your wrist.

- **iPhone**: Create and manage routines (morning, midday, evening, night)
- **Apple Watch**: View upcoming routines, run step-by-step timers with haptic feedback
- **Sync**: Automatic sync via WatchConnectivity (live messages + background context)

## Architecture

| Directory | Platform | Description |
|-----------|----------|-------------|
| `Guide individual/` | iPhone | SwiftUI app - models, store, views |
| `Guide Individual Watch Watch App/` | watchOS | SwiftUI app - models, store, views |

**Sync strategy** (iPhone to Watch):
1. `updateApplicationContext` - system-cached, delivered even when watch app is closed
2. `transferUserInfo` - queued background delivery
3. `sendMessage` - immediate push when both apps are active

## Requirements

- iOS 18.0+
- watchOS 11.0+
- Xcode 26.2+
- Apple Developer account (for device deployment)

## Setup

1. Clone the repo
2. Open `Guide individual.xcodeproj` in Xcode
3. Select your team in Signing & Capabilities
4. Build and run:
   - **iPhone**: scheme `Guide individual`, target your iPhone
   - **Watch**: scheme `Guide Individual Watch Watch App`, target your Apple Watch

> **Note**: Deploy the watch app directly to the watch via Xcode. The Watch app installer has a known storage bug that blocks installation through the iPhone Watch app.

## Bundle IDs

| Target | Bundle ID |
|--------|-----------|
| iPhone | `com.joostlaarakker.guide` |
| Watch  | `com.joostlaarakker.guide.watchkitapp` |
| App Group | `group.com.joostlaarakker.guide` |

## Known Issues

See [CHANGELOG.md](CHANGELOG.md) for fixes and [TODO.md](TODO.md) for planned work.

## License

Private - all rights reserved.
