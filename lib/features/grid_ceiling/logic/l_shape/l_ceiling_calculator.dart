import 'dart:math' as math;
import '../ceiling_material_service.dart';
import '../cross_t_spans.dart';
import '../grid_ceiling_calculator.dart';
import '../tile_purchase_optimizer.dart';
import 'l_ceiling_room.dart';
import 'l_ceiling_result.dart';

/// Independent opt-in engine. Existing rectangle callers are unchanged.
abstract final class LCeilingCalculator {
  static LCeilingResult calculate(
    LCeilingRoom room, {
    PlacementMode mode = PlacementMode.centerBased,
    double cuttingAllowanceMm = 0,
  }) {
    if (!cuttingAllowanceMm.isFinite || cuttingAllowanceMm < 0) {
      throw ArgumentError('Cutting allowance must be finite and non-negative.');
    }
    final w = room.widthMm, h = room.lengthMm;
    final startX = GridCeilingCalculator.calculateTPlacement(w);
    final startY = GridCeilingCalculator.calculateTPlacement(h);
    final oneSide = mode == PlacementMode.oneSide;
    List<double> interior(List<double> values, double size) =>
        values.where((v) => v > 0 && v < size).toList();
    final mains = interior(
        oneSide
            ? GridCeilingCalculator.calculateMainRunnersOneSide(w)
            : GridCeilingCalculator.calculateMainRunners(startX, w),
        w);
    final rows = interior(
        oneSide
            ? GridCeilingCalculator.calculateCrossTOneSide(h)
            : GridCeilingCalculator.calculateCrossT(startY, h),
        h);
    final dividers = interior(
        oneSide
            ? GridCeilingCalculator.calculateTwoFootCrossTOneSide(w)
            : GridCeilingCalculator.calculateTwoFootCrossT(startX, w),
        w);
    final sections = <LCeilingSection>[];
    void add(CeilingPoint a, CeilingPoint b, LCeilingStock stock,
        {bool divider = false}) {
      if (a != b) {
        sections.add(LCeilingSection(room.toWorld(a), room.toWorld(b), stock,
            isDivider: divider));
      }
    }

    double topAt(double x) =>
        x >= room.verticalArmWidthMm ? room.notchBottomMm : 0;
    var mainLength = 0.0;
    for (final x in mains) {
      final top = topAt(x);
      add((x: x, y: top), (x: x, y: h), LCeilingStock.main10ft);
      mainLength += h - top;
    }
    var baselineFourFoot = 0;
    var junction = false;
    for (final y in rows) {
      // At the re-entrant corner, the outer horizontal ledge is wall angle.
      final right = y <= room.notchBottomMm ? room.verticalArmWidthMm : w;
      final localMains = mains.where((x) => x < right).toList();
      final localDividers = dividers.where((x) => x < right).toList();
      final spans = crossTSpans(
          roomWidthMm: right,
          mainPositionsMm: localMains,
          twoFootPositionsMm: localDividers);
      baselineFourFoot += localMains.length + 1;
      junction |= spans.length > localMains.length + 1;
      for (final span in spans) {
        add((x: span.startMm, y: y), (x: span.endMm, y: y),
            span.usesTwoFoot ? LCeilingStock.cross2ft : LCeilingStock.cross4ft);
      }
    }
    for (final x in dividers) {
      final cuts = [topAt(x), ...rows.where((y) => y > topAt(x)), h];
      for (var i = 0; i < cuts.length - 1; i++) {
        add((x: x, y: cuts[i]), (x: x, y: cuts[i + 1]), LCeilingStock.cross2ft,
            divider: true);
      }
    }

    List<double> gridEdges(double size, double first) {
      final edges = <double>[0];
      for (var p = first; p < size; p += 600) {
        edges.add(p);
      }
      return [...edges, size];
    }

    final xs = gridEdges(w, oneSide ? 600 : startX);
    final ys = gridEdges(h, oneSide ? 600 : startY);
    final tiles = <LCeilingTile>[];
    final cuts = <TileCut>[];
    const stock = 595.0;
    for (var x = 0; x < xs.length - 1; x++) {
      for (var y = 0; y < ys.length - 1; y++) {
        final polygon = clipCeilingCell(
            room.canonicalBoundary, xs[x], ys[y], xs[x + 1], ys[y + 1]);
        if (polygon.isEmpty) continue;
        final width = ceilingExtent(polygon.map((p) => p.x));
        final height = ceilingExtent(polygon.map((p) => p.y));
        final rectangular = polygon.length == 4;
        final full = rectangular && width >= stock && height >= stock;
        final cutWidth = math.min(width, stock),
            cutHeight = math.min(height, stock);
        tiles.add(
            LCeilingTile(polygon.map(room.toWorld), full, cutWidth, cutHeight));
        // shortcut: notch-shaped cuts reserve their bounding rectangle; an exact
        // nesting solver is needed before claiming minimum tile purchases.
        if (!full) cuts.add((width: cutWidth, height: cutHeight));
      }
    }
    final fullTiles = tiles.where((t) => t.isFull).length;
    return LCeilingResult(
        room: room,
        mode: mode,
        sections: sections,
        tiles: tiles,
        mainRunnerPieces:
            (mainLength / CeilingMaterialService.runnerLengthMm).ceil(),
        tilesToBuy: fullTiles +
            TilePurchaseOptimizer.count(cuts,
                tileSizeMm: stock, cuttingAllowanceMm: cuttingAllowanceMm),
        wallAnglePieces:
            (room.perimeterMm / CeilingMaterialService.runnerLengthMm).ceil(),
        hangerWires: (room.perimeterMm / 1200).ceil(),
        fourFootBeforeOptimization: baselineFourFoot,
        requiresPerimeterJunction: junction,
        cuttingAllowanceMm: cuttingAllowanceMm);
  }
}
