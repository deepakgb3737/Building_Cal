import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/grid_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_inputs.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/l_shape/l_ceiling_results.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  testWidgets('Default build hides all L-shape UI and calculates rectangles',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: const GridCeilingCalculatorScreen()));
    expect(GridCeilingCalculatorScreen.lShapeEnabled, isFalse);
    expect(find.text('L-shape'), findsNothing);
    expect(find.text('Rectangle'), findsNothing);
    expect(find.byType(LCeilingInputs), findsNothing);
    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await t.enterText(find.byType(TextFormField).first, '3600');
    await t.enterText(find.byType(TextFormField).last, '3000');
    await t.ensureVisible(find.text('Calculate layout'));
    await t.tap(find.text('Calculate layout'));
    await t.pumpAndSettle();
    expect(find.byType(EnhancedRoomLayoutScreen), findsOneWidget);
    expect(find.byType(LCeilingResults), findsNothing);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Reset'));
    await t.tap(find.text('Reset'));
    await t.pumpAndSettle();
    expect(find.text('L-shape'), findsNothing);
    expect(find.byType(EnhancedRoomLayoutScreen), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  }, skip: GridCeilingCalculatorScreen.lShapeEnabled);
}
