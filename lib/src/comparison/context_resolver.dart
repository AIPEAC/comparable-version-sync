// Copyright 2026 comparable_version_sync authors. All rights reserved.

/// Resolves the smallest shared parent context for a set of diff paths.
///
/// e.g. if paths `["my.a", "my.b"]` both differ, the parent context is `"my"`.
/// If only `["my.b"]` differs, the context is `"my"` (the parent of that leaf).
class ContextResolver {
  /// Given a dot-notation [path] (e.g. `"my.b"`), return the parent path.
  ///
  /// If there is no parent (top-level key), returns the key itself.
  String resolveParent(String path) {
    final parts = path.split('.');
    if (parts.length <= 1) return path;
    return parts.sublist(0, parts.length - 1).join('.');
  }

  /// Navigates [root] by dot-notation [path] and returns the value found there.
  ///
  /// - If [path] is empty, returns [root] itself (the full root object).
  /// - Map keys are looked up by their string segment.
  /// - List elements are accessed by numeric index (parsed from the segment).
  /// - Returns `null` if any segment is not found or the type is unexpected.
  dynamic valueAtPath(dynamic root, String path) {
    if (path.isEmpty) return root;
    dynamic current = root;
    for (final segment in path.split('.')) {
      if (current is Map) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        if (index != null && index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
  }

  /// Given a list of [paths] that all differ, return the smallest shared
  /// parent context string (longest common dot-notation prefix, excluding
  /// the leaf segment).
  ///
  /// For a single path, equivalent to [resolveParent].
  String smallestSharedParent(List<String> paths) {
    if (paths.isEmpty) return '';
    if (paths.length == 1) return resolveParent(paths.first);

    final segmented = paths.map((p) => p.split('.')).toList();
    final first = segmented.first;

    // Walk segment by segment (stopping before the leaf) to find common prefix.
    var commonLength = 0;
    outer:
    for (var i = 0; i < first.length - 1; i++) {
      final seg = first[i];
      for (final segs in segmented) {
        if (i >= segs.length || segs[i] != seg) break outer;
      }
      commonLength = i + 1;
    }

    if (commonLength == 0) return resolveParent(paths.first);
    return first.sublist(0, commonLength).join('.');
  }
}
