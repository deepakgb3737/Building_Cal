import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  test('Both requested directions retain polygon coverage and cut demand', () {
    for (final shape in PvcShape.values) {
      final room = buildPvcRoom(shape, pvcDefaults(shape));
      final plans = [
        for (final orientation in [PvcOrientation.length, PvcOrientation.width])
          runPvcCalculation(
              PvcCalculation(room, 'mix', orientation: orientation))!
      ];
      expect(plans[0].turned, isFalse);
      expect(plans[1].turned, isTrue);
      for (final plan in plans) {
        expect(plan.area, room.area);
        final demand = <double, int>{};
        var joints = 0;
        for (final row in plan.layoutRows) {
          for (final segment in row.segments) {
            expect(segment.pieces.reduce((a, b) => a + b),
                closeTo(segment.x1 - segment.x0, .01));
            joints += segment.pieces.length - 1;
            for (final piece in segment.pieces) {
              demand[piece] = (demand[piece] ?? 0) + 1;
            }
          }
          for (final iv
              in scanPvcPolygon(plan.polygon, (row.y0 + row.y1) / 2)) {
            expect(
                row.segments
                    .any((s) => s.x0 <= iv.$1 + kEps && s.x1 >= iv.$2 - kEps),
                isTrue);
          }
        }
        expect(plan.joints, joints);
        for (var i = 0; i < plan.sizes.length; i++) {
          expect(plan.plan.fold<int>(0, (s, p) => s + p.counts[i]),
              demand[plan.sizes[i]]);
        }
      }
      final auto = runPvcCalculation(PvcCalculation(room, 'mix'))!;
      plans.sort((a, b) {
        final joints = a.joints.compareTo(b.joints);
        return joints != 0 ? joints : a.total.compareTo(b.total);
      });
      expect(auto.joints, plans.first.joints);
      expect(auto.total, plans.first.total);
    }
  });

  test('Forced invalid direction does not silently use the other direction',
      () {
    final room = buildPvcRoom(PvcShape.rectangle, {'A': '10', 'B': '0.5'});
    expect(
        runPvcCalculation(
            PvcCalculation(room, 'mix', orientation: PvcOrientation.length)),
        isNull);
    expect(
        runPvcCalculation(
            PvcCalculation(room, 'mix', orientation: PvcOrientation.width)),
        isNull);
  });

  for (final size in [const Size(280, 600), const Size(740, 360)]) {
    testWidgets('Direction change recalculates and preserves inputs at $size',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const PvcCeilingScreen()));
      Future<Layout> result() async {
        await t.pump();
        for (var i = 0;
            i < 100 && find.byType(PvcCeilingResults).evaluate().isEmpty;
            i++) {
          await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          await t.pump();
        }
        await t.pumpAndSettle();
        return t
            .widget<PvcCeilingResults>(find.byType(PvcCeilingResults))
            .layout!;
      }

      final calculate = find.widgetWithText(FilledButton, 'Calculate');
      await t.ensureVisible(calculate);
      await t.tap(calculate);
      expect((await result()).turned, isTrue);
      for (final option in [
        ('Along length · A direction', false),
        ('Across width · B direction', true),
        ('Auto · Best layout', true),
      ]) {
        final dropdown = find.byKey(const ValueKey('pvcOrientation'));
        await t.ensureVisible(dropdown);
        await t.pumpAndSettle();
        await t.tap(dropdown);
        await t.pumpAndSettle();
        await t.tap(find.text(option.$1).last);
        expect((await result()).turned, option.$2);
        expect(
            t
                .widget<TextFormField>(find.byType(TextFormField).first)
                .controller!
                .text,
            '14.5');
        expect(t.takeException(), isNull);
      }
    });
  }
}
