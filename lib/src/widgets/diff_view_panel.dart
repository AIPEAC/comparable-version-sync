// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/diff_context.dart';
import '../models/merge_result.dart';
import 'merge_overlay.dart';

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

  /// Optional builder that constructs a [MergeResult] from the accumulated
  /// resolved choices map (`path → resolvedValue`). When null a flat
  /// `MergeResult(mergedJson: choices)` is returned as a fallback.
  final MergeResult Function(Map<String, dynamic> resolvedChoices)?
      mergeResultBuilder;

  /// Whether to show the "Accept All Compatible" toggle chip.
  final bool showAcceptCompatibleButton;

  /// Initial state of the toggle: true = pre-accept compatible diffs on load.
  final bool acceptCompatibleByDefault;

  /// Whether to show a "View Raw Diff" button inside MergeOverlay.
  final bool showDiffDetailButton;

  /// Alignment of the "View Raw Diff" button inside MergeOverlay.
  final Alignment diffDetailButtonAlignment;

  /// Optional converter for non-serialisable values.
  final String Function(dynamic)? toJsonConverter;

  const DiffViewPanel({
    super.key,
    required this.diffs,
    required this.diffsPerPage,
    required this.displayWidget,
    this.mergeWidget,
    required this.onMergeComplete,
    this.mergeResultBuilder,
    this.showAcceptCompatibleButton = false,
    this.acceptCompatibleByDefault = true,
    this.showDiffDetailButton = false,
    this.diffDetailButtonAlignment = Alignment.topRight,
    this.toJsonConverter,
  });

  @override
  State<DiffViewPanel> createState() => _DiffViewPanelState();
}

class _DiffViewPanelState extends State<DiffViewPanel> {
  int _currentPage = 0;
  final Map<int, List<DiffContext>> _pageCache = {};

  /// Accumulated merge decisions: dot-notation path → chosen value.
  final Map<String, dynamic> _resolvedChoices = {};

  /// Paths that were auto-resolved by the compatible-accept toggle
  /// (so we can undo only those, not user-manual resolutions).
  final Set<String> _autoResolvedPaths = {};

  /// Current state of the auto-accept-compatible toggle.
  bool _autoAcceptEnabled = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.showAcceptCompatibleButton && widget.acceptCompatibleByDefault) {
      _autoAcceptEnabled = true;
      _applyAutoAccept();
    }
  }

  // ── Auto-accept compatible ─────────────────────────────────────────────────

  int get _compatibleCount =>
      widget.diffs.where((d) => d.isCompatible).length;

  void _applyAutoAccept() {
    for (final diff in widget.diffs) {
      if (diff.isCompatible && !_resolvedChoices.containsKey(diff.path)) {
        final value = diff.valueA ?? diff.valueB;
        _resolvedChoices[diff.path] = value;
        _autoResolvedPaths.add(diff.path);
      }
    }
  }

  void _removeAutoAccept() {
    for (final path in _autoResolvedPaths) {
      _resolvedChoices.remove(path);
    }
    _autoResolvedPaths.clear();
  }

  void _onToggleAutoAccept(bool enable) {
    setState(() {
      _autoAcceptEnabled = enable;
      if (enable) {
        _applyAutoAccept();
      } else {
        _removeAutoAccept();
      }
    });
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  int get _totalPages =>
      (widget.diffs.length / widget.diffsPerPage).ceil().clamp(1, 1 << 30);

  List<DiffContext> _getPage(int page) {
    return _pageCache.putIfAbsent(page, () {
      final start = page * widget.diffsPerPage;
      final end = min(start + widget.diffsPerPage, widget.diffs.length);
      // Keep only current ±1 pages in cache.
      _pageCache.removeWhere((k, _) => (k - page).abs() > 1);
      return widget.diffs.sublist(start, end);
    });
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() {
      _currentPage = page;
      _getPage(page); // prime cache
    });
  }

  // ── Merge overlay ──────────────────────────────────────────────────────────

  Future<void> _openMergeOverlay(DiffContext diff) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MergeOverlay(
          diff: diff,
          mergeWidget: widget.mergeWidget,
          showDiffDetailButton: widget.showDiffDetailButton,
          diffDetailButtonAlignment: widget.diffDetailButtonAlignment,
          toJsonConverter: widget.toJsonConverter,
          onResolved: (value) {
            setState(() {
              _resolvedChoices[diff.path] = value;
              // If the user manually resolves a previously auto-accepted path,
              // it is no longer tracked as auto-resolved.
              _autoResolvedPaths.remove(diff.path);
            });
          },
        ),
      ),
    );
  }

  void _finalizeMerge() {
    final MergeResult result;
    if (widget.mergeResultBuilder != null) {
      result = widget.mergeResultBuilder!(
        Map<String, dynamic>.unmodifiable(_resolvedChoices),
      );
    } else {
      result = MergeResult(
        mergedJson: Map<String, dynamic>.from(_resolvedChoices),
      );
    }
    widget.onMergeComplete(result);
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
          decoration: InputDecoration(hintText: '1 – $_totalPages'),
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
    if (widget.diffs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No differences found.', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    final page = _getPage(_currentPage);
    return Stack(
      children: [
        Column(
          children: [
            if (widget.showAcceptCompatibleButton) _compatibleChipBar(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: page.length,
                itemBuilder: (_, i) => _diffTile(page[i]),
              ),
            ),
            _navigationBar(),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 72,
          child: FloatingActionButton.extended(
            onPressed: _finalizeMerge,
            icon: const Icon(Icons.merge_type),
            label: Text(
              'Finalize (${_resolvedChoices.length}/${widget.diffs.length})',
            ),
          ),
        ),
      ],
    );
  }

  Widget _compatibleChipBar() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            FilterChip(
              label: Text('Auto-accept compatible ($_compatibleCount)'),
              selected: _autoAcceptEnabled,
              onSelected: _onToggleAutoAccept,
              avatar: Icon(
                _autoAcceptEnabled
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                size: 18,
              ),
              showCheckmark: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _diffTile(DiffContext diff) {
    final isResolved = _resolvedChoices.containsKey(diff.path);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMergeOverlay(diff),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: isResolved
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      )
                    : Icon(
                        diff.isCompatible
                            ? Icons.info_outline
                            : Icons.warning_amber,
                        color:
                            diff.isCompatible ? Colors.blue : Colors.orange,
                        size: 20,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diff.path,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    widget.displayWidget(diff),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
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
                'Page ${_currentPage + 1} / $_totalPages',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
