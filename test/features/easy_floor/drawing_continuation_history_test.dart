import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_doors.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

void main() {
  test('Non-wall edits preserve continuation intent in each history snapshot',
      () {
    const tip = DrawingPoint(1000, 0);
    final model = WallNetwork()..addPolyline([const DrawingPoint(0, 0), tip]);
    final history = DrawingHistory()..commit(model, drawingTip: tip);
    final notes = DrawingAnnotations()
      ..add('Room A', const DrawingPoint(0, 200));
    history.commit(model, annotations: notes);
    expect(history.drawingTip, same(tip));
    final doors = DrawingDoors()
      ..add(const DrawingDoor(0, DrawingPoint(0, 100)));
    history.commit(model, doors: doors);
    expect(history.drawingTip, same(tip));
    history.undo();
    expect(history.doors.items, isEmpty);
    expect(history.drawingTip, same(tip));
    history.redo();
    expect(history.drawingTip, same(tip));
    expect(history.doors.items, hasLength(1));
  });

  test(
      'Geometry changes clear stale intent; Undo and Redo restore correct intent',
      () {
    const tip = DrawingPoint(1000, 0);
    final model = WallNetwork()..addPolyline([const DrawingPoint(0, 0), tip]);
    final history = DrawingHistory()..commit(model, drawingTip: tip);
    final moved = model.copy()
      ..moveWall(model.walls.keys.single, const DrawingPoint(0, 500));
    history.commit(moved);
    expect(history.drawingTip, isNull);
    expect(history.undo().toJson(), model.toJson());
    expect(history.drawingTip, same(tip));
    expect(history.redo().toJson(), moved.toJson());
    expect(history.drawingTip, isNull);
    final next = moved.copy()
      ..addPolyline([const DrawingPoint(2000, 0), const DrawingPoint(3000, 0)]);
    history.commit(next, drawingTip: tip);
    expect(history.drawingTip, isNull);
  });

  test(
      'Reset clears transient intent, and a no-op does not create an Undo step',
      () {
    const tip = DrawingPoint(1000, 0);
    final model = WallNetwork()..addPolyline([const DrawingPoint(0, 0), tip]);
    final history = DrawingHistory()..commit(model, drawingTip: tip);
    final revision = history.revision;
    history.commit(model);
    expect(history.revision, revision);
    history.reset(model, annotations: DrawingAnnotations());
    expect(history.drawingTip, isNull);
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
  });
}
