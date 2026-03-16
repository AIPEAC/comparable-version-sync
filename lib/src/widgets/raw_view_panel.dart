// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 002 — implement this file.

import 'package:flutter/material.dart';

/// Display mode 0 — shows raw records from both files side-by-side,
/// paginated with [recordsPerPage] items per page.
///
/// Layout:
/// - Desktop / landscape: 2 panels side-by-side (file1 left, file2 right).
/// - Phone portrait: stacked panels with a tab switch between them.
///
/// Navigation: Prev/Next buttons + jump-to-page dialog.
/// Uses _pageCache (current page ±1) to avoid loading all data at once.
class RawViewPanel extends StatefulWidget {
  /// Records from file 1, keyed by page index.
  final Future<List<Map<String, dynamic>>> Function(int page) loadPageFile1;

  /// Records from file 2, keyed by page index.
  final Future<List<Map<String, dynamic>>> Function(int page) loadPageFile2;

  final int recordsPerPage;
  final int totalPages;

  const RawViewPanel({
    super.key,
    required this.loadPageFile1,
    required this.loadPageFile2,
    required this.recordsPerPage,
    required this.totalPages,
  });

  @override
  State<RawViewPanel> createState() => _RawViewPanelState();
}

class _RawViewPanelState extends State<RawViewPanel> {
  // TODO(AGENT:002): implement
  // - _pageCache: Map<int, Future<...>> keeping current ±1 pages.
  // - Page navigation: Prev/Next buttons + jump dialog.
  // - Responsive layout: Row for wide screens, Column+Tabs for portrait.

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('RawViewPanel — not yet implemented'));
  }
}
