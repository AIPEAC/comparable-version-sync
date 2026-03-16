// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 002 — implement this file.

import 'package:flutter/material.dart';

import '../models/diff_context.dart';
import '../models/merge_result.dart';

/// Display mode 1 — shows paginated diff items, each rendered via [displayWidget].
///
/// Tapping a diff item opens [MergeOverlay].
/// After all conflicts are resolved the FAB calls [onMergeComplete].
class DiffViewPanel extends StatefulWidget {
  final List<DiffContext> diffs;
  final int diffsPerPage;
  final Widget Function(DiffContext) displayWidget;
  final Widget Function(DiffContext)? mergeWidget;
  final void Function(MergeResult) onMergeComplete;

  const DiffViewPanel({
    super.key,
    required this.diffs,
    required this.diffsPerPage,
    required this.displayWidget,
    this.mergeWidget,
    required this.onMergeComplete,
  });

  @override
  State<DiffViewPanel> createState() => _DiffViewPanelState();
}

class _DiffViewPanelState extends State<DiffViewPanel> {
  // TODO(AGENT:002): implement
  // - _pageCache: Map<int, List<DiffContext>> keeping current ±1 pages.
  // - _resolvedChoices: Map<String path, dynamic resolvedValue>.
  // - Page navigation: Prev/Next + jump dialog.
  // - Tap item → open MergeOverlay.
  // - FAB (bottom-right) → build MergeResult from _resolvedChoices → onMergeComplete.

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('DiffViewPanel — not yet implemented'));
  }
}
