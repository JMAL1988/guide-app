# Guide x one — Launch Spec
*Drafted 2026-03-11 by Lana, from Sep + Joost's vision*

---

## Vision

Guide becomes the first commercial one product in the wild.

Not just a kids routine app. Proof that the one framework produces things people actually want to pay for — things built with ethics, ecology, and collective ownership baked in from day one.

Every person who downloads Guide gets introduced to one. Every subscriber funds the ecosystem that makes one possible.

---

## one Branding Integration

### Splash Screen
- one logo + "powered by one" on launch
- Transitions into Guide's own identity
- Sets the frame: this is not a random app company. This is something different.

### About / Philosophy Page (within Guide)
Short, plain language:
> "Guide is the first app built on one — an open framework for human-AI collaboration that nobody owns and everyone can use. When you subscribe, you're not paying a platform. You're funding the infrastructure, the people, and the public good behind it."

---

## Onboarding Flow (5 screens)

### Screen 1 — Welcome to Guide
- What Guide does (ritual, routine, rhythm for kids and families)
- Core value prop: less screen negotiation, more calm transitions
- Visual: kid moving through a day with warmth

### Screen 2 — How it works
- Quick demo of the timer / phase transitions / haptic cues
- 30-second interactive preview — let them feel it before committing

### Screen 3 — Meet one
- one logo prominent
- 3 lines max:
  > "Guide runs on one. one is an open AI framework built by people who believe your tools should work for you — not harvest you. No tracking. No selling your data. No landlords."
- Link to one-framework.org (or equivalent) for those who want to go deeper

### Screen 4 — Choose how you want in
Three options, clearly presented:

| Option | Price | What you get |
|--------|-------|--------------|
| **Free Trial** | 2 months free | Full access, no card required |
| **Own it** | One-time purchase (TBD — ~€14.99) | Guide forever, all updates, no recurring charges |
| **Sustain it** | Monthly subscription (TBD — ~€3.99/mo) | Full access + you fund the one pools (see below) |

Language under subscription:
> "Subscribers fund real things. See exactly where your money goes."

### Screen 5 — What your subscription funds (Pool Visibility)
Live data panel (see spec below). Shown during onboarding, also accessible anytime from settings.

---

## Pool Visibility Feature Spec

### What it is
A live, transparent dashboard inside Guide showing how subscription revenue is allocated across one's funding pools.

### Four pools (initial):

| Pool | Purpose | Default % |
|------|---------|-----------|
| **Infrastructure** | Servers, compute, uptime, security | 10% |
| **Broodfonds** | Income security for one contributors (mutual aid, not insurance) | 5% |
| **Teaching** | Open workshops, documentation, knowledge sharing | 5% |
| **Public Good** | Democratically decided each quarter by one contributors | 5% |

*Remainder: collaborator splits per project (Guide-specific)*

### Display format
- Simple visual: four bars or segments showing allocation
- Running totals: "This month, the Teaching pool received €___"
- Quarter summary: "Last quarter's Public Good fund went to: ___"
- Human language, not financial jargon

### Data source
- Pulled from one's public ledger (to be built — simple JSON endpoint)
- Updated monthly minimum
- Falls back to "last updated [date]" if data is stale — no hiding

### Placement in app
- Onboarding Screen 5 (as described above)
- Settings > "Where does my subscription go?"
- Optional: subtle persistent indicator for subscribers ("You're sustaining one")

---

## Sound Design Layer

### Vision
Guide ships with a curated starter pack of transition sounds. Over time, grows into a library — eventually thousands of options. Users find the exact sound that fits their family's rhythm.

### Phase 1 (launch)
- 5-10 hand-crafted transition sound sets (Sep to lead)
- Each set: 4 sounds (setup → active → warning → complete)
- Styles: calm, playful, minimal, nature, electronic
- Default set ships with app, others unlockable (free or via subscription)

### Phase 2 (post-launch)
- Sound library browser inside app
- Community contributions (one-attributed, contributor credited)
- Generative option: describe the vibe, get a custom sound set

### Phase 3 (separate product potential)
- Sound library as standalone one product
- Built inside Guide, graduates to its own thing when demand justifies it

---

## Crowdfunding Layer (future)

Guide becomes the platform through which one raises funds for specific initiatives.

- In-app crowdfunding campaigns: "We're building X. Help us fund it."
- Backers see progress, get credited in the product
- No Kickstarter cut. No platform in the middle.
- one owns the relationship with its funders.

This is not launch scope. But it's the direction. Design decisions now should not block it later.

---

## Open Questions (need answers before build)

1. **one brand assets** — logo files, brand guidelines. Does this exist yet?
2. **Pricing** — €14.99 one-time / €3.99/mo are placeholders. What's the real number?
3. **Free trial mechanics** — no card required? Card required but not charged? App Store complicates this.
4. **Pool ledger backend** — who builds and maintains the public JSON endpoint?
5. **Legal** — BV, cooperative, or foundation for one entity? Matters for the broodfonds structure.
6. **App Store** — Apple takes 30% on subscriptions (15% after year 1). This affects pool math. Android?

---

## Next Steps

- [ ] Sep/Joost align on pricing numbers
- [ ] one brand assets created or sourced
- [ ] Roberto builds onboarding screens into Guide iOS
- [ ] Pool visibility mockup (can be static data for launch, live later)
- [ ] Sound starter pack — Sep leads, timeline TBD
- [ ] Legal structure conversation (separate, but needed before money flows)

---

*This document is a living spec. Update it as decisions get made.*
