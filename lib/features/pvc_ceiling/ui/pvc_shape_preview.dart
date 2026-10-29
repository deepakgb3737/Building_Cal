part of 'pvc_ceiling_painter.dart';

class PvcShapePreview extends StatelessWidget {
  const PvcShapePreview(
      {super.key,
      required this.room,
      this.active,
      this.thumbnail = false,
      this.joint,
      this.orientation = PvcOrientation.length});
  final PvcRoom room;
  final String? active;
  final bool thumbnail;
  final double? joint;
  final PvcOrientation orientation;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final available = MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom;
        final maxHeight = (available * .35).clamp(240.0, 280.0);
        final height =
            thumbnail ? 88.0 : (box.maxWidth * .6).clamp(240.0, maxHeight);
        final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
        final bounds = pvcBounds(room.points);
        final alongLength = orientation == PvcOrientation.length;
        final start = alongLength ? bounds.x0 : bounds.y0;
        final run = alongLength ? bounds.width : bounds.height;
        final painter = PvcShapePreviewPainter(room, active,
            joint: joint,
            orientation: orientation,
            textScale: textScale,
            thumbnail: thumbnail);
        return Semantics(
            label:
                '${room.shape.label} dimension diagram. Letters match the input fields. ${thumbnail ? '' : room.edges.keys.map(painter.labelText).join(', ')}',
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: height,
                  width: double.infinity,
                  child: CustomPaint(painter: painter)),
              if (joint != null)
                Text(
                    'From ${alongLength ? "left" : "top"}: ${fmt(joint! - start)} ft · '
                    'From ${alongLength ? "right" : "bottom"}: ${fmt(run - (joint! - start))} ft',
                    key: const ValueKey('pvcJointPreviewPosition'),
                    textAlign: TextAlign.center,
                    style: AppTypography.text14Greymuted),
            ]));
      });
}

class PvcShapePreviewPainter extends CustomPainter {
  PvcShapePreviewPainter(this.room, this.active,
      {double textScale = 1,
      this.thumbnail = false,
      this.joint,
      this.orientation = PvcOrientation.length})
      : textScale = textScale.clamp(1, 1.5);
  final PvcRoom room;
  final String? active;
  final double textScale;
  final bool thumbnail;
  final double? joint;
  final PvcOrientation orientation;
  double get radius => (thumbnail ? 7 : 12) * textScale;

  String labelText(String key) {
    if (thumbnail) return key;
    final edge = room.edges[key]!;
    final a = room.points[edge.$1], b = room.points[edge.$2];
    return '$key · ${fmt(math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2)))} ft';
  }

  TextPainter _label(String key) => TextPainter(
      text: TextSpan(
          text: labelText(key),
          style: AppTypography.input.copyWith(
              fontSize: (thumbnail ? 9 : 11) * textScale,
              fontWeight: FontWeight.w700,
              color: AppColors.white)),
      textDirection: TextDirection.ltr)
    ..layout();

  Size _labelSize(String key) {
    if (thumbnail) return Size.square(radius * 2);
    final text = _label(key);
    final size = Size(text.width + 12, math.max(radius * 2, text.height + 8));
    text.dispose();
    return size;
  }

  Map<String, Rect> labelBounds(Size size) => {
        for (final entry in labelCenters(size).entries)
          entry.key: Rect.fromCenter(
              center: entry.value,
              width: _labelSize(entry.key).width,
              height: _labelSize(entry.key).height)
      };

  List<Offset> _points(Size size, [List<PvcPoint>? source]) {
    final b = pvcBounds(room.points), padding = radius + (thumbnail ? 12 : 20);
    final scale = math.max(
        0.0,
        math.min((size.width - padding * 2) / b.width,
            (size.height - padding * 2) / b.height));
    final origin = Offset((size.width - b.width * scale) / 2,
        (size.height - b.height * scale) / 2);
    return (source ?? room.points)
        .map((p) => origin + Offset((p.x - b.x0) * scale, (p.y - b.y0) * scale))
        .toList();
  }

  Map<String, Offset> labelCenters(Size size) {
    final points = _points(size), path = Path()..addPolygon(points, true);
    final placed = <String, Offset>{};
    final occupied = <Rect>[];
    for (final entry in room.edges.entries) {
      final label = _labelSize(entry.key);
      final safe = Rect.fromLTRB(label.width / 2 + 3, label.height / 2 + 3,
          size.width - label.width / 2 - 3, size.height - label.height / 2 - 3);
      Rect box(Offset center) => Rect.fromCenter(
          center: center, width: label.width + 4, height: label.height + 4);
      final a = points[entry.value.$1],
          b = points[entry.value.$2],
          delta = b - a;
      final mid = (a + b) / 2;
      final tangent =
          delta.distance > .01 ? delta / delta.distance : const Offset(0, 1);
      var normal = Offset(-tangent.dy, tangent.dx);
      if (path.contains(mid + normal * 3)) normal = -normal;
      final candidates = <Offset>[
        for (final distance in [radius + 8, radius + 24, radius + 40])
          for (final shift in [0.0, -28.0, 28.0, -56.0, 56.0])
            mid + normal * distance + tangent * shift,
        for (var y = safe.top;
            y <= safe.bottom;
            y += thumbnail ? radius * 2 + 8 : 8)
          for (var x = safe.left;
              x <= safe.right;
              x += thumbnail ? radius * 2 + 8 : 8)
            Offset(x, y),
      ];
      candidates.sort((a, b) =>
          (a - mid).distanceSquared.compareTo((b - mid).distanceSquared));
      bool clear(Offset p) =>
          safe.contains(p) && !occupied.any((r) => r.overlaps(box(p)));
      bool outsideWalls(Offset p) {
        final bounds = box(p);
        if (path.contains(p) ||
            [
              bounds.topLeft,
              bounds.topRight,
              bounds.bottomLeft,
              bounds.bottomRight
            ].any(path.contains)) {
          return false;
        }
        for (var i = 0; i < points.length; i++) {
          final a = points[i], d = points[(i + 1) % points.length] - a;
          if (Rect.fromPoints(a, a + d).inflate(3).overlaps(bounds)) {
            return false;
          }
          final t = d.distanceSquared < .001
              ? 0.0
              : (((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared)
                  .clamp(0.0, 1.0);
          if ((p - (a + d * t)).distance < radius + 3) return false;
        }
        return true;
      }

      final available = candidates.where(clear).toList();
      if (available.isEmpty && !thumbnail) {
        // Crowded guides use ordered callouts rather than overlapping labels.
        final edges = room.edges.entries.toList()
          ..sort((a, b) => (points[a.value.$1].dy + points[a.value.$2].dy)
              .compareTo(points[b.value.$1].dy + points[b.value.$2].dy));
        final rowHeight =
            edges.map((edge) => _labelSize(edge.key).height).reduce(math.max) +
                6;
        final callouts = {
          for (var i = 0; i < edges.length; i++)
            edges[i].key: Offset(
                size.width / 2,
                (size.height - rowHeight * edges.length) / 2 +
                    rowHeight * (i + .5))
        };
        return {for (final key in room.edges.keys) key: callouts[key]!};
      }
      final center = available.where(outsideWalls).firstOrNull ??
          available.firstOrNull ??
          Offset(mid.dx.clamp(safe.left, safe.right),
              mid.dy.clamp(safe.top, safe.bottom));
      occupied.add(box(center));
      placed[entry.key] = center;
    }
    return placed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points(size), path = Path()..addPolygon(points, true);
    canvas.drawPath(path, _fill(AppColors.softSurface));
    canvas.drawPath(path, _stroke(AppColors.ink, 2));
    if (joint != null) {
      final b = pvcBounds(room.points);
      final ends = _points(
          size,
          orientation == PvcOrientation.length
              ? [pvcPoint(joint!, b.y0), pvcPoint(joint!, b.y0 + b.height)]
              : [pvcPoint(b.x0, joint!), pvcPoint(b.x0 + b.width, joint!)]);
      canvas.save();
      _dashLine(canvas, ends[0], ends[1],
          _stroke(AppColors.pvcJoint.withValues(alpha: .4), 1));
      canvas.clipPath(path);
      _dashLine(canvas, ends[0], ends[1], _stroke(AppColors.pvcJoint, 2));
      canvas.restore();
    }
    final labels = labelBounds(size);
    for (final entry in room.edges.entries) {
      final a = points[entry.value.$1],
          b = points[entry.value.$2],
          mid = (a + b) / 2;
      final selected = entry.key == active, bounds = labels[entry.key]!;
      final center = bounds.center;
      final color = selected ? AppColors.primary : AppColors.ink;
      canvas.drawLine(a, b, _stroke(color, selected ? 5 : 3));
      if ((center - mid).distance > radius + 8.5) {
        canvas.drawLine(mid, center, _stroke(AppColors.muted, 1));
      }
      canvas.drawRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
          _fill(color));
      final text = _label(entry.key);
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant PvcShapePreviewPainter old) =>
      old.room != room ||
      old.active != active ||
      old.textScale != textScale ||
      old.thumbnail != thumbnail ||
      old.joint != joint ||
      old.orientation != orientation;
}
