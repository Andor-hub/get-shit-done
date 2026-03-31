# Phase 2: Core App - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the complete main app UI from scratch: Today view (habit cards + logging), habit management (create/edit/delete/reorder), all three logging types working end-to-end, per-habit History view, and per-habit Stats view. No widget code in this phase — that is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Today View Layout
- **D-01:** Display habits as **cards** (rounded, with breathing room) — not compact rows
- **D-02:** Each card shows **name + progress only** (e.g. "Water — 3/8 cups", "Meditate — Done"). No streak inline on the card.
- **D-03:** Empty state is a single **"Add habit" button**. When tapped, a picker opens that offers: (a) premade habits (Protein, Water) with pre-configured defaults that the user can adjust, or (b) blank habit from scratch with full configuration. No other content in the empty state.

### Logging Interactions
- **D-04:** **Boolean habits** — tap anywhere on the card toggles done/undone. No separate button needed.
- **D-05:** **Count habits (e.g. Water)** — a `+` button on the card increments by 1 each tap. Fast, one-handed, matches widget.
- **D-06:** **Input habits (e.g. Protein)** — a `+` button on the card opens a number input sheet for manual value entry. User types the value and confirms. This matches the widget deep-link behavior in Phase 3.
- **D-07:** The logging control (tap / `+` button) is the primary interaction. No need for a separate habit detail screen to log — logging happens directly from the Today card.

### Navigation Structure
- **D-08:** **Tab bar** with three top-level tabs: Today, History, Stats.
- **D-09:** Habit management (add/edit/delete/reorder) is accessed via **Edit mode on the Today view** — an "Edit" button in the navbar puts the habit list into iOS-standard edit mode (drag handles for reorder, swipe-to-delete or delete buttons, tap habit to open edit sheet).
- **D-10:** History tab and Stats tab are **per-habit** — each tab shows a list of habits, and tapping one drills into that habit's history log or stats detail.

### Visual Theme
- **D-11:** App respects **iOS system appearance** (dark/light mode) — does not force either. Uses SwiftUI's standard adaptive colors so it looks correct in both modes.
- **D-12:** **Single accent color** across all habits — one brand accent (exact color is Claude's discretion, but should be calm and health-appropriate, e.g. a blue or teal). Used for progress fills, active states, and primary buttons.

### Claude's Discretion
- Exact accent color (blue, teal, green — pick what looks best in both dark and light mode)
- Stats detail layout — how streak, best streak, and 30-day rate are visually arranged (numbers + labels, simple chart, or both)
- History detail layout — scrollable list of past dates with logged values (calendar grid vs. chronological list)
- Loading/transition animations — keep lightweight, no elaborate animations
- Add habit sheet vs. full-screen cover — Claude picks what fits best for the configuration flow
- Confirmation dialog copy for habit deletion

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & Requirements
- `.planning/REQUIREMENTS.md` — Full requirement list with REQ-IDs (HAB-01–05, LOG-01–04, TODAY-01–04, HIST-01–03, STAT-01–04)
- `.planning/ROADMAP.md` — Phase 2 success criteria and dependency on Phase 1
- `.planning/PROJECT.md` — Core value ("one tap from home screen"), constraints, and out-of-scope items

### Existing Code (Phase 1 output)
- `HabitX/HabitX/Models/Schema/HabitSchemaV1.swift` — `Habit` and `HabitLog` @Model definitions; `HabitType` enum (boolean/count/input). All Phase 2 UI must use these models as-is.
- `HabitX/HabitX/Models/SharedModelContainer.swift` — Shared ModelContainer singleton. Phase 2 views get the container from the environment (already injected in HabitXApp.swift).
- `HabitX/HabitX/HabitXApp.swift` — App entry point; .modelContainer already wired. Today view replaces ContentView as the root.

### Technology Constraints
- `CLAUDE.md` — Full stack requirements: SwiftUI, @Observable, SwiftData @Query, Swift 6 strict concurrency, iOS 17+ APIs only

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `HabitSchemaV1.Habit`: has `name`, `habitType` (String), `dailyTarget` (Double), `unit` (String), `sortOrder` (Int), `logs` ([HabitLog]) — all fields needed for Today cards and management
- `HabitSchemaV1.HabitLog`: has `date` (Date), `value` (Double), `habit` (Habit?) — sufficient for history and stats computation
- `HabitType` enum: `.boolean`, `.count`, `.input` — use this for all type-switching logic

### Established Patterns
- SwiftData `@Query` in SwiftUI views for live data (Phase 1 established this pattern)
- `SharedModelContainer.container` via `.modelContainer()` environment — do not create new containers
- `@Observable` ViewModels (not `ObservableObject`) per CLAUDE.md stack

### Integration Points
- `ContentView.swift` is a placeholder — Phase 2 replaces it with the real `TodayView` as the root content
- Widget extension reads from the same store — Phase 2 models/logs must be compatible with what Phase 3 will read

</code_context>

<specifics>
## Specific Ideas

- The add habit flow should feel like a picker/menu moment first ("choose a template or start blank"), then a configuration form — not just a blank form immediately. Protein and Water are the two premade options.
- Count habits and input habits both show a `+` button on the card, but the behavior differs: count = immediate +1 increment, input = opens number entry sheet.
- Boolean tap-to-toggle on the whole card is intentional — it mirrors how the widget works (single tap = done).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 2 scope.

</deferred>

---

*Phase: 02-core-app*
*Context gathered: 2026-03-29*
