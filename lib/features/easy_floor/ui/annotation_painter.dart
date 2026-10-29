import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_annotations.dart';
import '../logic/drawing_doors.dart';
import 'door_painter.dart';

Color annotationColor(AnnotationInk ink) => switch (ink) {
      AnnotationInk.ink => AppColors.ink,
      AnnotationInk.blue => AppColors.primary,
      AnnotationInk.red => AppColors.error,
      AnnotationInk.green => AppColors.success,
      AnnotationInk.brown => AppColors.brown,
    };

/// Nominal size is measured at .1 pixels/mm; zoom changes rendering, not data.
double annotationFontPixels(double mm, double scale) => mm * scale;

TextPainter annotationTextLayout(DrawingAnnotation note) => TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: switch (note.alignment) {
      AnnotationAlignment.left => TextAlign.left,
      AnnotationAlignment.center => TextAlign.center,
      AnnotationAlignment.right => TextAlign.right,
    },
    text: TextSpan(
        text: note.text,
        style: AppTypography.text14W600Text.copyWith(
            fontSize: note.sizeMm * .1, color: annotationColor(note.ink))))
  ..layout(maxWidth: 240);

Size annotationWorldSize(DrawingAnnotation note) {
  final layout = annotationTextLayout(note);
  final size = layout.size * 10;
  layout.dispose();
  return size;
}

class AnnotationPainter extends CustomPainter {
  AnnotationPainter(
      {required this.annotations,
      required this.origin,
      required this.scale,
      required this.bounds,
      this.doors,
      this.selectedDoor,
      this.onEditDoor,
      this.onEdit,
      this.selected = const {}});
  final DrawingAnnotations annotations;
  final DrawingDoors? doors;
  final int? selectedDoor;
  final ValueChanged<int>? onEditDoor;
  final Offset origin;
  final double scale;
  final Map<int, Rect> bounds;
  final Set<int> selected;
  final ValueChanged<int>? onEdit;

  @override
  void paint(Canvas canvas, Size size) {
    bounds.clear();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (doors != null) {
      DoorPainter(
              doors: doors!,
              origin: origin,
              scale: scale,
              selected: selectedDoor)
          .paint(canvas, size);
    }
    for (final note in annotations.items.values) {
      final factor =
          annotationFontPixels(note.sizeMm, scale) / (note.sizeMm * .1);
      final text = annotationTextLayout(note);
      final at =
          origin + Offset(note.position.x * scale, note.position.y * scale);
      final rect = at & (text.size * factor);
      bounds[note.id] = rect;
      if (selected.contains(note.id)) {
        final border = Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRect(rect.inflate(5), border);
        for (final corner in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight
        ]) {
          canvas.drawCircle(corner, 3, Paint()..color = AppColors.primary);
        }
        if (selected.length == 1) {
          canvas.drawCircle(rect.bottomRight + const Offset(5, 5), 6,
              Paint()..color = AppColors.primary);
        }
      }
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(factor);
      text.paint(canvas, Offset.zero);
      canvas.restore();
      text.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) => true;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
        final result = <CustomPainterSemantics>[
          for (final note in annotations.items.values)
            if (bounds.containsKey(note.id) &&
                bounds[note.id]!.overlaps(Offset.zero & size))
              CustomPainterSemantics(
                  rect: bounds[note.id]!.inflate(10),
                  properties: SemanticsProperties(
                      label: note.text,
                      textDirection: TextDirection.ltr,
                      selected: selected.contains(note.id),
                      button: onEdit != null,
                      onTap: onEdit == null ? null : () => onEdit!(note.id)))
        ];
        for (final door in doors?.items.values ?? <DrawingDoor>[]) {
          Offset screen(double x, double y) => origin + Offset(x, y) * scale;
          final hinge = screen(door.hinge.x, door.hinge.y);
          final rect =
              Rect.fromPoints(hinge, screen(door.leafEnd.x, door.leafEnd.y))
                  .expandToInclude(Rect.fromPoints(
                      hinge, screen(door.closedEnd.x, door.closedEnd.y)))
                  .inflate(12)
                  .intersect(Offset.zero & size);
          if (rect.isEmpty) continue;
          result.add(CustomPainterSemantics(
              rect: rect,
              properties: SemanticsProperties(
                  label:
                      'Door, width ${door.width.round()} millimetres, opening ${door.opening.round()} degrees',
                  textDirection: TextDirection.ltr,
                  selected: selectedDoor == door.id,
                  button: onEditDoor != null,
                  onTap:
                      onEditDoor == null ? null : () => onEditDoor!(door.id))));
        }
        return result;
      };

  @override
  bool shouldRebuildSemantics(covariant AnnotationPainter oldDelegate) => true;
}
