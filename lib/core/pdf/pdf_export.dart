import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

typedef PdfExportPage = ({Uint8List png, bool landscape});

/// Shared, sequential packaging of print-resolution drawing/report pages.
class BuildCalcPdfExport {
  static String filename(String projectName) {
    final safe = String.fromCharCodes(projectName.trim().runes.take(50))
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '');
    return 'BuildCalc_${safe.isEmpty ? 'Floor_plan' : safe}.pdf';
  }

  static Future<Uint8List> build(
          {required Uint8List png,
          required String projectName,
          required bool landscape}) =>
      buildPages(
          pages: Stream.value((png: png, landscape: landscape)),
          projectName: projectName);

  static Future<Uint8List> buildPages(
      {required Stream<PdfExportPage> pages,
      required String projectName}) async {
    final pdf = pw.Document(
        title: projectName, author: 'BuildCalc', creator: 'BuildCalc');
    var count = 0;
    await for (final page in pages) {
      if (++count > 200) throw ArgumentError('The PDF exceeds 200 pages.');
      final png = page.png;
      if (png.length < 8 ||
          png[0] != 137 ||
          png[1] != 80 ||
          png[2] != 78 ||
          png[3] != 71) {
        throw ArgumentError('A rendered plan image is required.');
      }
      final image = pw.MemoryImage(png);
      pdf.addPage(pw.Page(
          pageFormat:
              page.landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
    }
    if (count == 0) throw ArgumentError('The PDF requires at least one page.');
    return pdf.save();
  }
}
