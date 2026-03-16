// Test harness app — not part of the package API.
// Used during development to manually exercise the widget.

import 'package:flutter/material.dart';
import 'comparable_version_sync.dart';

void main() {
  runApp(const _TestApp());
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'comparable_version_sync — dev harness',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('comparable_version_sync')),
        body: ComparableVersionWidget.diffView(
          fileType: FileType.json,
          file1Path: 'assets/sample_a.json',
          file2Path: 'assets/sample_b.json',
          comparisonMode: ComparisonMode.allDiffs,
          diffsPerPage: 10,
          displayWidget: (diff) => ListTile(
            title: Text(diff.path),
            subtitle: Text('A: ${diff.valueA}  →  B: ${diff.valueB}'),
          ),
          returnType: ReturnType.json,
          onMergeComplete: (result) {
            debugPrint('Merged: ${result.mergedJson}');
          },
        ),
      ),
    );
  }
}
