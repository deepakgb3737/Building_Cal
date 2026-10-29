import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/pdf/pdf_export.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';
import '../../../ui/app_styles.dart';
import '../../area_converter/logic/area_unit_conversion_service.dart';
import '../../unit_converter/logic/unit_conversion_service.dart';
import '../logic/pvc_ceiling_calculator.dart';
import '../logic/pvc_pdf_rows.dart';
import '../logic/pvc_projects.dart';
import 'pvc_ceiling_painter.dart';
import 'pvc_format.dart';

class PvcPdfRenderer {
  static List<({String label, String value, String? detail})> roomMeasurements(
      Layout layout, PvcProjectData settings) {
    final bounds = pvcBounds(settings.request.room.points);
    double metres(double feet) => UnitConversionService.convert(
        value: feet,
        fromUnit: UnitConversionService.foot,
        toUnit: UnitConversionService.metre);
    final sqm = AreaUnitConversionService.convert(
        value: layout.area,
        fromUnit: AreaUnitConversionService.sqft,
        toUnit: AreaUnitConversionService.sqm);
    return [
      (
        label: settings.shape == PvcShape.rectangle
            ? 'Length (A)'
            : 'Overall length',
        value: '${fmt(bounds.width)} ft',
        detail: '${fmt(metres(bounds.width))} m'
      ),
      (
        label: settings.shape == PvcShape.rectangle
            ? 'Width (B)'
            : 'Overall width',
        value: '${fmt(bounds.height)} ft',
        detail: '${fmt(metres(bounds.height))} m'
      ),
      (label: 'Room area (sq ft)', value: fmt(layout.area), detail: null),
      (label: 'Room area (sq m)', value: fmt(sqm), detail: null),
    ];
  }

  static Stream<PdfExportPage> pages(
      {required Layout layout,
      required PvcProjectData settings,
      required String name}) async* {
    var number = 0;
    _ReportPage page(String section, {bool landscape = false}) =>
        _ReportPage(name, section, ++number, landscape: landscape);
    double mm(double feet) => UnitConversionService.convert(
        value: feet,
        fromUnit: UnitConversionService.foot,
        toUnit: UnitConversionService.millimetre);
    final summary = page('PVC Ceiling - Room & material summary');
    summary.line('Room size - ${settings.shape.label}', heading: true);
    summary.cards(roomMeasurements(layout, settings));
    if (settings.shape != PvcShape.rectangle) {
      summary.line(
          'Overall dimensions are the room extents; area follows the actual room shape.');
    }
    summary.line('Materials to buy', heading: true);
    summary.cards([
      (label: '12 ft PVC planks', value: '${layout.q12}', detail: null),
      (label: '10 ft PVC planks', value: '${layout.q10}', detail: null),
    ], prominent: true);
    summary.line(
        'Total purchase: ${layout.count} planks / ${fmt(layout.total)} ft of stock');
    summary.line('Installed piece length: ${fmt(layout.pieceTotal)} ft');
    summary.line(
        'Wastage: ${fmt(layout.waste)} ft (${layout.wastePercent}% of stock length)');
    summary
        .line('Installed joints: ${layout.joints} | Rows: ${layout.rowsCount}');
    summary.line('Installation settings', heading: true);
    summary.line('Shape: ${settings.shape.label}');
    summary.line(
        'Stock choice: ${settings.stock == 'mix' ? 'Mix 10 ft + 12 ft' : 'Only ${settings.stock} ft'}');
    summary.line('Requested direction: ${switch (settings.orientation) {
      PvcOrientation.automatic => 'Automatic',
      PvcOrientation.length => 'Length (A)',
      PvcOrientation.width => 'Width (B)'
    }}');
    summary.line(
        'Calculated installation: ${layout.turned ? 'Width (B)' : 'Length (A)'} direction');
    summary.line(
        'Plank run: ${ftin(layout.run)} | Across rows: ${ftin(layout.across)}');
    summary.line('Joint preference: ${switch (settings.jointMode) {
      PvcJointMode.automatic => 'Automatic (default optimisation)',
      PvcJointMode.centre => 'Room centre',
      PvcJointMode.custom => 'Custom position'
    }}');
    if (settings.jointMode == PvcJointMode.custom) {
      summary.line(
          'Requested joint: ${settings.distance} ft from ${settings.fromEnd ? (layout.turned ? 'bottom' : 'right') : (layout.turned ? 'top' : 'left')} side');
    }
    if (layout.alignedJoint != null) {
      final distance = layout.alignedJoint! - pvcBounds(layout.polygon).x0;
      summary.line(
          'Calculated joint line: ${ftx(distance)} from ${layout.turned ? 'top' : 'left'} side');
    }
    summary.line('Cutting / installation rules', heading: true);
    summary.line(
        'Cover width: ${fmt(mm(kPW))} mm per plank. Blade allowance: ${ftx(kKerf)} per cut.');
    summary.line(
        'Minimum joint piece: ${ftin(kMinPiece)}. Default preference: fewer joints before stock savings.');
    summary.line(
        'Use the cutting guide and row schedule below. Confirm wall measurements before buying or cutting.');
    yield await summary.finish();

    final dimensions = page('Room measurements');
    final room = settings.request.room;
    dimensions
        .line('Original room orientation - labels match the input fields.');
    dimensions.diagram(
        PvcShapePreviewPainter(room, null,
            joint: pvcJointPosition(
                room.points, settings.orientation, settings.request.jointRule),
            orientation: settings.orientation),
        const Size(740, 380),
        height: 380);
    for (final field in pvcDimensions(settings.shape)) {
      final value = settings.values[field.key]?.trim() ?? '';
      dimensions.line(
          '${field.key} - ${field.label}: ${value.isEmpty ? 'Automatic' : '$value ft'}');
    }
    if (settings.shape == PvcShape.l) {
      dimensions.line('Step-in corner: ${const {
        'tr': 'Top right',
        'tl': 'Top left',
        'br': 'Bottom right',
        'bl': 'Bottom left'
      }[settings.corner]}');
    }
    dimensions.line(
        'The installation layout may be rotated to show the plank direction left to right.');
    yield await dimensions.finish();

    final drawing = page('Ceiling layout', landscape: true);
    drawing.line('Installation: ${layout.turned ? 'Width (B)' : 'Length (A)'}. '
        'Small 10f / 12f labels show the source plank; larger labels show cut lengths.');
    if (!layout.uniform) {
      drawing.line(
          'Pieces cover the longest span of each row. Trim shaped edges to the wall.');
    }
    final geometry = LayoutGeometry.of(layout);
    drawing.diagram(CeilingPainter(layout, 1.2), Size(geometry.vw, geometry.vh),
        height: drawing.size.height - 100 - drawing.y);
    yield await drawing.finish();

    var cuts = page('Cutting guide');
    cuts.line(
        'Quantities below are numbers of stock planks, not numbers of cut pieces.');
    cuts.line(
        'Follow numbered cuts. Tape readings are measured from the stock start and include preceding blade cuts.');
    for (final group in buildGroups(layout)) {
      final title =
          '${group.q} x ${group.stock.toInt()} ft plank${group.q == 1 ? '' : 's'}';
      final pieces = 'Pieces per plank: ${group.cuts.map(ftin).join(' + ')}';
      final scrap = 'Scrap per plank: ${ftin(group.scrap)}';
      final spans = group.spans;
      final marks = [
        for (var i = 0; i < spans.length; i++)
          if (i < group.cuts.length - 1 || group.scrap > 0)
            '${i + 1}: ${ftx(spans[i].end)}'
      ];
      final tape = 'Tape marks: ${marks.join(' | ')}';
      final content =
          group.whole ? ['Use whole - no cutting.'] : [pieces, scrap, tape];
      final height = cuts.textHeight(title, heading: true) +
          8 +
          content.fold<double>(
              0, (sum, text) => sum + cuts.textHeight(text) + 8) +
          (group.whole ? 0 : 143);
      if (!cuts.fits(height)) {
        yield await cuts.finish();
        cuts = page('Cutting guide - continued');
      }
      cuts.line(title, heading: true);
      if (group.whole) {
        cuts.line('Use whole - no cutting.');
      } else {
        cuts.line(pieces);
        cuts.line(scrap);
        cuts.diagram(CutPainter(group, layout.sizes),
            const Size(CutPainter.viewW, CutPainter.viewH),
            height: 135);
        cuts.line(tape);
      }
    }
    const tapeNote =
        'Tape readings use the same nearest-1/8-inch display as the app. Verify each marking before cutting.';
    if (!cuts.fits(cuts.textHeight(tapeNote) + 8)) {
      yield await cuts.finish();
      cuts = page('Cutting guide - continued');
    }
    cuts.line(tapeNote);
    yield await cuts.finish();

    var rows = page('Installation row schedule');
    rows.line(
        'Rows refer to the ceiling layout. Identical consecutive rows are grouped; the instructions apply to every listed row.');
    for (final group in pvcPdfRows(layout)) {
      final lines = <String>[
        '${group.first == group.last ? 'Row ${group.first}' : 'Rows ${group.first}-${group.last}'}: cover width ${fmt(mm(group.row.width))} mm',
      ];
      var stockIndex = 0;
      for (final segment in group.row.segments) {
        final start = segment.x0 - pvcBounds(layout.polygon).x0;
        final end = segment.x1 - pvcBounds(layout.polygon).x0;
        lines.add(
            'Span ${ftx(start)} to ${ftx(end)} from the left of the layout:');
        for (var i = 0; i < segment.pieces.length; i++) {
          lines.add(
              '  Piece ${i + 1}: ${ftin(segment.pieces[i])} from ${group.stocks[stockIndex++].toInt()} ft stock');
        }
      }
      for (var i = 0; i < lines.length; i++) {
        final needed = rows.textHeight(lines[i], heading: i == 0) + 8;
        if (!rows.fits(needed)) {
          yield await rows.finish();
          rows = page('Installation row schedule - continued');
          if (i > 0) rows.line('${lines.first} (continued)', heading: true);
        }
        rows.line(lines[i], heading: i == 0);
      }
      rows.gap(10);
    }
    yield await rows.finish();
  }
}

class _ReportPage {
  _ReportPage(this.name, this.section, this.number, {this.landscape = false}) {
    size = landscape ? const Size(1190, 842) : const Size(842, 1190);
    canvas = Canvas(recorder)..scale(2);
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.white);
    _draw('BuildCalc / PVC Ceiling', const Offset(32, 25),
        AppTypography.text14W600Text);
    _draw(section, const Offset(32, 51),
        AppTypography.text17W700Text.copyWith(fontSize: 22));
    _draw(name, const Offset(32, 91), AppTypography.text14W600Text,
        maxLines: 2);
  }
  final String name, section;
  final int number;
  final bool landscape;
  final recorder = ui.PictureRecorder();
  late final Canvas canvas;
  late final Size size;
  double y = 132;
  TextStyle style(bool heading) =>
      heading ? AppTypography.text17W700Text : AppTypography.text14Drawingtext;
  TextPainter _layout(String text, TextStyle style, {int? maxLines}) =>
      TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          ellipsis: maxLines == null ? null : '…')
        ..layout(maxWidth: size.width - 64);
  double _draw(String text, Offset at, TextStyle style, {int? maxLines}) {
    final painter = _layout(text, style, maxLines: maxLines);
    painter.paint(canvas, at);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double textHeight(String text, {bool heading = false}) {
    final painter = _layout(text, style(heading));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  bool fits(double height) => y + height <= size.height - 90;
  void gap(double height) => y += height;
  void cards(List<({String label, String value, String? detail})> entries,
      {bool prominent = false}) {
    const gap = 12.0, height = 80.0;
    final width = (size.width - 64 - gap) / 2;
    for (var i = 0; i < entries.length; i += 2) {
      if (!fits(height)) throw StateError('PVC PDF summary exceeds its page.');
      for (var column = 0;
          column < 2 && i + column < entries.length;
          column++) {
        final entry = entries[i + column], x = 32 + column * (width + gap);
        final rect = AppRadii.r8.toRRect(Rect.fromLTWH(x, y, width, height));
        canvas.drawRRect(rect, Paint()..color = AppColors.surfaceAlt);
        canvas.drawRRect(
            rect,
            Paint()
              ..color = AppColors.border
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        _draw(entry.label, Offset(x + 14, y + 10), AppTypography.text12Muted);
        _draw(
            entry.value,
            Offset(x + 14, y + 29),
            AppTypography.text22BoldInk
                .copyWith(fontSize: prominent ? 30 : 22));
        if (entry.detail != null) {
          _draw(entry.detail!, Offset(x + 14, y + 57),
              AppTypography.text14Drawingtext);
        }
      }
      y += height + gap;
    }
  }

  void line(String text, {bool heading = false}) {
    final height = textHeight(text, heading: heading);
    if (!fits(height + 8)) {
      throw StateError('PVC PDF content exceeds its page.');
    }
    y += _draw(text, Offset(32, y), style(heading)) + 8;
  }

  void diagram(CustomPainter painter, Size natural, {required double height}) {
    final factor =
        math.min((size.width - 64) / natural.width, height / natural.height);
    canvas.save();
    canvas.translate(32 + (size.width - 64 - natural.width * factor) / 2, y);
    canvas.scale(factor);
    painter.paint(canvas, natural);
    canvas.restore();
    y += height + 8;
  }

  Future<PdfExportPage> finish() async {
    _draw(
        'Fit-to-page diagrams, not construction scale. All quantities use the current calculation.',
        Offset(32, size.height - 58),
        AppTypography.text12Muted);
    _draw(
        'Page $number | Confirm site measurements before purchase and cutting.',
        Offset(32, size.height - 36),
        AppTypography.text12Muted);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(
          (size.width * 2).round(), (size.height * 2).round());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not render the PVC report.');
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
