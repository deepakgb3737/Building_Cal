import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../ui/app_typography.dart';
import '../../../../ui/app_styles.dart';
import '../../logic/grid_ceiling_calculator.dart';
import '../../logic/l_shape/l_ceiling_result.dart';
import 'l_ceiling_drawing.dart';

class LCeilingResults extends StatelessWidget {
  final LCeilingResult result;
  final ValueChanged<bool> onInteractionChanged;
  const LCeilingResults(
      {super.key, required this.result, required this.onInteractionChanged});

  static const junctionNotice =
      'Edge split quantities assume compatible 2ft-to-2ft junctions at the existing dividers. Confirm with your grid supplier before ordering.';
  String get orderList => [
        'L-shaped ceiling order estimate',
        'Area: ${result.areaM2.toStringAsFixed(2)} m² / ${result.areaSqFt.toStringAsFixed(2)} sq ft',
        'Ceiling tiles (595 mm): ${result.tilesToBuy} pcs',
        '10ft main runners: ${result.mainRunnerPieces} pcs',
        '4ft cross Ts: ${result.fourFootPieces} pcs',
        '2ft cross Ts: ${result.twoFootPieces} pcs',
        'Wall angles (3048 mm): ${result.wallAnglePieces} pcs',
        'Hanger wires: ${result.hangerWires} pcs (perimeter estimate)',
        if (result.requiresPerimeterJunction) junctionNotice,
        'Purchases are estimates, not a minimum cutting schedule. Confirm with your supplier.',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget panel(Widget child) => Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: colors.outlineVariant),
              borderRadius: AppRadii.r14),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        );
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(label, style: AppTypography.text14W600Text)),
            const SizedBox(width: 12),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: AppTypography.text14W600Text)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Total area', style: AppTypography.text17W700Text),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final value in [
          '${result.areaSqFt.toStringAsFixed(2)} sq ft',
          '${result.areaM2.toStringAsFixed(2)} m²'
        ])
          panel(Text(value, style: AppTypography.text17W700Text)),
      ]),
      const SizedBox(height: 8),
      Text(
          result.mode == PlacementMode.oneSide
              ? 'L-shape · From one wall'
              : 'L-shape · Centered on overall dimensions',
          style: AppTypography.text14Secondarytext),
      const SizedBox(height: 16),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('What to buy', style: AppTypography.text17W700Text)),
          TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: orderList));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order list copied')));
                }
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy list')),
        ]),
        row('Ceiling tiles · 595 × 595 mm', '${result.tilesToBuy} pcs'),
        const Divider(height: 1),
        row('10ft main runners', '${result.mainRunnerPieces} pcs'),
        row('4ft cross Ts', '${result.fourFootPieces} pcs'),
        row('2ft cross Ts', '${result.twoFootPieces} pcs'),
        row('Wall angles · 3048 mm', '${result.wallAnglePieces} pcs'),
        row('Hanger wires · estimate', '${result.hangerWires} pcs'),
        const Text(
            'Purchase estimates include offcut reuse. Notched tiles reserve their bounding rectangle; minimum purchasing is not guaranteed. Confirm fittings and suspension with your supplier.',
            style: AppTypography.text14Secondarytext),
        if (result.requiresPerimeterJunction) ...[
          const SizedBox(height: 8),
          const Text(junctionNotice, style: AppTypography.text14Secondarytext),
        ],
      ])),
      const SizedBox(height: 16),
      panel(LCeilingDrawing(
          result: result, onInteractionChanged: onInteractionChanged)),
      const SizedBox(height: 16),
      panel(Column(children: [
        ExpansionTile(
            title: const Text('Tile breakdown'),
            tilePadding: EdgeInsets.zero,
            children: [
              row('Tile positions', '${result.tiles.length}'),
              row('Full pieces', '${result.fullTiles}'),
              row('Cut pieces', '${result.cutTiles}'),
              const Text('Fitted pieces are not extra tiles to buy.',
                  style: AppTypography.text14Secondarytext)
            ]),
        ExpansionTile(
            title: const Text('Runner lengths'),
            tilePadding: EdgeInsets.zero,
            children: [
              const Text(
                  'Actual clipped lengths. Stock purchasing uses total length ÷ 3048, rounded up; confirm joints and cut reuse before ordering.',
                  style: AppTypography.text14Secondarytext),
              for (final s in result.sections
                  .where((s) => s.stock == LCeilingStock.main10ft))
                row('Main at ${s.start.x.round()} mm across',
                    '${s.lengthMm.round()} mm'),
            ]),
        const ExpansionTile(
            title: Text('Installation notes'),
            tilePadding: EdgeInsets.zero,
            children: [
              Text(
                  'Keep one continuous grid across both arms. Fix wall angles along all six edges, including the inner corner. Check levels, actual openings, compatible joints and suspension with your installer before cutting.',
                  style: AppTypography.text14Secondarytext)
            ]),
      ])),
    ]);
  }
}
