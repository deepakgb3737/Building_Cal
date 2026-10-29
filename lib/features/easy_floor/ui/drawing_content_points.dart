import '../logic/drawing_point.dart';
import '../logic/drawing_annotations.dart';
import '../logic/drawing_doors.dart';
import '../logic/wall_network.dart';
import 'annotation_painter.dart';

/// Shared world-space bounds for screen fitting and full-plan PDF export.
List<DrawingPoint> drawingContentPoints(
    WallNetwork walls, DrawingAnnotations annotations, DrawingDoors doors) {
  final points = [...walls.corners.values];
  for (final door in doors.items.values) {
    points.addAll([
      door.hinge - DrawingPoint(door.width, door.width),
      door.hinge + DrawingPoint(door.width, door.width),
    ]);
  }
  for (final note in annotations.items.values) {
    final size = annotationWorldSize(note);
    points.addAll([
      note.position,
      note.position + DrawingPoint(size.width, size.height),
    ]);
  }
  return points;
}
