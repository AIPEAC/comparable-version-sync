// Copyright 2026 comparable_version_sync authors. All rights reserved.
// AGENT: 001 — implement this file.
//
// Uses the local clone of google/dart-json_diff (Apache 2.0).
// See lib/third_party/dart_json_diff/LICENSE for license details.

import '../enums/comparison_mode.dart';
import '../models/diff_context.dart';
import 'base_comparator.dart';
// ignore: unused_import — used by AGENT:001 during implementation
import 'compatibility_checker.dart';
// ignore: unused_import — used by AGENT:001 during implementation
import 'context_resolver.dart';

/// Compares two JSON files using the locally cloned dart-json_diff library.
class JsonComparator implements BaseComparator {
  @override
  Future<List<DiffContext>> compare(
    String file1Path,
    String file2Path,
    ComparisonMode mode,
  ) {
    // TODO(AGENT:001): implement
    // 1. Read both JSON files.
    // 2. Use json_diff.JsonDiffer to produce a DiffNode tree.
    // 3. Walk the tree → produce List<DiffContext> via ContextResolver.
    // 4. Filter with CompatibilityChecker when mode == incompatibleOnly.
    throw UnimplementedError('JsonComparator.compare not yet implemented');
  }
}
