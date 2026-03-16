// Copyright 2026 comparable_version_sync authors. All rights reserved.

/// Controls which differences are surfaced.
enum ComparisonMode {
  /// Show every difference between the two files (mode 0).
  allDiffs,

  /// Show only true conflicts — where both sides have a non-null,
  /// differing value (mode 1). A missing or null value on one side
  /// is considered compatible and is not shown.
  incompatibleOnly,
}
