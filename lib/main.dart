// Test harness app — not part of the package API.
// Used during development to manually exercise the widget.
//
// Provides an instructions screen with inline JSON sample data so the harness
// runs without any external asset files.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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

class _HarnessHome extends StatefulWidget {
  const _HarnessHome();

  @override
  State<_HarnessHome> createState() => _HarnessHomeState();
}

class _HarnessHomeState extends State<_HarnessHome> {
  String? _path1;
  String? _path2;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _writeSampleFiles();
  }

  Future<void> _writeSampleFiles() async {
    if (kIsWeb) {
      // On web there is no writable filesystem; use placeholder paths that
      // will trigger a friendly error inside ComparableVersionWidget.
      setState(() {
        _path1 = '/web/sample_a.json';
        _path2 = '/web/sample_b.json';
        _ready = true;
      });
      return;
    }
    try {
      final dir = Directory.systemTemp;
      final f1 = File('${dir.path}/sample_a.json');
      final f2 = File('${dir.path}/sample_b.json');
      await f1.writeAsString(jsonEncode(_sampleA));
      await f2.writeAsString(jsonEncode(_sampleB));
      setState(() {
        _path1 = f1.path;
        _path2 = f2.path;
        _ready = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('comparable_version_sync — dev harness')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text('Setup error: $_error',
            style: const TextStyle(color: Colors.red)),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return ComparableVersionWidget.diffView(
      fileType: FileType.json,
      file1Path: _path1!,
      file2Path: _path2!,
      comparisonMode: ComparisonMode.allDiffs,
      diffsPerPage: 10,
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
    );
  }
}
