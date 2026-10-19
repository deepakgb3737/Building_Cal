import 'dart:math' as math;

typedef TileCut = ({double width, double height});

abstract final class TilePurchaseOptimizer {
  /// Reuses disjoint rectangular offcuts. Allowance is lost per cutting line.
  static int count(Iterable<TileCut> pieces,
      {required double tileSizeMm, double cuttingAllowanceMm = 0}) {
    if (!tileSizeMm.isFinite ||
        tileSizeMm <= 0 ||
        !cuttingAllowanceMm.isFinite ||
        cuttingAllowanceMm < 0) {
      throw ArgumentError('Tile size and cutting allowance must be valid.');
    }
    final cuts = pieces.toList();
    for (final cut in cuts) {
      if (!cut.width.isFinite ||
          !cut.height.isFinite ||
          cut.width <= 0 ||
          cut.height <= 0 ||
          cut.width > tileSizeMm ||
          cut.height > tileSizeMm) {
        throw ArgumentError('Every cut must fit within a source tile.');
      }
    }
    cuts.sort((a, b) {
      final longest =
          math.max(b.width, b.height).compareTo(math.max(a.width, a.height));
      return longest != 0
          ? longest
          : (b.width * b.height).compareTo(a.width * a.height);
    });
    final offcuts = <TileCut>[];
    var tiles = 0;
    // shortcut: guillotine best-fit is not a global minimum; use an exact solver if certified minimum purchasing is required.
    for (final cut in cuts) {
      var best = -1;
      var placed = cut;
      var waste = double.infinity;
      for (var i = 0; i < offcuts.length; i++) {
        final space = offcuts[i];
        for (final candidate in [cut, (width: cut.height, height: cut.width)]) {
          if (candidate.width <= space.width &&
              candidate.height <= space.height) {
            final remaining =
                space.width * space.height - cut.width * cut.height;
            if (remaining < waste) {
              waste = remaining;
              best = i;
              placed = candidate;
            }
          }
        }
      }
      final space = best < 0
          ? (width: tileSizeMm, height: tileSizeMm)
          : offcuts.removeAt(best);
      if (best < 0) {
        tiles++;
      }
      final right =
          math.max(0.0, space.width - placed.width - cuttingAllowanceMm);
      final bottom =
          math.max(0.0, space.height - placed.height - cuttingAllowanceMm);
      void keep(double width, double height) {
        if (width > 0 && height > 0) {
          offcuts.add((width: width, height: height));
        }
      }

      if (right * space.height >= bottom * space.width) {
        keep(right, space.height);
        keep(placed.width, bottom);
      } else {
        keep(right, placed.height);
        keep(space.width, bottom);
      }
    }
    return tiles;
  }
}
