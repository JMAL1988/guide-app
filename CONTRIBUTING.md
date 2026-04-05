# Contributing to Guide

## Who contributes

- **Sep** (jessesep) — product, architecture, direction
- **Joost** (JMAL1988) — iOS development, UX, Apple platform expertise
- **Lana** — AI collaborator (one framework), generation + scaffolding

---

## Commit convention

```
type(scope): short description

Co-authored-by: Name <github-username@users.noreply.github.com>
```

**Types:** `feat` · `fix` · `design` · `docs` · `refactor` · `chore`

**Scopes:** `ios` · `ios-individual` · `web` · `design` · `docs` · `pitch`

**Examples:**
```
feat(ios-individual): add scheduled auto-start for routines

Co-authored-by: JMAL1988 <JMAL1988@users.noreply.github.com>
```

```
design(logo): refine 1b open G mark at small sizes

Co-authored-by: jessesep <jessesep@users.noreply.github.com>
```

---

## CHANGELOG

Every PR or direct commit that changes user-facing functionality must include a CHANGELOG.md entry.

Format:
```
- Description of change [YourName]
```

Add under the correct version heading. If no version exists yet for the current cycle, add one.

---

## Branches

- `main` — stable, always builds
- `dev` — active development
- Feature branches: `feat/short-name`

---

## Pull requests

- Keep PRs focused — one thing per PR
- Reference CHANGELOG entry in PR description
- Both Sep and Joost can merge
