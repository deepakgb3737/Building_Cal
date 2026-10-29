import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';
import '../logic/drawing_camera.dart';
import '../logic/floor_document.dart';
import 'drawing_content_points.dart';
import 'drawing_painter.dart';
import 'annotation_painter.dart';

class FloorPdfRenderer {
  /// Roughly 200 DPI on A4, with bounded memory regardless of screen dimensions.
  static Future<({Uint8List png, bool landscape})> render(
      FloorDocument document, String projectName) async {
    final points = drawingContentPoints(
        document.walls, document.annotations, document.doors);
    if (points.isEmpty) throw ArgumentError('Draw a plan before exporting.');
    final xs = points.map((p) => p.x), ys = points.map((p) => p.y);
    final left = xs.reduce((a, b) => a < b ? a : b),
        right = xs.reduce((a, b) => a > b ? a : b),
        top = ys.reduce((a, b) => a < b ? a : b),
        bottom = ys.reduce((a, b) => a > b ? a : b);
    final landscape = right - left >= bottom - top;
    final size = landscape ? const Size(1190, 842) : const Size(842, 1190);
    final drawingSize = Size(size.width - 64, size.height - 220);
    final camera = fitDrawingCamera(
        points, drawingSize.width, drawingSize.height,
        margin: 56)!;
    final origin = Offset(camera.$2.x, camera.$2.y);
    final recorder = ui.PictureRecorder();
    // The recorder is owned locally so all raster resources can be released.
    final sheet = Canvas(recorder)..scale(2);
    sheet.drawRect(Offset.zero & size, Paint()..color = AppColors.white);
    void text(String value, Offset at, TextStyle style, {int maxLines = 1}) {
      final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          ellipsis: '…')
        ..layout(maxWidth: size.width - 64);
      painter.paint(sheet, at);
      painter.dispose();
    }

    text('BuildCalc / EasyFloor', const Offset(32, 26),
        AppTypography.text14W600Text);
    text(projectName, const Offset(32, 50),
        AppTypography.text17W700Text.copyWith(fontSize: 22),
        maxLines: 2);
    text(
        '${document.settings.unit.name}  |  ${document.walls.walls.length} wall segment${document.walls.walls.length == 1 ? '' : 's'}  |  ${document.doors.items.length} door${document.doors.items.length == 1 ? '' : 's'}',
        const Offset(32, 101),
        AppTypography.text12Muted);
    sheet.save();
    sheet.translate(32, 128);
    final obstacles = [
      for (final note in document.annotations.items.values)
        (origin + Offset(note.position.x, note.position.y) * camera.$1) &
            (annotationWorldSize(note) * camera.$1)
    ];
    DrawingPainter(
            model: document.walls,
            origin: origin,
            scale: camera.$1,
            unit: document.settings.unit,
            preview: [],
            showAllMeasurements: true,
            showGrid: false,
            showCornerHandles: false,
            anglesEnabled: false,
            labelObstacles: obstacles)
        .paint(sheet, drawingSize);
    AnnotationPainter(
        annotations: document.annotations,
        doors: document.doors,
        origin: origin,
        scale: camera.$1,
        bounds: {}).paint(sheet, drawingSize);
    sheet.restore();
    text(
        'Solid: wall   Dashed: proposed wall   Red: locked wall   Door arcs: opening',
        Offset(32, size.height - 80),
        AppTypography.text12Muted);
    text('Plan axes: North up, East right (not geographic north).',
        Offset(32, size.height - 58), AppTypography.text12Muted);
    text('Fit to page - not to scale. Check dimensions on site.',
        Offset(32, size.height - 36), AppTypography.text12Muted);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(
          (size.width * 2).round(), (size.height * 2).round());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not render the plan.');
      return (
        png: bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        landscape: landscape
      );
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }
}
