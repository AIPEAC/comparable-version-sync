import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comparable_version_sync/comparable_version_sync.dart';

void main() {
  testWidgets('ComparableVersionWidget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ComparableVersionWidget.diffView(
        fileType: FileType.json,
        file1Path: 'a.json',
        file2Path: 'b.json',
        comparisonMode: ComparisonMode.allDiffs,
        displayWidget: (diff) => const SizedBox.shrink(),
        returnType: ReturnType.json,
        onMergeComplete: (_) {},
      ),
    );
  });
}
