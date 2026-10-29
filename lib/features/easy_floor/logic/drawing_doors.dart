import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'drawing_point.dart';
import 'document_json.dart';

/// A plan symbol, independent of the connected wall graph. All lengths are mm.
class DrawingDoor {
  const DrawingDoor(this.id, this.position,
      {this.width = 900,
      this.rotation = 0,
      this.opening = 90,
      this.rightHinge = false,
      this.reverseSwing = false});
  final int id;
  final DrawingPoint position;
  final double width, rotation, opening;
  final bool rightHinge, reverseSwing;
  DrawingDoor copyWith(
          {DrawingPoint? position,
          double? width,
          double? rotation,
          double? opening,
          bool? rightHinge,
          bool? reverseSwing}) =>
      DrawingDoor(id, position ?? this.position,
          width: width ?? this.width,
          rotation: rotation ?? this.rotation,
          opening: opening ?? this.opening,
          rightHinge: rightHinge ?? this.rightHinge,
          reverseSwing: reverseSwing ?? this.reverseSwing);
  DrawingPoint get direction => DrawingPoint(
      math.cos(rotation * math.pi / 180), math.sin(rotation * math.pi / 180));
  DrawingPoint get hinge => position + direction * (rightHinge ? width : 0);
  DrawingPoint get closedEnd => position + direction * (rightHinge ? 0 : width);
  double get startRadians =>
      (rotation + (rightHinge ? 180 : 0)) * math.pi / 180;
  double get sweepRadians =>
      opening * math.pi / 180 * (rightHinge ? -1 : 1) * (reverseSwing ? -1 : 1);
  DrawingPoint get leafEnd =>
      hinge +
      DrawingPoint(math.cos(startRadians + sweepRadians),
              math.sin(startRadians + sweepRadians)) *
          width;
  DrawingPoint get rotationHandle =>
      hinge + DrawingPoint(-direction.y, direction.x) * (width * .72);
  void validate() {
    if (!position.isFinite ||
        position.x.abs() > 1e8 ||
        position.y.abs() > 1e8 ||
        !width.isFinite ||
        width < 100 ||
        width > 5000 ||
        !rotation.isFinite ||
        rotation < 0 ||
        rotation > 360 ||
        !opening.isFinite ||
        opening < 0 ||
        opening > 180) {
      throw ArgumentError(
          'Use width 100–5000 mm, rotation 0–360°, and opening 0–180°.');
    }
  }
}

class DrawingDoors {
  final Map<int, DrawingDoor> _items = {};
  int _nextId = 1;
  Map<int, DrawingDoor> get items => UnmodifiableMapView(_items);
  DrawingDoors copy() => DrawingDoors()
    .._items.addAll(_items)
    .._nextId = _nextId;
  bool sameAs(DrawingDoors other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
  int add(DrawingDoor door) {
    door.validate();
    final id = _nextId++;
    _items[id] = DrawingDoor(id, door.position,
        width: door.width,
        rotation: door.rotation,
        opening: door.opening,
        rightHinge: door.rightHinge,
        reverseSwing: door.reverseSwing);
    return id;
  }

  void update(DrawingDoor door) {
    if (!_items.containsKey(door.id)) {
      throw ArgumentError('Select an existing door.');
    }
    door.validate();
    _items[door.id] = door;
  }

  void delete(int id) {
    if (!_items.containsKey(id)) {
      throw ArgumentError('Select an existing door.');
    }
    _items.remove(id);
  }

  int? hitTest(DrawingPoint point, double tolerance) {
    int? selected;
    var best = tolerance;
    for (final door in _items.values.toList().reversed) {
      final distance = math.min(
          (point - projectToSegment(point, door.hinge, door.leafEnd)).length,
          (point - projectToSegment(point, door.hinge, door.closedEnd)).length);
      if (distance < best) {
        best = distance;
        selected = door.id;
      }
    }
    return selected;
  }

  int? hitTestRotation(DrawingPoint point, double tolerance, {int? selected}) {
    if (selected == null) return null;
    final door = _items[selected];
    return door != null && (point - door.rotationHandle).length <= tolerance
        ? selected
        : null;
  }

  List<Object?> toJson() => [
        for (final door in _items.values)
          {
            'id': door.id,
            'x': door.position.x,
            'y': door.position.y,
            'width': door.width,
            'rotation': door.rotation,
            'opening': door.opening,
            'rightHinge': door.rightHinge,
            'reverseSwing': door.reverseSwing,
          }
      ];
  static DrawingDoors fromJson(Object? value) {
    final result = DrawingDoors();
    if (value == null) return result;
    for (final row in jsonArray(value)) {
      final r = jsonObject(row), id = jsonInteger(jsonObject(row)['id']);
      if (result._items.containsKey(id)) {
        throw const FormatException('Duplicate door.');
      }
      final door = DrawingDoor(
          id, DrawingPoint(jsonNumber(r['x']), jsonNumber(r['y'])),
          width: jsonNumber(r['width']),
          rotation: jsonNumber(r['rotation']),
          opening: jsonNumber(r['opening']),
          rightHinge: jsonBoolean(r['rightHinge']),
          reverseSwing: jsonBoolean(r['reverseSwing']));
      door.validate();
      result._items[id] = door;
      result._nextId = math.max(result._nextId, id + 1);
    }
    return result;
  }
}
