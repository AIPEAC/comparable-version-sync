// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 002 — implement this file.

import 'package:flutter/material.dart';

import '../enums/comparison_mode.dart';
import '../enums/file_type.dart';
import '../enums/return_type.dart';
import '../models/diff_context.dart';
import '../models/merge_result.dart';

/// The main entry-point widget for comparing two files.
///
/// Use the named constructors to get compile-time safety for the required
/// parameters of each display mode.
///
/// The widget is fully responsive and fills any parent box.
class ComparableVersionWidget extends StatefulWidget {
  // --- shared fields ---
  final FileType fileType;
  final String file1Path;
  final String file2Path;
  final ComparisonMode comparisonMode;
  final ReturnType returnType;
  final void Function(MergeResult) onMergeComplete;

  // --- display mode 0 (raw view) ---
  final int? recordsPerPage;

  // --- display mode 1 (diff view) ---
  final int? diffsPerPage;

  /// Required for display mode 1 at construction time (named constructor).
  final Widget Function(DiffContext)? displayWidget;

  /// Optional custom widget for merge resolution. Defaults to plain text.
  final Widget Function(DiffContext)? mergeWidget;

  /// True when constructed via [diffView]; false when via [rawView].
  /// Used by the state to choose which panel to render.
  final bool isDiffView;

  /// Display mode 0 — raw paginated view of both files side-by-side.
  const ComparableVersionWidget.rawView({
    super.key,
    required this.fileType,
    required this.file1Path,
    required this.file2Path,
    required this.comparisonMode,
    this.recordsPerPage = 10,
    required this.returnType,
    required this.onMergeComplete,
  })  : isDiffView = false,
        diffsPerPage = null,
        displayWidget = null,
        mergeWidget = null;

  /// Display mode 1 — paginated diff view with a required custom display widget.
  const ComparableVersionWidget.diffView({
    super.key,
    required this.fileType,
    required this.file1Path,
    required this.file2Path,
    required this.comparisonMode,
    this.diffsPerPage = 10,
    required Widget Function(DiffContext) this.displayWidget,
    this.mergeWidget,
    required this.returnType,
    required this.onMergeComplete,
  })  : isDiffView = true,
        recordsPerPage = null;

  @override
  State<ComparableVersionWidget> createState() =>
      _ComparableVersionWidgetState();
}

class _ComparableVersionWidgetState extends State<ComparableVersionWidget> {
  // TODO(AGENT:002): implement
  // 1. On init: run comparator (JsonComparator or SqliteComparator) based on fileType.
  // 2. Store List<DiffContext> in state.
  // 3. Show loading indicator while comparison runs.
  // 4. Show error if comparison fails.
  // 5. Render RawViewPanel or DiffViewPanel based on widget.isDiffView.
  // 6. Pass accumulated merge choices to onMergeComplete via MergeOverlay FAB.

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('ComparableVersionWidget — not yet implemented'));
  }
}
