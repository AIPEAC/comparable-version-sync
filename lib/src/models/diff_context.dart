// Copyright 2026 comparable_version_sync authors. All rights reserved.

/// Represents a single difference found between two files.
class DiffContext {
  /// Dot-notation path to the differing field (e.g. `"my.b"`).
  final String path;

  /// The smallest shared parent key/path for display context
  /// (e.g. if `path` is `"my.b"` and `"my.c"` both differ, context is `"my"`).
  final String parentContext;

  /// Value from file 1 (null if the key is absent in file 1).
  final dynamic valueA;

  /// Value from file 2 (null if the key is absent in file 2).
  final dynamic valueB;

  /// True when only one side has a non-null value — the diff is additive
  /// and the files are still compatible at this path.
  final bool isCompatible;

  const DiffContext({
    required this.path,
    required this.parentContext,
    required this.valueA,
    required this.valueB,
    required this.isCompatible,
  });

  @override
  String toString() =>
      'DiffContext(path: $path, valueA: $valueA, valueB: $valueB, '
      'compatible: $isCompatible)';
}
