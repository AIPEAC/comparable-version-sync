// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../enums/comparison_mode.dart';
import '../models/diff_context.dart';
import 'base_comparator.dart';
import 'compatibility_checker.dart';
import 'context_resolver.dart';

/// Compares two SQLite database files using the sqflite package.
///
/// Records are loaded lazily page by page (LIMIT/OFFSET) — no full-table load.
/// Matching strategy: primary key when detectable; positional (row index) otherwise.
class SqliteComparator implements BaseComparator {
  /// Number of records to load per page during comparison.
  final int pageSize;

  const SqliteComparator({this.pageSize = 100});

  // ── Platform initialisation ─────────────────────────────────────────────────

  static bool _initialized = false;

  /// Initialises the correct sqflite factory for the current platform.
  ///
  /// - Web  → `databaseFactoryFfiWeb` (sqflite_common_ffi_web)
  /// - Windows / Linux → `databaseFactoryFfi` + `sqfliteFfiInit()` (sqflite_common_ffi)
  /// - Android / iOS / macOS → built-in sqflite, no action needed.
  static Future<void> initPlatform() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  // ── BaseComparator ───────────────────────────────────────────────────────────

  @override
  Future<List<DiffContext>> compare(
    String file1Path,
    String file2Path,
    ComparisonMode mode,
  ) async {
    await initPlatform();

    final db1 = await openDatabase(file1Path, readOnly: true);
    final db2 = await openDatabase(file2Path, readOnly: true);

    final results = <DiffContext>[];
    final checker = CompatibilityChecker();
    final resolver = ContextResolver();

    try {
      final tables1 = await _getTables(db1);
      final tables2 = await _getTables(db2);
      final allTables = {...tables1, ...tables2};

      for (final table in allTables) {
        final inDb1 = tables1.contains(table);
        final inDb2 = tables2.contains(table);

        if (!inDb1) {
          results.add(DiffContext(
            path: table,
            parentContext: table,
            valueA: null,
            valueB: '<table present>',
            isCompatible: true,
          ));
          continue;
        }
        if (!inDb2) {
          results.add(DiffContext(
            path: table,
            parentContext: table,
            valueA: '<table present>',
            valueB: null,
            isCompatible: true,
          ));
          continue;
        }

        final pkColumns = await _getPrimaryKeyColumns(db1, table);
        await _compareTable(db1, db2, table, pkColumns, results, checker, resolver);
      }
    } finally {
      await db1.close();
      await db2.close();
    }

    if (mode == ComparisonMode.incompatibleOnly) {
      return checker.filterIncompatible(results);
    }
    return results;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<Set<String>> _getTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    return rows.map((r) => r['name'] as String).toSet();
  }

  Future<List<String>> _getPrimaryKeyColumns(Database db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info("$table")');
    return info
        .where((col) => (col['pk'] as int?) != null && (col['pk'] as int) > 0)
        .map((col) => col['name'] as String)
        .toList();
  }

  Future<void> _compareTable(
    Database db1,
    Database db2,
    String table,
    List<String> pkColumns,
    List<DiffContext> results,
    CompatibilityChecker checker,
    ContextResolver resolver,
  ) async {
    if (pkColumns.isNotEmpty) {
      await _compareByPrimaryKey(db1, db2, table, pkColumns, results, checker, resolver);
    } else {
      await _compareByPosition(db1, db2, table, results, checker, resolver);
    }
  }

  /// Matches rows across both databases by their primary key value(s).
  ///
  /// Pages through db1 and looks up each PK in db2. Then does a second pass
  /// through db2 to find rows whose PKs are absent in db1 (added rows).
  Future<void> _compareByPrimaryKey(
    Database db1,
    Database db2,
    String table,
    List<String> pkColumns,
    List<DiffContext> results,
    CompatibilityChecker checker,
    ContextResolver resolver,
  ) async {
    final pkCondition = pkColumns.map((col) => '"$col" = ?').join(' AND ');

    // Pass 1 — walk db1 and compare against db2.
    var offset = 0;
    while (true) {
      final rows1 = await db1.rawQuery(
        'SELECT * FROM "$table" LIMIT $pageSize OFFSET $offset',
      );
      if (rows1.isEmpty) break;

      for (final row1 in rows1) {
        final pkValues = pkColumns.map((col) => row1[col]).toList();
        final pkLabel = pkColumns.map((col) => '$col=${row1[col]}').join(',');

        final rows2 = await db2.rawQuery(
          'SELECT * FROM "$table" WHERE $pkCondition',
          pkValues,
        );

        if (rows2.isEmpty) {
          // Row only in db1 → removed.
          results.add(DiffContext(
            path: '$table.$pkLabel',
            parentContext: table,
            valueA: Map<String, Object?>.from(row1),
            valueB: null,
            isCompatible: true,
          ));
        } else {
          _compareRows(table, pkLabel, row1, rows2.first, results, checker, resolver);
        }
      }

      offset += pageSize;
    }

    // Pass 2 — walk db2 to find rows not present in db1 (added rows).
    offset = 0;
    while (true) {
      final rows2 = await db2.rawQuery(
        'SELECT * FROM "$table" LIMIT $pageSize OFFSET $offset',
      );
      if (rows2.isEmpty) break;

      for (final row2 in rows2) {
        final pkValues = pkColumns.map((col) => row2[col]).toList();
        final rows1 = await db1.rawQuery(
          'SELECT * FROM "$table" WHERE $pkCondition',
          pkValues,
        );
        if (rows1.isEmpty) {
          final pkLabel = pkColumns.map((col) => '$col=${row2[col]}').join(',');
          results.add(DiffContext(
            path: '$table.$pkLabel',
            parentContext: table,
            valueA: null,
            valueB: Map<String, Object?>.from(row2),
            isCompatible: true,
          ));
        }
      }

      offset += pageSize;
    }
  }

  /// Matches rows by position (row index) when no primary key is available.
  ///
  /// Both tables are paged in parallel with LIMIT/OFFSET; rows at the same
  /// offset are considered the same logical record.
  Future<void> _compareByPosition(
    Database db1,
    Database db2,
    String table,
    List<DiffContext> results,
    CompatibilityChecker checker,
    ContextResolver resolver,
  ) async {
    var offset = 0;
    while (true) {
      final rows1 = await db1.rawQuery(
        'SELECT * FROM "$table" LIMIT $pageSize OFFSET $offset',
      );
      final rows2 = await db2.rawQuery(
        'SELECT * FROM "$table" LIMIT $pageSize OFFSET $offset',
      );

      if (rows1.isEmpty && rows2.isEmpty) break;

      final maxLen = rows1.length > rows2.length ? rows1.length : rows2.length;
      for (var i = 0; i < maxLen; i++) {
        final rowIndex = offset + i;
        final row1 = i < rows1.length ? rows1[i] : null;
        final row2 = i < rows2.length ? rows2[i] : null;

        if (row1 == null) {
          results.add(DiffContext(
            path: '$table[pos$rowIndex]',
            parentContext: table,
            valueA: null,
            valueB: Map<String, Object?>.from(row2!),
            isCompatible: true,
          ));
        } else if (row2 == null) {
          results.add(DiffContext(
            path: '$table[pos$rowIndex]',
            parentContext: table,
            valueA: Map<String, Object?>.from(row1),
            valueB: null,
            isCompatible: true,
          ));
        } else {
          _compareRows(table, 'pos$rowIndex', row1, row2, results, checker, resolver);
        }
      }

      if (rows1.length < pageSize && rows2.length < pageSize) break;
      offset += pageSize;
    }
  }

  /// Compares two matched rows field-by-field and appends any differences.
  void _compareRows(
    String table,
    String rowLabel,
    Map<String, Object?> row1,
    Map<String, Object?> row2,
    List<DiffContext> results,
    CompatibilityChecker checker,
    ContextResolver resolver,
  ) {
    final allColumns = {...row1.keys, ...row2.keys};
    for (final col in allColumns) {
      final valA = row1[col];
      final valB = row2[col];
      if (valA == valB) continue;

      final path = '$table.$rowLabel.$col';
      results.add(DiffContext(
        path: path,
        parentContext: resolver.resolveParent(path),
        valueA: valA,
        valueB: valB,
        isCompatible: checker.isCompatible(valA, valB),
      ));
    }
  }
}
