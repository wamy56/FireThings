# Schedule + PDF Customiser — Implementation Handoff

**Scope:** Two new screens for the web portal, plus mobile-side PDF wiring.

This is a focused handoff for two specific features. It assumes the rest of the
web portal redesign (`docs/web-redesign/`) has already been started — same
design tokens, same shell, same sidebar.

---

## What's in this folder

```
docs/web-redesign-extras/
├── README.md                       ← you are here
├── CLAUDE_PROMPTS.md               ← exact prompts for each implementation session
├── prototypes/
│   ├── schedule.html               ← interactive prototype: week view with drag-and-drop
│   └── pdf_customiser.html         ← interactive prototype: live brand editor
└── specs/
    ├── SCHEDULE_SPEC.md            ← full implementation spec for schedule
    └── PDF_BRANDING_SPEC.md        ← full spec for PDF customiser + mobile wiring
```

---

## What changes

### Schedule (web only)

A new screen at `/schedule` showing dispatched jobs as a resource calendar —
engineers down the side, days across the top. Three view modes (Day, Week,
Month — Week is the default). Full drag-and-drop to reschedule jobs (move
between days) and reassign (move between engineer rows). Unassigned-job
bucket at the bottom for the dispatcher to drag into engineer rows.

This replaces or supplements `lib/screens/web/web_schedule_screen.dart` —
review what's currently there before deciding whether to rewrite or extend.

### PDF Customiser (web + mobile wiring)

A new screen under Reports in the sidebar. A two-pane editor: brand controls
on the left (logo, primary/accent colours, cover style, header style, footer
style, footer text), live PDF preview on the right with a pill switcher to
flip between Compliance Report / Quote / Invoice / Job sheet previews.

This writes a single `branding/main` document to Firestore. The four
existing PDF services (`compliance_report_service.dart`,
`quote_pdf_service.dart`, `invoice_pdf_service.dart`,
`template_pdf_service.dart` for jobsheets) read from this document and apply
the branding to their PDFs. **No mobile UI changes.** Engineers see the new
branding on their next-generated PDF, automatically.

---

## What does NOT change

- `lib/screens/floor_plans/interactive_floor_plan_screen.dart` — leave alone
- `lib/services/pdf_widgets/` — the existing widget library is fine, we're
  configuring it not changing it
- Any mobile screens — engineers don't get a customiser on phone
- Any Firestore security rules — these features use existing permission
  patterns
- The data model for `DispatchedJob`, `Asset`, `ServiceRecord`, etc — schedule
  reads existing fields, doesn't add new ones

---

## How to work through this

There are two natural workstreams that can be done in either order, or in
parallel by separate sessions. I'd recommend tackling **Schedule first**
because it's smaller in scope (no mobile wiring, no Cloud Functions) and
you'll learn the design system patterns before the bigger feature.

**Workstream A: Schedule** — roughly 6 sessions:

1. New schedule screen scaffold (week view skeleton with mock data)
2. Wire the engineer rows + day cells to real DispatchedJob streams
3. Job blocks: priority colours, status states, time display, click-to-open
4. Drag-and-drop within the same engineer (reschedule)
5. Drag-and-drop between engineers (reassign) + unassigned bucket
6. Day and Month view modes + view switcher polish

**Workstream B: PDF Customiser** — roughly 8 sessions:

1. Firestore data model + `BrandingService` + storage upload for logo
2. Web customiser screen scaffold (controls panel + preview canvas)
3. Brand controls (logo upload, colour pickers, style toggles)
4. Live HTML preview component for ONE doc type (Compliance Report)
5. Add the other three preview variants (Quote, Invoice, Job sheet)
6. Document-type pill switcher + "Apply branding to" multi-select
7. Wire `compliance_report_service.dart` to read branding config
8. Wire the other three PDF services + verify mobile output

Each session takes 1-3 hours of working time, depending on how much testing
you do between them. **Don't try to combine multiple steps in one session** —
the specs are designed for one chunk per session, and combining them tends
to produce sloppy work because there's too much context for one Claude Code
turn to track cleanly.

---

## Where to look first

Before opening a session, read in this order:

1. The relevant `.md` file in `specs/` for the feature you're working on
2. The matching prototype in `prototypes/` — open in a browser and click around
3. The targeted prompt in `CLAUDE_PROMPTS.md` for the specific session

Then open Claude Code and use the prompt.

---

## A reminder that's worth repeating

The HTML prototypes are **visual references**, not blueprints. They use HTML
+ CSS because that's the fastest way to communicate the design. The real
implementation is Flutter widgets. Specifically:

- HTML `<div class="job-block">` becomes a `Card` or custom widget
- CSS variables like `--ft-primary` become `FtColors.primary` from
  `lib/theme/web_theme.dart`
- HTML drag-and-drop attributes become Flutter's `Draggable` and
  `DragTarget` widgets
- Inline styles like `transform: translateY(-2px)` on hover become
  `MouseRegion` + `AnimatedContainer` patterns

Do not use the `flutter_html` package or a `WebView`. The prototypes never
ship; they exist only so you can see what's intended.
