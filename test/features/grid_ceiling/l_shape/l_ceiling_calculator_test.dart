import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/l_shape/l_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/l_shape/l_ceiling_result.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/l_shape/l_ceiling_room.dart';

LCeilingRoom room(
        {double width = 3600,
        double length = 3000,
        double arm = 1800,
        double depth = 1200,
        MissingCorner corner = MissingCorner.topRight}) =>
    LCeilingRoom(
        widthMm: width,
        lengthMm: length,
        verticalArmWidthMm: arm,
        horizontalArmDepthMm: depth,
        missingCorner: corner);

void main() {
  test('Arm field validation stays aligned with backend limits', () {
    for (final input in ['', '0', '-1', '1.5', 'text', '3600', '40000']) {
      expect(
          LCeilingRoom.armInputError(input, '3600', vertical: true), isNotNull);
    }
    expect(LCeilingRoom.armInputError('1800', '3600', vertical: true), isNull);
    expect(LCeilingRoom.armInputError('1200', '3000', vertical: false), isNull);
    expect(LCeilingRoom.armInputError('1200', '', vertical: false), isNotNull);
  });
  test(
      'Maximum room size has finite, bounded geometry and complete area coverage',
      () {
    final result = LCeilingCalculator.calculate(
        room(width: 40000, length: 40000, arm: 19995, depth: 19995));
    expect(result.tiles.length, lessThan(5000));
    expect(result.sections.length, lessThan(5000));
    expect(
        result.tiles
            .fold<double>(0, (a, t) => a + ceilingPolygonArea(t.footprint)),
        closeTo(result.room.areaMm2, .01));
    for (final tile in result.tiles) {
      expect(tile.cutWidthMm, inInclusiveRange(0.00001, 595));
      expect(tile.cutHeightMm, inInclusiveRange(0.00001, 595));
    }
  });
  test('Hand-counted aligned L uses one grid, not two overlapping rectangles',
      () {
    final result =
        LCeilingCalculator.calculate(room(), mode: PlacementMode.oneSide);
    expect(result.areaM2, 7.56);
    expect(result.areaSqFt, closeTo(7560000 / 92903.04, 1e-9));
    expect(result.room.perimeterMm, 13200);
    expect(result.mainRunnerPieces, 2); // (3000 + 1200) / 3048, rounded up.
    expect(result.fourFootPieces, 6);
    expect(result.twoFootPieces, 12);
    expect(result.fourFootBeforeOptimization, 9);
    expect(result.fullTiles, 21);
    expect(result.cutTiles, 0);
    expect(result.tilesToBuy, 21);
    expect(result.wallAnglePieces, 5);
    expect(result.hangerWires, 11);
    expect(result.requiresPerimeterJunction, isFalse);
    expect(
        result.sections
            .where((s) => s.stock == LCeilingStock.main10ft)
            .map((s) => s.lengthMm),
        [3000.0, 1200.0]);
    expect(
        result.sections
            .any((s) => s.start.y == 1800 && s.end.y == 1800 && s.end.x > 1800),
        isFalse);
  });

  test('Inner-corner notched tile remains one tile, not two rectangle cuts',
      () {
    final result = LCeilingCalculator.calculate(
        room(width: 2400, length: 2400, arm: 1500, depth: 1500),
        mode: PlacementMode.oneSide);
    expect(result.tiles.length, 15);
    expect(result.fullTiles, 12);
    expect(result.cutTiles, 3);
    expect(result.tiles.where((t) => t.footprint.length == 6).length, 1);
    expect(
        result.tiles.fold<double>(
            0, (sum, tile) => sum + ceilingPolygonArea(tile.footprint)),
        4950000);
    expect(result.tilesToBuy, lessThanOrEqualTo(result.tiles.length));
  });

  test('Compatible border offcuts are reused across the complete L', () {
    final result = LCeilingCalculator.calculate(
        room(width: 2690, length: 3290, arm: 1490, depth: 1490),
        mode: PlacementMode.oneSide);
    expect(result.cutTiles, greaterThan(0));
    expect(result.tilesToBuy, lessThan(result.tiles.length));
    final withLoss = LCeilingCalculator.calculate(result.room,
        mode: result.mode, cuttingAllowanceMm: 20);
    expect(withLoss.tilesToBuy, greaterThanOrEqualTo(result.tilesToBuy));
    expect(withLoss.tiles.length, result.tiles.length);
    expect(withLoss.sections.length, result.sections.length);
  });

  for (final mode in PlacementMode.values) {
    test('$mode: all four missing corners mirror geometry and quantities', () {
      final baseRoom = room(width: 4567, length: 3445, arm: 1650, depth: 1400);
      final base = LCeilingCalculator.calculate(baseRoom, mode: mode);
      for (final corner in MissingCorner.values) {
        final mirrored = LCeilingCalculator.calculate(
            room(
                width: 4567,
                length: 3445,
                arm: 1650,
                depth: 1400,
                corner: corner),
            mode: mode);
        expect(mirrored.tilesToBuy, base.tilesToBuy);
        expect(mirrored.mainRunnerPieces, base.mainRunnerPieces);
        expect(mirrored.fourFootPieces, base.fourFootPieces);
        expect(mirrored.twoFootPieces, base.twoFootPieces);
        expect(
            mirrored.tiles.map((t) => ceilingPolygonArea(t.footprint)),
            orderedEquals(
                base.tiles.map((t) => ceilingPolygonArea(t.footprint))));
        for (var i = 0; i < base.sections.length; i++) {
          expect(mirrored.sections[i].start,
              mirrored.room.toWorld(base.sections[i].start));
          expect(mirrored.sections[i].end,
              mirrored.room.toWorld(base.sections[i].end));
        }
      }
    });

    test(
        '$mode: clipped sections, tile coverage and stock counts stay consistent',
        () {
      final random = math.Random(492);
      for (var iteration = 0; iteration < 35; iteration++) {
        final w = 800.0 + random.nextInt(8000);
        final h = 800.0 + random.nextInt(8000);
        final arm = 20 + random.nextDouble() * (w - 40);
        final depth = 20 + random.nextDouble() * (h - 40);
        final r = LCeilingCalculator.calculate(
            room(width: w, length: h, arm: arm, depth: depth),
            mode: mode);
        expect(
            r.tiles
                .fold<double>(0, (a, t) => a + ceilingPolygonArea(t.footprint)),
            closeTo(r.room.areaMm2, .01));
        expect(r.tilesToBuy, inInclusiveRange(r.fullTiles, r.tiles.length));
        final seen = <String>{};
        for (final section in r.sections) {
          expect(section.lengthMm, greaterThan(0));
          expect(seen.add('${section.start}-${section.end}'), isTrue);
          if (section.stock == LCeilingStock.cross2ft) {
            expect(section.lengthMm, lessThanOrEqualTo(600.00001));
          } else if (section.stock == LCeilingStock.cross4ft) {
            expect(section.lengthMm, lessThanOrEqualTo(1200.00001));
          }
          for (final fraction in [0.0, .25, .5, .75, 1.0]) {
            final x =
                section.start.x + (section.end.x - section.start.x) * fraction;
            final y =
                section.start.y + (section.end.y - section.start.y) * fraction;
            expect(x, inInclusiveRange(0, w));
            expect(y, inInclusiveRange(0, h));
            expect(x > arm + .00001 && y < h - depth - .00001, isFalse);
          }
        }
        expect(
            r.sections.where((s) => s.stock == LCeilingStock.cross4ft).length,
            r.fourFootPieces);
        expect(
            r.sections.where((s) => s.stock == LCeilingStock.cross2ft).length,
            r.twoFootPieces);
        expect(() => r.sections.clear(), throwsUnsupportedError);
        expect(() => r.tiles.first.footprint.clear(), throwsUnsupportedError);
      }
    });
  }

  test('Invalid dimensions and cutting allowances fail before calculation', () {
    for (final value in [
      double.nan,
      double.infinity,
      0.0,
      -1.0,
      799.0,
      40001.0
    ]) {
      expect(() => room(width: value), throwsArgumentError);
      expect(() => room(length: value), throwsArgumentError);
    }
    for (final value in [double.nan, double.infinity, 0.0, -1.0, 3600.0]) {
      expect(() => room(arm: value), throwsArgumentError);
    }
    for (final value in [double.nan, double.infinity, 0.0, -1.0, 3000.0]) {
      expect(() => room(depth: value), throwsArgumentError);
    }
    for (final value in [double.nan, double.infinity, -1.0]) {
      expect(
          () => LCeilingCalculator.calculate(room(), cuttingAllowanceMm: value),
          throwsArgumentError);
    }
  });

  test('L calculation cannot change an existing rectangular result', () {
    final before = GridCeilingCalculator.calculate(4567, 3445,
        mode: PlacementMode.oneSide);
    LCeilingCalculator.calculate(room());
    final after = GridCeilingCalculator.calculate(4567, 3445,
        mode: PlacementMode.oneSide);
    expect(after.optimizedTilesRequired, before.optimizedTilesRequired);
    expect(after.crossTSpans, before.crossTSpans);
    expect(after.mainRunnersWidth, before.mainRunnersWidth);
    expect(after.optimizedFourFootT, before.optimizedFourFootT);
    expect(after.optimizedTwoFootCrossT, before.optimizedTwoFootCrossT);
  });
}
