// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/diff_context.dart';

/// Read-only, git-style side-by-side view for a single [DiffContext].
///
/// Left panel = local / file1 (parentValueA).
/// Right panel = incoming / file2 (parentValueB).
///
/// Features:
/// - Draggable vertical divider to adjust panel split ratio.
/// - Synchronized vertical scroll across both panels.
/// - Independent horizontal scroll per panel.
/// - Shared horizontal pan bar at the bottom.
/// - Tap a line to scroll both panels so that line is near the top.
/// - Differing field highlighted: green (left) / amber (right).
class DiffDetailScreen extends StatefulWidget {
  final DiffContext diff;

  /// Optional converter invoked when the default [jsonEncode] throws.
  final String Function(dynamic)? toJsonConverter;

  const DiffDetailScreen({
    super.key,
    required this.diff,
    this.toJsonConverter,
  });

  @override
  State<DiffDetailScreen> createState() => _DiffDetailScreenState();
}

class _DiffDetailScreenState extends State<DiffDetailScreen> {
  // ── split ratio ────────────────────────────────────────────────────────────
  double _splitRatio = 0.5;

  // ── vertical scroll (synchronized) ────────────────────────────────────────
  final _vertA = ScrollController();
  final _vertB = ScrollController();
  bool _syncingVert = false;

  // ── horizontal scroll (independent per panel + shared pan bar) ────────────
  final _horizA = ScrollController();
  final _horizB = ScrollController();
  double _hOffset = 0;

  // ── line data ──────────────────────────────────────────────────────────────
  late final List<String> _linesA;
  late final List<String> _linesB;
  late final Set<int> _highlightA;
  late final Set<int> _highlightB;

  static const double _lineHeight = 20.0;
  static const double _panelPadding = 8.0;

  @override
  void initState() {
    super.initState();

    _linesA = _toLines(widget.diff.parentValueA);
    _linesB = _toLines(widget.diff.parentValueB);

    final diffKey = widget.diff.path.split('.').last;
    _highlightA = _computeHighlight(_linesA, diffKey);
    _highlightB = _computeHighlight(_linesB, diffKey);

    _linkVerticalControllers();
  }

  @override
  void dispose() {
    _vertA.dispose();
    _vertB.dispose();
    _horizA.dispose();
    _horizB.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<String> _toLines(dynamic value) {
    if (value == null) return ['(no data)'];
    try {
      return const JsonEncoder.withIndent('  ').convert(value).split('\n');
    } catch (_) {
      if (widget.toJsonConverter != null) {
        return widget.toJsonConverter!(value).split('\n');
      }
      return [value.toString()];
    }
  }

  /// Returns the set of line indices that should be highlighted.
  ///
  /// Starts at the first line containing `"key":` and extends until the
  /// bracket/brace depth returns to the same level it was on the key line.
  Set<int> _computeHighlight(List<String> lines, String key) {
    final result = <int>{};
    final keyPattern = '"$key":';
    int? startDepth;
    bool inBlock = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (!inBlock) {
        if (line.contains(keyPattern)) {
          result.add(i);
          startDepth = _depthBefore(lines, i);
          // Check if this single line closes back to startDepth already.
          if (_depthAt(line) == 0) {
            inBlock = false;
          } else {
            inBlock = true;
          }
        }
      } else {
        result.add(i);
        // Finished when cumulative depth since the key line returns to startDepth.
        if (_cumulativeDepth(lines, result.reduce((a, b) => a < b ? a : b), i) <=
            (startDepth ?? 0)) {
          inBlock = false;
        }
      }
    }
    return result;
  }

  /// Counts the nesting depth (sum of `{` and `[` minus `}` and `]`) in
  /// all lines up to but not including [lineIndex].
  int _depthBefore(List<String> lines, int lineIndex) {
    var depth = 0;
    for (var i = 0; i < lineIndex; i++) {
      depth += _depthAt(lines[i]);
    }
    return depth;
  }

  /// Net depth change contributed by a single [line].
  int _depthAt(String line) {
    var d = 0;
    for (final ch in line.runes) {
      if (ch == 123 /* { */ || ch == 91 /* [ */) d++;
      if (ch == 125 /* } */ || ch == 93 /* ] */) d--;
    }
    return d;
  }

  /// Cumulative depth from [startLine] through [endLine] (inclusive).
  int _cumulativeDepth(List<String> lines, int startLine, int endLine) {
    var depth = 0;
    for (var i = startLine; i <= endLine && i < lines.length; i++) {
      depth += _depthAt(lines[i]);
    }
    return depth;
  }

  void _linkVerticalControllers() {
    _vertA.addListener(() {
      if (_syncingVert) return;
      _syncingVert = true;
      if (_vertB.hasClients) _vertB.jumpTo(_vertA.offset);
      _syncingVert = false;
    });
    _vertB.addListener(() {
      if (_syncingVert) return;
      _syncingVert = true;
      if (_vertA.hasClients) _vertA.jumpTo(_vertB.offset);
      _syncingVert = false;
    });
  }

  void _scrollToLine(int lineIndex) {
    final target = (lineIndex * _lineHeight).clamp(
      0.0,
      _vertA.hasClients ? _vertA.position.maxScrollExtent : double.infinity,
    );
    _vertA.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Diff: ${widget.diff.path}')),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                return Row(
                  children: [
                    // Left panel (file 1 / local)
                    SizedBox(
                      width: totalWidth * _splitRatio,
                      child: _Panel(
                        label: 'Local (file 1)',
                        lines: _linesA,
                        highlightLines: _highlightA,
                        highlightColor: Colors.green.withValues(alpha: 0.20),
                        vertController: _vertA,
                        horizController: _horizA,
                        hOffset: _hOffset,
                        lineHeight: _lineHeight,
                        padding: _panelPadding,
                        onLineTap: _scrollToLine,
                      ),
                    ),
                    // Draggable divider
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _splitRatio = (_splitRatio +
                                  details.delta.dx / totalWidth)
                              .clamp(0.1, 0.9);
                        });
                      },
                      child: Container(
                        width: 6,
                        color: Theme.of(context).dividerColor,
                        child: const Center(
                          child: VerticalDivider(width: 0),
                        ),
                      ),
                    ),
                    // Right panel (file 2 / incoming)
                    Expanded(
                      child: _Panel(
                        label: 'Incoming (file 2)',
                        lines: _linesB,
                        highlightLines: _highlightB,
                        highlightColor: Colors.amber.withValues(alpha: 0.20),
                        vertController: _vertB,
                        horizController: _horizB,
                        hOffset: _hOffset,
                        lineHeight: _lineHeight,
                        padding: _panelPadding,
                        onLineTap: _scrollToLine,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Shared horizontal pan bar
          _HorizontalPanBar(
            onDragUpdate: (dx) {
              setState(() {
                _hOffset = (_hOffset - dx).clamp(0.0, 10000.0);
                if (_horizA.hasClients) _horizA.jumpTo(_hOffset);
                if (_horizB.hasClients) _horizB.jumpTo(_hOffset);
              });
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Panel
// ─────────────────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final String label;
  final List<String> lines;
  final Set<int> highlightLines;
  final Color highlightColor;
  final ScrollController vertController;
  final ScrollController horizController;
  final double hOffset;
  final double lineHeight;
  final double padding;
  final void Function(int lineIndex) onLineTap;

  const _Panel({
    required this.label,
    required this.lines,
    required this.highlightLines,
    required this.highlightColor,
    required this.vertController,
    required this.horizController,
    required this.hOffset,
    required this.lineHeight,
    required this.padding,
    required this.onLineTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontFamily: 'monospace', height: 1.0) ??
        const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(label,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: horizController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              // Provide a wide enough canvas so all lines are visible.
              width: 2000,
              child: ListView.builder(
                controller: vertController,
                itemCount: lines.length,
                itemExtent: lineHeight,
                itemBuilder: (context, index) {
                  final isHighlighted = highlightLines.contains(index);
                  return GestureDetector(
                    onTap: () => onLineTap(index),
                    child: Container(
                      height: lineHeight,
                      color: isHighlighted ? highlightColor : null,
                      padding:
                          EdgeInsets.symmetric(horizontal: padding),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lines[index],
                        style: textStyle,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HorizontalPanBar
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalPanBar extends StatelessWidget {
  final void Function(double dx) onDragUpdate;

  const _HorizontalPanBar({required this.onDragUpdate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
      child: Container(
        height: 24,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
