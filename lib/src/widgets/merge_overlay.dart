// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/diff_context.dart';
import '../theme/comparable_version_theme.dart';
import 'diff_detail_screen.dart';

enum _MergeChoice { local, incoming, manual }

/// Git-conflict-style merge resolution overlay for a single [DiffContext].
///
/// Presents three options:
///
/// 1. **Accept Local** — keep the value from file 1.
/// 2. **Accept Incoming** — keep the value from file 2.
/// 3. **Manual Edit** — free-text edit of the value.
///
/// An optional [mergeWidget] replaces the default plain-text value display.
/// A floating action button ("Confirm") applies the choice and pops the route.
///
/// All visual dimensions are controlled via [theme].
class MergeOverlay extends StatefulWidget {
  /// The diff to resolve.
  final DiffContext diff;

  /// Optional custom widget rendered above the three choice cards.
  /// When provided the default value display is suppressed.
  final Widget Function(DiffContext)? mergeWidget;

  /// Called with the resolved value when the user taps "Confirm".
  final void Function(dynamic resolvedValue) onResolved;

  /// Whether to show a "View Raw Diff" button that navigates to
  /// [DiffDetailScreen]. Default: `false`.
  final bool showDiffDetailButton;

  /// Where to place the "View Raw Diff" button.
  ///
  /// [Alignment.topRight] (the default) adds it to the [AppBar] actions.
  /// Any other value wraps the body in a [Stack] and [Align]s it there.
  final Alignment diffDetailButtonAlignment;

  /// Optional converter for non-serialisable values passed through to
  /// [DiffDetailScreen].
  final String Function(dynamic)? toJsonConverter;

  /// Visual configuration. Defaults to [ComparableVersionTheme.new].
  final ComparableVersionTheme theme;

  /// Creates a [MergeOverlay] for the given [diff].
  const MergeOverlay({
    super.key,
    required this.diff,
    this.mergeWidget,
    required this.onResolved,
    this.showDiffDetailButton = false,
    this.diffDetailButtonAlignment = Alignment.topRight,
    this.toJsonConverter,
    this.theme = const ComparableVersionTheme(),
  });

  @override
  State<MergeOverlay> createState() => _MergeOverlayState();
}

class _MergeOverlayState extends State<MergeOverlay> {
  _MergeChoice _choice = _MergeChoice.local;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _toEditableString(widget.diff.valueA),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _toEditableString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return const JsonEncoder.withIndent('  ').convert(v);
  }

  dynamic get _resolvedValue {
    switch (_choice) {
      case _MergeChoice.local:
        return widget.diff.valueA;
      case _MergeChoice.incoming:
        return widget.diff.valueB;
      case _MergeChoice.manual:
        return _controller.text;
    }
  }

  void _confirm() {
    widget.onResolved(_resolvedValue);
    Navigator.of(context).pop();
  }

  void _openDiffDetail() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DiffDetailScreen(
          diff: widget.diff,
          toJsonConverter: widget.toJsonConverter,
          theme: widget.theme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final showInAppBar = widget.showDiffDetailButton &&
        widget.diffDetailButtonAlignment == Alignment.topRight;
    final showInBody = widget.showDiffDetailButton && !showInAppBar;

    final scrollBody = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, t.overlayBodyBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.mergeWidget != null) ...[
            widget.mergeWidget!(widget.diff),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],
          _ChoiceCard(
            label: 'Accept Local (File 1)',
            value: widget.diff.valueA,
            diff: widget.diff,
            choice: _MergeChoice.local,
            currentChoice: _choice,
            accentColor: Colors.green,
            onSelect: () => setState(() => _choice = _MergeChoice.local),
            theme: t,
          ),
          SizedBox(height: t.cardPadding),
          _ChoiceCard(
            label: 'Accept Incoming (File 2)',
            value: widget.diff.valueB,
            diff: widget.diff,
            choice: _MergeChoice.incoming,
            currentChoice: _choice,
            accentColor: Colors.blue,
            onSelect: () => setState(() => _choice = _MergeChoice.incoming),
            theme: t,
          ),
          SizedBox(height: t.cardPadding),
          _ManualCard(
            controller: _controller,
            choice: _MergeChoice.manual,
            currentChoice: _choice,
            onSelect: () => setState(() => _choice = _MergeChoice.manual),
            theme: t,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Resolve Conflict', style: TextStyle(fontSize: 16)),
            Text(
              widget.diff.path,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (showInAppBar)
            TextButton.icon(
              onPressed: _openDiffDetail,
              icon: const Icon(Icons.difference),
              label: const Text('View Raw Diff'),
            ),
        ],
      ),
      body: showInBody
          ? Stack(
              children: [
                scrollBody,
                Align(
                  alignment: widget.diffDetailButtonAlignment,
                  child: Padding(
                    padding: EdgeInsets.all(t.cardPadding),
                    child: FilledButton.icon(
                      onPressed: _openDiffDetail,
                      icon: const Icon(Icons.difference),
                      label: const Text('View Raw Diff'),
                    ),
                  ),
                ),
              ],
            )
          : scrollBody,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirm,
        icon: const Icon(Icons.check),
        label: const Text('Confirm'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChoiceCard
// ---------------------------------------------------------------------------

class _ChoiceCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final DiffContext diff;
  final _MergeChoice choice;
  final _MergeChoice currentChoice;
  final Color accentColor;
  final VoidCallback onSelect;
  final ComparableVersionTheme theme;

  const _ChoiceCard({
    required this.label,
    required this.value,
    required this.diff,
    required this.choice,
    required this.currentChoice,
    required this.accentColor,
    required this.onSelect,
    required this.theme,
  });

  bool get _selected => currentChoice == choice;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final t = theme;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: t.cardAnimationDuration,
        decoration: BoxDecoration(
          color: _selected
              ? appTheme.colorScheme.primaryContainer
              : appTheme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(t.cardBorderRadius),
          border: Border.all(
            color: _selected ? accentColor : appTheme.dividerColor,
            width: _selected ? t.selectedBorderWidth : t.unselectedBorderWidth,
          ),
        ),
        padding: EdgeInsets.all(t.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: t.iconSize,
                  color: _selected ? accentColor : Colors.grey,
                ),
                SizedBox(width: t.cardPadding / 1.5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.cardPadding / 1.5),
            _ValueDisplay(value: value, monoFontSize: t.monoFontSize),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ManualCard
// ---------------------------------------------------------------------------

class _ManualCard extends StatelessWidget {
  final TextEditingController controller;
  final _MergeChoice choice;
  final _MergeChoice currentChoice;
  final VoidCallback onSelect;
  final ComparableVersionTheme theme;

  const _ManualCard({
    required this.controller,
    required this.choice,
    required this.currentChoice,
    required this.onSelect,
    required this.theme,
  });

  bool get _selected => currentChoice == choice;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final t = theme;
    return AnimatedContainer(
      duration: t.cardAnimationDuration,
      decoration: BoxDecoration(
        color: _selected
            ? appTheme.colorScheme.primaryContainer
            : appTheme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(t.cardBorderRadius),
        border: Border.all(
          color: _selected ? Colors.orange : appTheme.dividerColor,
          width: _selected ? t.selectedBorderWidth : t.unselectedBorderWidth,
        ),
      ),
      padding: EdgeInsets.all(t.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: t.iconSize,
                color: _selected ? Colors.orange : Colors.grey,
              ),
              SizedBox(width: t.cardPadding / 1.5),
              Text(
                'Manual Edit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: t.cardPadding / 1.5),
          TextField(
            controller: controller,
            onTap: onSelect,
            maxLines: null,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: t.monoFontSize,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.textFieldBorderRadius),
              ),
              hintText: 'Enter merged value…',
              filled: true,
              fillColor: appTheme.colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ValueDisplay
// ---------------------------------------------------------------------------

class _ValueDisplay extends StatelessWidget {
  final dynamic value;
  final double monoFontSize;

  const _ValueDisplay({required this.value, required this.monoFontSize});

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Text(
        '(absent)',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }
    final text = value is String
        ? value as String
        : const JsonEncoder.withIndent('  ').convert(value);
    return SelectableText(
      text,
      style: TextStyle(fontFamily: 'monospace', fontSize: monoFontSize),
    );
  }
}
