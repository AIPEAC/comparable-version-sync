# Changelog
## 1.1.0+0

- Added data-based JSON constructors: `ComparableVersionWidget.diffViewFromJson`
  and `ComparableVersionWidget.rawViewFromJson`, which accept decoded JSON
  roots (`Map`/`List`/scalar) and perform comparison/visualisation without any
  `dart:io` inside the package.
- Updated `JsonComparator` to work purely on in-memory JSON values via
  `compareStrings` / `compareRoots`; the old file-path based `compare` now
  throws `UnsupportedError` and is only used by the legacy file-based widget
  constructors.
- Kept the original file-path constructors (`diffView` / `rawView`) for apps
  that prefer to pass paths (JSON or SQLite), but all documentation now
  recommends the new `*FromJson` APIs for JSON.
- Refreshed `ARCHITECTURE.md`, `README.md`, and `pubspec.yaml` docs to match
  the new JSON data-first design.

## 1.0.2+7
- Fixed homepage in pubspec.yaml.
- Corrected LICENSE copyright display.

## 1.0.2+6
- fixed LICENSE copyright year.
- fixed homepage in pubspec.yaml.

## 1.0.2+5

### A-001
- Add GIF for demonstration.

## 1.0.2+3

### A-00X
- Added `ComparableVersionTheme` — every hardcoded dimension, colour, and animation
  parameter is now a named field with a sensible default and full dartdoc.
  Pass it to any constructor via the new `theme` parameter on
  `ComparableVersionWidget`, or use `copyWith` to tweak only what you need.
- Threaded `ComparableVersionTheme` through the entire widget tree:
  `ComparableVersionWidget` → `DiffViewPanel` → `MergeOverlay` → `DiffDetailScreen`
  and `RawViewPanel`.
- Exported `ComparableVersionTheme` from the public barrel
  (`comparable_version_sync.dart`).
- Inlined `dart_json_diff` source into `lib/src/vendor/json_diff.dart`,
  eliminating the path dependency that blocked pub.dev publishing.
  Apache 2.0 copyright header preserved; full license copied to
  `LICENSE-dart-json-diff` at the repository root.
- Added `collection` as an explicit dependency (previously transitive only).
- Removed `cupertino_icons` (unused app-only dependency).
- Removed `publish_to: none` — package is now publishable to pub.dev.
- Relaxed SDK lower-bound to `>=3.5.0 <4.0.0` for broader compatibility.
- Rewrote `README.md` with full quick-start, API tables, theming reference,
  architecture diagram, and platform support matrix.
- Cleaned up `pubspec.yaml` (removed boilerplate comments, tightened description).

## 1.0.2

### A-001
- Added `parentValueA` / `parentValueB` fields to `DiffContext` (full parent JSON subtree from each file).
- Added `valueAtPath(root, path)` helper to `ContextResolver` for dot-notation navigation of nested JSON/Map structures.
- Updated `JsonComparator` to parse root objects and populate `parentValueA`/`parentValueB` on every `DiffContext`; added `_parentPath` helper returning `""` for top-level diffs so the full root object is captured.
- Updated `SqliteComparator` to set `parentValueA`/`parentValueB` to the full row map for field-level diffs and to the row map / null for missing-row diffs.
- Implemented `lib/src/widgets/diff_detail_screen.dart`: read-only git-style side-by-side view with synchronized vertical scroll, independent horizontal scroll per panel, draggable split divider, shared horizontal pan bar, and diff-key highlighting (green = local, amber = incoming).

### A-002
- Added `showAcceptCompatibleButton` and `acceptCompatibleByDefault` parameters to `ComparableVersionWidget.diffView` and wired through to `DiffViewPanel`.
- `DiffViewPanel` now auto-resolves all compatible diffs (`isCompatible == true`) on load when `acceptCompatibleByDefault` is true; toggling the `FilterChip` off removes only auto-accepted resolutions, preserving manually-resolved ones.
- Added `_compatibleChipBar()` toolbar above the diff list showing a `FilterChip` labelled `"Auto-accept compatible (N)"`.
- Added `showDiffDetailButton`, `diffDetailButtonAlignment`, and `toJsonConverter` parameters to `ComparableVersionWidget.diffView`, wired through `DiffViewPanel` to `MergeOverlay`.
- `MergeOverlay` now shows a "View Raw Diff" button (icon: `Icons.difference`) — in the `AppBar` actions when alignment is `topRight`, or as a `FilledButton.icon` in a `Stack` overlay otherwise — that pushes `DiffDetailScreen`.
- Created stub `lib/src/widgets/diff_detail_screen.dart` for compilation; full implementation pending Agent 001.

## 1.0.1

### A-001
- Implemented `context_resolver.dart`: `resolveParent` (dot-notation parent extraction) and `smallestSharedParent` (longest common dot-notation prefix across a set of paths).
- Implemented `compatibility_checker.dart`: `isCompatible` (true when exactly one side is null/absent) and `filterIncompatible` (retains only true conflicts).
- Implemented `json_comparator.dart`: reads both JSON files, runs `JsonDiffer`, recursively walks the `DiffNode` tree (changed / added / removed / sub-nodes) to produce `List<DiffContext>`, and filters via `CompatibilityChecker` when `mode == incompatibleOnly`.
- Implemented `sqlite_comparator.dart`: platform init (FFI on Windows/Linux, FFI-web on web, built-in on mobile), enumerates tables via `sqlite_master`, pages through records with `LIMIT`/`OFFSET`, matches by primary key when available and falls back to positional matching, produces `List<DiffContext>` with per-column diffs; filters via `CompatibilityChecker` when needed.
- Fixed `json_comparator.dart` for web safety: `dart:io` import aliased; `compare()` now throws `UnsupportedError` with a clear message on web; added `compareStrings()` as the web-safe alternative for callers with pre-loaded JSON strings.

### A-002
- Implemented `comparable_version_widget.dart`: async comparator init, loading/error states, dispatch to RawViewPanel or DiffViewPanel; JSON and SQLite raw-data loading; merge-result builder with dot-notation path application.
- Implemented `raw_view_panel.dart`: responsive 2-panel layout (side-by-side ≥ 600 dp / tabbed portrait), `_pageCache` keeping current ±1 pages, Prev/Next + jump-to-page dialog.
- Implemented `diff_view_panel.dart`: paginated diff list with `_resolvedChoices` accumulator, MergeOverlay tap flow, Finalize FAB showing resolved count, optional `mergeResultBuilder` hook.
- Implemented `merge_overlay.dart`: Accept Local / Accept Incoming / Manual Edit cards with animated selection highlight, Confirm FAB.
- Fixed `main.dart` test harness: replaced non-existent asset paths with inline JSON written to `Directory.systemTemp`; web path shows a friendly error via the widget's built-in error view.
- Added multi-table SQLite raw view: table selector dropdown (hidden when only one table) above `RawViewPanel`; switching table recomputes `_rawTotalPages` and rekeys the panel to flush the page cache.
- Synced `pubspec.yaml` version to `1.0.1+2`.

## 1.0.0

### A-000
- Initial project setup: package skeleton, folder structure, enums, models, widget stubs.
- Cloned `google/dart-json_diff` (Apache 2.0) into `lib/third_party/dart_json_diff/`.
- Added dependencies: `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`, `path`, local `json_diff`.
- Wrote full architecture in `ARCHITECTURE.md` and `architecture.mdc`.
- Defined public API via `ComparableVersionWidget.rawView` and `.diffView` named constructors.
