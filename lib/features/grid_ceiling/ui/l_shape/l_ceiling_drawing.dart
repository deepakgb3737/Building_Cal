import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/build_calc_colors.dart';
import '../../../../ui/app_typography.dart';
import '../../logic/l_shape/l_ceiling_room.dart';
import '../../logic/l_shape/l_ceiling_result.dart';
import '../ceiling_label_placement.dart';

Color lCeilingStockColor(LCeilingStock stock) => switch (stock) {
      LCeilingStock.main10ft => BuildCalcColors.chartPrimary,
      LCeilingStock.cross4ft => BuildCalcColors.chartSecondary,
      LCeilingStock.cross2ft => BuildCalcColors.chartTertiary,
    };

class LCeilingDrawing extends StatefulWidget {
  final LCeilingResult result;
  final ValueChanged<bool> onInteractionChanged;
  const LCeilingDrawing(
      {super.key, required this.result, required this.onInteractionChanged});
  @override
  State<LCeilingDrawing> createState() => _LCeilingDrawingState();
}

class _LCeilingDrawingState extends State<LCeilingDrawing> {
  bool _threeD = true, _labels = true;
  double _yaw = .6, _pitch = .75, _zoom = 1, _startZoom = 1;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget drawing() => CustomPaint(
          painter: LCeilingPlanPainter(widget.result, colors,
              threeD: _threeD,
              yaw: _yaw,
              pitch: _pitch,
              zoom: _threeD ? _zoom : 1,
              showMeasurements: _labels,
              textScaler: MediaQuery.textScalerOf(context)),
          child: const SizedBox.expand(),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Ceiling layout', style: AppTypography.text17W700Text),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('3D view'),
                icon: Icon(Icons.view_in_ar)),
            ButtonSegment(
                value: false,
                label: Text('2D plan'),
                icon: Icon(Icons.grid_on)),
          ],
          selected: {
            _threeD
          },
          onSelectionChanged: (v) {
            widget.onInteractionChanged(false);
            setState(() => _threeD = v.single);
          }),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Measurement labels'),
          value: _labels,
          onChanged: (v) => setState(() => _labels = v)),
      ClipRect(
          child: SizedBox(
        height: 340,
        child: _threeD
            ? GestureDetector(
                key: const ValueKey('l-ceiling-3d'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) {
                  _startZoom = _zoom;
                  widget.onInteractionChanged(true);
                },
                onScaleUpdate: (d) => setState(() {
                  _yaw += d.focalPointDelta.dx * .012;
                  _pitch =
                      (_pitch + d.focalPointDelta.dy * .01).clamp(-1.4, 1.4);
                  _zoom = (_startZoom * d.scale).clamp(.6, 4);
                }),
                onScaleEnd: (_) => widget.onInteractionChanged(false),
                onDoubleTap: () => setState(() {
                  _yaw = .6;
                  _pitch = .75;
                  _zoom = 1;
                }),
                child: drawing(),
              )
            : InteractiveViewer(
                key: const ValueKey('l-ceiling-2d'),
                minScale: 1,
                maxScale: 8,
                onInteractionStart: (_) => widget.onInteractionChanged(true),
                onInteractionEnd: (_) => widget.onInteractionChanged(false),
                child: drawing(),
              ),
      )),
      const SizedBox(height: 8),
      Wrap(spacing: 16, runSpacing: 8, children: [
        for (final stock in LCeilingStock.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 18,
                child: Divider(thickness: 3, color: lCeilingStockColor(stock))),
            const SizedBox(width: 6),
            Text(
                switch (stock) {
                  LCeilingStock.main10ft => '10ft main',
                  LCeilingStock.cross4ft => '4ft cross T',
                  LCeilingStock.cross2ft => '2ft cross T'
                },
                style: AppTypography.text12W600Label
                    .copyWith(color: colors.onSurface)),
          ]),
      ]),
      const SizedBox(height: 6),
      const Text(
          'Outline: wall angle · Skeleton only. Pinch to zoom; drag 3D to rotate.',
          style: AppTypography.text14Secondarytext),
    ]);
  }
}

/// Paint only backend sections; neither view reconstructs a rectangular grid.
class LCeilingPlanPainter extends CustomPainter {
  final LCeilingResult result;
  final ColorScheme colors;
  final bool threeD, showMeasurements;
  final double yaw, pitch, zoom;
  final TextScaler textScaler;
  const LCeilingPlanPainter(
    this.result,
    this.colors, {
    this.threeD = false,
    this.showMeasurements = true,
    this.yaw = .6,
    this.pitch = .75,
    this.zoom = 1,
    this.textScaler = TextScaler.noScaling,
  });

  List<({Offset start, Offset end, LCeilingStock stock})> projectedSections(
      Size size) {
    final project = _projection(size);
    return [
      for (final s in result.sections)
        (start: project(s.start), end: project(s.end), stock: s.stock)
    ];
  }

  Offset Function(CeilingPoint) _projection(Size size) {
    final room = result.room;
    Offset rotate(CeilingPoint p) {
      final x = p.x - room.widthMm / 2, y = p.y - room.lengthMm / 2;
      if (!threeD) return Offset(x, y);
      return Offset(x * math.cos(yaw) - y * math.sin(yaw),
          (x * math.sin(yaw) + y * math.cos(yaw)) * math.cos(pitch));
    }

    final points = room.boundary.map(rotate).toList();
    final left = points.map((p) => p.dx).reduce(math.min);
    final right = points.map((p) => p.dx).reduce(math.max);
    final top = points.map((p) => p.dy).reduce(math.min);
    final bottom = points.map((p) => p.dy).reduce(math.max);
    final scale = math.min((size.width - 90) / (right - left),
            (size.height - 90) / (bottom - top)) *
        zoom;
    final center = Offset((left + right) / 2, (top + bottom) / 2);
    return (p) => (rotate(p) - center) * scale + size.center(Offset.zero);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final project = _projection(size);
    final boundary = result.room.boundary;
    final points = boundary.map(project).toList();
    final lines = <(Offset, Offset)>[
      for (var i = 0; i < points.length; i++)
        (points[i], points[(i + 1) % points.length]),
    ];
    final sections = projectedSections(size);
    lines.addAll(sections.map((s) => (s.start, s.end)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final s in sections) {
      if (threeD) {
        canvas.drawLine(
            s.start + const Offset(0, 2),
            s.end + const Offset(0, 2),
            paint
              ..color = colors.shadow.withValues(alpha: .18)
              ..strokeWidth = 4);
      }
      canvas.drawLine(
          s.start,
          s.end,
          paint
            ..color = lCeilingStockColor(s.stock)
            ..strokeWidth = 2);
    }
    canvas.drawPath(
        Path()..addPolygon(points, true),
        paint
          ..color = colors.onSurfaceVariant
          ..strokeWidth = 3);
    final occupied = <Rect>[];
    void label(String value, Offset anchor, Color color,
        {bool vertical = false}) {
      final text = TextPainter(
          text: TextSpan(
              text: value,
              style: AppTypography.text12W600Label.copyWith(color: color)),
          textScaler: textScaler.clamp(maxScaleFactor: 1.3),
          textDirection: TextDirection.ltr)
        ..layout();
      final rect = placeCeilingLabel(
          anchor: anchor,
          size: Size(text.width + 6, text.height + 4),
          bounds: (Offset.zero & size).deflate(2),
          occupied: occupied,
          lines: lines,
          vertical: vertical);
      if (rect == null) return;
      canvas.drawLine(
          anchor, rect.center, Paint()..color = color.withValues(alpha: .5));
      canvas.drawRect(rect, Paint()..color = colors.surface);
      text.paint(canvas, rect.topLeft + const Offset(3, 2));
    }

    if (showMeasurements) {
      for (var i = 0; i < boundary.length; i++) {
        final j = (i + 1) % boundary.length;
        final a = boundary[i], b = boundary[j];
        final length = (a.x - b.x).abs() + (a.y - b.y).abs();
        final direction = points[j] - points[i];
        label('${length.toStringAsFixed(length == length.round() ? 0 : 1)} mm',
            (points[i] + points[j]) / 2, colors.onSurface,
            vertical: direction.dy.abs() > direction.dx.abs());
      }
    }
    for (final stock in LCeilingStock.values) {
      final matches = sections.where((s) => s.stock == stock).toList()
        ..sort((a, b) =>
            (b.end - b.start).distance.compareTo((a.end - a.start).distance));
      if (matches.isEmpty) continue;
      final s = matches.first;
      final delta = s.end - s.start;
      label(
          switch (stock) {
            LCeilingStock.main10ft => '10f',
            LCeilingStock.cross4ft => '4f',
            LCeilingStock.cross2ft => '2f'
          },
          ceilingSectionLabelAnchor(s.start, s.end),
          lCeilingStockColor(stock),
          vertical: delta.dy.abs() > delta.dx.abs());
    }
  }

  @override
  bool shouldRepaint(covariant LCeilingPlanPainter old) =>
      result != old.result ||
      colors != old.colors ||
      threeD != old.threeD ||
      showMeasurements != old.showMeasurements ||
      yaw != old.yaw ||
      pitch != old.pitch ||
      zoom != old.zoom ||
      textScaler != old.textScaler;
}
