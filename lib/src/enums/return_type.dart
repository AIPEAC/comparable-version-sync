// Copyright 2026 comparable_version_sync authors. All rights reserved.

/// What the merge result should contain.
enum ReturnType {
  /// Return a combined JSON structure only.
  json,

  /// Return combined SQL rows only.
  sql,

  /// Return both combined JSON and SQL data structures.
  both,
}
