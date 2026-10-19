import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/l_shape/l_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/l_shape/l_ceiling_room.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/grid_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_inputs.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_results.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_drawing.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';

Future<void> enter(WidgetTester t, int index, String value) async {
  final fields = find.byType(TextFormField);
  await t.ensureVisible(fields.at(index));
  await t.enterText(fields.at(index), value);
  await t.pump();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final mode in PlacementMode.values) {
      testWidgets(
          '$size $mode: same calculator builds an L, copies and navigates',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: const GridCeilingCalculatorScreen()));
        expect(find.byType(LCeilingInputs), findsNothing);
        await enter(t, 0, '3600');
        await enter(t, 1, '3000');
        await tapText(t, 'L-shape');
        expect(
            t
                .widget<AppNumberField>(find.byType(AppNumberField).first)
                .controller
                .text,
            '3600');
        expect(find.byType(LCeilingInputs), findsOneWidget);
        await enter(t, 2, '1800');
        await enter(t, 3, '1200');
        await tapText(
            t, mode == PlacementMode.oneSide ? 'From one wall' : 'Centered');
        await tapText(t, 'Calculate layout');
        expect(find.byType(EnhancedRoomLayoutScreen), findsNothing);
        final ui = t.widget<LCeilingResults>(find.byType(LCeilingResults));
        final expected = LCeilingCalculator.calculate(
            LCeilingRoom(
                widthMm: 3600,
                lengthMm: 3000,
                verticalArmWidthMm: 1800,
                horizontalArmDepthMm: 1200),
            mode: mode);
        expect(ui.result.tilesToBuy, expected.tilesToBuy);
        expect(ui.result.fourFootPieces, expected.fourFootPieces);
        expect(ui.result.twoFootPieces, expected.twoFootPieces);
        expect(find.text('7.56 m²'), findsOneWidget);
        expect(t.getTopLeft(find.text('What to buy')).dy,
            lessThan(t.getTopLeft(find.text('3D view')).dy));
        String? copied;
        t.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(() => t.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null));
        await tapText(t, 'Copy list');
        expect(
            copied, contains('4ft cross Ts: ${expected.fourFootPieces} pcs'));
        await tapText(t, '2D plan');
        final viewer = find.byKey(const ValueKey('l-ceiling-2d'));
        await t.ensureVisible(viewer);
        await t.drag(viewer, const Offset(25, 10));
        await t.pumpAndSettle();
        final center = t.getCenter(viewer);
        final a =
            await t.startGesture(center - const Offset(20, 0), pointer: 1);
        final b =
            await t.startGesture(center + const Offset(20, 0), pointer: 2);
        await a.moveBy(const Offset(-20, 0));
        await b.moveBy(const Offset(20, 0));
        await a.up();
        await b.up();
        await t.pumpAndSettle();
        expect(
            identical(
                t.widget<LCeilingResults>(find.byType(LCeilingResults)).result,
                ui.result),
            isTrue);
        await tapText(t, '3D view');
        final threeD = find.byKey(const ValueKey('l-ceiling-3d'));
        await t.ensureVisible(threeD);
        await t.drag(threeD, const Offset(70, 25));
        await t.pumpAndSettle();
        final painter = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<LCeilingPlanPainter>()
            .single;
        expect(painter.yaw, isNot(.6));
        await t.ensureVisible(find.text('Measurement labels'));
        await t.tap(find.byType(Switch));
        await t.pumpAndSettle();
        expect(
            t
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .map((w) => w.painter)
                .whereType<LCeilingPlanPainter>()
                .single
                .showMeasurements,
            isFalse);
        expect(t.takeException(), isNull);
        await enter(t, 2, '1700');
        expect(find.byType(LCeilingResults), findsNothing);
        await tapText(t, 'Rectangle');
        expect(find.byType(LCeilingInputs), findsNothing);
        await tapText(t, 'L-shape');
        expect(
            t
                .widget<AppNumberField>(find.byType(AppNumberField).at(2))
                .controller
                .text,
            '1700');
        await tapText(t, 'Reset');
        expect(find.byType(LCeilingInputs), findsNothing);
        expect(
            t
                .widget<AppNumberField>(find.byType(AppNumberField).first)
                .controller
                .text,
            isEmpty);
        expect(t.takeException(), isNull);
      }, skip: !GridCeilingCalculatorScreen.lShapeEnabled);
    }
  }

  testWidgets('Invalid arms block results and current preview is never stale',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: const GridCeilingCalculatorScreen()));
    await tapText(t, 'L-shape');
    await enter(t, 0, '3600');
    await enter(t, 1, '3000');
    await enter(t, 2, '3600');
    await enter(t, 3, '3000');
    await tapText(t, 'Calculate layout');
    expect(find.byType(LCeilingResults), findsNothing);
    expect(find.text('Must be greater than 0 and smaller than overall width'),
        findsOneWidget);
    expect(find.text('Must be greater than 0 and smaller than overall length'),
        findsOneWidget);
    expect(find.text('Preview uses your dimensions.'), findsNothing);
    await enter(t, 2, '1800');
    await enter(t, 3, '1200');
    expect(find.text('Preview uses your dimensions.'), findsOneWidget);
    await tapText(t, 'Calculate layout');
    for (final (label, corner) in [
      ('Top left', MissingCorner.topLeft),
      ('Bottom left', MissingCorner.bottomLeft),
      ('Bottom right', MissingCorner.bottomRight),
      ('Top right', MissingCorner.topRight),
    ]) {
      final dropdown = find.byType(DropdownButtonFormField<MissingCorner>);
      await t.ensureVisible(dropdown);
      await t.tap(dropdown);
      await t.pumpAndSettle();
      await t.tap(find.text(label).last);
      await t.pumpAndSettle();
      expect(find.byType(LCeilingResults), findsNothing);
      final preview = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<LCeilingGuidePainter>()
          .single;
      expect(preview.room.missingCorner, corner);
      await tapText(t, 'Calculate layout');
      expect(
          t
              .widget<LCeilingResults>(find.byType(LCeilingResults))
              .result
              .room
              .missingCorner,
          corner);
    }
    expect(t.takeException(), isNull);
  }, skip: !GridCeilingCalculatorScreen.lShapeEnabled);

  test(
      'Both drawings project exactly one line for every returned backend section',
      () {
    for (final corner in MissingCorner.values) {
      final r = LCeilingCalculator.calculate(LCeilingRoom(
          widthMm: 4567,
          lengthMm: 3445,
          verticalArmWidthMm: 1650,
          horizontalArmDepthMm: 1400,
          missingCorner: corner));
      for (final threeD in [false, true]) {
        final painter =
            LCeilingPlanPainter(r, AppTheme.light.colorScheme, threeD: threeD);
        final projected = painter.projectedSections(const Size(320, 340));
        expect(projected.length, r.sections.length);
        for (var i = 0; i < projected.length; i++) {
          expect(projected[i].stock, r.sections[i].stock);
          expect(projected[i].start.dx.isFinite, isTrue);
          expect(projected[i].end.dy.isFinite, isTrue);
          expect(projected[i].start, isNot(projected[i].end));
        }
        expect((Canvas c) => painter.paint(c, const Size(320, 340)),
            paints..path());
      }
    }
  });
}
