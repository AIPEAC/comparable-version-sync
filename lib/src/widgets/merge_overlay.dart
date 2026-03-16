// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/diff_context.dart';

enum _MergeChoice { local, incoming, manual }

/// Git-conflict-style merge resolution overlay for a single [DiffContext].
///
/// Presents three options:
///   1. Accept Local (file1 value).
///   2. Accept Incoming (file2 value).
///   3. Manual merge (editable text/SQL field).
///
/// An optional [mergeWidget] overrides the default plain-text display of the diff.
///
/// A floating action button at the bottom of the overlay confirms the choice
/// and calls [onResolved] with the chosen/edited value.
class MergeOverlay extends StatefulWidget {
  final DiffContext diff;
  final Widget Function(DiffContext)? mergeWidget;
  final void Function(dynamic resolvedValue) onResolved;

  const MergeOverlay({
    super.key,
    required this.diff,
    this.mergeWidget,
    required this.onResolved,
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

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
              showMergeWidget: widget.mergeWidget == null,
              mergeWidget: null,
              diff: widget.diff,
              choice: _MergeChoice.local,
              currentChoice: _choice,
              accentColor: Colors.green,
              onSelect: () => setState(() => _choice = _MergeChoice.local),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              label: 'Accept Incoming (File 2)',
              value: widget.diff.valueB,
              showMergeWidget: false,
              mergeWidget: null,
              diff: widget.diff,
              choice: _MergeChoice.incoming,
              currentChoice: _choice,
              accentColor: Colors.blue,
              onSelect: () => setState(() => _choice = _MergeChoice.incoming),
            ),
            const SizedBox(height: 12),
            _ManualCard(
              controller: _controller,
              choice: _MergeChoice.manual,
              currentChoice: _choice,
              onSelect: () => setState(() => _choice = _MergeChoice.manual),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirm,
        icon: const Icon(Icons.check),
        label: const Text('Confirm'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ChoiceCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool showMergeWidget;
  final Widget Function(DiffContext)? mergeWidget;
  final DiffContext diff;
  final _MergeChoice choice;
  final _MergeChoice currentChoice;
  final Color accentColor;
  final VoidCallback onSelect;

  const _ChoiceCard({
    required this.label,
    required this.value,
    required this.showMergeWidget,
    required this.mergeWidget,
    required this.diff,
    required this.choice,
    required this.currentChoice,
    required this.accentColor,
    required this.onSelect,
  });

  bool get _selected => currentChoice == choice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selected ? accentColor : theme.dividerColor,
            width: _selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: _selected ? accentColor : Colors.grey,
                ),
                const SizedBox(width: 8),
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
            const SizedBox(height: 8),
            _ValueDisplay(value: value),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ManualCard extends StatelessWidget {
  final TextEditingController controller;
  final _MergeChoice choice;
  final _MergeChoice currentChoice;
  final VoidCallback onSelect;

  const _ManualCard({
    required this.controller,
    required this.choice,
    required this.currentChoice,
    required this.onSelect,
  });

  bool get _selected => currentChoice == choice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selected ? Colors.orange : theme.dividerColor,
          width: _selected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: _selected ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Manual Edit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onTap: onSelect,
            maxLines: null,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Enter merged value…',
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ValueDisplay extends StatelessWidget {
  final dynamic value;

  const _ValueDisplay({required this.value});

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
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }
}
