import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_doors.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_history.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';

void main() {
  test('Door leaf length is exact for both hinges, swing sides and rotations',
      () {
    for (final angle in [0.0, 90.0, 137.0, 360.0]) {
      for (final opening in [0.0, 45.0, 90.0, 180.0]) {
        for (final hinge in [false, true]) {
          for (final reverse in [false, true]) {
            final door = DrawingDoor(1, const DrawingPoint(1000, 2000),
                rotation: angle,
                opening: opening,
                rightHinge: hinge,
                reverseSwing: reverse,
                width: 812.8);
            door.validate();
            expect((door.leafEnd - door.hinge).length, closeTo(812.8, 1e-8));
            expect((door.closedEnd - door.hinge).length, closeTo(812.8, 1e-8));
            if (opening == 0) {
              expect((door.leafEnd - door.closedEnd).length, closeTo(0, 1e-8));
            }
          }
        }
      }
    }
  });
  test(
      'Door history remains separate from walls and survives wall-only commits',
      () {
    final walls = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(4000, 0)]);
    final geometry = walls.toJson();
    final history = DrawingHistory()..commit(walls);
    final doors = DrawingDoors();
    final id = doors.add(const DrawingDoor(0, DrawingPoint(100, 0)));
    history.commit(walls, doors: doors);
    doors.update(doors.items[id]!.copyWith(opening: 0, reverseSwing: true));
    history.commit(walls, doors: doors);
    expect(history.undo().toJson(), geometry);
    expect(history.doors.items[id]!.opening, 90);
    expect(history.redo().toJson(), geometry);
    expect(history.doors.items[id]!.opening, 0);
    walls.addPolyline(
        [const DrawingPoint(5000, 0), const DrawingPoint(5000, 2000)]);
    history.commit(walls);
    expect(history.doors.toJson(), doors.toJson());
    doors.delete(id);
    history.commit(walls, doors: doors);
    history.undo();
    expect(history.doors.items, hasLength(1));
  });
  test('Doors persist, legacy documents load, invalid door data is rejected',
      () {
    final walls = WallNetwork(), doors = DrawingDoors();
    doors.add(const DrawingDoor(0, DrawingPoint(500, 600),
        width: 812.8,
        rotation: 137,
        opening: 120,
        rightHinge: true,
        reverseSwing: true));
    final document = FloorDocument(
        walls, DrawingAnnotations(), const DocumentSettings(),
        doors: doors);
    final json =
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
    expect(FloorDocument.fromJson(json).doors.toJson(), doors.toJson());
    final old = Map<String, dynamic>.of(json)..remove('doors');
    expect(FloorDocument.fromJson(old).doors.items, isEmpty);
    final rows = json['doors'] as List;
    (rows.first as Map)['width'] = -1;
    expect(() => FloorDocument.fromJson(json), throwsFormatException);
    expect(
        () => doors
            .update(doors.items.values.single.copyWith(opening: double.nan)),
        throwsArgumentError);
    expect(doors.items.values.single.opening, 120);
  });
  test('Door hit tolerance is zoom independent and never alters geometry', () {
    final doors = DrawingDoors();
    final id = doors.add(const DrawingDoor(0, DrawingPoint(0, 0), width: 5000));
    final original = doors.toJson();
    for (final scale in [.02, .1, 1.0]) {
      expect(doors.hitTest(DrawingPoint(8 / scale, 2500), 12 / scale), id);
      expect(doors.hitTest(DrawingPoint(20 / scale, 2500), 12 / scale), isNull);
    }
    expect(doors.toJson(), original);
  });
}
