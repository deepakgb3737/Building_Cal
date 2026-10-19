import 'dart:math' as math;

typedef CeilingPoint = ({double x, double y});

enum MissingCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Dimensions are mm. Arms are measured along the overall width/length axes.
class LCeilingRoom {
  static String? armInputError(String? input, String overall,
      {required bool vertical}) {
    if (input == null || input.isEmpty) return 'Enter the arm size in mm';
    if (!RegExp(r'^\d+$').hasMatch(input)) {
      return 'Only numeric numbers are allowed';
    }
    final value = double.tryParse(input);
    final limit = double.tryParse(overall);
    final axis = vertical ? 'width' : 'length';
    if (limit == null || !limit.isFinite || limit < 800 || limit > 40000) {
      return 'Enter a valid overall $axis first';
    }
    if (value == null || !value.isFinite || value <= 0 || value >= limit) {
      return 'Must be greater than 0 and smaller than overall $axis';
    }
    return null;
  }

  final double widthMm;
  final double lengthMm;
  final double verticalArmWidthMm;
  final double horizontalArmDepthMm;
  final MissingCorner missingCorner;

  LCeilingRoom({
    required this.widthMm,
    required this.lengthMm,
    required this.verticalArmWidthMm,
    required this.horizontalArmDepthMm,
    this.missingCorner = MissingCorner.topRight,
  }) {
    for (final dimension in [widthMm, lengthMm]) {
      if (!dimension.isFinite || dimension < 800 || dimension > 40000) {
        throw ArgumentError('Overall dimensions must be 800 to 40000 mm.');
      }
    }
    if (!verticalArmWidthMm.isFinite ||
        verticalArmWidthMm <= 0 ||
        verticalArmWidthMm >= widthMm) {
      throw ArgumentError(
          'Vertical arm width must be greater than 0 and smaller than overall width.');
    }
    if (!horizontalArmDepthMm.isFinite ||
        horizontalArmDepthMm <= 0 ||
        horizontalArmDepthMm >= lengthMm) {
      throw ArgumentError(
          'Horizontal arm depth must be greater than 0 and smaller than overall length.');
    }
  }

  double get notchBottomMm => lengthMm - horizontalArmDepthMm;
  double get areaMm2 =>
      widthMm * lengthMm - (widthMm - verticalArmWidthMm) * notchBottomMm;
  double get perimeterMm => 2 * (widthMm + lengthMm);

  /// A top-right cutout is the calculation frame; mirror all output together.
  CeilingPoint toWorld(CeilingPoint point) => (
        x: missingCorner == MissingCorner.topLeft ||
                missingCorner == MissingCorner.bottomLeft
            ? widthMm - point.x
            : point.x,
        y: missingCorner == MissingCorner.bottomLeft ||
                missingCorner == MissingCorner.bottomRight
            ? lengthMm - point.y
            : point.y,
      );

  List<CeilingPoint> get canonicalBoundary => [
        (x: 0.0, y: 0.0),
        (x: verticalArmWidthMm, y: 0.0),
        (x: verticalArmWidthMm, y: notchBottomMm),
        (x: widthMm, y: notchBottomMm),
        (x: widthMm, y: lengthMm),
        (x: 0.0, y: lengthMm),
      ];

  List<CeilingPoint> get boundary =>
      List.unmodifiable(canonicalBoundary.map(toWorld));
}

double ceilingPolygonArea(List<CeilingPoint> polygon) {
  var sum = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i], b = polygon[(i + 1) % polygon.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

/// Clip a room footprint to a grid cell, keeping a notched tile as one piece.
List<CeilingPoint> clipCeilingCell(List<CeilingPoint> polygon, double left,
    double top, double right, double bottom) {
  var output = polygon;
  for (final (axisX, edge, greater) in [
    (true, left, true),
    (true, right, false),
    (false, top, true),
    (false, bottom, false),
  ]) {
    final input = output;
    output = [];
    if (input.isEmpty) break;
    double coordinate(CeilingPoint p) => axisX ? p.x : p.y;
    bool inside(CeilingPoint p) =>
        greater ? coordinate(p) >= edge : coordinate(p) <= edge;
    var previous = input.last;
    for (final current in input) {
      if (inside(previous) != inside(current)) {
        final t = (edge - coordinate(previous)) /
            (coordinate(current) - coordinate(previous));
        output.add((
          x: previous.x + (current.x - previous.x) * t,
          y: previous.y + (current.y - previous.y) * t
        ));
      }
      if (inside(current)) output.add(current);
      previous = current;
    }
  }
  final cleaned = <CeilingPoint>[];
  for (final p in output) {
    if (cleaned.isEmpty || p != cleaned.last) cleaned.add(p);
  }
  if (cleaned.length > 1 && cleaned.first == cleaned.last) cleaned.removeLast();
  var changed = true;
  while (changed && cleaned.length > 3) {
    changed = false;
    for (var i = 0; i < cleaned.length; i++) {
      final a = cleaned[(i + cleaned.length - 1) % cleaned.length];
      final b = cleaned[i], c = cleaned[(i + 1) % cleaned.length];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross.abs() < 1e-7) {
        cleaned.removeAt(i);
        changed = true;
        break;
      }
    }
  }
  return ceilingPolygonArea(cleaned) < 1e-7 ? [] : cleaned;
}

double ceilingExtent(Iterable<double> values) {
  final list = values.toList();
  return list.reduce(math.max) - list.reduce(math.min);
}
