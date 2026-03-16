# comparable_version_sync

A Flutter package for comparing and merging versions of **JSON** or **SQLite** data with a fully configurable, git-conflict-style diff/merge widget.
[Link to pub.dev](https://pub.dev/packages/comparable_version_sync)

---
## Demostration
![comparable_version_sync_JnULoDU6yg](https://github.com/user-attachments/assets/9e595eee-d952-432e-a38b-e585648785e7)

---

## Features

- **Two display modes** — raw paginated view or per-field diff view.
- **Two file types** — JSON (any Map/List root) or SQLite (multi-table).
- **Git-style merge resolution** — Accept Local, Accept Incoming, or Manual Edit per field.
- **Auto-accept compatible diffs** — one-tap to accept all fields where only one side has a value.
- **Side-by-side diff detail** — read-only view of the parent JSON context with highlights.
- **Synchronized scroll** — both panels scroll together vertically; independent horizontal scroll per panel.
- **Resizable split panel** — drag the divider in the diff detail screen to adjust the panel ratio.
- **Responsive layout** — automatically switches between side-by-side and tabbed layout based on screen width.
- **Fully configurable** — every dimension, colour, and animation parameter is exposed via `ComparableVersionTheme`.
- **Lazy loading** — only the current page ±1 is kept in memory; safe for large files.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  comparable_version_sync:
    path: ../comparable_version_sync   # or your pub.dev reference
```

Then run:

```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:comparable_version_sync/comparable_version_sync.dart';

// Diff view from in-memory JSON (no file I/O inside the package)
ComparableVersionWidget.diffViewFromJson(
  jsonA: jsonDecode(jsonStringA),   // or a Map/List you already have
  jsonB: jsonDecode(jsonStringB),
  comparisonMode: ComparisonMode.allDiffs,
  diffsPerPage: 10,
  displayWidget: (diff) => Text(
    'A: ${diff.valueA}  →  B: ${diff.valueB}',
    style: const TextStyle(fontSize: 12, color: Colors.black54),
    overflow: TextOverflow.ellipsis,
  ),
  returnType: ReturnType.json,
  onMergeComplete: (result) {
    print(result.mergedJson); // your merged data
  },
)
```

---

## Display Modes

### `ComparableVersionWidget.diffViewFromJson`

Shows every detected difference as a tappable tile. Tapping opens a full-screen merge overlay where the user picks Local, Incoming, or types a custom value. A "Finalize" FAB collects all choices and calls `onMergeComplete`.

```dart
ComparableVersionWidget.diffViewFromJson(
  jsonA: jsonA,
  jsonB: jsonB,
  comparisonMode: ComparisonMode.allDiffs,
  diffsPerPage: 10,
  displayWidget: (diff) => Text('${diff.valueA} → ${diff.valueB}'),
  // Optional: custom content above the choice cards in the merge overlay
  mergeWidget: (diff) => MyCustomDiffSummary(diff: diff),
  // Optional features
  showAcceptCompatibleButton: true,
  acceptCompatibleByDefault: true,
  showDiffDetailButton: true,
  returnType: ReturnType.json,
  onMergeComplete: (result) => handleMerge(result),
)
```

### `ComparableVersionWidget.rawViewFromJson`

Shows the raw JSON records from both in-memory structures side-by-side (or in a tab view on narrow screens), paginated. No per-field resolution — "Accept File 1" FAB immediately returns the left side as the winner.

```dart
ComparableVersionWidget.rawViewFromJson(
  jsonA: jsonA,
  jsonB: jsonB,
  recordsPerPage: 10,
  returnType: ReturnType.json,
  onMergeComplete: (result) => handleMerge(result),
)
```

### `ComparableVersionWidget.diffView` and `.rawView` (file-based)

For apps that prefer to pass file paths (JSON or SQLite), the original
constructors are still available:

```dart
ComparableVersionWidget.diffView(
  fileType: FileType.json,
  file1Path: path1,
  file2Path: path2,
  comparisonMode: ComparisonMode.incompatibleOnly,
  diffsPerPage: 10,
  returnType: ReturnType.json,
  onMergeComplete: (result) => handleMerge(result),
)
```

---

## API Reference

### `ComparableVersionWidget`

#### Shared parameters (all constructors)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `comparisonMode` | `ComparisonMode` | — **required** | `allDiffs` or `incompatibleOnly` |
| `returnType` | `ReturnType` | — **required** | `json`, `sql`, or `both` |
| `onMergeComplete` | `void Function(MergeResult)` | — **required** | Called with the merge result |
| `theme` | `ComparableVersionTheme` | `ComparableVersionTheme()` | Visual configuration |

#### `diffViewFromJson` only

| Parameter | Type | Default | Description |
|---|---|---|---|
| `diffsPerPage` | `int` | `10` | Diffs shown per page |
| `displayWidget` | `Widget Function(DiffContext)` | — **required** | Summary row renderer |
| `mergeWidget` | `Widget Function(DiffContext)?` | `null` | Custom content above choice cards |
| `showAcceptCompatibleButton` | `bool` | `false` | Show auto-accept toggle chip |
| `acceptCompatibleByDefault` | `bool` | `true` | Pre-accept compatible diffs on load |
| `showDiffDetailButton` | `bool` | `false` | Show "View Raw Diff" button in overlay |
| `diffDetailButtonAlignment` | `Alignment` | `Alignment.topRight` | Placement of the raw diff button |
| `toJsonConverter` | `String Function(dynamic)?` | `null` | Fallback serialiser for custom types |

#### `rawViewFromJson` only

| Parameter | Type | Default | Description |
|---|---|---|---|
| `recordsPerPage` | `int` | `10` | Records shown per page |

#### File-based constructors (`diffView` / `rawView`)

These legacy constructors accept file paths and a `FileType` (JSON/SQLite).
On JSON, they may use platform-specific I/O; on SQLite they use `sqflite` /
FFI factories to open the databases.

---

### `ComparisonMode`

| Value | Behaviour |
|---|---|
| `ComparisonMode.allDiffs` | Every field that differs between the two files |
| `ComparisonMode.incompatibleOnly` | Only true conflicts — both sides non-null and different. Fields where one side is absent or null are skipped. |

---

### `ReturnType`

| Value | `MergeResult` fields populated |
|---|---|
| `ReturnType.json` | `mergedJson` |
| `ReturnType.sql` | `mergedRows` |
| `ReturnType.both` | Both `mergedJson` and `mergedRows` |

---

### `DiffContext`

Passed to `displayWidget`, `mergeWidget`, and `onMergeComplete` callbacks.

| Field | Type | Description |
|---|---|---|
| `path` | `String` | Dot-notation path to the differing field (e.g. `"user.address.city"`) |
| `parentContext` | `String` | Dot-notation path of the smallest shared parent |
| `valueA` | `dynamic` | Value from file 1 (`null` if absent) |
| `valueB` | `dynamic` | Value from file 2 (`null` if absent) |
| `isCompatible` | `bool` | `true` when only one side is non-null (no true conflict) |
| `parentValueA` | `dynamic` | Full parent JSON subtree from file 1 |
| `parentValueB` | `dynamic` | Full parent JSON subtree from file 2 |

---

### `MergeResult`

| Field | Type | Description |
|---|---|---|
| `mergedJson` | `Map<String, dynamic>?` | Merged JSON structure; `null` when `returnType == ReturnType.sql` |
| `mergedRows` | `List<Map<String, dynamic>>?` | Merged rows; `null` when `returnType == ReturnType.json` |

---

## Theming

`ComparableVersionTheme` exposes every visual knob as a named parameter.
All parameters are optional and have sensible defaults.

```dart
const myTheme = ComparableVersionTheme(
  // Panel split
  initialSplitRatio: 0.4,       // left panel starts at 40 %
  minSplitRatio: 0.15,
  maxSplitRatio: 0.85,
  dividerWidth: 8.0,

  // Code lines
  lineHeight: 22.0,
  linePadding: 10.0,
  codeCanvasWidth: 3000.0,      // increase for very deeply-indented JSON

  // Horizontal pan bar
  panBarHeight: 28.0,
  panBarHandleWidth: 56.0,
  panBarHandleHeight: 5.0,

  // Highlight colours (ARGB)
  localHighlightColor: Color(0x2200BCD4),     // cyan tint for local
  incomingHighlightColor: Color(0x22FF5722),  // deep-orange tint for incoming

  // Scroll animation
  scrollAnimationDuration: Duration(milliseconds: 200),
  scrollAnimationCurve: Curves.easeInOut,

  // Layout
  responsiveBreakpoint: 720.0,  // wider breakpoint for the raw view

  // Cards
  cardBorderRadius: 16.0,
  cardPadding: 14.0,
  selectedBorderWidth: 2.5,
  cardAnimationDuration: Duration(milliseconds: 120),

  // Icons & text
  iconSize: 22.0,
  smallIconSize: 20.0,
  monoFontSize: 14.0,
  smallLabelFontSize: 12.0,

  // FAB offsets
  fabBottomOffset: 24.0,
  fabRightOffset: 24.0,
  diffFabBottomOffset: 80.0,
  diffFabRightOffset: 24.0,
  listBottomPadding: 90.0,
  overlayBodyBottomPadding: 110.0,
);

ComparableVersionWidget.diffView(
  theme: myTheme,
  ...
)
```

Use `copyWith` to derive a variant from the defaults:

```dart
final compactTheme = const ComparableVersionTheme().copyWith(
  lineHeight: 16,
  panBarHeight: 18,
  monoFontSize: 11,
);
```

### Full `ComparableVersionTheme` parameter reference

#### DiffDetailScreen — split panel

| Parameter | Default | Description |
|---|---|---|
| `initialSplitRatio` | `0.5` | Starting width ratio of the left panel `[0, 1]` |
| `minSplitRatio` | `0.1` | Minimum ratio after dragging |
| `maxSplitRatio` | `0.9` | Maximum ratio after dragging |
| `dividerWidth` | `6.0` | Width of the draggable vertical divider (dp) |

#### DiffDetailScreen — code lines

| Parameter | Default | Description |
|---|---|---|
| `lineHeight` | `20.0` | Fixed height per code line (dp) |
| `linePadding` | `8.0` | Horizontal padding inside each line cell (dp) |
| `codeCanvasWidth` | `2000.0` | Virtual canvas width for horizontal scroll (dp) |

#### DiffDetailScreen — horizontal pan bar

| Parameter | Default | Description |
|---|---|---|
| `panBarHeight` | `24.0` | Height of the bottom pan bar (dp) |
| `panBarHandleWidth` | `48.0` | Width of the pill handle (dp) |
| `panBarHandleHeight` | `4.0` | Height of the pill handle (dp) |

#### DiffDetailScreen — highlights

| Parameter | Default | Description |
|---|---|---|
| `localHighlightColor` | `Color(0x334CAF50)` | Semi-transparent green for left panel |
| `incomingHighlightColor` | `Color(0x33FFC107)` | Semi-transparent amber for right panel |

#### DiffDetailScreen — scroll animation

| Parameter | Default | Description |
|---|---|---|
| `scrollAnimationDuration` | `Duration(milliseconds: 300)` | Tap-to-scroll animation duration |
| `scrollAnimationCurve` | `Curves.easeOut` | Tap-to-scroll animation curve |

#### RawViewPanel

| Parameter | Default | Description |
|---|---|---|
| `responsiveBreakpoint` | `600.0` | Width (dp) at which side-by-side layout activates |

#### Cards (MergeOverlay, DiffViewPanel)

| Parameter | Default | Description |
|---|---|---|
| `cardBorderRadius` | `12.0` | Corner radius of choice cards |
| `selectedBorderWidth` | `2.0` | Border width of the selected card |
| `unselectedBorderWidth` | `1.0` | Border width of unselected cards |
| `cardPadding` | `12.0` | Inner padding of choice cards |
| `cardAnimationDuration` | `Duration(milliseconds: 150)` | Selection animation duration |

#### Icons

| Parameter | Default | Description |
|---|---|---|
| `iconSize` | `20.0` | Standard action icon size |
| `smallIconSize` | `18.0` | Small/secondary icon size |

#### Text

| Parameter | Default | Description |
|---|---|---|
| `monoFontSize` | `13.0` | Monospace content font size |
| `smallLabelFontSize` | `11.0` | Index / label font size |
| `textFieldBorderRadius` | `8.0` | Manual-edit TextField corner radius |

#### Layout offsets

| Parameter | Default | Description |
|---|---|---|
| `fabBottomOffset` | `16.0` | Raw view FAB bottom offset |
| `fabRightOffset` | `16.0` | Raw view FAB right offset |
| `diffFabBottomOffset` | `72.0` | Diff view FAB bottom offset (clears nav bar) |
| `diffFabRightOffset` | `16.0` | Diff view FAB right offset |
| `listBottomPadding` | `80.0` | List bottom padding (clears FAB) |
| `overlayBodyBottomPadding` | `100.0` | Overlay scroll body bottom padding (clears FAB) |

---

## File Type Details

### JSON

- Accepts any valid JSON file whose root is a `Map` or `List`.
- Comparison walks the decoded JSON object graph directly with a lightweight\n  built-in comparator (no external diff dependency).
- Web: file I/O (`dart:io`) is unavailable; raw view shows empty pages but diff\n  view works when file paths are substituted with pre-loaded data.

### SQLite

- Compares tables by name across both databases.
- Within each table, rows are matched by primary key when detectable (`PRAGMA table_info`); falls back to positional matching otherwise.
- Records are loaded lazily in pages of 100 rows during comparison.
- Requires the `sqflite` family of packages (included).
- Initialises the correct FFI factory per platform automatically.

---

## Comparison Modes

### `ComparisonMode.allDiffs`

Every field that has a different value between the two files appears in the diff list, including:

- Fields present in file 1 but missing in file 2 (`valueB == null`).
- Fields present in file 2 but missing in file 1 (`valueA == null`).
- Fields present in both but with different non-null values.

### `ComparisonMode.incompatibleOnly`

Only true conflicts are shown — both sides must have a non-null value and those values must differ. This is useful when you want to ignore additive changes and focus only on genuine conflicts.

---

## Merge Resolution

Each diff in `diffView` mode can be resolved in three ways inside the `MergeOverlay`:

| Option | Result |
|---|---|
| **Accept Local (File 1)** | Uses `diff.valueA` |
| **Accept Incoming (File 2)** | Uses `diff.valueB` |
| **Manual Edit** | Uses the text typed into the editable field |

Tapping "Confirm" stores the choice. The "Finalize" FAB is always visible and calls `onMergeComplete` with whatever has been resolved so far — you can finalise at any point.

### Auto-accept compatible diffs

When `showAcceptCompatibleButton: true`, a toggle chip appears above the list. Enabling it automatically resolves all diffs where `isCompatible == true` (i.e. only one side has a value) by choosing the non-null side. Disabling the toggle removes only the auto-resolved entries, preserving any manual choices.

---

## Architecture

```
comparable_version_sync/
├── lib/
│   ├── comparable_version_sync.dart     ← public barrel export
│   └── src/
│       ├── enums/
│       │   ├── comparison_mode.dart
│       │   ├── file_type.dart
│       │   └── return_type.dart
│       ├── models/
│       │   ├── diff_context.dart        ← per-field diff data
│       │   └── merge_result.dart        ← final merged output
│       ├── theme/
│       │   └── comparable_version_theme.dart  ← all visual knobs
│       ├── comparison/
│       │   ├── base_comparator.dart
│       │   ├── compatibility_checker.dart
│       │   ├── context_resolver.dart
│       │   ├── json_comparator.dart     ← built-in JSON comparator
│       │   └── sqlite_comparator.dart   ← uses sqflite
│       └── widgets/
│           ├── comparable_version_widget.dart  ← entry point
│           ├── diff_view_panel.dart
│           ├── merge_overlay.dart
│           ├── diff_detail_screen.dart
│           └── raw_view_panel.dart
└── lib/third_party/                     ← (no runtime code; only legacy vendor assets if present)
```

**Public API surface** (exported by the barrel):

- `ComparableVersionWidget` — the widget entry point
- `ComparableVersionTheme` — visual configuration
- `FileType`, `ComparisonMode`, `ReturnType` — enums
- `DiffContext`, `MergeResult` — data models

Everything else is internal.

---

## License

This package is APACHE 2.0 licensed. See [LICENSE](LICENSE).

