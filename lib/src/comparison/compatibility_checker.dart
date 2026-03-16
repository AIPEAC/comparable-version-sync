// Copyright 2026 comparable_version_sync authors. All rights reserved.

import '../models/diff_context.dart';

/// Filters a list of [DiffContext] items to only true incompatibilities.
///
/// A diff is **compatible** (filtered out) when one side is null or absent
/// and the other has a value — the combination is straightforward (additive).
/// A diff is **incompatible** (kept) when both sides have non-null, differing values.
class CompatibilityChecker {
  /// Returns only the incompatible diffs from [diffs].
  List<DiffContext> filterIncompatible(List<DiffContext> diffs) {
    return diffs.where((d) => !d.isCompatible).toList();
  }

  /// Determines whether a single diff is compatible.
  ///
  /// Compatible: one side is null/absent, the other has a value.
  /// Incompatible: both sides have non-null, differing values.
  bool isCompatible(dynamic valueA, dynamic valueB) {
    return valueA == null || valueB == null;
  }
}
