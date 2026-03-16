// Copyright 2014 Google Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Source: https://github.com/google/dart-json_diff
// Inlined to avoid a path dependency that would prevent pub.dev publishing.
// Attribution preserved as required by Apache 2.0 Section 4(c).
// See LICENSE-dart-json-diff at the repository root for the full license text.

/// A library for determining the difference between two JSON objects.
library;

import 'dart:convert';
import 'package:collection/collection.dart';

// ---------------------------------------------------------------------------
// DiffNode
// ---------------------------------------------------------------------------

/// A hierarchical structure representing the differences between two JSON
/// objects.
///
/// A DiffNode object is returned by [JsonDiffer]'s `diff()` method. DiffNode
/// is a tree structure, referring to more DiffNodes in the `node` property.
/// To access the differences in a DiffNode, refer to the following properties:
///
/// * [added] is a Map of key-value pairs found in the _right_ JSON but not in
///   the _left_ JSON.
/// * [removed] is a Map of key-value pairs found in the _left_ JSON but not in
///   the _right_ JSON.
/// * [changed] is a Map referencing immediate values that are different
///   between the _left_ and _right_ JSONs. Each key in the Map is a key whose
///   values changed, mapping to a 2-element array which lists the left value
///   and the right value.
/// * [node] is a Map of deeper changes. Each key in this Map is a key whose
///   values changed deeply between the left and right JSONs, mapping to a
///   DiffNode containing those deep changes.
class DiffNode {
  DiffNode(this.path);

  final node = <Object, DiffNode>{};
  final added = <Object, Object?>{};
  final removed = <Object, Object?>{};
  final Map<Object, List<Object?>> changed = <Object, List<Object?>>{};
  final moved = <int, int>{};

  /// The path from the root to this node, e.g. `["propertyA", 1, "propertyB"]`.
  final List<Object> path;

  void operator []=(Object s, DiffNode d) => node[s] = d;
  DiffNode? operator [](Object s) => node[s];
  bool containsKey(Object s) => node.containsKey(s);
  void forEach(void Function(Object s, DiffNode dn) ffn) => node.forEach(ffn);

  List<Object?> map(void Function(Object s, DiffNode dn) ffn) {
    final result = <void>[];
    forEach((s, dn) => result.add(ffn(s, dn)));
    return result;
  }

  void forEachOf(String key, void Function(Object s, DiffNode dn) ffn) {
    if (node.containsKey(key)) node[key]!.forEach(ffn);
  }

  void forEachAdded(void Function(Object s, Object? o) ffn) =>
      added.forEach(ffn);
  void forEachRemoved(void Function(Object s, Object? o) ffn) =>
      removed.forEach(ffn);
  void forEachChanged(void Function(Object s, List<Object?> o) ffn) =>
      changed.forEach(ffn);

  void forAllAdded(
    void Function(Object? _, Object? o) ffn, {
    Map<Object, Object?> root = const {},
  }) {
    added.forEach((key, thisNode) => ffn(root, thisNode));
    node.forEach((key, node) {
      root[key] = <String, Object?>{};
      node.forAllAdded(
        (addedMap, root) => ffn(root, addedMap),
        root: root[key] as Map<String, Object?>,
      );
    });
  }

  Map<Object, Object?>? allAdded() {
    final thisNode = <Object, Object?>{};
    added.forEach((k, v) => thisNode[k] = v);
    node.forEach((k, v) {
      final down = v.allAdded();
      if (down == null) return;
      thisNode[k] = down;
    });
    return thisNode.isEmpty ? null : thisNode;
  }

  bool get hasAdded => added.isNotEmpty;
  bool get hasRemoved => removed.isNotEmpty;
  bool get hasChanged => changed.isNotEmpty;
  bool get hasMoved => moved.isNotEmpty;
  bool get hasNothing =>
      added.isEmpty &&
      removed.isEmpty &&
      changed.isEmpty &&
      moved.isEmpty &&
      node.isEmpty;

  /// Prunes child [DiffNode]s that have no differences.
  void prune() {
    final keys = node.keys.toList();
    for (var i = keys.length - 1; i >= 0; i--) {
      final key = keys[i];
      final d = node[key]!;
      d.prune();
      if (d.hasNothing) node.remove(key);
    }
  }

  @override
  String toString() => _diffToString(this).join('\n');
}

List<String> _diffToString(DiffNode diff) => [
      for (final e in diff.removed.entries) ...[
        '@ Removed from left at path "${[...diff.path, e.key]}":',
        '- ${jsonEncode(e.value)}',
      ],
      for (final e in diff.added.entries) ...[
        '@ Added to right at path "${[...diff.path, e.key]}":',
        '+ ${jsonEncode(e.value)}',
      ],
      for (final e in diff.changed.entries) ...[
        '@ Changed at path "${[...diff.path, e.key]}":',
        '- ${jsonEncode(e.value.first)}',
        '+ ${jsonEncode(e.value.last)}',
      ],
      for (final e in diff.moved.entries) ...[
        '@ Moved at path "${[...diff.path, e.key]}"',
        '${e.key} -> ${e.value}',
      ],
      for (final e in diff.node.entries) ..._diffToString(e.value),
    ];

// ---------------------------------------------------------------------------
// JsonDiffer
// ---------------------------------------------------------------------------

/// A configurable class that produces a [DiffNode] diff from two JSON strings.
class JsonDiffer {
  final Object leftJson, rightJson;
  final List<String> atomics = <String>[];
  final List<String> ignored = <String>[];

  JsonDiffer(String leftString, String rightString)
      : leftJson = jsonDecode(leftString) as Object,
        rightJson = jsonDecode(rightString) as Object;

  JsonDiffer.fromJson(this.leftJson, this.rightJson);

  /// Compares the two JSON objects and returns a [DiffNode] tree.
  DiffNode diff() {
    if (leftJson is Map && rightJson is Map) {
      return _diffObjects(
        (leftJson as Map).cast<String, Object?>(),
        (rightJson as Map).cast<String, Object?>(),
        [],
      )..prune();
    } else if (leftJson is List && rightJson is List) {
      return _diffLists(
        (leftJson as List).cast<Object?>(),
        (rightJson as List).cast<Object?>(),
        null,
        [],
      );
    }
    return DiffNode([])..changed[''] = [leftJson, rightJson];
  }

  DiffNode _diffObjects(
      Map<String, Object?> left, Map<String, Object?> right, List<Object> path) {
    final node = DiffNode(path);
    left.forEach((key, leftValue) {
      if (ignored.contains(key)) return;
      if (!right.containsKey(key)) {
        node.removed[key] = leftValue;
        return;
      }
      final rightValue = right[key];
      if (atomics.contains(key) &&
          leftValue.toString() != rightValue.toString()) {
        node.changed[key] = [leftValue, rightValue];
      } else if (leftValue is List && rightValue is List) {
        node[key] = _diffLists(leftValue.cast<Object?>(),
            rightValue.cast<Object?>(), key, [...path, key]);
      } else if (leftValue is Map && rightValue is Map) {
        node[key] = _diffObjects(leftValue.cast<String, Object?>(),
            rightValue.cast<String, Object?>(), [...path, key]);
      } else if (leftValue != rightValue) {
        node.changed[key] = [leftValue, rightValue];
      }
    });
    right.forEach((key, value) {
      if (!ignored.contains(key) && !left.containsKey(key)) {
        node.added[key] = value;
      }
    });
    return node;
  }

  bool _deepEquals(Object? e1, Object? e2) =>
      const DeepCollectionEquality.unordered().equals(e1, e2);

  DiffNode _diffLists(List<Object?> left, List<Object?> right, String? parentKey,
      List<Object> path) {
    final node = DiffNode(path);
    var leftHand = 0;
    var leftFoot = 0;
    var rightHand = 0;
    var rightFoot = 0;
    while (leftFoot < left.length && rightFoot < right.length) {
      if (!_deepEquals(left[leftFoot], right[rightFoot])) {
        var foundMissing = false;
        while (true) {
          rightHand++;
          if (rightHand < right.length &&
              _deepEquals(left[leftFoot], right[rightHand])) {
            for (var i = rightFoot; i < rightHand; i++) {
              node.added[i] = right[i];
            }
            rightFoot = rightHand;
            leftHand = leftFoot;
            foundMissing = true;
            break;
          }
          leftHand++;
          if (leftHand < left.length &&
              _deepEquals(left[leftHand], right[rightFoot])) {
            for (var i = leftFoot; i < leftHand; i++) {
              node.removed[i] = left[i];
            }
            leftFoot = leftHand;
            rightHand = rightFoot;
            foundMissing = true;
            break;
          }
          if (leftHand >= left.length && rightHand >= right.length) break;
        }
        if (!foundMissing) {
          final leftObject = left[leftFoot];
          final rightObject = right[rightFoot];
          if (parentKey != null &&
              atomics.contains('$parentKey[]') &&
              leftObject.toString() != rightObject.toString()) {
            node.changed[leftFoot] = [leftObject, rightObject];
          } else if (leftObject is Map && rightObject is Map) {
            node[leftFoot] = _diffObjects(leftObject.cast<String, Object?>(),
                rightObject.cast<String, Object?>(), [...path, leftFoot]);
          } else if (leftObject is List && rightObject is List) {
            node[leftFoot] = _diffLists(leftObject.cast<Object?>(),
                rightObject.cast<Object?>(), null, [...path, leftFoot]);
          } else {
            node.changed[leftFoot] = [leftObject, rightObject];
          }
        }
      }
      leftHand++;
      rightHand++;
      leftFoot++;
      rightFoot++;
    }
    for (var i = rightFoot; i < right.length; i++) {
      node.added[i] = right[i];
    }
    for (var i = leftFoot; i < left.length; i++) {
      node.removed[i] = left[i];
    }
    final removedFiltered = node.removed.entries.where((e) {
      final addedEntry = node.added
          .removeFirstWhere((key, value) => _deepEquals(e.value, value));
      if (addedEntry != null) {
        node.moved[e.key as int] = addedEntry.key as int;
        return false;
      }
      return true;
    }).toList();
    node.removed.clear();
    node.removed.addEntries(removedFiltered);
    return node;
  }
}

/// Thrown when two JSON strings failed a basic sanity check before diffing.
class UncomparableJsonException implements Exception {
  final String msg;
  const UncomparableJsonException(this.msg);
  @override
  String toString() => 'UncomparableJsonException: $msg';
}

extension _MapExt<K, V> on Map<K, V> {
  MapEntry<K, V>? removeFirstWhere(bool Function(K, V) test) {
    for (final entry in entries) {
      if (test(entry.key, entry.value)) {
        remove(entry.key);
        return entry;
      }
    }
    return null;
  }
}
