# Web Portal Design System

The rules that every web screen must follow. When in doubt, this document wins.

---

## Typography

Two fonts, one role each. Never mix these up.

**Inter** — body, labels, buttons, table cells, forms, everything except page-level headlines. Available weights: 400, 500, 600, 700, 800.

**Outfit** — page-level headlines ONLY. This is the "hero" font and gets reserved for the top of each page. Section titles within a page use Inter 700. Card titles use Inter 700. Only things like "Good morning, Chris" on the dashboard or "Fire alarm reset — sounder panel" at the top of a job detail get Outfit.

Rule of thumb: if there's only one of this heading on the screen, it's Outfit. If there are multiple, it's Inter.

**JetBrains Mono** — exclusively for numeric data that needs alignment (SLA timers, job references, monetary values in tables, timestamps). Never for body text.

**Standard sizes:**

| Role | Font | Size | Weight | Letter-spacing |
|---|---|---|---|---|
| Page title (Outfit) | Outfit | 34-44px | 800 | -1.0 to -1.2px |
| Section title | Inter | 16-18px | 700 | -0.3px |
| Card title | Inter | 14-16px | 700 | -0.2px |
| Body | Inter | 14px | 400-500 | -0.005em |
| Label (caps) | Inter | 11px | 600-700 | +0.3-0.4px |
| Meta / helper | Inter | 12px | 500 | 0 |
| KPI value | Outfit | 32-36px | 800 | -1.0 to -1.2px |
| Mono (numbers) | JetBrains Mono | 12-13px | 500-600 | 0 |

---

## Colour

The entire palette is in `web_theme.dart` as const values. Use them by name. Never inline a hex code.

**Semantic use:**

- **Navy** (`FtColors.primary`) = authority surface. Sidebar active item, summary cards, dark buttons, dark backgrounds.
- **Amber** (`FtColors.accent`) = "the one thing you do right now." Primary action buttons, active indicators, alert badges on dark surfaces, the most important KPI.
- **White** (`FtColors.bg`) = card surfaces, form inputs
- **Warm off-white** (`FtColors.bgAlt` — `#FAFAF7`) = page background, hover states, sunken panel backgrounds
- **Red** (`FtColors.danger`) = emergencies, SLA breaches, destructive actions. Use sparingly.
- **Green** (`FtColors.success`) = completed states, compliance pass
- **Amber warning** (`FtColors.warning`) = at-risk states, urgent priority (NOT the same as the accent amber — warning is more orange)

**Ratio discipline:** on any given screen, amber should be maybe 2-5% of visible colour. When everything is amber, nothing is urgent. The default page is navy-on-warm-white, with amber appearing on the primary CTA, one accent detail, and that's it.

---

## Spacing and rhythm

Use the 4px grid. Every margin and padding is a multiple of 4. The tokens are `FtSpacing.xs` through `FtSpacing.xxxl` — use them rather than raw numbers.

**Card padding:** 22-24px. Don't go below 16px on a real card.
**Section padding:** 18px header, 20-24px body.
**Page padding:** 32-40px horizontal.

**Border radius scale:**

- `FtRadii.sm` = 6px — small chips, tiny controls
- `FtRadii.md` = 10px — buttons, inputs, small cards, pills
- `FtRadii.lg` = 16px — cards, sections, main surfaces
- `FtRadii.xl` = 20px — large marquee cards (pricing cards on marketing)

Never use sharp corners. Never use circular radius except on avatars and status dots.

---

## Elevation and shadows

Material Design uses elevation generously. We don't. Our surfaces are flat by default and shadow only appears on hover or focus to signal interactivity.

- Default state: `border: 1.5px solid FtColors.border`, no shadow
- Hover state: `boxShadow: FtShadows.md` (subtle) OR `transform: translate(0, -2px)` + `FtShadows.lg` (for primary cards like KPI)
- Primary buttons: always have `FtShadows.amber` (amber glow underneath)

**Never use Material's default card elevation.** Strip it explicitly.

---

## Component patterns

### Buttons

Three variants only:

- **Primary** — amber bg, white text, amber glow shadow. Used max once per screen region. Always the "the thing you'd do right now."
- **Secondary** — white bg, navy text, 1.5px border. Used for all other actions.
- **Ghost** — no bg, no border, fg2 text. Used for tertiary actions like "View all →" links.

Hover: primary and secondary lift by 1-2px. Ghost gets a light background.

NO floating action buttons on web. Create actions go in a fixed position within the content (top-right of a list, for example), not floating over it.

### Inputs

Field style:
- Background: white
- Border: 1.5px `FtColors.border` (default), `FtColors.primary` (focused)
- Focus ring: `0 0 0 4px rgba(255,176,32,0.12)` (amber with low alpha)
- Radius: 10px
- Padding: 11px 14px
- Label above the field, never floating inside

### Cards

All cards share one shape:
- 16px radius
- 1.5px border in `FtColors.border`
- White background (or navy for "featured" cards)
- Header with padding 18-22px, separated by 1px border from body
- Body with padding 20-24px

If you want to show off a card (dashboard's featured KPI, job detail's summary), use the **navy treatment**: navy bg, white text, amber radial glow effect behind the content. Don't overuse — one of these per screen region at most.

### Status pills

Pills are for state, not for actions. Shape: 20px radius, 4px vertical padding, 11px padding left/right, with a 6px coloured dot inside. Colour-coded backgrounds using the `*-soft` palette (`warningSoft`, `dangerSoft`, etc).

### Tables

Dense but readable. Row padding 16px vertical, 22px horizontal. Header row has a grey background and uppercase 11px label text. Hover state darkens the row to `bgAlt`. No alternating stripes. Border under each row, 1px `FtColors.border`.

Every column has a fixed width except the "main content" column which is flex.

### Navigation

Left sidebar, 236px wide, white background, 1px right border.

Nav items:
- Default: 9px 14px padding, 10px radius, fg2 text, hint-coloured icon
- Hover: bgAlt background, primary text
- Active: navy background, white text, amber icon, 4-layer shadow

Section labels are 11px uppercase, 700 weight, hint colour, with 16px left padding (aligned to item icons, not item padding).

### Topbar

64px tall, sticky, `rgba(255,255,255,0.9)` background with `backdrop-filter: blur(12px)`, 1px bottom border. Left: logo mark + wordmark. Centre: search input with `⌘K` kbd hint. Right: icon buttons + user chip.

---

## Layout patterns

### Two-column page (document + rail)

Most detail screens use this:

- Grid: `minmax(0, 1fr) 360px`, gap 28px
- Left: main content, flows vertically
- Right: sticky rail (top: 140px), max-height `calc(100vh - 160px)`, overflow-y: auto

### KPI strip

- Grid: 5 equal columns, 16px gap
- Each KPI is a card (see Card pattern)
- Hover lifts by 4px with larger shadow
- One KPI per strip can be "featured" (navy treatment)

### Section stacking

Pages that stack sections (job detail, quote detail, invoice detail) use:

- 20px vertical gap between sections
- Each section is a standalone card
- Sections NEVER nest inside other sections. If you think they need to, it's two sections at the same level with clear titles.

### Forms

Forms should be two-column on desktop (≥1024px):
- Label + field stack = one cell
- 32px column gap, 18px row gap
- Never stretch a form input to full 1200px width — it looks weird. Max input width: 480px unless it's explicitly a multi-line text field.

---

## Motion

Keep it subtle. Interactions should feel responsive, not theatrical.

**Allowed:**
- 120-200ms transitions on colour, background, border
- `translateY(-1px)` to `translateY(-4px)` lifts on hover
- Sliding panels in (150-200ms)
- Pulsing "live" dots (2s infinite)
- Shimmer skeletons on loading

**Not allowed:**
- Bouncing springs
- Rotations on hover
- Flip animations
- Anything that takes longer than 300ms

---

## Accessibility

- All interactive elements must have a visible focus state (amber outline, 2.5px, 2px offset)
- Colour is never the only signal — status pills have both colour and text, SLA timers have both colour and sign (−0:14)
- Tab order matches visual order
- Keyboard shortcuts are discoverable (show `⌘K` hint in the search input)
- Minimum touch target on clickable elements: 32px (we're desktop-first but respect this anyway)

---

## When to break the rules

You can break these rules, but you have to do it on purpose and document why. "I felt like it" isn't a reason. "The Schedule screen genuinely needs a three-column layout because it's a calendar view and two-column would hide critical data" is a reason.

If you're about to break a rule, pause and ask first.
