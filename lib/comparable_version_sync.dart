// Copyright 2026 comparable_version_sync authors. All rights reserved.
//
// A Flutter package providing a GUI widget for comparing two versions of
// JSON or SQLite files, with git-conflict-style merge resolution.
//
// ## Quick start
//
// ```dart
// import 'package:comparable_version_sync/comparable_version_sync.dart';
//
// ComparableVersionWidget.diffView(
//   fileType: FileType.json,
//   file1Path: '/path/to/v1.json',
//   file2Path: '/path/to/v2.json',
//   comparisonMode: ComparisonMode.allDiffs,
//   displayWidget: (diff) => Text('${diff.valueA} → ${diff.valueB}'),
//   returnType: ReturnType.json,
//   onMergeComplete: (result) => print(result.mergedJson),
// )
// ```
//
// See [ComparableVersionWidget] for the full API.
// See [ComparableVersionTheme] to customise all visual dimensions, colours,
// and animation parameters.

export 'src/enums/comparison_mode.dart';
export 'src/enums/file_type.dart';
export 'src/enums/return_type.dart';
export 'src/models/diff_context.dart';
export 'src/models/merge_result.dart';
export 'src/theme/comparable_version_theme.dart';
export 'src/widgets/comparable_version_widget.dart';
