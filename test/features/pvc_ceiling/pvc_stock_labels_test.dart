import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_painter.dart';

void main() {
  testWidgets(
      'Stock text is smaller and stacks or moves inline without clipping',
      (tester) async {
    final painter = CeilingPainter(runBest([10.0, 10.0, '10'])!, 1);
    final stacked = painter.pieceLabel(4, 12, const Size(240, 80))!;
    expect(stacked.text!.toPlainText(), '4 ft\n12f plank');
    final spans =
        (stacked.text! as TextSpan).children!.cast<TextSpan>().toList();
    expect(spans[1].style!.fontSize, lessThan(spans[0].style!.fontSize!));
    stacked.dispose();
    final inline = painter.pieceLabel(4, 10, const Size(300, 28))!;
    expect(inline.text!.toPlainText(), '4 ft  10f plank');
    expect(inline.height, lessThanOrEqualTo(24));
    inline.dispose();
    final compact = painter.pieceLabel(4, 12, const Size(90, 28))!;
    expect(compact.text!.toPlainText(), '4 ft');
    compact.dispose();
    expect(painter.pieceLabel(4, 12, const Size(10, 10)), isNull);
  });

  test('Centre and custom cuts use actual source stock in both directions', () {
    for (final direction in [PvcOrientation.length, PvcOrientation.width]) {
      final room = buildPvcRoom(
          PvcShape.rectangle,
          direction == PvcOrientation.length
              ? {'A': '21', 'B': '8'}
              : {'A': '8', 'B': '21'});
      for (final rule in [
        const PvcJointRule(mode: PvcJointMode.centre),
        const PvcJointRule(
            mode: PvcJointMode.custom, distanceFt: 10, fromEnd: true),
      ]) {
        final layout = runPvcCalculation(PvcCalculation(room, '12',
            orientation: direction, jointRule: rule))!;
        final originalCuts = layout.layoutRows
            .expand((r) => r.segments)
            .expand((s) => s.pieces)
            .toList();
        final sources = pvcInstalledStocks(layout);
        expect(sources, List.filled(originalCuts.length, 12));
        expect(
            layout.layoutRows.expand((r) => r.segments).expand((s) => s.pieces),
            originalCuts);
      }
    }
  });
  test('Every diagram stock label consumes a real planned cut', () {
    for (final shape in PvcShape.values) {
      for (final mode in ['10', '12', 'mix']) {
        final layout = runPvcCalculation(
            PvcCalculation(buildPvcRoom(shape, pvcDefaults(shape)), mode))!;
        final sources = pvcInstalledStocks(layout);
        final expected = <(double, double), int>{};
        for (final plank in layout.plan) {
          for (var i = 0; i < layout.sizes.length; i++) {
            final key = (plank.stock, layout.sizes[i]);
            expected[key] = (expected[key] ?? 0) + plank.counts[i];
          }
        }
        final actual = <(double, double), int>{};
        var index = 0;
        for (final row in layout.layoutRows) {
          for (final segment in row.segments) {
            for (final piece in segment.pieces) {
              final stock = sources[index++];
              expect(stock, greaterThanOrEqualTo(piece));
              final key = (stock, piece);
              actual[key] = (actual[key] ?? 0) + 1;
            }
          }
        }
        expected.removeWhere((key, value) => value == 0);
        expect(actual, expected);
        expect(sources.length, index);
        expect(pvcInstalledStocks(layout), sources);
      }
    }
  });

  Layout mixedSameSize(List<PlanItem> plan) => Layout(
      dir: 'length',
      run: 12,
      across: kPW,
      rowsCount: 1,
      rows: const RowInfo(1, 0, true),
      pcs: const [4, 4, 4],
      sizes: const [4],
      plan: plan,
      total: 22,
      joints: 2,
      polygon: [
        pvcPoint(0, 0),
        pvcPoint(12, 0),
        pvcPoint(12, kPW),
        pvcPoint(0, kPW)
      ],
      layoutRows: const [
        PvcPlankRow(0, kPW, [
          PvcPlankSegment(0, 12, [4, 4, 4])
        ])
      ],
      pieceTotal: 12);

  test('Equal cut lengths can originate from different stock lengths', () {
    final layout = mixedSameSize(const [
      PlanItem(10, [2]),
      PlanItem(12, [1])
    ]);
    expect(pvcInstalledStocks(layout), [12, 10, 10]);
    expect(layout.layoutRows.single.segments.single.pieces, [4, 4, 4]);
    expect(layout.total, 22);
  });

  test('Inconsistent stock demand fails instead of inventing labels', () {
    expect(
        () => pvcInstalledStocks(mixedSameSize(const [
              PlanItem(10, [2])
            ])),
        throwsStateError);
    expect(
        () => pvcInstalledStocks(mixedSameSize(const [
              PlanItem(10, [4])
            ])),
        throwsStateError);
  });
}
