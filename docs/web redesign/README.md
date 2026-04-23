# Web Portal Redesign — Handoff Brief

**Scope:** Redesign the web dispatch portal (`lib/screens/web/`) to match the
marketing site's visual language. Mobile app UI is OUT OF SCOPE and must not
be modified.

---

## The job, in one paragraph

The current web portal (`lib/screens/web/`) inherits Material Design styling
from the mobile app. This makes it feel like a phone UI stretched onto a
1440px monitor — cards, FABs, mobile-style density — rather than a
professional B2B tool. We're rebuilding it to match the identity established
on the marketing site (`firethings.app`): navy + amber, Inter + Outfit,
confident SaaS. The mobile app stays exactly as it is. The services, models,
Firestore flows, PDF generation, and floor plan widget are all shared between
platforms and MUST NOT be touched.

---

## What changes

**Visual language** of every screen under `lib/screens/web/`:

- `web_dashboard_screen.dart`
- `web_shell.dart`
- `web_login_screen.dart`
- `web_schedule_screen.dart`
- `web_quotes_screen.dart`, `web_quote_detail_panel.dart`, `web_create_quote_screen.dart`
- `web_invoices_screen.dart`, `web_invoice_detail_panel.dart`, `web_create_invoice_screen.dart`
- `web_job_detail_panel.dart`, `web_create_job_screen.dart`
- `web_settings_screen.dart`
- `web_access_denied_screen.dart`
- `web_notification_feed.dart`, `web_notification_toast.dart`
- `cancel_job_dialog.dart`

**Layouts** where the desktop can do better than a scaled-up mobile form:

- Job detail → document layout with sticky summary rail (see prototype)
- Create forms → two-column with live preview where sensible
- Dashboard → KPI strip + two-column content (see prototype)
- Schedule → true calendar view (not a list)

---

## What DOES NOT change

**Do not modify these under any circumstances:**

- `lib/screens/floor_plans/interactive_floor_plan_screen.dart` — the pin
  placement maths took ages to get right and the `kIsWeb` scale branches at
  lines 734 and 793 are critical. Floor plan viewer wraps but doesn't
  reimplement.
- `lib/services/pdf_widgets/` — shared PDF component library. Reports and
  certificates generated here work identically on mobile and web.
- `lib/services/pdf_service.dart` and related PDF services.
- Any file under `lib/models/` — models are shared with mobile.
- Any file under `lib/services/` — business logic is shared with mobile.
- `firestore.rules` — permissions are being hardened in a separate workstream.
- Any file under `lib/screens/` that is NOT under `lib/screens/web/` — that's
  the mobile app.

**Shared theme files need a decision:**

`lib/utils/theme.dart` is currently used by both mobile and web. We're
introducing `lib/theme/web_theme.dart` for web-specific tokens. Web screens
should import from `web_theme.dart`. The existing `theme.dart` stays
untouched so mobile is unaffected.

---

## Design reference

Two HTML prototypes in `prototypes/`:

- `dispatch_dashboard.html` — establishes the shell (topbar + sidebar),
  KPI strip, primary content + rail layout, navy summary card pattern
- `job_detail.html` — document layout with sticky rail, timeline pattern,
  multi-section page, dark summary card with quick actions

**These are reference only.** Do not port the HTML into a WebView. Do not
copy the CSS classes as string keys. Translate the visual decisions into
Flutter widgets using the Dart tokens in `lib/theme/web_theme.dart` and the
conventions in `DESIGN_SYSTEM.md`.

---

## How to work on this

One screen per session. Pick one file under `lib/screens/web/`, redesign it,
ship it, move on. Don't try to redo the whole portal in one go.

For each screen:

1. Read `DESIGN_SYSTEM.md` for the rules.
2. Open the relevant prototype if there is one. If there isn't, extrapolate
   from the dashboard/job-detail prototypes using the documented patterns.
3. Before writing code, outline what you're going to change and which tokens
   you'll use.
4. Translate to Flutter. Use `GoogleFonts.inter()` and `GoogleFonts.outfit()`.
   Never use default Material typography on web screens.
5. Keep every Firestore stream, service call, navigation action, state
   handler, and data flow IDENTICAL. Only the visual layer changes.
6. Verify on Chrome at 1440×900 (primary), 1280×800 (min supported), and
   degrade gracefully below that.

---

## Definition of done (per screen)

- All visual elements use tokens from `web_theme.dart`, no hard-coded colours
  or font sizes
- No Material Design defaults visible (no elevation shadows, no FABs, no
  AppBars with Material styling, no BottomNavigationBar)
- Fonts: Inter for body, Outfit for page headlines only
- Keyboard focus visible on all interactive elements
- Hover states on all clickable elements
- All existing functionality preserved — every button that worked before
  still works, every stream still updates the UI
- Dark mode: NOT REQUIRED for v1, leave it for a later pass

---

## Order

Do them in this order unless there's a specific reason not to:

1. `web_theme.dart` — the tokens file (copy from `tokens.dart` in this folder)
2. `web_shell.dart` — topbar + sidebar, every other screen lives inside this
3. `web_dashboard_screen.dart` — matches `dispatch_dashboard.html` prototype
4. `web_job_detail_panel.dart` — matches `job_detail.html` prototype
5. `web_login_screen.dart` — simple, establishes the login pattern
6. `web_quotes_screen.dart` + related
7. `web_invoices_screen.dart` + related
8. `web_create_*` screens — all share a form pattern, do them together
9. `web_schedule_screen.dart` — biggest layout change, save for last
10. `web_settings_screen.dart`
11. `web_access_denied_screen.dart`, `web_notification_*`, `cancel_job_dialog.dart`

---

## Questions / ambiguities

When in doubt, ask before coding. The right question is better than the
wrong assumption. Particularly: if a design decision isn't covered in
`DESIGN_SYSTEM.md` and isn't visible in a prototype, flag it and propose
an option rather than guessing.
