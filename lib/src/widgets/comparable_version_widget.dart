// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../comparison/base_comparator.dart';
import '../comparison/json_comparator.dart';
import '../comparison/sqlite_comparator.dart';
import '../enums/comparison_mode.dart';
import '../enums/file_type.dart';
import '../enums/return_type.dart';
import '../models/diff_context.dart';
import '../models/merge_result.dart';
import 'diff_view_panel.dart';
import 'raw_view_panel.dart';

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// The main entry-point widget for comparing two files.
///
/// Use the named constructors to get compile-time safety for the required
/// parameters of each display mode.
///
/// The widget is fully responsive and fills any parent box.
class ComparableVersionWidget extends StatefulWidget {
  // --- shared fields ---
  final FileType fileType;
  final String file1Path;
  final String file2Path;
  final ComparisonMode comparisonMode;
  final ReturnType returnType;
  final void Function(MergeResult) onMergeComplete;

  // --- display mode 0 (raw view) ---
  final int? recordsPerPage;

  // --- display mode 1 (diff view) ---
  final int? diffsPerPage;

  /// Required for display mode 1 at construction time (named constructor).
  final Widget Function(DiffContext)? displayWidget;

  /// Optional custom widget for merge resolution. Defaults to plain text.
  final Widget Function(DiffContext)? mergeWidget;

  /// True when constructed via [diffView]; false when via [rawView].
  /// Used by the state to choose which panel to render.
  final bool isDiffView;

  /// Display mode 0 — raw paginated view of both files side-by-side.
  const ComparableVersionWidget.rawView({
    super.key,
    required this.fileType,
    required this.file1Path,
    required this.file2Path,
    required this.comparisonMode,
    this.recordsPerPage = 10,
    required this.returnType,
    required this.onMergeComplete,
  })  : isDiffView = false,
        diffsPerPage = null,
        displayWidget = null,
        mergeWidget = null;

  /// Display mode 1 — paginated diff view with a required custom display widget.
  const ComparableVersionWidget.diffView({
    super.key,
    required this.fileType,
    required this.file1Path,
    required this.file2Path,
    required this.comparisonMode,
    this.diffsPerPage = 10,
    required Widget Function(DiffContext) this.displayWidget,
    this.mergeWidget,
    required this.returnType,
    required this.onMergeComplete,
  })  : isDiffView = true,
        recordsPerPage = null;

  @override
  State<ComparableVersionWidget> createState() =>
      _ComparableVersionWidgetState();
}

// ---------------------------------------------------------------------------
// Internal load-state
// ---------------------------------------------------------------------------

enum _LoadState { loading, error, success }

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _ComparableVersionWidgetState extends State<ComparableVersionWidget> {
  _LoadState _status = _LoadState.loading;
  String? _error;
  List<DiffContext> _diffs = [];

  // JSON raw data — kept for raw-view display and merge-result reconstruction.
  // dart:io File is guarded by kIsWeb; on web this stays null.
  dynamic _jsonRawData1;
  dynamic _jsonRawData2;

  // SQLite databases — kept open for lazy raw-view loading; closed on dispose.
  Database? _db1;
  Database? _db2;
  List<String> _sqliteTables = [];

  /// Currently selected table for SQLite raw view.
  String? _selectedTable;

  // Total pages for RawViewPanel.
  int _rawTotalPages = 1;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _db1?.close();
    _db2?.close();
    super.dispose();
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    try {
      await _runComparison();
      await _loadRawData();
      if (mounted) {
        setState(() => _status = _LoadState.success);
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = '$e\n\n$st';
          _status = _LoadState.error;
        });
      }
    }
  }

  Future<void> _runComparison() async {
    final BaseComparator comparator = widget.fileType == FileType.json
        ? JsonComparator()
        : SqliteComparator();
    _diffs = await comparator.compare(
      widget.file1Path,
      widget.file2Path,
      widget.comparisonMode,
    );
  }

  Future<void> _loadRawData() async {
    if (widget.fileType == FileType.json) {
      await _loadJsonData();
    } else {
      await _loadSqliteData();
    }
  }

  // ── JSON raw data loading ──────────────────────────────────────────────────

  Future<void> _loadJsonData() async {
    if (kIsWeb) {
      // dart:io File is unavailable on web; show empty raw view.
      _jsonRawData1 = <String, dynamic>{};
      _jsonRawData2 = <String, dynamic>{};
      _rawTotalPages = 1;
      return;
    }
    _jsonRawData1 = jsonDecode(await File(widget.file1Path).readAsString());
    _jsonRawData2 = jsonDecode(await File(widget.file2Path).readAsString());

    final perPage = widget.recordsPerPage ?? 10;
    _rawTotalPages =
        max(1, (_toRecordList(_jsonRawData1).length / perPage).ceil());
  }

  // ── SQLite raw data loading ────────────────────────────────────────────────

  Future<void> _loadSqliteData() async {
    // Mirror SqliteComparator.initPlatform() — safe to call multiple times
    // because the comparator tracks an _initialized flag.
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _db1 = await openDatabase(widget.file1Path, readOnly: true);
    _db2 = await openDatabase(widget.file2Path, readOnly: true);

    final tableRows = await _db1!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'"
      " AND name NOT LIKE 'sqlite_%'",
    );
    _sqliteTables = tableRows.map((r) => r['name'] as String).toList();

    if (_sqliteTables.isNotEmpty) {
      _selectedTable = _sqliteTables.first;
      await _recomputeSqlitePages(_selectedTable!);
    }
  }

  /// Recomputes [_rawTotalPages] for the given [table] and triggers a rebuild.
  Future<void> _recomputeSqlitePages(String table) async {
    final countRows = await _db1!.rawQuery(
      'SELECT COUNT(*) FROM "$table"',
    );
    final count = countRows.isNotEmpty
        ? (countRows.first.values.first as int?) ?? 0
        : 0;
    final perPage = widget.recordsPerPage ?? 10;
    _rawTotalPages = max(1, (count / perPage).ceil());
  }

  /// Called when the user picks a different table from the dropdown.
  Future<void> _onTableSelected(String table) async {
    await _recomputeSqlitePages(table);
    if (mounted) {
      setState(() => _selectedTable = table);
    }
  }

  // ── Page loaders (passed to RawViewPanel) ─────────────────────────────────

  Future<List<Map<String, dynamic>>> _pageLoaderFile1(int page) async {
    if (widget.fileType == FileType.json) {
      return _jsonPage(_jsonRawData1, page);
    }
    return _sqlitePage(_db1!, page);
  }

  Future<List<Map<String, dynamic>>> _pageLoaderFile2(int page) async {
    if (widget.fileType == FileType.json) {
      return _jsonPage(_jsonRawData2, page);
    }
    return _sqlitePage(_db2!, page);
  }

  List<Map<String, dynamic>> _jsonPage(dynamic rawData, int page) {
    final records = _toRecordList(rawData);
    final perPage = widget.recordsPerPage ?? 10;
    final start = page * perPage;
    final end = (start + perPage).clamp(0, records.length);
    if (start >= records.length) return [];
    return records.sublist(start, end);
  }

  Future<List<Map<String, dynamic>>> _sqlitePage(Database db, int page) async {
    final table = _selectedTable;
    if (table == null) return [];
    final perPage = widget.recordsPerPage ?? 10;
    final rows = await db.rawQuery(
      'SELECT * FROM "$table" LIMIT $perPage OFFSET ${page * perPage}',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ── Merge result construction ──────────────────────────────────────────────

  MergeResult _buildMergeResult(Map<String, dynamic> choices) {
    return widget.fileType == FileType.json
        ? _buildJsonMergeResult(choices)
        : _buildSqliteMergeResult(choices);
  }

  MergeResult _buildJsonMergeResult(Map<String, dynamic> choices) {
    final base = _deepClone(_jsonRawData1 is Map<String, dynamic>
        ? _jsonRawData1 as Map<String, dynamic>
        : <String, dynamic>{'data': _jsonRawData1});

    for (final entry in choices.entries) {
      _setAtPath(base, entry.key, entry.value);
    }

    return MergeResult(
      mergedJson: widget.returnType != ReturnType.sql ? base : null,
      mergedRows: widget.returnType != ReturnType.json
          ? _toRecordList(base)
          : null,
    );
  }

  MergeResult _buildSqliteMergeResult(Map<String, dynamic> choices) {
    // Full row reconstruction requires re-querying with open DB connections;
    // return choices as a flat structure for the initial implementation.
    return MergeResult(
      mergedJson: widget.returnType != ReturnType.sql ? choices : null,
      mergedRows: widget.returnType != ReturnType.json
          ? choices.entries
              .map(
                (e) => <String, dynamic>{'path': e.key, 'value': e.value},
              )
              .toList()
          : null,
    );
  }

  MergeResult _buildRawViewMergeResult() {
    // Raw view default: file1 wins all diffs (no per-field resolution UI).
    final choices = <String, dynamic>{
      for (final d in _diffs) d.path: d.valueA,
    };
    return _buildMergeResult(choices);
  }

  // ── Static utilities ───────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _toRecordList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      return [Map<String, dynamic>.from(data.cast<String, dynamic>())];
    }
    return [
      <String, dynamic>{'value': data},
    ];
  }

  static void _setAtPath(
      Map<String, dynamic> map, String path, dynamic value) {
    final parts = path.split('.');
    var current = map;
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (current[part] is! Map<String, dynamic>) {
        current[part] = <String, dynamic>{};
      }
      current = current[part] as Map<String, dynamic>;
    }
    current[parts.last] = value;
  }

  static Map<String, dynamic> _deepClone(Map<String, dynamic> src) =>
      jsonDecode(jsonEncode(src)) as Map<String, dynamic>;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _LoadState.loading => _loadingView(),
      _LoadState.error => _errorView(),
      _LoadState.success => _contentView(),
    };
  }

  Widget _loadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Comparing files…'),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Comparison failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  _error ?? 'Unknown error',
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _status = _LoadState.loading;
                  _error = null;
                });
                _initialize();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentView() {
    if (widget.isDiffView) {
      return DiffViewPanel(
        diffs: _diffs,
        diffsPerPage: widget.diffsPerPage ?? 10,
        displayWidget: widget.displayWidget!,
        mergeWidget: widget.mergeWidget,
        onMergeComplete: widget.onMergeComplete,
        mergeResultBuilder: _buildMergeResult,
      );
    }

    // Raw view: optional table selector (SQLite only) + RawViewPanel + FAB.
    return Stack(
      children: [
        Column(
          children: [
            if (widget.fileType == FileType.sqlite &&
                _sqliteTables.length > 1)
              _tableSelector(),
            Expanded(
              child: RawViewPanel(
                // Key forces a full rebuild (cache reset) when the table changes.
                key: ValueKey(_selectedTable),
                loadPageFile1: _pageLoaderFile1,
                loadPageFile2: _pageLoaderFile2,
                recordsPerPage: widget.recordsPerPage ?? 10,
                totalPages: _rawTotalPages,
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () =>
                widget.onMergeComplete(_buildRawViewMergeResult()),
            icon: const Icon(Icons.check),
            label: const Text('Accept File 1'),
          ),
        ),
      ],
    );
  }

  Widget _tableSelector() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Text('Table:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedTable,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: _sqliteTables
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t)),
                    )
                    .toList(),
                onChanged: (t) {
                  if (t != null && t != _selectedTable) _onTableSelected(t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
