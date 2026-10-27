part of 'pvc_ceiling_calculator.dart';

/// Global joint coordinate in the selected plank direction, in feet.
double? pvcJointPosition(
    List<PvcPoint> polygon, PvcOrientation orientation, PvcJointRule rule) {
  if (rule.mode == PvcJointMode.automatic) return null;
  if (orientation == PvcOrientation.automatic) {
    throw ArgumentError('Choose length (A) or width (B) for the joint line.');
  }
  final bounds = pvcBounds(polygon);
  final start = orientation == PvcOrientation.length ? bounds.x0 : bounds.y0;
  final run =
      orientation == PvcOrientation.length ? bounds.width : bounds.height;
  final distance = rule.mode == PvcJointMode.centre ? run / 2 : rule.distanceFt;
  if (distance == null ||
      !distance.isFinite ||
      distance <= 0 ||
      distance >= run) {
    throw ArgumentError('Joint distance must be above 0 and below $run ft.');
  }
  return start + (rule.fromEnd ? run - distance : distance);
}

List<List<double>> _jointSplits(
    double start, double end, double? joint, double mn, List<double> stocks,
    [double? preferredStock]) {
  final crosses = joint != null && joint > start + kEps && joint < end - kEps;
  final lengths = crosses ? [joint - start, end - joint] : [end - start];
  if (crosses && lengths.any((l) => l < mn - kEps)) {
    throw ArgumentError('The joint line creates a piece shorter than $mn ft. '
        'Move the line or choose another installation direction.');
  }
  if (preferredStock != null) {
    return [
      [for (final l in lengths) ..._minSplit(l, stocks, mn, preferredStock)]
    ];
  }
  return _product([for (final l in lengths) splitsFor(l, mn, stocks)], 400)
      .map((parts) => parts.expand((p) => p).toList())
      .toList();
}
