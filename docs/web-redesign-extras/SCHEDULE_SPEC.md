# Schedule — Implementation Spec

**Status:** Proposed
**Effort:** ~6 sessions, roughly 1-2 weeks elapsed
**Prerequisites:** `lib/theme/web_theme.dart` exists with FtColors etc.
The web shell (topbar + sidebar) has been redesigned per the original
`web-redesign/` package.

**Reference prototype:** `docs/web-redesign-extras/prototypes/schedule.html`

---

## What we're building

A web-only resource calendar showing dispatched jobs across all engineers in
the company. The page lives at the existing `/schedule` route and replaces
the contents of `lib/screens/web/web_schedule_screen.dart`.

Three view modes:

- **Day** — single day, denser detail with hour-row time grid
- **Week** (default) — Mon–Sun across the top, engineers down the side, jobs
  as cards in cells
- **Month** — overview, jobs as small blocks, mostly for capacity planning

Jobs are draggable. Drop on a different cell = reschedule. Drop on a
different engineer's row = reassign. Drop on the unassigned bucket = remove
assignment. Every drag triggers a Firestore update via existing
`DispatchService`.

---

## What changes / what doesn't

**Changes:**
- `lib/screens/web/web_schedule_screen.dart` — replaced with new layout
- `lib/screens/web/widgets/` — several new widgets specific to web schedule
  (see file list below)

**Does not change:**
- `lib/models/dispatched_job.dart` — already has `scheduledDate`,
  `assignedTo`, `assignedToName` fields we need
- `lib/services/dispatch_service.dart` — already has `updateScheduledDate`
  and reassignment methods (verify these exist; if not, add them with the
  same patterns as existing methods)
- Mobile schedule screen (engineers don't see this — they see their own
  assigned-job list which is different)
- Firestore rules — schedule reads existing `dispatched_jobs` collection,
  writes via `DispatchService` which already respects permissions

---

## Files to create

```
lib/screens/web/
├── web_schedule_screen.dart                ← rewritten, top-level container
└── widgets/schedule/                       ← new folder
    ├── schedule_view_switcher.dart         ← Day/Week/Month segmented control
    ├── schedule_filter_bar.dart            ← chips for priority + engineer filters
    ├── schedule_week_grid.dart             ← the main resource grid (week view)
    ├── schedule_day_grid.dart              ← hour-rows time grid (day view)
    ├── schedule_month_grid.dart            ← overview grid (month view)
    ├── schedule_engineer_row.dart          ← a single engineer's row + cells
    ├── schedule_day_cell.dart              ← one day's cell for one engineer
    ├── schedule_job_block.dart             ← draggable job card
    ├── schedule_unassigned_row.dart        ← special row for unassigned jobs
    ├── schedule_day_header.dart            ← top header for one day column
    └── schedule_navigation_controls.dart   ← prev / today / next + date label
```

---

## Data model

### Existing fields we use

From `lib/models/dispatched_job.dart`:

- `id`, `siteId`, `siteName`, `customerName`
- `assignedTo` (engineer UID) and `assignedToName`
- `scheduledDate` (DateTime?)
- `estimatedDuration` (String?, e.g. "1.5h")
- `priority` (JobPriority enum: emergency, urgent, normal, low)
- `status` (DispatchedJobStatus enum: created, assigned, accepted,
  enRoute, onSite, completed, cancelled, declined)
- `description`

From `lib/services/company_service.dart`:

- Member list with `uid`, `displayName`, `role`, `isActive`

### New fields (none required)

The schedule reads existing data. Engineer presence (online/onsite/offline)
should come from existing presence tracking if it exists; if not, infer:

- "On site" = any active job for them has `status: onSite`
- "Online" = they have a recent FCM token activity (if you track this)
- "Offline" = no recent activity in the last 30 minutes

If presence isn't tracked at all yet, just show "available" for everyone and
add a TODO for v2.

---

## Service methods needed

Most of these probably exist. Verify and add if missing.

### `DispatchService` (existing)

```dart
// Existing — verify
Future<void> updateScheduledDate(String jobId, DateTime? newDate);
Future<void> assignToEngineer(String jobId, String engineerId, String engineerName);
Future<void> unassignJob(String jobId);

// May need adding — atomic combined update
Future<void> rescheduleAndReassign({
  required String jobId,
  required DateTime? newScheduledDate,
  required String? newAssignedTo,
  required String? newAssignedToName,
});
```

The combined `rescheduleAndReassign` is important for drag-and-drop because
moving a job between engineers AND changing its date in one drop should be
atomic (single Firestore write, single push notification to the new
engineer). If you do it as two separate writes, the new engineer might get
a notification before the date is correct.

### Schedule queries

The week grid needs all jobs for a date range, grouped by engineer. Add to
`DispatchService` if not present:

```dart
Stream<List<DispatchedJob>> watchJobsForDateRange({
  required String companyId,
  required DateTime from,
  required DateTime to,
});
```

This streams updates so the schedule live-refreshes as engineers update
their job statuses on mobile.

---

## Layout (Week view, primary)

Reference: `prototypes/schedule.html` — open in a browser, this is exactly
what to build.

Top to bottom:

1. **Sub-header** — date range title ("21 — 27 April"), week stats (e.g.
   "Week 17 · 38 jobs scheduled · 4 unassigned"), prev/today/next nav
   buttons, view switcher (Day/Week/Month segmented control), Print
   button, "New job" primary button.

2. **Filter strip** — engineer filter chips ("All engineers / Available
   only / By region"), priority chips with colour dots ("Emergency / Urgent
   / Normal / Completed" — toggleable), capacity stats on the right
   (Booked / Unassigned / Capacity %).

3. **Calendar grid:**

   - First row is the day-headers row (sticky to top): leftmost cell says
     "Engineer" in caps, then 7 day cells with day-name + day-number (like
     "21 / Apr · Tue") + a small stat ("8 jobs · full" in red, "7 jobs" in
     amber, "5 jobs" in default).
   - Today's column has a soft amber gradient background.
   - One row per engineer, leftmost cell shows avatar + name + workload
     bar (green/amber/red based on % of capacity), then 7 day cells.
   - Each day cell is a drop target.
   - Within each day cell, jobs are stacked vertically as cards.
   - Engineer rows that are offline (e.g. on holiday) get diagonal stripes
     in their row to signal unavailability.

4. **Unassigned row at the bottom** — same layout as engineer rows but the
   leftmost cell has a warning-amber background and shows "Unassigned" + a
   count of pending jobs. Drag a job FROM here onto an engineer to assign.
   Drag a job TO here from an engineer to unassign.

### Job block visual

Each job block:

- Coloured left border (3px) by priority
- Time + duration top line (small, mono, fg2): "10:30 · 1.5h"
- Title (medium weight, fg1, max 2 lines, ellipsis): "Fire alarm reset —
  sounder panel"
- Site (small, fg2, single line, ellipsis): "Berkeley Sq"

Visual states:

- **Default** — white background, soft shadow
- **In progress** (status = `onSite` or `enRoute`) — amber soft gradient,
  amber pulsing dot in top-right corner, glow border
- **Completed** — green soft background, line-through title, slightly
  reduced opacity
- **Emergency priority** — red soft gradient background regardless of state
- **Dragging** — opacity 0.4, cursor grabbing

### Drag interactions

Use Flutter's built-in `Draggable` and `DragTarget`:

```dart
// Inside ScheduleJobBlock
Draggable<DispatchedJob>(
  data: job,
  feedback: Material(
    elevation: 8,
    child: SizedBox(width: 200, child: ScheduleJobBlockCard(job)),
  ),
  childWhenDragging: Opacity(opacity: 0.4, child: ...),
  child: ScheduleJobBlockCard(job),
)

// Inside ScheduleDayCell
DragTarget<DispatchedJob>(
  onWillAccept: (job) => job != null && _canAcceptHere(job),
  onAccept: (job) => _handleDrop(job),
  builder: (ctx, candidate, _) => Container(
    decoration: BoxDecoration(
      color: candidate.isNotEmpty ? FtColors.accentSoft : null,
      border: candidate.isNotEmpty
        ? Border.all(color: FtColors.accent, width: 2)
        : null,
    ),
    child: ...,
  ),
)
```

Where `_handleDrop` extracts the target engineer (from the row this cell
belongs to) and target date (from the day this cell represents) and calls:

```dart
DispatchService.instance.rescheduleAndReassign(
  jobId: job.id,
  newScheduledDate: targetDate,
  newAssignedTo: targetEngineerId,
  newAssignedToName: targetEngineerName,
);
```

Apply optimistic UI: update the local job list immediately, sync to
Firestore, revert on failure with a toast. The pattern is in the bug-fix
spec (Section 10). Without optimistic UI the drag feels laggy.

---

## Day view

Same engineers along the top this time as columns, hours down the side as
rows. Each job becomes a vertical block sized by its duration. This is
denser than week view and useful when "I want to see exactly what Sarah is
doing today, hour by hour."

Optional for v1 — implement if you have time, otherwise the view switcher
shows it as disabled with a "coming soon" tooltip.

---

## Month view

A standard month grid (5-6 weeks shown). Each day cell shows up to 3
"job pellets" — tiny coloured dots or short bars with the priority colour
and engineer initial — plus a "+5 more" affordance if there are extras.
Click a day to drill into Day view for that date.

Drag-and-drop NOT supported in month view (cells are too small to be a
useful drop target). Click a job pellet to open the job detail.

Optional for v1 — implement if you have time.

---

## Performance considerations

For a small team (5-10 engineers, ~100 jobs/week) the week grid is trivially
fast. For larger teams or longer date ranges, two things matter:

1. **Stream pagination** — don't load all jobs ever, load the visible date
   range plus a small buffer. The `watchJobsForDateRange` query above
   already does this.

2. **Avoid full rebuild on drag** — when a drag completes, only the source
   and target cells should rebuild, not the whole grid. Use `ValueKey` on
   each row and cell so Flutter's diffing works correctly.

If the grid feels janky during dragging, profile before optimising. It
probably doesn't.

---

## Edge cases and what to do

**Engineer becomes inactive while their row is showing.** Strike through
their name, fade their avatar, but don't remove the row mid-week — the dispatcher
needs to see what was assigned to them so they can reassign.

**Job completed while being dragged.** Don't let it happen — disable drag on
completed jobs (`status == DispatchedJobStatus.completed`).

**Job in `onSite` status being dragged elsewhere.** Show a confirm dialog:
"This job is currently on site with [engineer]. Are you sure you want to
reschedule?" If they confirm, do it; the engineer will get a notification.

**Drop on the same cell.** No-op, no Firestore write.

**Drop on a holiday/offline engineer's row.** Allow it (they might come
back), but show a yellow warning toast: "Engineer is currently offline. Job
assigned but they may not see it until they return."

**Two simultaneous drags from different dispatchers.** Last-write-wins is
fine for v1. The Firestore real-time stream will rebroadcast the final state
to both dispatchers within a couple of seconds.

**Job with `null` scheduledDate.** Goes in the Unassigned row by default.
Once dragged onto a day cell, the date is set.

**Job with `null` assignedTo but a real `scheduledDate`.** Still goes in
Unassigned (since no engineer to put it under). Show the date as a small
chip on the job card so the dispatcher knows it's already scheduled.

---

## Definition of done

- All four widget files render correctly with mock data
- Real DispatchedJob streams populate the grid
- Drag-and-drop reschedule (within same engineer) updates Firestore
- Drag-and-drop reassign (between engineers) updates Firestore atomically
- Unassigned bucket works in both directions
- Optimistic UI: drags feel instant
- Failure path: if Firestore write fails, the job snaps back and a toast
  shows the error
- Today column is highlighted
- Filter chips actually filter the displayed jobs
- View switcher works (Week mandatory, Day and Month optional for v1)
- Engineer workload bar reflects actual job count vs capacity
- Hover states on every clickable element
- Keyboard accessible (tab through job blocks, Enter to open)
- Tested on Chrome at 1440×900 and 1280×800

---

## Implementation order (one item per session)

### Session 1 — scaffold

Create the new schedule screen with hardcoded mock data. Get the layout
working at the visual level. No Firestore, no drag-and-drop yet. This
session should produce something that looks like the prototype but isn't
functional.

Files to create:
- `web_schedule_screen.dart` (top container)
- `schedule_week_grid.dart` (the grid container)
- `schedule_day_header.dart`
- `schedule_engineer_row.dart`
- `schedule_day_cell.dart`
- `schedule_job_block.dart` (display only, not draggable yet)

### Session 2 — wire to real data

Replace the mock data with real streams:

- Engineer list from `CompanyService`
- Jobs from `DispatchService.watchJobsForDateRange`

Add the navigation controls (prev/today/next) and the date range state.
Filter chips wire up but don't filter yet.

### Session 3 — job block details + click-to-open

Polish the job block widget — priority colours, status states (in-progress
amber, completed strikethrough), click handler that opens the existing
`WebJobDetailPanel` as a slide-over.

Wire the filter chips (priority and engineer filtering). Wire the workload
bars on engineer rows.

### Session 4 — drag-and-drop within engineer (reschedule)

Add `Draggable` to `ScheduleJobBlock` and `DragTarget` to
`ScheduleDayCell`. Drop on a different day = call
`DispatchService.updateScheduledDate`. Use optimistic UI.

Test edge cases: drop on same cell (no-op), drop on completed job's cell,
drop with null target date.

### Session 5 — drag-and-drop between engineers (reassign) + unassigned

Add the unassigned row. Make engineer rows accept drops from other
engineers (reassign). Make the unassigned row accept drops (unassign) and
let users drag FROM unassigned onto engineers (assign).

Use the new `rescheduleAndReassign` atomic method (add it to
`DispatchService` if it doesn't exist).

Test: reassign with confirmation dialog if status is `onSite`.

### Session 6 — Day view + Month view + polish

Implement the other two view modes if time allows. Wire the view switcher.
Final polish pass: keyboard navigation, focus states, loading skeletons,
empty state ("No jobs scheduled this week — drag from Unassigned to get
started").

If you only get one extra view, do **Day** (it's more useful day-to-day
than Month).

---

## Tests to write as you go

For each service method:

- `rescheduleAndReassign` writes both fields atomically (mock Firestore)
- `watchJobsForDateRange` streams updates correctly
- Optimistic UI: state reverts on failure

For the widget layer (golden tests are useful here):

- Week grid renders correctly with 0 jobs
- Week grid renders correctly with 50 jobs across 5 engineers
- Engineer workload bar colours change at 50% / 75% / 100% thresholds
- Job block in `onSite` state renders with amber treatment
- Drop target highlight appears during drag-over

---

## What to ask if you're unsure

When in doubt during implementation, ask the user. Particular questions
worth raising:

- "Is engineer presence tracked anywhere? If not, should I default everyone
  to 'available' for now?"
- "What's the company's default 'capacity' per engineer per day? I'm
  assuming 8 hours of work for the workload bar — confirm?"
- "Should Month view drilling into Day view change the route, or just the
  in-page state?"
- "Are dispatchers allowed to drag a job that's currently in `onSite`
  status, or should that be blocked entirely?"
