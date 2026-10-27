part of 'pvc_ceiling_calculator.dart';

bool _better(Layout a, Layout? b) {
  if (b == null) return true;
  // Finishing takes priority over offcut savings that introduce extra joints.
  if (a.joints != b.joints) return a.joints < b.joints;
  final d = a.total - b.total;
  if (d != 0) return d < 0;
  return a.count < b.count;
}

/// Candidate-limited polygon search, matching the supplied multi-layout HTML.
Layout? bestPolygon(List<PvcPoint> polygon, List<double> stocks,
    [double mn = kMinPiece,
    PvcOrientation orientation = PvcOrientation.automatic,
    PvcJointRule jointRule = const PvcJointRule()]) {
  if (polygon.length < 3 ||
      polygon.length > 16 ||
      polygon.any((p) => !p.x.isFinite || !p.y.isFinite) ||
      polygonArea(polygon) <= kEps ||
      stocks.isEmpty ||
      stocks.length > 2 ||
      stocks.any((s) => s != 10 && s != 12) ||
      stocks.toSet().length != stocks.length ||
      !mn.isFinite ||
      mn < 2) {
    throw ArgumentError(
        'Invalid room geometry, stock or minimum piece length.');
  }
  final originalBounds = pvcBounds(polygon);
  if (originalBounds.width > 200 || originalBounds.height > 200) {
    throw ArgumentError('Room dimensions exceed the supported range.');
  }
  Layout? res;
  final joint = pvcJointPosition(polygon, orientation, jointRule);
  for (final turned in [false, true]) {
    if (orientation == PvcOrientation.length && turned ||
        orientation == PvcOrientation.width && !turned) {
      continue;
    }
    final p =
        turned ? polygon.map((p) => pvcPoint(p.y, p.x)).toList() : polygon;
    final bb = pvcBounds(p), wl = rowsFor(bb.height);
    if (!wl.ok || wl.n <= 0) continue;
    final hs = wl.edge > 0
        ? [wl.edge, ...List.filled(wl.n - 2, kPW), wl.edge]
        : List.filled(wl.n, kPW);
    var yy = bb.y0;
    final raw = <({double y0, double y1, List<(double, double)> iv})>[];
    for (final h in hs) {
      raw.add((y0: yy, y1: yy + h, iv: pvcRowIntervals(p, yy, yy + h)));
      yy += h;
    }
    if (raw.any((r) => r.iv.isEmpty)) continue;
    (double, double) spanKey((double, double) iv) =>
        joint == null ? (0.0, r3(iv.$2 - iv.$1)) : iv;
    final keys = raw.expand((r) => r.iv.map(spanKey)).toSet().toList()
      ..sort((a, b) {
        final length = (b.$2 - b.$1).compareTo(a.$2 - a.$1);
        return length != 0 ? length : a.$1.compareTo(b.$1);
      });
    List<List<List<double>>> combos;
    if (keys.length <= 3) {
      final cap = keys.length == 1
          ? 1000000000
          : keys.length == 2
              ? 20
              : 7;
      final lists = keys.map((l) {
        final splits = joint == null
            ? splitsFor(l.$2, mn, stocks)
            : _jointSplits(l.$1, l.$2, joint, mn, stocks);
        if (splits.isEmpty) return <List<double>>[];
        final fewest = splits.map((s) => s.length).reduce(math.min);
        return _trim(splits.where((s) => s.length == fewest).toList(), cap);
      }).toList();
      if (lists.any((l) => l.isEmpty)) continue;
      combos = _product(lists, 400);
    } else {
      combos = [
        for (final kind in <double?>[null, ...stocks])
          keys
              .map((l) => joint == null
                  ? _minSplit(l.$2, stocks, mn, kind)
                  : _jointSplits(l.$1, l.$2, joint, mn, stocks,
                          kind ?? stocks.reduce(math.max))
                      .first)
              .toList()
      ];
    }
    final index = {for (var i = 0; i < keys.length; i++) keys[i]: i};
    Layout? best;
    for (final combo in combos) {
      final counts = <double, int>{};
      var joints = 0;
      final rows = <PvcPlankRow>[];
      for (final row in raw) {
        final segs = <PvcPlankSegment>[];
        for (final iv in row.iv) {
          final pieces = combo[index[spanKey(iv)]!];
          for (final p in pieces) {
            final q = r3(p);
            counts[q] = (counts[q] ?? 0) + 1;
          }
          joints += pieces.length - 1;
          segs.add(PvcPlankSegment(iv.$1, iv.$2, pieces.map(r3).toList()));
        }
        rows.add(PvcPlankRow(row.y0, row.y1, segs));
      }
      final sizes = counts.keys.toList();
      final plan =
          _packing(sizes, sizes.map((s) => counts[s]!).toList(), stocks);
      if (plan == null) continue;
      final candidate = Layout(
          dir: turned ? 'width' : 'length',
          run: bb.width,
          across: bb.height,
          rowsCount: wl.n,
          rows: wl,
          pcs: rows.first.segments.first.pieces,
          sizes: sizes,
          plan: plan,
          total: plan.fold(0.0, (s, p) => s + p.stock),
          joints: joints,
          alignedJoint: joint,
          polygon: p,
          layoutRows: rows,
          pieceTotal: rows.fold(
              0.0,
              (s, r) =>
                  s +
                  r.segments.fold(
                      0.0, (s, g) => s + g.pieces.fold(0.0, (s, p) => s + p))));
      if (_better(candidate, best)) best = candidate;
    }
    if (best != null && _better(best, res)) res = best;
  }
  return res;
}
