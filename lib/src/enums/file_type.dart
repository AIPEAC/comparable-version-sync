// Copyright 2026 comparable_version_sync authors. All rights reserved.

/// The type of files being compared.
enum FileType {
  /// JSON files (mode 0).
  json,

  /// SQLite database files (mode 1).
  sqlite,
}
