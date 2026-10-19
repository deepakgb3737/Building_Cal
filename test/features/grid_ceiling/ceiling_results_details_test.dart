import 'package:flutter/material.dart';
import 'material_expectations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  for (final dimension in [2000.0, 40000.0]) {
    testWidgets('Area and purchase cards fit a narrow screen at $dimension mm',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = GridCeilingCalculator.calculate(dimension, dimension);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: EnhancedRoomLayoutScreen(
            result: result, width: dimension, length: dimension),
      ));
      await tester.pumpAndSettle();
      final metres = find
          .text('${(dimension * dimension / 1000000).toStringAsFixed(2)} m²');
      expect(metres, findsOneWidget);
      final bounds = tester.getRect(metres);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      await tester.ensureVisible(find.text('Hanger wires'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(320, 640),
    const Size(640, 320),
    const Size(1024, 768),
  ]) {
    for (final mode in PlacementMode.values) {
      testWidgets('$size $mode: simple purchase list keeps details accessible',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final result = GridCeilingCalculator.calculate(4567, 3445, mode: mode);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: EnhancedRoomLayoutScreen(
              result: result, width: 4567, length: 3445),
        ));
        await tester.pumpAndSettle();
        expect(find.text('CEILING AREA'), findsOneWidget);
        expect(find.text('sq ft'), findsOneWidget);
        expect(find.text('${(4567 * 3445 / 1000000).toStringAsFixed(2)} m²'),
            findsOneWidget);
        expect(find.text((4567 * 3445 / 1000000 * 10.7639).toStringAsFixed(2)),
            findsOneWidget);
        expect(tester.getTopLeft(find.text('CEILING AREA')).dy,
            lessThan(tester.getTopLeft(find.text('What to buy')).dy));
        expect(tester.getTopLeft(find.text('What to buy')).dy,
            lessThan(tester.getTopLeft(find.text('3D view')).dy));
        expect(find.byType(ActionChip), findsNothing);
        expect(find.text('Tiles to buy'), findsNothing);
        expect(find.text('CEILING TILES'), findsOneWidget);
        for (final title in ['Full tiles ', 'Total tile positions']) {
          expect(find.text(title), findsNothing);
        }
        final material = find.text('What to buy');
        await tester.ensureVisible(material);
        await tester.pumpAndSettle();
        expectCeilingMaterial('4ft cross Ts', result.optimizedFourFootT);
        expectCeilingMaterial('2ft cross Ts', result.optimizedTwoFootCrossT);
        expect(find.byTooltip('Copy order list'), findsOneWidget);
        if (result.requiresPerimeterJunction) {
          expect(find.textContaining('Edge split quantities assume compatible'),
              findsOneWidget);
        }
        for (final (section, content) in [
          ('Tile breakdown', 'Total tile positions'),
          ('Measurements', 'Along width'),
          (
            'Runner cutting',
            'Runners sit end to end. Only the last piece is cut.'
          ),
          ('Installation steps', 'All values are in millimeters (mm).'),
        ]) {
          await tester.ensureVisible(find.text(section));
          if (find.text(content).evaluate().isEmpty) {
            await tester.tap(find.text(section));
            await tester.pumpAndSettle();
          }
          expect(find.text(content), findsOneWidget);
          await tester.ensureVisible(find.text(content));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        // Rebuilding the drawing and rotating must not reopen/reset details.
        await tester.ensureVisible(find.text('Tile breakdown'));
        await tester.tap(find.text('Tile breakdown'));
        await tester.pumpAndSettle();
        expect(find.text('Total tile positions'), findsNothing);
        await tester.ensureVisible(find.text('2D plan'));
        await tester.tap(find.text('2D plan'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pumpAndSettle();
        expect(find.text('Total tile positions'), findsNothing);
        expect(find.text('Along width'), findsOneWidget);
        expect(find.text('Runners sit end to end. Only the last piece is cut.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
