// Copyright 2014 Google Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0, found in the LICENSE file.

/// A library for determining the difference between two JSON objects.
///
/// ## Usage
///
/// In order to diff two JSON objects, stored as Dart strings, create a new
/// [JsonDiffer], passing the two objects:
///
///     JsonDiffer differ = new JsonDiffer(leftJsonString, rightJsonString)
///
/// To calculate the diff between the two objects, call `diff()` on the
/// [JsonDiffer], which will return a [DiffNode]:
///
///     DiffNode diff = differ.diff();
///
/// This [DiffNode] object is a hierarchical structure (like JSON) of the
/// differences between the two objects.
library;

import 'dart:convert';
import 'package:collection/collection.dart';

// ---------------------------------------------------------------------------
// DiffNode  (originally src/diff_node.dart)
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

  /// A Map of deep changes between the two JSON objects.
  final node = <Object, DiffNode>{};

  /// A Map containing the key/value pairs that were _added_ between the left
  /// JSON and the right.
  final added = <Object, Object?>{};

  /// A Map containing the key/value pairs that were _removed_ between the left
  /// JSON and the right.
  final removed = <Object, Object?>{};

  /// A Map whose values are 2-element arrays containing the left value and the
  /// right value, corresponding to the mapping key.
  final Map<Object, List<Object?>> changed = <Object, List<Object?>>{};

  /// A Map of _moved_ elements in the List, where the key is the original
  /// position, and the value is the new position.
  final moved = <int, int>{};

  /// The path, starting from the root, where this [DiffNode] is describing the
  /// left and right JSON, e.g. ["propertyA", 1, "propertyB"].
  final List<Object> path;

  /// A convenience method for `node[]=`.
  void operator []=(Object s, DiffNode d) {
    node[s] = d;
  }

  /// A convenience method for `node[]`.
  DiffNode? operator [](Object s) {
    return node[s];
  }

  /// A convenience method for `node.containsKey()`.
  bool containsKey(Object s) {
    return node.containsKey(s);
  }

  void forEach(void Function(Object s, DiffNode dn) ffn) => node.forEach(ffn);

  List<Object?> map(void Function(Object s, DiffNode dn) ffn) {
    final result = <void>[];
    forEach((s, dn) {
      result.add(ffn(s, dn));
    });
    return result;
  }

  void forEachOf(String key, void Function(Object s, DiffNode dn) ffn) {
    if (node.containsKey(key)) {
      node[key]!.forEach(ffn);
    }
  }

  void forEachAdded(void Function(Object s, Object? o) ffn) =>
      added.forEach(ffn);

  void forEachRemoved(void Function(Object s, Object? o) ffn) =>
      removed.forEach(ffn);

  void forEachChanged(void Function(Object s, List<Object?> o) ffn) =>
      changed.forEach(ffn);

  void forAllAdded(void Function(Object? _, Object? o) ffn,
      {Map<Object, Object?> root = const {}}) {
    added.forEach((key, thisNode) => ffn(root, thisNode));
    node.forEach((key, node) {
      root[key] = <String, Object?>{};
      node.forAllAdded((addedMap, root) => ffn(root, addedMap),
          root: root[key] as Map<String, Object?>);
    });
  }

  Map<Object, Object?>? allAdded() {
    final thisNode = <Object, Object?>{};
    added.forEach((k, v) {
      thisNode[k] = v;
    });
    node.forEach((k, v) {
      final down = v.allAdded();
      if (down == null) {
        return;
      }
      thisNode[k] = down;
    });

    if (thisNode.isEmpty) {
      return null;
    }
    return thisNode;
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

  /// Prunes the DiffNode tree.
  ///
  /// If a child DiffNode has nothing added, removed, changed, nor a node, then it will
  /// be deleted from the parent's [node] Map.
  void prune() {
    var keys = node.keys.toList();
    for (var i = keys.length - 1; i >= 0; i--) {
      final key = keys[i];
      final d = node[key]!;
      d.prune();
      if (d.hasNothing) {
        node.remove(key);
      }
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
        '+ ${jsonEncode(e.value)}'
      ],
      for (final e in diff.changed.entries) ...[
        '@ Changed at path "${[...diff.path, e.key]}":',
        '- ${jsonEncode(e.value.first)}',
        '+ ${jsonEncode(e.value.last)}',
      ],
      for (final e in diff.moved.entries) ...[
        '@ Moved at path "${[...diff.path, e.key]}"',
        '${e.key} -> ${e.value}'
      ],
      for (final e in diff.node.entries) ..._diffToString(e.value)
    ];

// ---------------------------------------------------------------------------
// JsonDiffer  (originally src/json_differ.dart)
// ---------------------------------------------------------------------------

/// A configurable class that can produce a diff of two JSON Strings.
class JsonDiffer {
  final Object leftJson, rightJson;
  final List<String> atomics = <String>[];
  final List<String> ignored = <String>[];

  /// Constructs a new JsonDiffer using [leftString] and [rightString], two
  /// JSON objects represented as Dart strings.
  ///
  /// If the two JSON objects that need to be diffed are only available as
  /// Dart Maps, you can use the
  /// [dart:convert](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:convert)
  /// library to encode each Map into a JSON String.
  JsonDiffer(
    String leftString,
    String rightString,
  )   : leftJson = jsonDecode(leftString) as Object,
        rightJson = jsonDecode(rightString) as Object;

  JsonDiffer.fromJson(this.leftJson, this.rightJson);

  /// Compare the two JSON Strings, producing a [DiffNode].
  ///
  /// The differ will walk the entire object graph of each JSON object,
  /// tracking all additions, deletions, and changes. Please see the
  /// documentation for [DiffNode] to understand how to access the differences
  /// found between the two JSON Strings.
  DiffNode diff() {
    if (leftJson is Map && rightJson is Map) {
      return _diffObjects(
        (leftJson as Map).cast<String, Object?>(),
        (rightJson as Map).cast<String, Object?>(),
        [],
      )..prune();
    } else if (leftJson is List && rightJson is List) {
      return _diffLists((leftJson as List).cast<Object?>(),
          (rightJson as List).cast<Object?>(), null, []);
    }
    return DiffNode([])..changed[''] = [leftJson, rightJson];
  }

  DiffNode _diffObjects(Map<String, Object?> left, Map<String, Object?> right,
      List<Object> path) {
    final node = DiffNode(path);
    left.forEach((String key, Object? leftValue) {
      if (ignored.contains(key)) {
        return;
      }

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

    right.forEach((String key, Object? value) {
      if (ignored.contains(key)) {
        return;
      }

      if (!left.containsKey(key)) {
        node.added[key] = value;
      }
    });

    return node;
  }

  bool _deepEquals(Object? e1, Object? e2) =>
      DeepCollectionEquality.unordered().equals(e1, e2);

  DiffNode _diffLists(List<Object?> left, List<Object?> right,
      String? parentKey, List<Object> path) {
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

          if (leftHand >= left.length && rightHand >= right.length) {
            break;
          }
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
      final added = node.added
          .removeFirstWhere((key, value) => _deepEquals(e.value, value));

      if (added != null) {
        node.moved[e.key as int] = added.key as int;
        return false;
      }

      return true;
    }).toList();

    node.removed.clear();
    node.removed.addEntries(removedFiltered);

    return node;
  }
}

/// An exception that is thrown when two JSON Strings did not pass a basic sanity test.
class UncomparableJsonException implements Exception {
  final String msg;

  const UncomparableJsonException(this.msg);

  @override
  String toString() => 'UncomparableJsonException: $msg';
}

extension<K, V> on Map<K, V> {
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
