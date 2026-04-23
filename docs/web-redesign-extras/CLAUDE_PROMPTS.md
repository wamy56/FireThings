# Claude Code Prompts — Session by Session

Copy-paste these into Claude Code, one per session. Each prompt assumes
this folder lives at `docs/web-redesign-extras/` in the repo and that
`CLAUDE.md` already documents the codebase conventions.

**Universal rules** (build into your habits, not into every prompt):

- Always include "show me the plan before writing code" for non-trivial work
- Commit at the end of every successful session
- One screen / one feature chunk per session — don't combine
- If Claude Code wants to change anything outside the listed files, stop it
- If Claude Code reaches for `flutter_html` or `WebView`, stop it

---

## Schedule — 6 sessions

### Session 1 — Schedule scaffold

> Implement Session 1 of `docs/web-redesign-extras/specs/SCHEDULE_SPEC.md`
> (the scaffold). Create the new schedule screen and the week-grid widget
> hierarchy with hardcoded mock data — no Firestore, no drag-and-drop yet.
> Match the visual layout shown in
> `docs/web-redesign-extras/prototypes/schedule.html`. Use tokens from
> `lib/theme/web_theme.dart` — no hard-coded colours, font sizes, or
> spacing. Files to create are listed in the spec under "Files to create"
> — only create the ones tagged for Session 1. Show me the plan before
> writing any code.

### Session 2 — Wire to real data

> Implement Session 2 of
> `docs/web-redesign-extras/specs/SCHEDULE_SPEC.md`. Replace the mock data
> from Session 1 with real Firestore streams. Use
> `DispatchService.watchJobsForDateRange` (verify it exists, add it if not
> per the spec's "Service methods needed" section). Use `CompanyService`
> for the engineer list. Wire the prev/today/next nav controls and the
> filter chips into the displayed jobs. Don't add drag-and-drop yet. Show
> me the plan before writing code.

### Session 3 — Job block details + click-to-open

> Implement Session 3 of
> `docs/web-redesign-extras/specs/SCHEDULE_SPEC.md`. Polish the job-block
> widget with priority colours, status states (in-progress amber pulse,
> completed strikethrough), and click-to-open. The click should slide in
> the existing `WebJobDetailPanel` as a side panel. Wire the engineer
> workload bars to actual job-count vs capacity. Don't add drag-and-drop
> yet. Show me the plan first.

### Session 4 — Drag-and-drop reschedule (within engineer)

> Implement Session 4 of
> `docs/web-redesign-extras/specs/SCHEDULE_SPEC.md`. Add Flutter's
> `Draggable` to `ScheduleJobBlock` and `DragTarget` to
> `ScheduleDayCell`. Drop on a different day for the same engineer should
> update the job's scheduledDate via
> `DispatchService.updateScheduledDate`. Use optimistic UI: update local
> state immediately, sync to Firestore, revert with a toast on failure.
> Handle these edge cases: drop on same cell (no-op), drop on completed
> job's cell (allow but warn), drop with null target date. Show me the
> plan first.

### Session 5 — Drag-and-drop reassign + unassigned bucket

> Implement Session 5 of
> `docs/web-redesign-extras/specs/SCHEDULE_SPEC.md`. Add the unassigned
> row at the bottom of the grid. Make engineer rows accept drops from
> other engineers (reassign). Make the unassigned row accept drops
> (unassign) and let users drag from unassigned onto engineer rows
> (assign). Use the new `rescheduleAndReassign` atomic method (add it to
> `DispatchService` if needed — see the spec for the signature). Show a
> confirmation dialog if the dispatcher tries to reassign a job that's
> currently in `onSite` status. Show me the plan first.

### Session 6 — Day view + Month view + final polish

> Implement Session 6 of
> `docs/web-redesign-extras/specs/SCHEDULE_SPEC.md`. Wire the view
> switcher to actually change between Day, Week, and Month views. If
> there's not enough time for both Day and Month, do Day first — it's
> more useful day-to-day. Add keyboard navigation (tab through job
> blocks, Enter opens). Add empty state for weeks with no jobs. Run
> through the full Definition of Done in the spec and tick off each item
> verbally before declaring complete. Show me the plan first.

---

## PDF Customiser — 8 sessions

### Session 1 — Data model + service + Firestore rules

> Implement Session 1 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Create the
> `PdfBranding` model with all enums and `BrandingCoverText` per the spec
> (full code shown in "Data model" section). Create
> `BrandingService` with cache, get, watch, save, upload methods.
> Add the Firestore rule for `companies/{companyId}/branding/{docId}`
> gated by `company_edit` permission. Write a quick test that creates a
> default branding, saves it, loads it back. No UI in this session. Show
> me the plan first.

### Session 2 — Customiser screen scaffold

> Implement Session 2 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Create
> `web_branding_screen.dart` with the topbar, two-pane layout, and
> tab-bar in the controls panel. Create `branding_controls_panel.dart`
> and `branding_preview_canvas.dart` shells with hardcoded sample
> content. Match the visual layout in
> `docs/web-redesign-extras/prototypes/pdf_customiser.html`. Use tokens
> from `lib/theme/web_theme.dart`. Don't bind to BrandingService yet.
> Show me the plan first.

### Session 3 — Brand controls (logo, colours, styles, switches)

> Implement Session 3 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Build out the
> Brand tab content: apply-to multi-select, logo upload preview, two
> colour pickers (Primary and Accent) with swatch + hex input + preset
> grid, three style toggle groups (cover, header, footer), header/footer
> switches, cover text fields, footer text field. Bind everything to
> local state — no Firestore save yet, no live preview wiring yet. Show
> me the plan first.

### Session 4 — Live preview for the Compliance Report

> Implement Session 4 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Create
> `pdf_preview_page.dart` (the paper-like container) and
> `pdf_preview_report.dart` (compliance report sample content with
> cover, header, summary section, asset register, footer). Wire the
> Session 3 local state to the preview so changing the primary colour,
> cover style, footer text, etc updates the preview in real time within
> 100ms. Use the prototype as the visual reference. Show me the plan
> first.

### Session 5 — Other three doc-type previews + switcher

> Implement Session 5 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Create
> `branding_doc_type_switcher.dart` (the four pills above the canvas)
> and the three additional preview widgets:
> `pdf_preview_quote.dart`, `pdf_preview_invoice.dart`,
> `pdf_preview_jobsheet.dart`. Each uses the same `pdf_preview_page`
> container but renders different sample content (the prototype shows
> exactly what each should contain). Verify that brand controls update
> all four equally — colours, styles, footer text are global. Show me
> the plan first.

### Session 6 — Wire to BrandingService (autosave + watch)

> Implement Session 6 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Replace local
> state with `StreamBuilder<PdfBranding>` watching
> `BrandingService.watchBranding`. Add a 500ms debounce on every control
> change before calling `BrandingService.saveBranding`. Add the "Saved"
> status pill in the topbar. Wire the logo upload to actually call
> `uploadLogo` and surface error toasts for invalid file type or
> oversize. Wire "Generate test PDF" to call the existing
> `compliance_report_service.dart` with the current branding. End of
> this session: customiser is fully functional from a write perspective.
> Mobile reads still use defaults. Show me the plan first.

### Session 7 — Mobile wiring: cover builder + compliance report service

> Implement Session 7 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Create the new
> `lib/services/pdf_widgets/pdf_cover_builder.dart` with all three style
> implementations (Bold, Minimal, Bordered). Modify
> `lib/services/compliance_report_service.dart` to read branding via
> `BrandingService.getBranding`, check `appliesTo`, use
> `PdfCoverBuilder` for the cover, and pass branding colours/styles into
> header/footer builders. Verify end-to-end: change primary colour to red
> on web, generate a compliance report from a phone, the PDF should be
> red. Show me the plan first.

### Session 8 — Wire the other three PDF services + extended header/footer

> Implement Session 8 of
> `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`. Repeat the
> Session 7 pattern for `quote_pdf_service.dart`,
> `invoice_pdf_service.dart`, and `template_pdf_service.dart`
> (jobsheets). Extend `PdfHeaderBuilder` and `PdfFooterBuilder` with
> the new style enums (Solid/Minimal/Bordered for header,
> Light/Minimal/Coloured for footer). Run through the end-to-end test
> from the spec: change branding on web, generate one of each PDF type
> on mobile, verify all four reflect the new branding; then untick
> Invoices from "Apply to all", regenerate an invoice, verify it falls
> back to defaults. Tick off each item in the Definition of Done before
> declaring complete. Show me the plan first.

---

## Tips for working through this efficiently

**Run the prototypes locally before each session.** Open the relevant
HTML file in your browser and click around. Two minutes of poking at the
prototype before opening Claude Code makes the briefing 10x clearer in
your head, and you'll catch design questions before Claude Code has to
guess.

**Don't switch between Schedule and PDF Customiser sessions.** Pick one
workstream and finish it (or get to a sensible pause point) before
starting the other. Context-switching between two big features burns the
window faster than you'd think.

**After each session, update a `PROGRESS.md` file in the repo.** A single
line per session: "Session 3 done — colour pickers working, switched
preset palette to use named colours instead of indices because…" The
next session, Claude Code reads it and knows the state without
re-discovering it.

**If Claude Code wants to take a shortcut you don't like**, say so
directly: "Don't simplify the rescheduleAndReassign method — keep the
atomic transaction even if it means a Cloud Function call. The optimistic
UI in the spec depends on that being atomic." Specific course-corrections
beat vague "do better" every time.

**The spec is the contract — but you can override it.** If you decide
mid-implementation that something in the spec is wrong, change the spec
first, commit that change, then ask Claude Code to follow the new spec.
Don't try to verbally override the spec mid-session — it gets confused.

**For the PDF Customiser specifically: test on real phones early.** After
Session 7, generate a compliance report on an actual iPhone and an actual
Android phone before moving on. PDF rendering on Flutter has historically
been platform-flaky and you want to catch any rendering differences before
you've wired up four services instead of just one.
