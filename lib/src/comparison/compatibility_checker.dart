// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 001 — implement this file.

import '../models/diff_context.dart';

/// Filters a list of [DiffContext] items to only true incompatibilities.
///
/// A diff is **compatible** (filtered out) when one side is null or absent
/// and the other has a value — the combination is straightforward (additive).
/// A diff is **incompatible** (kept) when both sides have non-null, differing values.
class CompatibilityChecker {
  /// Returns only the incompatible diffs from [diffs].
  List<DiffContext> filterIncompatible(List<DiffContext> diffs) {
    // TODO(AGENT:001): implement
    // Keep only items where isCompatible == false.
    throw UnimplementedError('CompatibilityChecker.filterIncompatible not yet implemented');
  }

  /// Determines whether a single diff is compatible.
  ///
  /// Compatible: one side is null/absent, the other has a value.
  /// Incompatible: both sides have non-null, differing values.
  bool isCompatible(dynamic valueA, dynamic valueB) {
    // TODO(AGENT:001): implement
    throw UnimplementedError('CompatibilityChecker.isCompatible not yet implemented');
  }
}
