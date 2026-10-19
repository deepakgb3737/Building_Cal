import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../ui/app_typography.dart';
import '../../../../ui/app_styles.dart';
import '../../../../ui/app_widgets.dart';
import '../../logic/l_shape/l_ceiling_room.dart';

class LCeilingInputs extends StatelessWidget {
  final TextEditingController width, length, arm, depth;
  final MissingCorner corner;
  final ValueChanged<MissingCorner> onCornerChanged;
  final List<FocusNode> dimensionFocus;
  const LCeilingInputs(
      {super.key,
      required this.width,
      required this.length,
      required this.arm,
      required this.depth,
      required this.corner,
      required this.dimensionFocus,
      required this.onCornerChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          DropdownButtonFormField<MissingCorner>(
            key: ValueKey(corner),
            initialValue: corner,
            decoration: const InputDecoration(labelText: 'Missing corner'),
            isExpanded: true,
            items: [
              for (final c in MissingCorner.values)
                DropdownMenuItem(
                    value: c,
                    child: Text(switch (c) {
                      MissingCorner.topLeft => 'Top left',
                      MissingCorner.topRight => 'Top right',
                      MissingCorner.bottomLeft => 'Bottom left',
                      MissingCorner.bottomRight => 'Bottom right',
                    }))
            ],
            onChanged: (c) {
              if (c != null) onCornerChanged(c);
            },
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: Listenable.merge(
                [width, length, arm, depth, ...dimensionFocus]),
            builder: (context, _) {
              final activeIndex =
                  dimensionFocus.indexWhere((node) => node.hasFocus);
              final active = activeIndex < 0 ? null : 'ABCD'[activeIndex];
              LCeilingRoom? room;
              try {
                room = LCeilingRoom(
                    widthMm: double.parse(width.text),
                    lengthMm: double.parse(length.text),
                    verticalArmWidthMm: double.parse(arm.text),
                    horizontalArmDepthMm: double.parse(depth.text),
                    missingCorner: corner);
              } on FormatException {
                room = null;
              } on ArgumentError {
                room = null;
              }
              return Column(children: [
                if (activeIndex >= 0)
                  Semantics(
                      liveRegion: true,
                      child: Text(
                          '$active · ${const [
                            'Overall width — full horizontal size',
                            'Overall length — full vertical size',
                            'Vertical arm width — across the vertical arm',
                            'Horizontal arm depth — height of the horizontal arm'
                          ][activeIndex]}',
                          key: const ValueKey('l-active-dimension'),
                          style: AppTypography.text14W600Text)),
                SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                        painter: LCeilingGuidePainter(
                            room ??
                                LCeilingRoom(
                                    widthMm: 3600,
                                    lengthMm: 3000,
                                    verticalArmWidthMm: 1800,
                                    horizontalArmDepthMm: 1200,
                                    missingCorner: corner),
                            Theme.of(context).colorScheme,
                            MediaQuery.textScalerOf(context),
                            activeDimension: active))),
                Text(
                    room == null
                        ? 'Dimension guide — enter all four sizes to preview your room.'
                        : 'Preview uses your dimensions.',
                    style: AppTypography.text14Secondarytext),
              ]);
            },
          ),
          const SizedBox(height: 12),
          AppNumberField(
              label: 'C · Vertical arm width (mm)',
              controller: arm,
              focusNode: dimensionFocus[2],
              integerOnly: true,
              labelAbove: true,
              validator: (v) =>
                  LCeilingRoom.armInputError(v, width.text, vertical: true)),
          const SizedBox(height: 12),
          AppNumberField(
              label: 'D · Horizontal arm depth (mm)',
              controller: depth,
              focusNode: dimensionFocus[3],
              integerOnly: true,
              labelAbove: true,
              validator: (v) =>
                  LCeilingRoom.armInputError(v, length.text, vertical: false)),
          const SizedBox(height: 8),
          const Text(
              'C is measured across the vertical arm. D is measured down the horizontal arm. Both sizes stay on these axes when the missing corner changes.',
              style: AppTypography.text14Secondarytext),
        ],
      );
}

class LCeilingGuidePainter extends CustomPainter {
  final LCeilingRoom room;
  final ColorScheme colors;
  final TextScaler textScaler;
  final String? activeDimension;

  const LCeilingGuidePainter(this.room, this.colors, this.textScaler,
      {this.activeDimension});

  List<(String, CeilingPoint, CeilingPoint)> get dimensionEdges => [
        ('A', (x: 0.0, y: room.lengthMm), (x: room.widthMm, y: room.lengthMm)),
        ('B', (x: 0.0, y: 0.0), (x: 0.0, y: room.lengthMm)),
        ('C', (x: 0.0, y: 0.0), (x: room.verticalArmWidthMm, y: 0.0)),
        (
          'D',
          (x: room.widthMm, y: room.notchBottomMm),
          (x: room.widthMm, y: room.lengthMm)
        ),
      ].map((e) => (e.$1, room.toWorld(e.$2), room.toWorld(e.$3))).toList();

  (CeilingPoint, CeilingPoint)? get highlightedEdge {
    for (final edge in dimensionEdges) {
      if (edge.$1 == activeDimension) return (edge.$2, edge.$3);
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
        (size.width - 72) / room.widthMm, (size.height - 56) / room.lengthMm);
    final origin = Offset((size.width - room.widthMm * scale) / 2,
        (size.height - room.lengthMm * scale) / 2);
    Offset point(CeilingPoint p) => origin + Offset(p.x, p.y) * scale;
    final polygon = room.boundary;
    final path = Path()..addPolygon(polygon.map(point).toList(), true);
    canvas.drawPath(path, Paint()..color = colors.primaryContainer);
    canvas.drawPath(
        path,
        Paint()
          ..color = colors.onSurfaceVariant
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final center = point((x: room.widthMm / 2, y: room.lengthMm / 2));
    for (final (label, from, to) in dimensionEdges) {
      final start = point(from), end = point(to);
      final active = label == activeDimension;
      if (active) {
        canvas.drawLine(
            start,
            end,
            Paint()
              ..color = colors.primary
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round);
        for (final p in [start, end]) {
          canvas.drawCircle(p, 3.5, Paint()..color = colors.primary);
        }
      }
      final mid = (start + end) / 2;
      var normal = Offset(-(end - start).dy, (end - start).dx);
      normal /= normal.distance;
      if ((mid + normal - center).distance < (mid - normal - center).distance) {
        normal = -normal;
      }
      final text = TextPainter(
          text: TextSpan(
              text: label,
              style: AppTypography.text14W600Text
                  .copyWith(color: active ? colors.primary : colors.onSurface)),
          textScaler: textScaler.clamp(maxScaleFactor: 1.3),
          textDirection: TextDirection.ltr)
        ..layout();
      final position = mid + normal * 15 - Offset(text.width, text.height) / 2;
      if (active) {
        canvas.drawRRect(AppRadii.r4.toRRect((position & text.size).inflate(3)),
            Paint()..color = colors.primaryContainer);
      }
      text.paint(canvas, position);
    }
  }

  @override
  bool shouldRepaint(covariant LCeilingGuidePainter old) =>
      room != old.room ||
      colors != old.colors ||
      textScaler != old.textScaler ||
      activeDimension != old.activeDimension;
}
