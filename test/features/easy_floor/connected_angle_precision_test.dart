import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_precision.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_angles.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;

DrawingPoint ray(DrawingPoint anchor, double degrees, double length) =>
    anchor +
    DrawingPoint(math.cos(degrees * math.pi / 180),
            math.sin(degrees * math.pi / 180)) *
        length;
void main() {
  testWidgets(
      'Long visible continuation shows and commits an exact right angle',
      (t) async {
    await board.open(t, showLabels: false);
    await board.collapseTools(t);
    await wall(t, const Offset(60, 100), const Offset(110, 100));
    final origin = t.getTopLeft(board.canvas);
    final stroke = await t.startGesture(origin + const Offset(110, 100));
    await stroke.moveTo(origin + const Offset(120, 580));
    await t.pump();
    final view = board.painter(t);
    expect(view.preview.last.x, closeTo(view.preview.first.x, 1e-8));
    expect(contextualAngles(view.model, preview: view.preview).first.degrees,
        closeTo(90, 1e-8));
    await stroke.up();
    await t.pumpAndSettle();
    await board.keepSketch(t);
    expect(board.painter(t).model.walls, hasLength(2));
    expect(board.painter(t).model.corners, hasLength(3));
    expect(t.takeException(), isNull);
  });

  test(
      'Connected 90 and 180 degree intent is consistent across lengths and zoom',
      () {
    const anchor = DrawingPoint(1000, 0);
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), anchor]);
    final before = model.toJson();
    for (final scale in [.02, .1, .4]) {
      for (final length in [1000.0, 10000.0, 30000.0]) {
        for (final direction in [0.0, 90.0, 180.0, 270.0]) {
          final raw = ray(anchor, direction + 2, length);
          final result = precisionPoint(model, raw,
              anchor: anchor, axes: true, tolerance: 6 / scale);
          expect(directionDegrees(anchor, result), closeTo(direction, 1e-8));
        }
      }
    }
    expect(model.toJson(), before);
  });
  test('Diagonal references and previous stroke use the same exact local angle',
      () {
    const anchor = DrawingPoint(1000, 1000), previous = DrawingPoint(0, 0);
    final model = WallNetwork()..addPolyline([previous, anchor]);
    final raw = ray(anchor, 137, 20000);
    for (final network in [model, WallNetwork()]) {
      final result = precisionPoint(network, raw,
          anchor: anchor, previous: previous, axes: true, tolerance: 10);
      expect(directionDegrees(anchor, result), closeTo(135, 1e-8));
    }
  });
  test('A multi-wall diagonal junction keeps 90-degree assistance during edits',
      () {
    const junction = DrawingPoint(1000, 1000);
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), junction])
      ..addPolyline([junction, const DrawingPoint(0, 2000)]);
    final incident = model.walls.keys.toSet();
    final raw = ray(junction, 137, 2000);
    final result = precisionPoint(model, raw,
        anchor: junction,
        axes: true,
        excludeWalls: incident,
        angleToleranceDegrees: 5,
        tolerance: 60);
    expect(directionDegrees(junction, result), closeTo(135, 1e-8));
  });
  test(
      'Free angles, disabled assistance and unrelated parallels remain unforced',
      () {
    const anchor = DrawingPoint(1000, 0);
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), anchor]);
    final outside = ray(anchor, 94, 10000), near = ray(anchor, 92, 10000);
    expect(
        precisionPoint(model, outside,
            anchor: anchor, axes: true, tolerance: 60),
        same(outside));
    expect(
        precisionPoint(model, near, anchor: anchor, axes: false, tolerance: 60),
        same(near));
    expect(
        precisionPoint(model, near,
            anchor: anchor,
            axes: true,
            angleToleranceDegrees: 1,
            tolerance: 60),
        same(near));
    const distant = DrawingPoint(4000, 4000);
    final remote = ray(distant, 2, 10000);
    expect(
        precisionPoint(model, remote,
            anchor: distant, axes: true, parallel: true, tolerance: 60),
        same(remote));
  });
}
