# Architecture — comparable_version_sync

## Overview
A Flutter package providing a GUI widget to compare 2 versions of JSON or side-by-side, with git-conflict-style merge resolution.

---

## Directory Structure

```
lib/
  comparable_version_sync.dart       # Public package API (barrel export)
  main.dart                          # Test harness app (not part of package API)
  src/
    enums/
      file_type.dart                 # FileType { json, sqlite }
      comparison_mode.dart           # ComparisonMode { allDiffs, incompatibleOnly }
      return_type.dart               # ReturnType { json, sql, both }
    models/
      diff_context.dart              # One diff item: path, valueA, valueB, isCompatible
      merge_result.dart              # Final output: mergedJson / mergedRows
    comparison/
      base_comparator.dart           # Abstract interface
      json_comparator.dart           # JSON diff via local dart-json_diff clone
      sqlite_comparator.dart         # SQLite diff via sqflite; lazy page-by-page loading
      compatibility_checker.dart     # Filters diffs to true conflicts only (mode 1)
      context_resolver.dart          # Finds smallest shared parent path
    widgets/
      comparable_version_widget.dart # Main entry-point widget (2 named constructors)
      raw_view_panel.dart            # Display mode 0: paginated raw records
      diff_view_panel.dart           # Display mode 1: paginated diff items
      merge_overlay.dart             # Conflict resolution UI with FAB
  third_party/
    dart_json_diff/                  # Local clone of google/dart-json_diff (Apache 2.0)
```

---

## Public API

### `ComparableVersionWidget`

Two named constructors enforce compile-time parameter requirements.

**Display mode 0 — raw paginated view:**
```dart
ComparableVersionWidget.rawView({
  required int fileType,        // 0=JSON, 1=SQLite
  required String file1Path,
  required String file2Path,
  required int comparisonMode,  // 0=allDiffs, 1=incompatibleOnly
  int recordsPerPage = 10,
  required int returnType,      // 0=JSON, 1=SQL, 2=both
  required void Function(MergeResult) onMergeComplete,
})
```

**Display mode 1 — diff view with custom widget:**
```dart
ComparableVersionWidget.diffView({
  required int fileType,
  required String file1Path,
  required String file2Path,
  required int comparisonMode,
  int diffsPerPage = 10,
  required Widget Function(DiffContext) displayWidget,  // compile-time required
  Widget Function(DiffContext)? mergeWidget,            // optional; default = plain text
  required int returnType,
  required void Function(MergeResult) onMergeComplete,
})
```

The widget is fully responsive — no fixed dimensions; fits any parent box.

---

## Key Models

### `DiffContext`
```dart
class DiffContext {
  final String path;           // dot-notation path to the differing field
  final String parentContext;  // smallest shared parent path
  final dynamic valueA;        // value in file1
  final dynamic valueB;        // value in file2
  final bool isCompatible;     // true if only one side has a non-null value
}
```

### `MergeResult`
```dart
class MergeResult {
  final Map<String, dynamic>? mergedJson;
  final List<Map<String, dynamic>>? mergedRows;
}
```

---

## Comparison Logic

### JSON
Uses a local clone of [google/dart-json_diff](https://github.com/google/dart-json_diff) (Apache 2.0).
Integrated as a local path dependency. Produces a flat list of `DiffContext` from the diff result.

### SQLite
Uses the `sqflite` package. Lazy-loads records via `LIMIT`/`OFFSET` — no full-table load.
Matches records by detected primary key; falls back to cartesian product.
Uses `sqflite_common_ffi` on Windows/Linux, `sqflite_common_ffi_web` on web.

### Compatibility Mode (comparisonMode=1)
A diff is **compatible** (hidden) when one side is null/missing and the other has a value.
A diff is **incompatible** (shown) when both sides have non-null, differing values.

---

## Pagination
- Both panels use a `_pageCache` map: only current page ±1 is kept in memory.
- SQLite uses `LIMIT pageSize OFFSET page*pageSize` per query.
- Navigation: Prev/Next buttons + jump-to-page dialog.

---

## Merge Flow
1. User browses diffs in `DiffViewPanel`.
2. Tapping a diff opens `MergeOverlay` (accept local / accept incoming / manual edit).
3. All resolved choices accumulate in widget state.
4. FAB at bottom of overlay confirms; `onMergeComplete(MergeResult)` fires.

---

## Dependencies
| Package | Purpose |
|---|---|
| `sqflite ^2.4.2` | SQLite on Android/iOS/macOS |
| `sqflite_common_ffi` | SQLite on Windows/Linux desktop |
| `sqflite_common_ffi_web` | SQLite on web (experimental) |
| `path` | File path utilities |
| `dart_json_diff` (local) | JSON diffing (cloned from Google, Apache 2.0) |
