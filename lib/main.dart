// Test harness app — not part of the package API.
// Used during development to manually exercise the widget.

import 'dart:convert';

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
      home: const _HarnessHome(),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline sample JSON used as test data
// ---------------------------------------------------------------------------

const _sampleA = {
  'name': 'Alice',
  'version': 1,
  'role': 'admin',
  'address': {'city': 'London', 'zip': 'EC1A'},
  'tags': ['flutter', 'dart'],
  'email': null,
};

const _sampleB = {
  'name': 'Alice',
  'version': 2,
  'role': 'editor',
  'address': {'city': 'Manchester', 'zip': 'M1 1AE'},
  'tags': ['flutter', 'dart', 'mobile'],
  'email': 'alice@example.com',
};

// ---------------------------------------------------------------------------

class _HarnessHome extends StatelessWidget {
  const _HarnessHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('comparable_version_sync — dev harness')),
      body: ComparableVersionWidget.diffViewFromJson(
        jsonA: _sampleA,
        jsonB: _sampleB,
        comparisonMode: ComparisonMode.allDiffs,
        diffsPerPage: 10,
        showAcceptCompatibleButton: true,
        acceptCompatibleByDefault: true,
        showDiffDetailButton: true,
        displayWidget: (diff) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'A: ${diff.valueA}  →  B: ${diff.valueB}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        returnType: ReturnType.json,
        onMergeComplete: (result) {
          debugPrint('Merged JSON: ${jsonEncode(result.mergedJson)}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Merge complete — see debug console.')),
          );
        },
      ),
    );
  }
}
