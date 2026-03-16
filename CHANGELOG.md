# Changelog

## 1.0.1

### agent-001
- Implemented `context_resolver.dart`: `resolveParent` (dot-notation parent extraction) and `smallestSharedParent` (longest common dot-notation prefix across a set of paths).
- Implemented `compatibility_checker.dart`: `isCompatible` (true when exactly one side is null/absent) and `filterIncompatible` (retains only true conflicts).
- Implemented `json_comparator.dart`: reads both JSON files, runs `JsonDiffer`, recursively walks the `DiffNode` tree (changed / added / removed / sub-nodes) to produce `List<DiffContext>`, and filters via `CompatibilityChecker` when `mode == incompatibleOnly`.
- Implemented `sqlite_comparator.dart`: platform init (FFI on Windows/Linux, FFI-web on web, built-in on mobile), enumerates tables via `sqlite_master`, pages through records with `LIMIT`/`OFFSET`, matches by primary key when available and falls back to positional matching, produces `List<DiffContext>` with per-column diffs; filters via `CompatibilityChecker` when needed.

### agent-002
- Implemented `comparable_version_widget.dart`: async comparator init, loading/error states, dispatch to RawViewPanel or DiffViewPanel; JSON and SQLite raw-data loading; merge-result builder with dot-notation path application.
- Implemented `raw_view_panel.dart`: responsive 2-panel layout (side-by-side ≥ 600 dp / tabbed portrait), `_pageCache` keeping current ±1 pages, Prev/Next + jump-to-page dialog.
- Implemented `diff_view_panel.dart`: paginated diff list with `_resolvedChoices` accumulator, MergeOverlay tap flow, Finalize FAB showing resolved count, optional `mergeResultBuilder` hook.
- Implemented `merge_overlay.dart`: Accept Local / Accept Incoming / Manual Edit cards with animated selection highlight, Confirm FAB.

## 1.0.0

### default-agent
- Initial project setup: package skeleton, folder structure, enums, models, widget stubs.
- Cloned `google/dart-json_diff` (Apache 2.0) into `lib/third_party/dart_json_diff/`.
- Added dependencies: `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`, `path`, local `json_diff`.
- Wrote full architecture in `ARCHITECTURE.md` and `architecture.mdc`.
- Defined public API via `ComparableVersionWidget.rawView` and `.diffView` named constructors.
