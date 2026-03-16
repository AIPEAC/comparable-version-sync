// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';

/// Display mode 0 — shows raw records from both files side-by-side,
/// paginated with [recordsPerPage] items per page.
///
/// Layout:
/// - Desktop / landscape (width > 600 dp): 2 panels side-by-side.
/// - Phone portrait (width ≤ 600 dp): stacked panels with a tab switch.
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

class _RawViewPanelState extends State<RawViewPanel>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;

  // Current page ±1 kept in memory; older pages evicted.
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
    final controller =
        TextEditingController(text: '${_currentPage + 1}');
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
        final isWide = constraints.maxWidth > 600;
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
          return Center(
            child: Text('$label: no records on this page.'),
          );
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
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(record),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
