import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/tile_purchase_optimizer.dart';

int purchase(List<TileCut> cuts, {double allowance = 0}) =>
    TilePurchaseOptimizer.count(cuts,
        tileSizeMm: 595, cuttingAllowanceMm: allowance);

void main() {
  test('Opposite 290 mm strips reuse one tile when allowance permits', () {
    const cuts = [(width: 290.0, height: 595.0), (width: 290.0, height: 595.0)];
    expect(purchase(cuts), 1);
    expect(purchase(cuts, allowance: 3), 1);
    expect(purchase(cuts, allowance: 15), 1);
    expect(purchase(cuts, allowance: 15.1), 2);
  });
  test('Unequal edge strips share compatible leftovers', () {
    expect(
        purchase([(width: 200, height: 595), (width: 390, height: 595)],
            allowance: 3),
        1);
    expect(purchase([(width: 300, height: 595), (width: 300, height: 595)]), 2);
  });
  test('Corner pieces reuse an offcut without counting it twice', () {
    expect(
        purchase([
          (width: 300, height: 595),
          (width: 290, height: 290),
          (width: 290, height: 290),
        ], allowance: 3),
        1);
  });
  test('Rotated cuts fit the same offcut', () {
    expect(purchase([(width: 290, height: 595), (width: 595, height: 290)]), 1);
  });
  test('Empty cuts need no tiles; invalid dimensions and allowances fail', () {
    expect(purchase([]), 0);
    for (final allowance in [-1.0, double.nan, double.infinity]) {
      expect(() => purchase([], allowance: allowance), throwsArgumentError);
    }
    for (final cut in [
      (width: 0.0, height: 200.0),
      (width: 596.0, height: 200.0),
      (width: double.nan, height: 200.0),
    ]) {
      expect(() => purchase([cut]), throwsArgumentError);
    }
  });
  test('One-side Buy Tiles reuses edge strips and counts the corner once', () {
    final result = GridCeilingCalculator.calculate(2690, 2690,
        mode: PlacementMode.oneSide, cuttingAllowanceMm: 3);
    expect(result.fullTilesRequired, 16);
    expect(result.cutTilesRequired, 9);
    expect(result.tilesRequired, 25);
    expect(result.optimizedTilesRequired, 21);
    expect(result.widthEdgeCutSizeMm, 290);
    expect(result.lengthEdgeCutSizeMm, 290);
  });
  test('Centered corner cuts are not added to both edge purchase counts', () {
    final result = GridCeilingCalculator.calculate(2438, 3200);
    expect(result.optimizedTilesRequired, 30);
    expect(result.fullTilesRequired, 12);
    expect(result.cutTilesRequired, 18);
  });
  test('No edge cuts means no extra purchase tiles', () {
    final result = GridCeilingCalculator.calculate(2400, 2400,
        mode: PlacementMode.oneSide);
    expect(result.optimizedTilesRequired, 16);
  });
}
