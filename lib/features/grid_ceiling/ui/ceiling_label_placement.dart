import 'package:flutter/painting.dart';
import '../logic/cross_t_spans.dart';

/// Stay close to a section end, but inset enough to clear the wall junction.
Offset ceilingSectionLabelAnchor(Offset start, Offset end,
    {bool atEnd = false}) {
  final delta = end - start;
  final distance = delta.distance;
  if (distance == 0) return start;
  final inset = distance < 40 ? distance / 2 : 20.0;
  return atEnd
      ? end - delta / distance * inset
      : start + delta / distance * inset;
}

/// Identify stock once, retaining the short sections at each perimeter edge.
Set<int> ceilingStockLabelSpans(List<CrossTSpan> spans) {
  final full = spans.indexWhere((span) => !span.usesTwoFoot);
  return {
    if (full >= 0) full,
    if (spans.isNotEmpty && spans.first.usesTwoFoot) 0,
    if (spans.isNotEmpty && spans.last.usesTwoFoot) spans.length - 1,
  };
}

/// Finds a nearby clear position without clamping multiple labels to one corner.
Rect? placeCeilingLabel({
  required Offset anchor,
  required Size size,
  required Rect bounds,
  required List<Rect> occupied,
  List<(Offset, Offset)> lines = const [],
  bool vertical = false,
}) {
  final normal = vertical ? const Offset(1, 0) : const Offset(0, -1);
  final tangent = vertical ? const Offset(0, 1) : const Offset(1, 0);
  final normalSize = vertical ? size.width : size.height;
  final tangentSize = vertical ? size.height : size.width;
  final candidates = <Offset>[
    for (var lane = 0; lane < 3; lane++)
      for (final side in [1.0, -1.0])
        for (final shift in [0.0, -.5, .5, -1.0, 1.0, -1.5, 1.5])
          anchor +
              normal * side * (normalSize / 2 + 4 + lane * (normalSize + 4)) +
              tangent * shift * (tangentSize + 8),
  ]..sort((a, b) =>
      (a - anchor).distanceSquared.compareTo((b - anchor).distanceSquared));
  for (final center in candidates) {
    final rect =
        Rect.fromCenter(center: center, width: size.width, height: size.height);
    if (bounds.contains(rect.topLeft) &&
        bounds.contains(rect.bottomRight) &&
        !occupied.any((other) => other.overlaps(rect.inflate(2))) &&
        !lines.any((line) => ceilingLineCrossesLabel(line, rect.inflate(3)))) {
      occupied.add(rect);
      return rect;
    }
  }
  return null;
}

/// Clip the segment against the label; bounding boxes alone reject diagonal gaps.
bool ceilingLineCrossesLabel((Offset, Offset) line, Rect rect) {
  var enter = 0.0;
  var leave = 1.0;
  final delta = line.$2 - line.$1;
  for (final (origin, direction, low, high) in [
    (line.$1.dx, delta.dx, rect.left, rect.right),
    (line.$1.dy, delta.dy, rect.top, rect.bottom),
  ]) {
    if (direction.abs() < 1e-9) {
      if (origin < low || origin > high) return false;
    } else {
      final a = (low - origin) / direction;
      final b = (high - origin) / direction;
      final near = a < b ? a : b;
      final far = a > b ? a : b;
      if (near > enter) enter = near;
      if (far < leave) leave = far;
      if (enter > leave) return false;
    }
  }
  return true;
}
