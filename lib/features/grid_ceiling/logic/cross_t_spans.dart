typedef CrossTSpan = ({double startMm, double endMm, bool usesTwoFoot});

/// Cut perimeter bays may split at a system-compatible existing divider joint.
List<CrossTSpan> crossTSpans({
  required double roomWidthMm,
  required List<double> mainPositionsMm,
  required List<double> twoFootPositionsMm,
}) {
  final mains = mainPositionsMm.where((p) => p > 0 && p < roomWidthMm).toList()
    ..sort();
  final boundaries = [0.0, ...mains, roomWidthMm];
  final spans = <CrossTSpan>[];
  for (var i = 0; i < boundaries.length - 1; i++) {
    final start = boundaries[i], end = boundaries[i + 1];
    if (end <= start) continue;
    final edge = mains.isNotEmpty && (i == 0 || i == boundaries.length - 2);
    double? joint;
    // Keep full 1200 mm bays and internal spans intact.
    if (edge && end - start > 600 && end - start < 1200) {
      for (final divider in twoFootPositionsMm) {
        if (divider > start &&
            divider < end &&
            divider - start <= 600 &&
            end - divider <= 600) {
          joint = divider;
          break;
        }
      }
    }
    if (joint != null) {
      spans.addAll([
        (startMm: start, endMm: joint, usesTwoFoot: true),
        (startMm: joint, endMm: end, usesTwoFoot: true),
      ]);
    } else {
      spans.add((
        startMm: start,
        endMm: end,
        usesTwoFoot: edge && end - start <= 600
      ));
    }
  }
  return List.unmodifiable(spans);
}
