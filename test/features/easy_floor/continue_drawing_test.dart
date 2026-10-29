import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_angles.dart';

Future<void> draw(WidgetTester t, Offset from, Offset to) async {
  final origin = t.getTopLeft(board.canvas);
  final gesture = await t.startGesture(origin + from);
  await gesture.moveTo(origin + to);
  await t.pump();
  await gesture.up();
  await t.pumpAndSettle();
  await board.keepSketch(t);
}

void main() {
  testWidgets('An accepted multi-corner sketch can continue from its final end',
      (t) async {
    await board.open(t, showLabels: false);
    await board.collapseTools(t);
    final origin = t.getTopLeft(board.canvas);
    final stroke = await t.startGesture(origin + const Offset(60, 110));
    await stroke.moveTo(origin + const Offset(220, 110));
    await t.pump();
    await stroke.moveTo(origin + const Offset(220, 260));
    await t.pump();
    await stroke.up();
    await t.pumpAndSettle();
    await board.keepSketch(t);
    expect(board.painter(t).model.walls, hasLength(2));
    await board.collapseTools(t);
    await draw(t, const Offset(220, 260), const Offset(60, 262));
    expect(board.painter(t).model.walls, hasLength(3));
    expect(board.painter(t).model.corners, hasLength(4));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Tap first still reshapes an open endpoint instead of adding a wall',
      (t) async {
    await board.open(t, showLabels: false);
    await board.collapseTools(t);
    await draw(t, const Offset(60, 110), const Offset(220, 110));
    final origin = t.getTopLeft(board.canvas);
    await t.tapAt(origin + const Offset(220, 110));
    await t.pumpAndSettle();
    await draw(t, const Offset(220, 110), const Offset(225, 250));
    expect(board.painter(t).model.walls, hasLength(1));
    expect(board.painter(t).model.corners, hasLength(2));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Second finger cancels continuation without creating a stray wall',
      (t) async {
    await board.open(t, showLabels: false);
    await board.collapseTools(t);
    await draw(t, const Offset(60, 110), const Offset(220, 110));
    final before = board.painter(t).model.toJson();
    final origin = t.getTopLeft(board.canvas);
    final stroke = await t.startGesture(origin + const Offset(220, 110));
    await stroke.moveTo(origin + const Offset(223, 260));
    await t.pump();
    final second =
        await t.startGesture(origin + const Offset(70, 320), pointer: 2);
    await t.pump();
    await stroke.moveBy(const Offset(20, 15));
    await second.moveBy(const Offset(20, 15));
    await t.pump();
    await second.up();
    await stroke.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), before);
    expect(board.painter(t).preview, isEmpty);
    expect(t.takeException(), isNull);
  });

  for (final tool in ['Draw', 'Wall']) {
    testWidgets('$tool continues from a shared junction after Undo and Redo',
        (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, tool);
      await board.collapseTools(t);
      await draw(t, const Offset(60, 240), const Offset(260, 240));
      await draw(t, const Offset(160, 100), const Offset(160, 240));
      final before = board.painter(t).model.copy();
      expect(before.walls, hasLength(3));
      await draw(t, const Offset(160, 240), const Offset(162, 365));
      await board.expandTools(t);
      for (final action in ['Undo', 'Redo', 'Undo']) {
        await t.tap(find.byTooltip(action));
        await t.pumpAndSettle();
      }
      expect(board.painter(t).model.toJson(), before.toJson());
      await board.collapseTools(t);
      await draw(t, const Offset(160, 240), const Offset(162, 355));
      final after = board.painter(t).model;
      expect(after.walls, hasLength(4));
      for (final entry in before.corners.entries) {
        expect(
            (after.corners[entry.key]! - entry.value).length, closeTo(0, .001));
      }
      final junction = before.corners.keys.firstWhere((id) =>
          before.walls.values
              .where((wall) => wall.start == id || wall.end == id)
              .length ==
          3);
      expect(
          after.walls.values
              .where((wall) => wall.start == junction || wall.end == junction),
          hasLength(4));
      expect(t.takeException(), isNull);
    });
    testWidgets(
        '$tool continues an open endpoint with exact 90 degree assistance',
        (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, tool);
      await board.collapseTools(t);
      await draw(t, const Offset(60, 110), const Offset(220, 110));
      final first = board.painter(t).model.copy();
      final origin = t.getTopLeft(board.canvas);
      final next = await t.startGesture(origin + const Offset(220, 110));
      await next.moveTo(origin + const Offset(223, 265));
      await t.pump();
      final preview = board.painter(t).preview;
      expect(preview, hasLength(2));
      expect(preview.last.x, closeTo(preview.first.x, 1e-8));
      await next.up();
      await t.pumpAndSettle();
      await board.keepSketch(t);
      await draw(t, const Offset(220, 265), const Offset(65, 267));
      final m = board.painter(t).model;
      expect(m.walls, hasLength(3));
      expect(m.corners, hasLength(4));
      for (final wall in first.walls.values) {
        expect(m.corners[wall.start], first.corners[wall.start]);
        expect(m.corners[wall.end], first.corners[wall.end]);
      }
      final angles = contextualAngles(m,
          corner: m.nearestCorner(
              first.corners[first.walls.values.first.end]!, .001));
      expect(angles.where((a) => (a.degrees - 90).abs() < 1e-6), isNotEmpty);
      expect(t.takeException(), isNull);
    });
    testWidgets(
        '$tool continues through a newly connected T junction and undoes once',
        (t) async {
      await board.open(t, showLabels: false);
      await board.tool(t, tool);
      await board.collapseTools(t);
      await draw(t, const Offset(60, 240), const Offset(260, 240));
      await draw(t, const Offset(160, 100), const Offset(160, 240));
      expect(board.painter(t).model.walls, hasLength(3));
      final before = board.painter(t).model.toJson();
      await draw(t, const Offset(160, 240), const Offset(162, 365));
      expect(board.painter(t).model.walls, hasLength(4));
      await board.expandTools(t);
      await t.tap(find.byTooltip('Undo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.toJson(), before);
      await t.tap(find.byTooltip('Redo'));
      await t.pumpAndSettle();
      expect(board.painter(t).model.walls, hasLength(4));
      expect(t.takeException(), isNull);
    });
  }
}
