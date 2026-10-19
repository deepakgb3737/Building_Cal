import 'package:flutter/material.dart';
import 'material_expectations.dart';
import 'package:flutter/services.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/ceiling_label_placement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/core/theme/build_calc_colors.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/cross_t_spans.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  testWidgets('3D stock labels remain visible with measurement labels off',
      (t) async {
    final r = GridCeilingCalculator.calculate(4567, 3445,
        mode: PlacementMode.oneSide);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: EnhancedRoomLayoutScreen(result: r, width: 4567, length: 3445)));
    await t.pumpAndSettle();
    final toggle = find.byType(Switch);
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    final painter = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .singleWhere(
                (p) => p.runtimeType.toString() == '_IsometricCeilingPainter')
        as dynamic;
    expect(painter.showMeasurements, isFalse);
    for (final size in [const Size(320, 240), const Size(740, 360)]) {
      expect(
          (Canvas canvas) => painter.paint(canvas, size), paints..paragraph());
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('Screenshot perimeter colors, counts and junction notice agree',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final r = GridCeilingCalculator.calculate(4567, 3445,
        mode: PlacementMode.oneSide);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: EnhancedRoomLayoutScreen(result: r, width: 4567, length: 3445)));
    await t.pumpAndSettle();
    expectCeilingMaterial('4ft cross Ts', 15);
    expectCeilingMaterial('2ft cross Ts', 34);
    expect(find.textContaining('Edge split quantities assume compatible'),
        findsOneWidget);
    final painter = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .singleWhere(
                (p) => p.runtimeType.toString() == '_IsometricCeilingPainter')
        as dynamic;
    expect(identical(painter.crossSpans, r.crossTSpans), isTrue);
    String? copied;
    final messenger = t.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.ensureVisible(find.byTooltip('Copy order list'));
    await t.tap(find.byTooltip('Copy order list'));
    await t.pumpAndSettle();
    expect(copied, contains('4ft cross Ts: 15 pcs'));
    expect(copied, contains('2ft cross Ts: 34 pcs'));
    expect(
        copied, contains('Confirm with your grid supplier before ordering.'));
    await t.ensureVisible(find.text('2D plan'));
    await t.tap(find.text('2D plan'));
    await t.pumpAndSettle();
    for (var row = 0; row < 5; row++) {
      for (final (index, mm) in [(3, 600), (4, 367)]) {
        final piece = find.byKey(ValueKey('crossT-$row-$index-2ft'));
        final line =
            find.descendant(of: piece, matching: find.byType(Container)).first;
        expect(t.widget<Container>(line).color, BuildCalcColors.chartTertiary);
        expect(t.getSize(line).width, closeTo(mm / 10, .001));
      }
    }
    expect(t.takeException(), isNull);
  });
  test('Screenshot: 967 mm perimeter becomes 600 + 367, not one short T', () {
    final r = GridCeilingCalculator.calculate(4567, 3445,
        mode: PlacementMode.oneSide);
    expect(r.crossTSpans, [
      (startMm: 0.0, endMm: 1200.0, usesTwoFoot: false),
      (startMm: 1200.0, endMm: 2400.0, usesTwoFoot: false),
      (startMm: 2400.0, endMm: 3600.0, usesTwoFoot: false),
      (startMm: 3600.0, endMm: 4200.0, usesTwoFoot: true),
      (startMm: 4200.0, endMm: 4567.0, usesTwoFoot: true),
    ]);
    expect(r.numFourFootT, 20);
    expect(r.optimizedFourFootT, 15);
    expect(r.savedFourFootT, 5);
    expect(r.numTwoFootCrossT, 24);
    expect(r.optimizedTwoFootCrossT, 34);
    expect(r.requiresPerimeterJunction, isTrue);
    expect(() => r.crossTSpans.clear(), throwsUnsupportedError);
  });
  test('A missing or misplaced divider must not create an invented junction',
      () {
    for (final dividers in [
      <double>[],
      [3900.0],
      [4567.0]
    ]) {
      final spans = crossTSpans(
          roomWidthMm: 4567,
          mainPositionsMm: [1200, 2400, 3600],
          twoFootPositionsMm: dividers);
      expect(spans.last, (startMm: 3600.0, endMm: 4567.0, usesTwoFoot: false));
    }
  });
  test('Left cut bay can split, but internal and full 1200 mm bays stay intact',
      () {
    final spans = crossTSpans(
        roomWidthMm: 3300,
        mainPositionsMm: [900, 2100],
        twoFootPositionsMm: [300, 1500, 2700]);
    expect(spans, [
      (startMm: 0.0, endMm: 300.0, usesTwoFoot: true),
      (startMm: 300.0, endMm: 900.0, usesTwoFoot: true),
      (startMm: 900.0, endMm: 2100.0, usesTwoFoot: false),
      (startMm: 2100.0, endMm: 3300.0, usesTwoFoot: false),
    ]);
  });
  test('Top and bottom border pieces remain included as 2ft Ts', () {
    final r = GridCeilingCalculator.calculate(4567, 3445,
        mode: PlacementMode.oneSide);
    expect(r.twoFootCrossT, [600, 1800, 3000, 4200]);
    expect(r.crossTLength, [600, 1200, 1800, 2400, 3000]);
    expect(3445 - r.crossTLength.last, 445);
    expect(r.numTwoFootCrossT, 4 * 6);
  });
  for (final mode in PlacementMode.values) {
    for (final width in [2438.0, 2690.0, 2999.0, 3000.0, 3001.0, 3600.0]) {
      test('$mode width $width: drawing pieces match optimized quantities', () {
        final result = GridCeilingCalculator.calculate(width, 3200, mode: mode);
        final spans = result.crossTSpans;
        final short = spans.where((s) => s.usesTwoFoot).length;
        final rows = result.crossTLength.length;
        expect(result.numFourFootT - (spans.length - short) * rows,
            result.savedFourFootT);
        expect((spans.length - short) * rows, result.optimizedFourFootT);
        expect(result.numTwoFootCrossT + short * rows,
            result.optimizedTwoFootCrossT);
        expect(spans.first.startMm, 0);
        expect(spans.last.endMm, width);
        for (var i = 0; i < spans.length; i++) {
          if (spans[i].usesTwoFoot) {
            expect(spans[i].endMm - spans[i].startMm, lessThanOrEqualTo(600));
          }
          if (i > 0) expect(spans[i].startMm, spans[i - 1].endMm);
        }
      });
    }
  }
  for (final edge in [599.0, 600.0, 601.0]) {
    test('One-side edge $edge mm uses the correct stock', () {
      final r = GridCeilingCalculator.calculate(2400 + edge, 3200,
          mode: PlacementMode.oneSide);
      expect(r.edgeUsesTwoFootRight, isTrue);
      expect(r.savedFourFootT, 5);
      expect(r.crossTSpans.where((s) => s.usesTwoFoot).length,
          edge <= 600 ? 1 : 2);
    });
  }
  for (final mode in PlacementMode.values) {
    testWidgets(
        '$mode: material totals and colored 2D/3D pieces stay consistent',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = GridCeilingCalculator.calculate(2690, 3200, mode: mode);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home:
              EnhancedRoomLayoutScreen(result: r, width: 2690, length: 3200)));
      await t.pumpAndSettle();
      expect(r.optimizedFourFootT, mode == PlacementMode.oneSide ? 10 : 5);
      expect(r.optimizedTwoFootCrossT, mode == PlacementMode.oneSide ? 17 : 27);
      expectCeilingMaterial('4ft cross Ts', r.optimizedFourFootT);
      expectCeilingMaterial('2ft cross Ts', r.optimizedTwoFootCrossT);
      expect(find.text('Cross T · 2ft'), findsOneWidget);
      expect(find.text('Cross T · 4ft'), findsOneWidget);
      final painter = t
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((p) => p.painter)
              .singleWhere(
                  (p) => p.runtimeType.toString() == '_IsometricCeilingPainter')
          as dynamic;
      expect(identical(painter.crossSpans, r.crossTSpans), isTrue);
      expect(painter.palette.shortRunner, BuildCalcColors.chartTertiary);
      expect(painter.palette.crossRunner, BuildCalcColors.chartSecondary);
      await t.ensureVisible(find.text('2D plan'));
      await t.tap(find.text('2D plan'));
      await t.pumpAndSettle();
      for (var row = 0; row < 5; row++) {
        for (var span = 0; span < r.crossTSpans.length; span++) {
          final short = r.crossTSpans[span].usesTwoFoot;
          final piece = find
              .byKey(ValueKey('crossT-$row-$span-${short ? '2ft' : '4ft'}'));
          expect(piece, findsOneWidget);
          final line = t.widget<Container>(find
              .descendant(of: piece, matching: find.byType(Container))
              .first);
          expect(
              line.color,
              short
                  ? BuildCalcColors.chartTertiary
                  : BuildCalcColors.chartSecondary);
        }
      }
      expect(find.text('2f'), findsWidgets);
      expect(find.text('4f'), findsWidgets);
      expect(find.text('10f'), findsWidgets);
      for (var s = 0; s < r.crossTSpans.length; s++) {
        final row =
            r.crossTSpans[s].usesTwoFoot ? 0 : r.crossTLength.length ~/ 2;
        final text = find.descendant(
            of: find.byKey(ValueKey('crossType-$row-$s')),
            matching: find.byType(Text));
        if (!ceilingStockLabelSpans(r.crossTSpans).contains(s)) {
          expect(text, findsNothing);
          continue;
        }
        final label = t.widget<Text>(text);
        if (!r.crossTSpans[s].usesTwoFoot && row > 0) {
          expect(find.byKey(ValueKey('crossType-0-$s')), findsNothing);
        }
        expect(label.data, r.crossTSpans[s].usesTwoFoot ? '2f' : '4f');
        expect(
            label.style!.color,
            r.crossTSpans[s].usesTwoFoot
                ? BuildCalcColors.chartTertiary
                : BuildCalcColors.chartSecondary);
      }
      expect(t.takeException(), isNull);
    });
  }
}
