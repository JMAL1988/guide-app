# Guide

> A guide to a screenless life.

Haptic-first routine app for iPhone + Apple Watch. Built on the one framework.

---

## Product lines

### Guide Individual (active)
ADHD self-management for adults and teens. You build your own routines; the Watch guides you through them with haptic feedback.
- Source: `ios-individual/`
- Status: complete single-file Swift prototype, ready to build

### Guide Family (parked)
Parent-managed schedules for children with ADHD. Multi-child support, shared transitions, guided rituals.
- Source: `ios/`
- Status: full Xcode project exists, not current focus

---

## Repo structure

```
ios/                 — Guide Family: Xcode project (iPhone + Apple Watch)
ios-individual/      — Guide Individual: single-file Swift + docs
web/                 — PWA web prototype
website/             — Marketing pages (b2b, b2c, device mockups)
pitch/               — Pitch documents (V1 Connection, V2 Business)
design/              — Logo concepts, mark explorations, design system
design/branding/     — one framework brand assets
docs/                — Launch spec, product decisions
```

---

## Build (Guide Individual)

1. Open Xcode 15+
2. File → New → Project → Multiplatform App
3. Replace ContentView with `ios-individual/Guide-Individual.swift`
4. Set iOS 17.0+ and watchOS 10.0+ deployment targets
5. Build → Run

See `ios-individual/QUICKSTART.md` for full instructions.

---

## Design

Logo direction: the open G mark (1b). See `design/concepts/guide-1b-refined.html`.
Design system: one framework — `design/one-design-system.md`.

---

## Philosophy

- Screen-free use is the goal — the Watch is the real interface
- Haptic first: time made tangible, not visible
- Built on one: open infrastructure, no data extraction
- ADHD-friendly: structure without punishment

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for commit conventions and changelog format.

---

*Part of the one framework. Built by Sep + Joost + Lana.*
