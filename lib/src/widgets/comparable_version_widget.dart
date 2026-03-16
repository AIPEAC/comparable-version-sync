// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'dart:convert';
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
import '../theme/comparable_version_theme.dart';
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
/// The widget is fully responsive and fills any parent box — it has no minimum
/// or maximum size constraints of its own.
///
/// ## Display modes
///
/// | Constructor | Description |
/// |---|---|
/// | [ComparableVersionWidget.rawView] | Side-by-side raw JSON / SQL records paginated view. |
/// | [ComparableVersionWidget.diffView] | Paginated diff list with per-field merge resolution. |
///
/// ## File types
///
/// | [FileType] | Format |
/// |---|---|
/// | [FileType.json] | Standard JSON files (`Map` or `List` root). |
/// | [FileType.sqlite] | SQLite database files compared table-by-table. |
///
/// ## Theming
///
/// Pass a [ComparableVersionTheme] to control every dimension, colour, and
/// animation parameter:
///
/// ```dart
/// ComparableVersionWidget.diffView(
///   theme: const ComparableVersionTheme(
///     responsiveBreakpoint: 720,
///     localHighlightColor: Color(0x2200BCD4),
///     incomingHighlightColor: Color(0x22FF5722),
///   ),
///   ...
/// )
/// ```
///
/// ## Minimal diff-view example
///
/// ```dart
/// ComparableVersionWidget.diffView(
///   fileType: FileType.json,
///   file1Path: '/path/to/v1.json',
///   file2Path: '/path/to/v2.json',
///   comparisonMode: ComparisonMode.allDiffs,
///   diffsPerPage: 10,
///   displayWidget: (diff) => Text('${diff.valueA} → ${diff.valueB}'),
///   returnType: ReturnType.json,
///   onMergeComplete: (result) => print(result.mergedJson),
/// )
/// ```
class ComparableVersionWidget extends StatefulWidget {
  // --- shared fields ---

  /// Whether the inputs are JSON files or SQLite databases.
  final FileType fileType;

  /// Absolute path to the first file (local / "base" version).
  final String file1Path;

  /// Absolute path to the second file (incoming / "new" version).
  final String file2Path;

  /// Controls which diffs are included in the result.
  ///
  /// - [ComparisonMode.allDiffs] — every field that differs.
  /// - [ComparisonMode.incompatibleOnly] — only true conflicts where **both**
  ///   sides have non-null values.
  final ComparisonMode comparisonMode;

  /// Format of the [MergeResult] returned via [onMergeComplete].
  final ReturnType returnType;

  /// Called with the final [MergeResult] when the user confirms the merge.
  final void Function(MergeResult) onMergeComplete;

  // --- display mode 0 (raw view) ---

  /// Number of records shown per page in raw view. Default: `10`.
  final int? recordsPerPage;

  // --- display mode 1 (diff view) ---

  /// Number of diff items shown per page in diff view. Default: `10`.
  final int? diffsPerPage;

  /// Required for diff view — renders a summary row for each [DiffContext].
  final Widget Function(DiffContext)? displayWidget;

  /// Optional custom widget shown inside [MergeOverlay] above the choice cards.
  /// When `null`, the default plain-text / JSON value display is used.
  final Widget Function(DiffContext)? mergeWidget;

  // --- diff view — accept-compatible feature ---

  /// Whether to show the "Auto-accept compatible" toggle chip above the diff
  /// list. Default: `false`.
  ///
  /// Compatible diffs are those where only one side has a non-null value.
  final bool showAcceptCompatibleButton;

  /// Initial state of the auto-accept toggle when [showAcceptCompatibleButton]
  /// is `true`.
  ///
  /// - `true` (default) — compatible diffs are pre-accepted on load.
  /// - `false` — all diffs start unresolved.
  final bool acceptCompatibleByDefault;

  // --- diff view — raw diff detail feature ---

  /// Whether to show a "View Raw Diff" button inside the merge overlay that
  /// navigates to the side-by-side [DiffDetailScreen]. Default: `false`.
  final bool showDiffDetailButton;

  /// Placement of the "View Raw Diff" button within the merge overlay.
  ///
  /// [Alignment.topRight] (the default) adds it to the [AppBar] actions.
  /// Any other value positions it inside the body with [Stack] + [Align].
  final Alignment diffDetailButtonAlignment;

  /// Optional converter for non-serialisable values (e.g. custom SQLite types).
  /// Called by [DiffDetailScreen] when the default [jsonEncode] throws.
  final String Function(dynamic)? toJsonConverter;

  /// Visual configuration for all sub-widgets. Defaults to
  /// [ComparableVersionTheme.new].
  final ComparableVersionTheme theme;

  /// `true` when constructed via [diffView]; `false` when via [rawView].
  final bool isDiffView;

  /// When true, JSON diffs/raw view use the in-memory [jsonA]/[jsonB] values
  /// instead of reading from [file1Path]/[file2Path]. This allows the package
  /// to avoid `dart:io` while still providing a rich visualisation API.
  final bool useInMemoryJson;

  /// In-memory JSON inputs corresponding to the \"left\"/\"right\" side.
  /// Only used when [fileType] is [FileType.json] and [useInMemoryJson] is true.
  final dynamic jsonA;
  final dynamic jsonB;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Display mode 0 — paginated raw view of records from both files
  /// side-by-side (or in a tabbed view on narrow screens).
  const ComparableVersionWidget.rawView({
    super.key,
    required this.fileType,
    required this.file1Path,
    required this.file2Path,
    required this.comparisonMode,
    this.recordsPerPage = 10,
    required this.returnType,
    required this.onMergeComplete,
    this.theme = const ComparableVersionTheme(),
  })  : isDiffView = false,
        useInMemoryJson = false,
        jsonA = null,
        jsonB = null,
        diffsPerPage = null,
        displayWidget = null,
        mergeWidget = null,
        showAcceptCompatibleButton = false,
        acceptCompatibleByDefault = true,
        showDiffDetailButton = false,
        diffDetailButtonAlignment = Alignment.topRight,
        toJsonConverter = null;

  /// Display mode 1 — paginated diff view with per-field merge resolution.
  ///
  /// [displayWidget] is required at construction time and renders the summary
  /// row for each detected difference.
  const ComparableVersionWidget.diffView({
    super.key,
    required this.fileType,
    required this.file1Path,
    required this.file2Path,
    required this.comparisonMode,
    this.diffsPerPage = 10,
    required Widget Function(DiffContext) this.displayWidget,
    this.mergeWidget,
    this.showAcceptCompatibleButton = false,
    this.acceptCompatibleByDefault = true,
    this.showDiffDetailButton = false,
    this.diffDetailButtonAlignment = Alignment.topRight,
    this.toJsonConverter,
    required this.returnType,
    required this.onMergeComplete,
    this.theme = const ComparableVersionTheme(),
  })  : isDiffView = true,
        useInMemoryJson = false,
        jsonA = null,
        jsonB = null,
        recordsPerPage = null;

  /// Diff view that works purely with in-memory JSON structures (no file I/O).
  /// [jsonA] and [jsonB] should be decoded JSON roots (`Map`/`List`/scalar).
  const ComparableVersionWidget.diffViewFromJson({
    super.key,
    required dynamic jsonA,
    required dynamic jsonB,
    required this.comparisonMode,
    this.diffsPerPage = 10,
    required Widget Function(DiffContext) this.displayWidget,
    this.mergeWidget,
    this.showAcceptCompatibleButton = false,
    this.acceptCompatibleByDefault = true,
    this.showDiffDetailButton = false,
    this.diffDetailButtonAlignment = Alignment.topRight,
    this.toJsonConverter,
    required this.returnType,
    required this.onMergeComplete,
    this.theme = const ComparableVersionTheme(),
  })  : fileType = FileType.json,
        file1Path = '',
        file2Path = '',
        isDiffView = true,
        useInMemoryJson = true,
        jsonA = jsonA,
        jsonB = jsonB,
        recordsPerPage = null;

  /// Raw-view mode that works purely with in-memory JSON structures.
  const ComparableVersionWidget.rawViewFromJson({
    super.key,
    required dynamic jsonA,
    required dynamic jsonB,
    this.recordsPerPage = 10,
    required this.returnType,
    required this.onMergeComplete,
    this.theme = const ComparableVersionTheme(),
  })  : fileType = FileType.json,
        file1Path = '',
        file2Path = '',
        comparisonMode = ComparisonMode.allDiffs,
        diffsPerPage = null,
        displayWidget = null,
        mergeWidget = null,
        showAcceptCompatibleButton = false,
        acceptCompatibleByDefault = true,
        showDiffDetailButton = false,
        diffDetailButtonAlignment = Alignment.topRight,
        toJsonConverter = null,
        isDiffView = false,
        useInMemoryJson = true,
        jsonA = jsonA,
        jsonB = jsonB;

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

  dynamic _jsonRawData1;
  dynamic _jsonRawData2;

  Database? _db1;
  Database? _db2;
  List<String> _sqliteTables = [];
  String? _selectedTable;

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
    if (widget.fileType == FileType.json && widget.useInMemoryJson) {
      final comparator = JsonComparator();
      _diffs = comparator.compareRoots(
        widget.jsonA,
        widget.jsonB,
        widget.comparisonMode,
      );
      return;
    }

    final BaseComparator comparator =
        widget.fileType == FileType.json ? JsonComparator() : SqliteComparator();
    _diffs = await comparator.compare(
      widget.file1Path,
      widget.file2Path,
      widget.comparisonMode,
    );
  }

  Future<void> _loadRawData() async {
    if (widget.fileType == FileType.json) {
      _loadJsonData();
    } else {
      await _loadSqliteData();
    }
  }

  // ── JSON raw data loading ──────────────────────────────────────────────────

  void _loadJsonData() {
    if (widget.useInMemoryJson) {
      _jsonRawData1 = widget.jsonA;
      _jsonRawData2 = widget.jsonB;
    } else {
      // No in-memory JSON provided and this package no longer performs file I/O
      // for JSON. Fall back to empty structures.
      _jsonRawData1 = <String, dynamic>{};
      _jsonRawData2 = <String, dynamic>{};
    }

    final perPage = widget.recordsPerPage ?? 10;
    _rawTotalPages =
        max(1, (_toRecordList(_jsonRawData1).length / perPage).ceil());
  }

  // ── SQLite raw data loading ────────────────────────────────────────────────

  Future<void> _loadSqliteData() async {
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

  Future<void> _recomputeSqlitePages(String table) async {
    final countRows = await _db1!.rawQuery('SELECT COUNT(*) FROM "$table"');
    final count = countRows.isNotEmpty
        ? (countRows.first.values.first as int?) ?? 0
        : 0;
    final perPage = widget.recordsPerPage ?? 10;
    _rawTotalPages = max(1, (count / perPage).ceil());
  }

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
    final t = widget.theme;
    if (widget.isDiffView) {
      return DiffViewPanel(
        diffs: _diffs,
        diffsPerPage: widget.diffsPerPage ?? 10,
        displayWidget: widget.displayWidget!,
        mergeWidget: widget.mergeWidget,
        onMergeComplete: widget.onMergeComplete,
        mergeResultBuilder: _buildMergeResult,
        showAcceptCompatibleButton: widget.showAcceptCompatibleButton,
        acceptCompatibleByDefault: widget.acceptCompatibleByDefault,
        showDiffDetailButton: widget.showDiffDetailButton,
        diffDetailButtonAlignment: widget.diffDetailButtonAlignment,
        toJsonConverter: widget.toJsonConverter,
        theme: t,
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            if (widget.fileType == FileType.sqlite &&
                _sqliteTables.length > 1)
              _tableSelector(),
            Expanded(
              child: RawViewPanel(
                key: ValueKey(_selectedTable),
                loadPageFile1: _pageLoaderFile1,
                loadPageFile2: _pageLoaderFile2,
                recordsPerPage: widget.recordsPerPage ?? 10,
                totalPages: _rawTotalPages,
                theme: t,
              ),
            ),
          ],
        ),
        Positioned(
          right: t.fabRightOffset,
          bottom: t.fabBottomOffset,
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
