// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 001 — implement this file.

/// Resolves the smallest shared parent context for a set of diff paths.
///
/// e.g. if paths `["my.a", "my.b"]` both differ, the parent context is `"my"`.
/// If only `["my.b"]` differs, the context is `"b"`.
class ContextResolver {
  /// Given a dot-notation [path] (e.g. `"my.b"`), return the parent key.
  ///
  /// If there is no parent (top-level key), returns the key itself.
  String resolveParent(String path) {
    // TODO(AGENT:001): implement
    // Split by '.', return all but last segment joined; or last if single segment.
    throw UnimplementedError('ContextResolver.resolveParent not yet implemented');
  }

  /// Given a list of [paths] that all differ under the same parent,
  /// return the smallest shared parent context string.
  String smallestSharedParent(List<String> paths) {
    // TODO(AGENT:001): implement
    throw UnimplementedError('ContextResolver.smallestSharedParent not yet implemented');
  }
}
