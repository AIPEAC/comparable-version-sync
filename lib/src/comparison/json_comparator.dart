// Copyright 2026 comparable_version_sync authors. All rights reserved.
//
// Lightweight JSON comparator that walks the decoded JSON structure directly.
// No external diff library is used to keep dependencies minimal.

import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../enums/comparison_mode.dart';
import '../models/diff_context.dart';
import 'base_comparator.dart';
import 'compatibility_checker.dart';
import 'context_resolver.dart';

/// Compares two JSON files or JSON strings and produces a list of [DiffContext]
/// entries without relying on external diff packages.
class JsonComparator implements BaseComparator {
  @override
  Future<List<DiffContext>> compare(
    String file1Path,
    String file2Path,
    ComparisonMode mode,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'JSON file path comparison is not supported on web. '
        'Load JSON strings yourself and call compareStrings().',
      );
    }

    final left = await io.File(file1Path).readAsString();
    final right = await io.File(file2Path).readAsString();
    return compareStrings(left, right, mode);
  }

  /// Compares two JSON strings directly — safe on all platforms, including web
  /// when the caller provides the strings.
  List<DiffContext> compareStrings(
    String leftJson,
    String rightJson,
    ComparisonMode mode,
  ) {
    final rootA = jsonDecode(leftJson);
    final rootB = jsonDecode(rightJson);

    final results = <DiffContext>[];
    final checker = CompatibilityChecker();
    final resolver = ContextResolver();

    _walk(
      rootA,
      rootB,
      '',
      results,
      checker,
      resolver,
      rootA,
      rootB,
    );

    if (mode == ComparisonMode.incompatibleOnly) {
      return checker.filterIncompatible(results);
    }
    return results;
  }

  void _walk(
    dynamic a,
    dynamic b,
    String path,
    List<DiffContext> out,
    CompatibilityChecker checker,
    ContextResolver resolver,
    dynamic rootA,
    dynamic rootB,
  ) {
    if (a is Map && b is Map) {
      final keys = <String>{
        ...a.keys.cast<String>(),
        ...b.keys.cast<String>(),
      };
      for (final key in keys) {
        final va = a[key];
        final vb = b[key];
        final childPath = path.isEmpty ? key : '$path.$key';
        if (_bothComplex(va, vb)) {
          _walk(va, vb, childPath, out, checker, resolver, rootA, rootB);
        } else if (!_equals(va, vb)) {
          _addDiff(out, childPath, va, vb, checker, resolver, rootA, rootB);
        }
      }
    } else if (a is List && b is List) {
      final maxLen = a.length > b.length ? a.length : b.length;
      for (var i = 0; i < maxLen; i++) {
        final va = i < a.length ? a[i] : null;
        final vb = i < b.length ? b[i] : null;
        final childPath = path.isEmpty ? '$i' : '$path.$i';
        if (_bothComplex(va, vb)) {
          _walk(va, vb, childPath, out, checker, resolver, rootA, rootB);
        } else if (!_equals(va, vb)) {
          _addDiff(out, childPath, va, vb, checker, resolver, rootA, rootB);
        }
      }
    } else if (!_equals(a, b)) {
      final effectivePath = path.isEmpty ? r'$' : path;
      _addDiff(out, effectivePath, a, b, checker, resolver, rootA, rootB);
    }
  }

  bool _bothComplex(dynamic a, dynamic b) =>
      (a is Map && b is Map) || (a is List && b is List);

  bool _equals(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    return a == b;
  }

  void _addDiff(
    List<DiffContext> out,
    String fullPath,
    dynamic valueA,
    dynamic valueB,
    CompatibilityChecker checker,
    ContextResolver resolver,
    dynamic rootA,
    dynamic rootB,
  ) {
    final parentPath = _parentPath(fullPath);
    out.add(
      DiffContext(
        path: fullPath,
        parentContext: resolver.resolveParent(fullPath),
        valueA: valueA,
        valueB: valueB,
        isCompatible: checker.isCompatible(valueA, valueB),
        parentValueA: resolver.valueAtPath(rootA, parentPath),
        parentValueB: resolver.valueAtPath(rootB, parentPath),
      ),
    );
  }

  String _parentPath(String path) {
    final parts = path.split('.');
    if (parts.length <= 1) return '';
    return parts.sublist(0, parts.length - 1).join('.');
  }
}
