import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void checkPlan(Layout plan) {
  final demand = <double, int>{};
  var joints = 0;
  for (final row in plan.layoutRows) {
    for (final segment in row.segments) {
      expect(segment.pieces.reduce((a, b) => a + b),
          closeTo(segment.x1 - segment.x0, .01));
      var position = segment.x0;
      final joins = <double>[];
      for (var i = 0; i < segment.pieces.length; i++) {
        final piece = segment.pieces[i];
        demand[piece] = (demand[piece] ?? 0) + 1;
        position += piece;
        if (i < segment.pieces.length - 1) joins.add(position);
      }
      final line = plan.alignedJoint!;
      if (line > segment.x0 + kEps && line < segment.x1 - kEps) {
        expect(joins.any((x) => (x - line).abs() < .01), isTrue);
      }
      joints += joins.length;
    }
  }
  expect(plan.joints, joints);
  for (var i = 0; i < plan.sizes.length; i++) {
    expect(plan.plan.fold<int>(0, (n, p) => n + p.counts[i]),
        demand[plan.sizes[i]]);
  }
  for (final stock in plan.plan) {
    var length = 0.0, pieces = 0;
    for (var i = 0; i < plan.sizes.length; i++) {
      length += plan.sizes[i] * stock.counts[i];
      pieces += stock.counts[i];
    }
    expect(
        length + (pieces - 1) * kKerf, lessThanOrEqualTo(stock.stock + kEps));
  }
}

void main() {
  PvcRoom rectangle(double a, double b) =>
      buildPvcRoom(PvcShape.rectangle, {'A': '$a', 'B': '$b'});
  test('21 ft centre uses 10.5 + 10.5; default optimization is unchanged', () {
    final room = rectangle(21, 8);
    final old = runPvcCalculation(
        PvcCalculation(room, 'mix', orientation: PvcOrientation.length))!;
    final explicitAuto = runPvcCalculation(PvcCalculation(room, 'mix',
        orientation: PvcOrientation.length, jointRule: const PvcJointRule()))!;
    expect(explicitAuto.pcs, old.pcs);
    expect(explicitAuto.total, old.total);
    final centre = runPvcCalculation(PvcCalculation(room, 'mix',
        orientation: PvcOrientation.length,
        jointRule: const PvcJointRule(mode: PvcJointMode.centre)))!;
    expect(centre.pcs, [10.5, 10.5]);
    expect(centre.alignedJoint, 10.5);
    expect(centre.q10, 0);
    expect(centre.q12, centre.rowsCount * 2);
    checkPlan(centre);
  });
  test('Custom side and rotated direction retain ordered cuts', () {
    for (final dir in [PvcOrientation.length, PvcOrientation.width]) {
      final room =
          dir == PvcOrientation.length ? rectangle(21, 8) : rectangle(8, 21);
      for (final fromEnd in [false, true]) {
        final plan = runPvcCalculation(PvcCalculation(room, 'mix',
            orientation: dir,
            jointRule: PvcJointRule(
                mode: PvcJointMode.custom, distanceFt: 10, fromEnd: fromEnd)))!;
        expect(plan.pcs, fromEnd ? [11.0, 10.0] : [10.0, 11.0]);
        expect(plan.alignedJoint, fromEnd ? 11 : 10);
        checkPlan(plan);
      }
    }
  });
  test('Long sides add necessary joints but keep the chosen centre line', () {
    final plan = runPvcCalculation(PvcCalculation(rectangle(50, 8), 'mix',
        orientation: PvcOrientation.length,
        jointRule: const PvcJointRule(mode: PvcJointMode.centre)))!;
    expect(plan.alignedJoint, 25);
    expect(plan.pcs.length, 6);
    checkPlan(plan);
  });
  test('Concave, mirrored and angled rows use global line, not each row centre',
      () {
    for (final shape in PvcShape.values) {
      final dir = [PvcShape.l, PvcShape.cutCorner].contains(shape)
          ? PvcOrientation.length
          : PvcOrientation.width;
      final room = buildPvcRoom(shape, pvcDefaults(shape));
      final plan = runPvcCalculation(PvcCalculation(room, 'mix',
          orientation: dir,
          jointRule: const PvcJointRule(mode: PvcJointMode.centre)))!;
      expect(plan.area, room.area);
      checkPlan(plan);
    }
    for (final corner in ['tr', 'tl', 'br', 'bl']) {
      final room =
          buildPvcRoom(PvcShape.l, pvcDefaults(PvcShape.l), corner: corner);
      checkPlan(runPvcCalculation(PvcCalculation(room, 'mix',
          orientation: PvcOrientation.length,
          jointRule: const PvcJointRule(mode: PvcJointMode.centre)))!);
    }
  });
  test('Invalid reference, distance and short joint pieces explain conflicts',
      () {
    final room = rectangle(21, 8);
    expect(
        () => runPvcCalculation(PvcCalculation(room, 'mix',
            jointRule: const PvcJointRule(mode: PvcJointMode.centre))),
        throwsArgumentError);
    for (final distance in [
      double.nan,
      double.infinity,
      -1.0,
      0.0,
      21.0,
      22.0,
      1.0
    ]) {
      expect(
          () => runPvcCalculation(PvcCalculation(room, 'mix',
              orientation: PvcOrientation.length,
              jointRule: PvcJointRule(
                  mode: PvcJointMode.custom, distanceFt: distance))),
          throwsArgumentError);
    }
    final irregular = buildPvcRoom(PvcShape.l, pvcDefaults(PvcShape.l));
    expect(
        () => runPvcCalculation(PvcCalculation(irregular, 'mix',
            orientation: PvcOrientation.width,
            jointRule: const PvcJointRule(mode: PvcJointMode.centre))),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('shorter'))));
  });
  for (final size in [const Size(280, 600), const Size(740, 360)]) {
    testWidgets('Optional joint selection, side and preview at $size',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const PvcCeilingScreen()));
      Future<void> choose(String key, String text) async {
        final finder = find.byKey(ValueKey(key));
        await t.ensureVisible(finder);
        await t.pumpAndSettle();
        await t.tap(finder);
        await t.pumpAndSettle();
        await t.tap(find.text(text).last);
        await t.pumpAndSettle();
      }

      await choose('pvcJointMode', 'Centre of room');
      expect(find.textContaining('Choose length (A)'), findsOneWidget);
      await choose('pvcOrientation', 'Along length · A direction');
      await t.enterText(find.byType(TextFormField).at(0), '21');
      await t.enterText(find.byType(TextFormField).at(1), '8');
      final calculate = find.widgetWithText(FilledButton, 'Calculate');
      await t.ensureVisible(calculate);
      await t.tap(calculate);
      await t.pump();
      for (var i = 0;
          i < 100 && find.byType(PvcCeilingResults).evaluate().isEmpty;
          i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump();
      }
      await t.pumpAndSettle();
      final plan =
          t.widget<PvcCeilingResults>(find.byType(PvcCeilingResults)).layout!;
      expect(plan.pcs, [10.5, 10.5]);
      expect(find.text('From left: 10.5 ft · From right: 10.5 ft'),
          findsOneWidget);
      await choose('pvcJointMode', 'Custom joint position');
      await choose('pvcJointSide', 'Right side');
      await t.ensureVisible(find.byKey(const ValueKey('pvcJointDistance')));
      await t.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('pvcJointDistance')),
              matching: find.byType(TextFormField)),
          '10');
      await t.pumpAndSettle();
      expect(find.byType(PvcCeilingResults), findsNothing);
      expect(find.text('From left: 11 ft · From right: 10 ft'), findsOneWidget);
      await t.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('pvcJointDistance')),
              matching: find.byType(TextFormField)),
          '11');
      await t.pumpAndSettle();
      expect(find.text('From left: 10 ft · From right: 11 ft'), findsOneWidget);
      expect(t.takeException(), isNull);
      await choose('pvcJointMode', 'Auto · Existing optimization');
      expect(find.byKey(const ValueKey('pvcJointDistance')), findsNothing);
    });
  }
}
