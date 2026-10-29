import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;

void main() {
  testWidgets(
      'Selected freehand wall still moves near its tip and cancels safely',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Draw');
    await board.collapseTools(t);
    await wall(t, const Offset(100, 150), const Offset(200, 150));
    await board.keepSketch(t);
    await board.collapseTools(t);
    final origin = t.getTopLeft(board.canvas);
    await t.tapAt(origin + const Offset(150, 150));
    await t.pumpAndSettle();
    final before = board.painter(t);
    final model = before.model.copy();
    final first = model.walls.values.single;
    final drag = await t.startGesture(origin + const Offset(192, 150));
    await drag.moveTo(origin + const Offset(192, 250));
    await t.pump();
    final live = board.painter(t);
    expect(live.preview, isEmpty);
    expect(live.model.walls, hasLength(1));
    for (final id in [first.start, first.end]) {
      final delta = live.model.corners[id]! - model.corners[id]!;
      expect(delta.x, closeTo(0, .001));
      expect(delta.y, closeTo(100 / before.scale, .001));
    }
    await drag.cancel();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), model.toJson());
    expect(t.takeException(), isNull);
  });
  for (final tool in ['Wall', 'Draw']) {
    for (final direction in [const Offset(1, 0), const Offset(0, 1)]) {
      for (final side in [-1, 1]) {
        testWidgets(
            '$tool imprecise tip starts connected right angle $direction/$side',
            (t) async {
          await board.open(t, showLabels: true);
          await board.tool(t, tool);
          await board.collapseTools(t);
          const start = Offset(100, 150);
          final tip = start + direction * 100;
          final normal = Offset(-direction.dy, direction.dx) * side.toDouble();
          await wall(t, start, tip);
          await board.keepSketch(t);
          await board.collapseTools(t);
          final before = board.painter(t).model.copy();
          final first = before.walls.values.single;
          final press = tip - direction * 8;
          final origin = t.getTopLeft(board.canvas);
          final gesture = await t.startGesture(origin + press);
          await gesture.moveTo(origin + tip + normal * 100);
          await t.pump();
          final preview = board.painter(t).preview;
          expect(preview, hasLength(2));
          expect((preview.first - before.corners[first.end]!).length,
              closeTo(0, .001));
          final original =
              before.corners[first.end]! - before.corners[first.start]!;
          expect(original.dot(preview.last - preview.first), closeTo(0, .001));
          await gesture.up();
          await t.pumpAndSettle();
          await board.keepSketch(t);
          final after = board.painter(t).model;
          expect(after.walls, hasLength(2));
          expect(after.walls.values.last.start, first.end);
          for (final id in [first.start, first.end]) {
            expect((after.corners[id]! - before.corners[id]!).length,
                closeTo(0, .001));
          }
          final completed = after.toJson();
          await board.expandTools(t);
          await t.tap(find.byTooltip('Undo'));
          await t.pumpAndSettle();
          expect(board.painter(t).model.toJson(), before.toJson());
          await t.tap(find.byTooltip('Redo'));
          await t.pumpAndSettle();
          expect(board.painter(t).model.toJson(), completed);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
  for (final labels in [false, true]) {
    for (final start in [
      const Offset(180, 180),
      const Offset(172, 180),
      const Offset(188, 180),
      const Offset(180, 188)
    ]) {
      testWidgets('Single wall extends after lift from $start, labels=$labels',
          (t) async {
        await board.open(t, showLabels: labels);
        await board.tool(t, 'Wall');
        await board.collapseTools(t);
        await wall(t, const Offset(80, 180), const Offset(180, 180));
        final before = board.painter(t),
            first = before.model.walls.values.single;
        final anchor = before.model.corners[first.start]!;
        await wall(t, start, const Offset(260, 180));
        final after = board.painter(t);
        expect((after.model.corners[first.start]! - anchor).length,
            closeTo(0, 1e-8));
        final wanted = DrawingPoint((260 - before.origin.dx) / before.scale,
            (180 - before.origin.dy) / before.scale);
        expect(after.model.nearestCorner(wanted, .001), isNotNull);
        expect(after.model.corners, hasLength(3));
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final direction in [const Offset(0, 1), const Offset(.8, .6)]) {
    testWidgets('Near-tip continuation preserves direction $direction',
        (t) async {
      await board.open(t, showLabels: true);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      const start = Offset(80, 100);
      final tip = start + direction * 100;
      final end = tip + direction * 80;
      await wall(t, start, tip);
      final before = board.painter(t);
      final first = before.model.walls.values.single;
      final originalStart = before.model.corners[first.start]!;
      final originalEnd = before.model.corners[first.end]!;
      await wall(t, tip - direction * 8, end);
      final after = board.painter(t);
      expect((after.model.corners[first.start]! - originalStart).length,
          closeTo(0, 1e-8));
      expect((after.model.corners[first.end]! - originalEnd).length,
          closeTo(0, 1e-8));
      expect(after.model.walls, hasLength(2));
      final next = after.model.walls.values.last;
      expect(next.start, first.end);
      expect((after.screen(after.model.corners[next.end]!) - end).distance,
          closeTo(0, .001));
      expect(t.takeException(), isNull);
    });
  }
}
