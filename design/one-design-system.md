# one Design System
Source: stageix.site / one framework
Last extracted: 2026-03-11

---

## Color Palette

### Dark Mode (Default)
```
--black:          #0a0a0a   ← page background
--grey-1:         #111111   ← surface 1
--grey-2:         #1a1a1a   ← surface 2
--grey-3:         #262626   ← surface 3 / borders
--grey-4:         #333333
--grey-5:         #555555   ← mid text
--grey-6:         #888888   ← dim text
--grey-7:         #aaaaaa
--white:          #f0ede8   ← primary text (warm off-white)
--brand:          #8b7f72   ← brand accent (warm taupe)
--brand-l:        #a39589   ← brand accent light

--surface-bg:     #0a0a0a
--surface-1:      #111111
--surface-2:      #1a1a1a
--surface-3:      #262626
--surface-active: #2a2218   ← active state (warm dark)
--text-primary:   #f0ede8
--text-dim:       #888888
--border-col:     #262626
```

### Light Mode
```
Background:   #f5f2ee   ← warm cream
Text:         #1a1a1a
Brand:        #6b5f52   ← darker for legibility
Brand light:  #8b7f72
Borders:      #c8bfb5
Surface 1:    #ebe6df
Surface 2:    #e0d9d0
```

---

## Typography

```
Font family (sans):  IBM Plex Sans — weights 300, 400, 500
Font family (mono):  IBM Plex Mono — weights 400, 500
Body weight:         300
Body line-height:    1.65
```

Google Fonts import:
```
https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@300;400;500&display=swap
```

---

## Design Principles

- **Dark-first** — dark is the canonical mode; light is the override
- **Warm neutrals** — never pure black/white; all tones have a slight warm/brown undertone
- **Minimal** — low visual noise, data-forward, no decorative elements
- **Technical** — IBM Plex (designed for technical/data contexts)
- **Subdued brand** — the brand color (#8b7f72) is a muted taupe, not a loud accent

---

## Links & Interactions
```
Default link:   #a39589 with bottom border 1px #262626
Hover:          #f0ede8 border #8b7f72
Visited:        #8b7f72
Transition:     0.2s on color and border-color
```

---

## Surfaces & Elevation
```
Level 0 (page):     #0a0a0a
Level 1 (card):     #111111
Level 2 (modal):    #1a1a1a
Level 3 (overlay):  #262626
Active highlight:   #2a2218  ← warm dark brown tint
```

---

---

## one Mark — Logo Asset

**ALWAYS use the original PNG asset. Never recreate the mark as custom SVG.**

Files in `assets/branding/`:
```
one-logo-transparent.png  ← use this (transparent bg, taupe mark)
one-logo-black-bg.png
one-logo-white-bg.png
```

**Actual mark geometry** (from the real asset):
- Three vertical pill-shaped bars with fully rounded caps
- CENTER bar is taller than the two outer bars
- Outer bars are shorter and vertically centered relative to center bar
- Small circular dot below and centered under the middle bar
- Color: brand taupe (#8b7f72 area)

**Color variants via CSS filter:**
```css
/* White mark on dark bg */
filter: brightness(0) invert(1);

/* Natural taupe — use the asset as-is */
/* no filter needed */
```

**Sizing:** Works cleanly from 24px to 512px+. Use the transparent PNG and scale with width/height.

---

## Usage Notes

- All infographics, splash screens, data visualizations should use this palette
- Prefer dark mode as default for any one-branded output
- IBM Plex Sans at weight 300 for body, 400/500 for labels and headers
- Brand color (#8b7f72) is an accent only — not a dominant color
- Borders: always #262626 in dark mode, subtle and minimal
- **Never generate or guess the one mark shape** — always embed the asset from assets/branding/
