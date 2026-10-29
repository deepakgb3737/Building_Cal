import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import '../logic/drawing_doors.dart';

class DoorPainter extends CustomPainter {
  DoorPainter(
      {required this.doors,
      required this.origin,
      required this.scale,
      this.selected});
  final DrawingDoors doors;
  final Offset origin;
  final double scale;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final door in doors.items.values) {
      final hinge = origin + Offset(door.hinge.x, door.hinge.y) * scale;
      final closed =
          origin + Offset(door.closedEnd.x, door.closedEnd.y) * scale;
      final leaf = origin + Offset(door.leafEnd.x, door.leafEnd.y) * scale;
      final paint = Paint()
        ..color = selected == door.id ? AppColors.primary : AppColors.ink
        ..strokeWidth = selected == door.id ? 3 : 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          hinge,
          closed,
          Paint()
            ..color = AppColors.muted.withValues(alpha: .5)
            ..strokeWidth = 1);
      canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: door.width * scale),
          door.startRadians,
          door.sweepRadians,
          false,
          Paint()
            ..color = paint.color.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawLine(hinge, leaf, paint);
      canvas.drawCircle(hinge, 3, Paint()..color = paint.color);
      if (selected == door.id) canvas.drawCircle(leaf, 4, paint);
      if (selected == door.id) {
        final handle = origin +
            Offset(door.rotationHandle.x, door.rotationHandle.y) * scale;
        canvas.drawLine(
            hinge,
            handle,
            Paint()
              ..color = AppColors.primary.withValues(alpha: .45)
              ..strokeWidth = 1);
        canvas.drawCircle(handle, 9, Paint()..color = AppColors.primary);
        canvas.drawCircle(handle, 5, Paint()..color = AppColors.white);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DoorPainter oldDelegate) => true;
}
