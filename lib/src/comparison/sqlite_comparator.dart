// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 001 — implement this file.

import '../enums/comparison_mode.dart';
import '../models/diff_context.dart';
import 'base_comparator.dart';

/// Compares two SQLite database files using the sqflite package.
///
/// Records are loaded lazily page by page (LIMIT/OFFSET) — no full-table load.
/// Matching strategy: by primary key if detectable; cartesian product otherwise.
class SqliteComparator implements BaseComparator {
  /// Number of records to load per page during comparison.
  final int pageSize;

  const SqliteComparator({this.pageSize = 100});

  @override
  Future<List<DiffContext>> compare(
    String file1Path,
    String file2Path,
    ComparisonMode mode,
  ) {
    // TODO(AGENT:001): implement
    // 1. Initialise sqflite_common_ffi on desktop / sqflite_common_ffi_web on web.
    // 2. Open both databases read-only.
    // 3. Enumerate all tables (sqlite_master).
    // 4. For each table, page through records (LIMIT pageSize OFFSET n).
    // 5. Match rows by primary key when available; otherwise cartesian product.
    // 6. Produce List<DiffContext> for differing fields.
    // 7. Filter with CompatibilityChecker when mode == incompatibleOnly.
    throw UnimplementedError('SqliteComparator.compare not yet implemented');
  }
}
