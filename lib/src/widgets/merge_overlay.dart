// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 002 — implement this file.

import 'package:flutter/material.dart';

import '../models/diff_context.dart';

/// Git-conflict-style merge resolution overlay for a single [DiffContext].
///
/// Presents three options:
///   1. Accept Local (file1 value).
///   2. Accept Incoming (file2 value).
///   3. Manual merge (editable text/SQL field).
///
/// An optional [mergeWidget] overrides the default plain-text display.
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
  // TODO(AGENT:002): implement
  // - Show diff.valueA (local) and diff.valueB (incoming) via mergeWidget or plain text.
  // - 3 action buttons: Accept Local, Accept Incoming, Manual.
  // - Manual mode: editable TextField (or SQL row editor).
  // - FAB (FloatingActionButton, bottom of overlay) calls onResolved with the chosen value.

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('MergeOverlay — not yet implemented'));
  }
}
