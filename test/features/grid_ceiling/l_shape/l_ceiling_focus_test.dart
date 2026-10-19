import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/l_shape/l_ceiling_room.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/grid_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_inputs.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_results.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';

LCeilingGuidePainter guide(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<LCeilingGuidePainter>()
    .single;
Future<void> focus(WidgetTester t, int i) async {
  final field = find.byType(TextFormField).at(i);
  await t.ensureVisible(field);
  await t.tap(field);
  await t.pumpAndSettle();
}

void main() {
  for (final corner in MissingCorner.values) {
    testWidgets('$corner: A/B/C/D focus highlights the correct mirrored edge',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
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
      await t.tap(find.text('L-shape'));
      await t.pumpAndSettle();
      final dropdown = find.byType(DropdownButtonFormField<MissingCorner>);
      await t.ensureVisible(dropdown);
      await t.tap(dropdown);
      await t.pumpAndSettle();
      final name = switch (corner) {
        MissingCorner.topLeft => 'Top left',
        MissingCorner.topRight => 'Top right',
        MissingCorner.bottomLeft => 'Bottom left',
        MissingCorner.bottomRight => 'Bottom right',
      };
      await t.tap(find.text(name).last);
      await t.pumpAndSettle();
      // Focus assistance works before any valid room has been entered.
      await focus(t, 0);
      expect(guide(t).activeDimension, 'A');
      expect(guide(t).highlightedEdge, isNotNull);
      expect(find.text('Preview uses your dimensions.'), findsNothing);
      for (var i = 0; i < 4; i++) {
        final field = find.byType(TextFormField).at(i);
        await t.ensureVisible(field);
        await t.enterText(field, ['3600', '3000', '1800', '1200'][i]);
      }
      await t.pumpAndSettle();
      final room = guide(t).room;
      final edges = <(CeilingPoint, CeilingPoint)>[
        ((x: 0.0, y: 3000.0), (x: 3600.0, y: 3000.0)),
        ((x: 0.0, y: 0.0), (x: 0.0, y: 3000.0)),
        ((x: 0.0, y: 0.0), (x: 1800.0, y: 0.0)),
        ((x: 3600.0, y: 1800.0), (x: 3600.0, y: 3000.0)),
      ];
      for (var i = 0; i < 4; i++) {
        await focus(t, i);
        final painter = guide(t);
        expect(painter.activeDimension, 'ABCD'[i]);
        expect(painter.highlightedEdge,
            (room.toWorld(edges[i].$1), room.toWorld(edges[i].$2)));
        final hint =
            t.widget<Text>(find.byKey(const ValueKey('l-active-dimension')));
        expect(hint.data, startsWith('${'ABCD'[i]} · '));
        expect((Canvas canvas) => painter.paint(canvas, const Size(288, 180)),
            paints..line(strokeWidth: 5));
      }
      // Editing C updates its highlight endpoints immediately, not an old preview.
      await focus(t, 2);
      await t.enterText(find.byType(TextFormField).at(2), '1700');
      await t.pumpAndSettle();
      expect(guide(t).activeDimension, 'C');
      expect(guide(t).room.verticalArmWidthMm, 1700);
      expect(guide(t).highlightedEdge, (
        guide(t).room.toWorld((x: 0.0, y: 0.0)),
        guide(t).room.toWorld((x: 1700.0, y: 0.0))
      ));
      final cFocus = t
          .widget<AppNumberField>(find.byType(AppNumberField).at(2))
          .focusNode!;
      t.view.viewInsets = const FakeViewPadding(bottom: 180);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(640, 320);
      await t.pumpAndSettle();
      expect(cFocus.hasFocus, isTrue);
      expect(guide(t).activeDimension, 'C');
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Calculate layout'));
      await t.tap(find.text('Calculate layout'));
      await t.pumpAndSettle();
      expect(guide(t).activeDimension, isNull);
      expect(find.byKey(const ValueKey('l-active-dimension')), findsNothing);
      final result =
          t.widget<LCeilingResults>(find.byType(LCeilingResults)).result;
      expect(result.room.verticalArmWidthMm, 1700);
      expect(result.room.missingCorner, corner);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    }, skip: !GridCeilingCalculatorScreen.lShapeEnabled);
  }
}
