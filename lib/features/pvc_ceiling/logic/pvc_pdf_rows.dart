import 'dart:convert';
import 'pvc_ceiling_calculator.dart';

class PvcPdfRows {
  const PvcPdfRows(this.first, this.last, this.row, this.stocks);
  final int first, last;
  final PvcPlankRow row;
  final List<double> stocks;
  int get quantity => last - first + 1;
}

/// Group adjacent equivalent rows; rounding only removes sub-epsilon float noise.
List<PvcPdfRows> pvcPdfRows(Layout layout) {
  final sources = pvcInstalledStocks(layout), result = <PvcPdfRows>[];
  var index = 0;
  String? previous;
  for (var i = 0; i < layout.layoutRows.length; i++) {
    final row = layout.layoutRows[i];
    final count =
        row.segments.fold<int>(0, (n, segment) => n + segment.pieces.length);
    final stocks =
        List<double>.unmodifiable(sources.sublist(index, index + count));
    index += count;
    final key = jsonEncode([
      row.width.toStringAsFixed(8),
      stocks,
      for (final segment in row.segments)
        [
          segment.x0.toStringAsFixed(8),
          segment.x1.toStringAsFixed(8),
          segment.pieces
        ]
    ]);
    if (key == previous) {
      final old = result.removeLast();
      result.add(PvcPdfRows(old.first, i + 1, old.row, old.stocks));
    } else {
      result.add(PvcPdfRows(i + 1, i + 1, row, stocks));
    }
    previous = key;
  }
  return result;
}
