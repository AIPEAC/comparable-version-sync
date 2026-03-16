// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/comparable_version_theme.dart';

/// Display mode 0 — shows raw records from both files in a paginated view.
///
/// ## Layout
///
/// - **Wide** (width > [ComparableVersionTheme.responsiveBreakpoint]):
///   two panels side-by-side separated by a vertical divider.
/// - **Narrow** (width ≤ breakpoint):
///   stacked panels with a [TabBar] toggle.
///
/// ## Pagination
///
/// Prev/Next buttons + jump-to-page dialog.
/// Only the current page ±1 is kept in memory; other pages are evicted.
///
/// All visual dimensions are controlled via [theme].
class RawViewPanel extends StatefulWidget {
  /// Async record loader for file 1, called with a zero-based page index.
  final Future<List<Map<String, dynamic>>> Function(int page) loadPageFile1;

  /// Async record loader for file 2, called with a zero-based page index.
  final Future<List<Map<String, dynamic>>> Function(int page) loadPageFile2;

  /// Number of records per page (determines the slice passed to the loaders).
  final int recordsPerPage;

  /// Total number of pages (used by the navigation bar).
  final int totalPages;

  /// Visual configuration. Defaults to [ComparableVersionTheme.new].
  final ComparableVersionTheme theme;

  /// Creates a [RawViewPanel].
  const RawViewPanel({
    super.key,
    required this.loadPageFile1,
    required this.loadPageFile2,
    required this.recordsPerPage,
    required this.totalPages,
    this.theme = const ComparableVersionTheme(),
  });

  @override
  State<RawViewPanel> createState() => _RawViewPanelState();
}

class _RawViewPanelState extends State<RawViewPanel>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;

  final Map<int, Future<List<Map<String, dynamic>>>> _cacheFile1 = {};
  final Map<int, Future<List<Map<String, dynamic>>>> _cacheFile2 = {};

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _primeCache(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Cache management ───────────────────────────────────────────────────────

  void _primeCache(int page) {
    for (var p = page - 1; p <= page + 1; p++) {
      if (p < 0 || p >= widget.totalPages) continue;
      _cacheFile1.putIfAbsent(p, () => widget.loadPageFile1(p));
      _cacheFile2.putIfAbsent(p, () => widget.loadPageFile2(p));
    }
    _cacheFile1.removeWhere((k, _) => (k - page).abs() > 1);
    _cacheFile2.removeWhere((k, _) => (k - page).abs() > 1);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= widget.totalPages) return;
    setState(() {
      _currentPage = page;
      _primeCache(page);
    });
  }

  // ── Jump dialog ────────────────────────────────────────────────────────────

  Future<void> _showJumpDialog() async {
    final controller = TextEditingController(text: '${_currentPage + 1}');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(hintText: '1 – ${widget.totalPages}'),
          autofocus: true,
          onSubmitted: (_) {
            final p = int.tryParse(controller.text);
            if (p != null) _goToPage(p - 1);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final p = int.tryParse(controller.text);
              if (p != null) _goToPage(p - 1);
              Navigator.of(ctx).pop();
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide =
            constraints.maxWidth > widget.theme.responsiveBreakpoint;
        return Column(
          children: [
            Expanded(
              child: isWide ? _widePanels() : _narrowPanels(),
            ),
            _navigationBar(),
          ],
        );
      },
    );
  }

  Widget _widePanels() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _filePanel('File 1', _cacheFile1[_currentPage]),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _filePanel('File 2', _cacheFile2[_currentPage]),
        ),
      ],
    );
  }

  Widget _narrowPanels() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'File 1'), Tab(text: 'File 2')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _filePanel('File 1', _cacheFile1[_currentPage]),
              _filePanel('File 2', _cacheFile2[_currentPage]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filePanel(
    String label,
    Future<List<Map<String, dynamic>>>? future,
  ) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(future),
      future: future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return Center(child: Text('$label: no records on this page.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: records.length,
          itemBuilder: (_, i) => _recordCard(records[i], i),
        );
      },
    );
  }

  Widget _recordCard(Map<String, dynamic> record, int indexOnPage) {
    final t = widget.theme;
    final globalIndex =
        _currentPage * widget.recordsPerPage + indexOnPage + 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#$globalIndex',
              style: TextStyle(
                fontSize: t.smallLabelFontSize,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(record),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: t.monoFontSize - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationBar() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed:
                  _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            ),
            GestureDetector(
              onTap: _showJumpDialog,
              child: Text(
                'Page ${_currentPage + 1} / ${widget.totalPages}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < widget.totalPages - 1
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
