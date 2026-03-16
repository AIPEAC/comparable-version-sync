// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/diff_context.dart';
import '../models/merge_result.dart';
import '../theme/comparable_version_theme.dart';
import 'merge_overlay.dart';

/// Display mode 1 — shows a paginated list of [DiffContext] items rendered
/// via [displayWidget].
///
/// Each tile opens a [MergeOverlay] on tap.
/// After all conflicts are resolved the "Finalize" FAB calls [onMergeComplete].
///
/// All visual dimensions are controlled via [theme].
class DiffViewPanel extends StatefulWidget {
  /// Full list of diffs to display and resolve.
  final List<DiffContext> diffs;

  /// Number of diff items shown per page.
  final int diffsPerPage;

  /// Required builder that renders a summary for each [DiffContext].
  final Widget Function(DiffContext) displayWidget;

  /// Optional custom widget rendered inside [MergeOverlay] above the cards.
  final Widget Function(DiffContext)? mergeWidget;

  /// Called with the final [MergeResult] when the user taps "Finalize".
  final void Function(MergeResult) onMergeComplete;

  /// Optional builder that constructs a [MergeResult] from the accumulated
  /// resolved choices map (`path → resolvedValue`). When `null`, a flat
  /// `MergeResult(mergedJson: choices)` is returned as a fallback.
  final MergeResult Function(Map<String, dynamic> resolvedChoices)?
      mergeResultBuilder;

  /// Whether to show the "Auto-accept compatible" toggle chip above the list.
  final bool showAcceptCompatibleButton;

  /// Initial state of the toggle:
  /// - `true` — compatible diffs are pre-accepted when the widget loads.
  /// - `false` — all diffs start unresolved.
  final bool acceptCompatibleByDefault;

  /// Whether to show a "View Raw Diff" button inside [MergeOverlay].
  final bool showDiffDetailButton;

  /// Alignment of the "View Raw Diff" button inside [MergeOverlay].
  final Alignment diffDetailButtonAlignment;

  /// Optional converter for non-serialisable values (passed through to
  /// [MergeOverlay] and [DiffDetailScreen]).
  final String Function(dynamic)? toJsonConverter;

  /// Visual configuration. Defaults to [ComparableVersionTheme.new].
  final ComparableVersionTheme theme;

  /// Creates a [DiffViewPanel].
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
    this.theme = const ComparableVersionTheme(),
  });

  @override
  State<DiffViewPanel> createState() => _DiffViewPanelState();
}

class _DiffViewPanelState extends State<DiffViewPanel> {
  int _currentPage = 0;
  final Map<int, List<DiffContext>> _pageCache = {};

  /// Accumulated merge decisions: dot-notation path → chosen value.
  final Map<String, dynamic> _resolvedChoices = {};

  /// Paths that were auto-resolved by the compatible-accept toggle.
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
      _pageCache.removeWhere((k, _) => (k - page).abs() > 1);
      return widget.diffs.sublist(start, end);
    });
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() {
      _currentPage = page;
      _getPage(page);
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
          theme: widget.theme,
          onResolved: (value) {
            setState(() {
              _resolvedChoices[diff.path] = value;
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
    final controller = TextEditingController(text: '${_currentPage + 1}');
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
    final t = widget.theme;

    if (widget.diffs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: t.iconSize * 3.2,
              color: Colors.green,
            ),
            SizedBox(height: t.cardPadding),
            const Text(
              'No differences found.',
              style: TextStyle(fontSize: 18),
            ),
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
                padding: EdgeInsets.fromLTRB(12, 12, 12, t.listBottomPadding),
                itemCount: page.length,
                itemBuilder: (_, i) => _diffTile(page[i]),
              ),
            ),
            _navigationBar(),
          ],
        ),
        Positioned(
          right: t.diffFabRightOffset,
          bottom: t.diffFabBottomOffset,
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
    final t = widget.theme;
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
                size: t.smallIconSize,
              ),
              showCheckmark: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _diffTile(DiffContext diff) {
    final t = widget.theme;
    final isResolved = _resolvedChoices.containsKey(diff.path);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.cardBorderRadius),
        onTap: () => _openMergeOverlay(diff),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: isResolved
                    ? Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: t.iconSize,
                      )
                    : Icon(
                        diff.isCompatible
                            ? Icons.info_outline
                            : Icons.warning_amber,
                        color: diff.isCompatible ? Colors.blue : Colors.orange,
                        size: t.iconSize,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diff.path,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: t.monoFontSize,
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
