// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 001 — implement concrete subclasses.

import '../enums/comparison_mode.dart';
import '../models/diff_context.dart';

/// Abstract interface for all file comparators.
abstract class BaseComparator {
  /// Compare [file1Path] against [file2Path] and return a list of differences.
  ///
  /// When [mode] is [ComparisonMode.incompatibleOnly], only true conflicts
  /// (both sides non-null and differing) are included in the result.
  Future<List<DiffContext>> compare(
    String file1Path,
    String file2Path,
    ComparisonMode mode,
  );
}
