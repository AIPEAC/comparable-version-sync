// Copyright 2026 comparable_version_sync authors. All rights reserved.
//
// Uses the local clone of google/dart-json_diff (Apache 2.0).
// See lib/third_party/dart_json_diff/LICENSE for license details.

import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:json_diff/json_diff.dart';

import '../enums/comparison_mode.dart';
import '../models/diff_context.dart';
import 'base_comparator.dart';
import 'compatibility_checker.dart';
import 'context_resolver.dart';

/// Compares two JSON files using the locally cloned dart-json_diff library.
///
/// On web, `dart:io` is unavailable. Callers on web must use
/// [compareStrings] directly instead of [compare].
class JsonComparator implements BaseComparator {
  @override
  Future<List<DiffContext>> compare(
    String file1Path,
    String file2Path,
    ComparisonMode mode,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'JSON file path comparison is not supported on web — '
        'pass pre-loaded JSON strings via JsonComparator.compareStrings() instead.',
      );
    }

    final left = await io.File(file1Path).readAsString();
    final right = await io.File(file2Path).readAsString();

    final root = JsonDiffer(left, right).diff();

    final results = <DiffContext>[];
    final checker = CompatibilityChecker();
    final resolver = ContextResolver();

    _walkNode(root, results, checker, resolver);

    if (mode == ComparisonMode.incompatibleOnly) {
      return checker.filterIncompatible(results);
    }
    return results;
  }

  /// Compares two JSON strings directly — safe on all platforms including web.
  List<DiffContext> compareStrings(
    String leftJson,
    String rightJson,
    ComparisonMode mode,
  ) {
    final root = JsonDiffer(leftJson, rightJson).diff();
    final results = <DiffContext>[];
    final checker = CompatibilityChecker();
    final resolver = ContextResolver();
    _walkNode(root, results, checker, resolver);
    if (mode == ComparisonMode.incompatibleOnly) {
      return checker.filterIncompatible(results);
    }
    return results;
  }

  /// Recursively walks a [DiffNode] tree and appends [DiffContext] items to [results].
  ///
  /// [node.path] already carries the ancestor segments (as `List<Object>`), so
  /// we only need to append the current key to build the full dot-notation path.
  void _walkNode(
    DiffNode node,
    List<DiffContext> results,
    CompatibilityChecker checker,
    ContextResolver resolver,
  ) {
    // changed: both sides have a value but they differ.
    node.changed.forEach((key, pair) {
      final path = _buildPath(node.path, key);
      final valueA = pair[0];
      final valueB = pair[1];
      results.add(DiffContext(
        path: path,
        parentContext: resolver.resolveParent(path),
        valueA: valueA,
        valueB: valueB,
        isCompatible: checker.isCompatible(valueA, valueB),
      ));
    });

    // added: key present in right (file2) but absent in left (file1).
    node.added.forEach((key, valueB) {
      final path = _buildPath(node.path, key);
      results.add(DiffContext(
        path: path,
        parentContext: resolver.resolveParent(path),
        valueA: null,
        valueB: valueB,
        isCompatible: true,
      ));
    });

    // removed: key present in left (file1) but absent in right (file2).
    node.removed.forEach((key, valueA) {
      final path = _buildPath(node.path, key);
      results.add(DiffContext(
        path: path,
        parentContext: resolver.resolveParent(path),
        valueA: valueA,
        valueB: null,
        isCompatible: true,
      ));
    });

    // node: deeper sub-trees — recurse.
    node.forEach((_, child) => _walkNode(child, results, checker, resolver));
  }

  String _buildPath(List<Object> nodePath, Object key) {
    final segments = [...nodePath.map((e) => e.toString()), key.toString()];
    return segments.join('.');
  }
}
