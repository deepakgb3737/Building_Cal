import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectCeilingMaterial(String label, int quantity) {
  final row = find.byKey(ValueKey('ceiling-material-$label'));
  expect(row, findsOneWidget);
  expect(find.descendant(of: row, matching: find.text('$quantity')),
      findsOneWidget);
}
