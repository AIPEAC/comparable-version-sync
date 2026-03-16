// Copyright 2026 comparable_version_sync authors. All rights reserved.

/// The output produced after the user resolves all merge conflicts.
class MergeResult {
  /// Combined JSON structure (populated when returnType is json or both).
  final Map<String, dynamic>? mergedJson;

  /// Combined SQL rows (populated when returnType is sql or both).
  final List<Map<String, dynamic>>? mergedRows;

  const MergeResult({
    this.mergedJson,
    this.mergedRows,
  });
}
