import 'dart:convert';

import 'package:comparable_version_sync/comparable_version_sync.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Simple example showing [ComparableVersionWidget.diffViewFromJson].
///
/// Pass two decoded JSON objects and the widget handles comparison,
/// pagination, merge resolution, and returns the merged result.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // Two versions of the same JSON document to compare.
  final _jsonA = const {
    'name': 'Alice',
    'version': 1,
    'role': 'admin',
    'address': {'city': 'London', 'zip': 'EC1A'},
    'tags': ['flutter', 'dart'],
  };

  final _jsonB = const {
    'name': 'Alice',
    'version': 2,
    'role': 'editor',
    'address': {'city': 'Manchester', 'zip': 'M1 1AE'},
    'tags': ['flutter', 'dart', 'mobile'],
    'email': 'alice@example.com',
  };

  String _mergeResult = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'comparable_version_sync example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('comparable_version_sync example')),
        body: Column(
          children: [
            Expanded(
              child: ComparableVersionWidget.diffViewFromJson(
                jsonA: _jsonA,
                jsonB: _jsonB,
                comparisonMode: ComparisonMode.allDiffs,
                diffsPerPage: 10,
                showAcceptCompatibleButton: true,
                showDiffDetailButton: true,
                displayWidget: (diff) => Text(
                  'A: ${diff.valueA}  →  B: ${diff.valueB}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
                returnType: ReturnType.json,
                onMergeComplete: (result) {
                  setState(() {
                    _mergeResult = const JsonEncoder.withIndent('  ')
                        .convert(result.mergedJson);
                  });
                },
              ),
            ),
            if (_mergeResult.isNotEmpty)
              Container(
                color: Colors.green.shade50,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  'Merged result:\n$_mergeResult',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
