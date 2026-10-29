import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:grid_ceiling_calculator/core/pdf/pdf_export.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_pdf_rows.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_projects.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_pdf_renderer.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';

PvcProjectData pdfSettings(
        {PvcShape shape = PvcShape.rectangle,
        String joint = 'automatic',
        String orientation = 'automatic'}) =>
    PvcProjectData.fromJson({
      'shape': shape.name,
      'values': pvcDefaults(shape),
      'stock': 'mix',
      'corner': 'tl',
      'orientation': orientation,
      'joint': joint,
      'distance': '4',
      'fromEnd': true,
    });

String layoutSignature(Layout layout) => jsonEncode([
      layout.q10,
      layout.q12,
      layout.area,
      layout.waste,
      layout.joints,
      layout.pcs,
      layout.sizes,
      layout.alignedJoint,
      for (final row in layout.layoutRows)
        [
          row.y0,
          row.y1,
          for (final segment in row.segments)
            [segment.x0, segment.x1, segment.pieces]
        ],
      for (final item in layout.plan) [item.stock, item.counts],
    ]);

void main() {
  test('Room summary retains original dimensions when planks rotate', () {
    final settings = PvcProjectData.fromJson({
      ...pdfSettings(orientation: 'width').toJson(),
      'values': {'A': '21', 'B': '11'}
    });
    final layout = runPvcCalculation(settings.request)!;
    expect(layout.turned, isTrue);
    final cards = PvcPdfRenderer.roomMeasurements(layout, settings);
    expect(cards, [
      (label: 'Length (A)', value: '21 ft', detail: '6.4 m'),
      (label: 'Width (B)', value: '11 ft', detail: '3.35 m'),
      (label: 'Room area (sq ft)', value: '231', detail: null),
      (label: 'Room area (sq m)', value: '21.46', detail: null),
    ]);
  });
  test('Irregular room summary distinguishes extents from actual area', () {
    final settings = pdfSettings(shape: PvcShape.l, orientation: 'width');
    final layout = runPvcCalculation(settings.request)!;
    final cards = PvcPdfRenderer.roomMeasurements(layout, settings);
    expect(cards.first.label, 'Overall length');
    expect(cards.first.value, '16 ft');
    expect(cards[1].label, 'Overall width');
    expect(cards[1].value, '12 ft');
    expect(cards[2].value, '162');
    expect(cards[3].value, '15.05');
  });
  test(
      'Shared engine rejects overlong or failed streams, never returns partial PDF',
      () async {
    final first = (
      png: image.encodePng(image.Image(width: 1, height: 1)),
      landscape: false
    );
    await expectLater(
        BuildCalcPdfExport.buildPages(
            pages: Stream.fromIterable(List.filled(201, first)),
            projectName: 'Large report'),
        throwsA(isA<ArgumentError>()
            .having((error) => error.message, 'message', contains('200'))));
    await expectLater(
        BuildCalcPdfExport.buildPages(
            pages: Stream<PdfExportPage>.error(StateError('Renderer failed')),
            projectName: 'Failed report'),
        throwsStateError);
  });
  testWidgets('Summary body text is visible on its white PDF page', (t) async {
    final settings = pdfSettings();
    final layout = runPvcCalculation(settings.request)!;
    final page = await t.runAsync(() => PvcPdfRenderer.pages(
            layout: layout, settings: settings, name: 'Site ceiling')
        .first);
    final codec = await t.runAsync(() => ui.instantiateImageCodec(page!.png));
    final frame = await t.runAsync(() => codec!.getNextFrame());
    final pixels = await t.runAsync(
        () => frame!.image.toByteData(format: ui.ImageByteFormat.rawRgba));
    var dark = 0;
    for (var y = 920; y < 1040; y++) {
      for (var x = 64; x < 1400; x++) {
        final i = (y * frame!.image.width + x) * 4;
        if (pixels!.getUint8(i) +
                pixels.getUint8(i + 1) +
                pixels.getUint8(i + 2) <
            500) {
          dark++;
        }
      }
    }
    expect(dark, greaterThan(100));
    frame!.image.dispose();
    codec!.dispose();
  });
  test('Shared PDF engine rejects empty page streams', () async {
    await expectLater(
        BuildCalcPdfExport.buildPages(
            pages: const Stream<PdfExportPage>.empty(), projectName: 'Empty'),
        throwsArgumentError);
  });
  for (final shape in PvcShape.values) {
    test(
        'Row grouping preserves all pieces and source stocks for ${shape.name}',
        () {
      final settings = pdfSettings(shape: shape),
          layout = runPvcCalculation(pdfSettings(shape: shape).request)!;
      final before = layoutSignature(layout), groups = pvcPdfRows(layout);
      expect(groups.first.first, 1);
      expect(groups.last.last, layout.rowsCount);
      expect(groups.fold<int>(0, (sum, row) => sum + row.quantity),
          layout.rowsCount);
      final originalStocks = pvcInstalledStocks(layout);
      for (final group in groups) {
        for (var i = group.first - 1; i < group.last; i++) {
          expect(layout.layoutRows[i].width, closeTo(group.row.width, kEps));
        }
      }
      final restoredStocks = [
        for (final group in groups)
          for (var row = group.first; row <= group.last; row++) ...group.stocks
      ];
      expect(restoredStocks, originalStocks);
      final restoredLengths = [
        for (final group in groups)
          for (var row = group.first; row <= group.last; row++)
            for (final segment in group.row.segments) ...segment.pieces
      ];
      expect(restoredLengths, [
        for (final row in layout.layoutRows)
          for (final segment in row.segments) ...segment.pieces
      ]);
      expect(buildGroups(layout).fold<int>(0, (sum, cut) => sum + cut.q),
          layout.count);
      expect(layoutSignature(layout), before);
      expect(settings.request.room.area, layout.area);
    });
  }
  for (final choice in [
    (shape: PvcShape.rectangle, joint: 'automatic', direction: 'automatic'),
    (shape: PvcShape.l, joint: 'automatic', direction: 'width'),
    (shape: PvcShape.u, joint: 'centre', direction: 'length'),
    (shape: PvcShape.t, joint: 'custom', direction: 'width'),
    (shape: PvcShape.angled, joint: 'automatic', direction: 'length'),
    (shape: PvcShape.cutCorner, joint: 'automatic', direction: 'width'),
  ]) {
    testWidgets(
        'Complete multi-page PVC report ${choice.shape.name}/${choice.joint}/${choice.direction}',
        (t) async {
      final settings = pdfSettings(
          shape: choice.shape,
          joint: choice.joint,
          orientation: choice.direction);
      final layout = runPvcCalculation(settings.request)!;
      final signature = layoutSignature(layout),
          inputs = jsonEncode(settings.toJson());
      final pages = await t.runAsync(() => PvcPdfRenderer.pages(
              layout: layout, settings: settings, name: 'Site ceiling')
          .toList());
      expect(pages!.length, greaterThanOrEqualTo(5));
      expect(pages.where((p) => p.landscape), hasLength(1));
      final bytes = await BuildCalcPdfExport.buildPages(
          pages: Stream.fromIterable(pages), projectName: 'Site ceiling');
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(layoutSignature(layout), signature);
      expect(jsonEncode(settings.toJson()), inputs);
    });
  }
  const sample = String.fromEnvironment('PVC_PDF_SAMPLE');
  if (sample.isNotEmpty) {
    testWidgets('PVC visual sample', (t) async {
      const font = String.fromEnvironment('PVC_PDF_FONT');
      if (font.isNotEmpty) {
        await t.runAsync(() async {
          final loader = FontLoader(AppTypography.fontFamily)
            ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        });
      }
      final data = PvcProjectData.fromJson({
        ...pdfSettings(joint: 'centre', orientation: 'length').toJson(),
        'values': {'A': '21', 'B': '11'}
      });
      final layout = runPvcCalculation(data.request)!;
      final bytes = await t.runAsync(() => BuildCalcPdfExport.buildPages(
          pages: PvcPdfRenderer.pages(
              layout: layout, settings: data, name: 'Living room PVC ceiling'),
          projectName: 'Living room PVC ceiling'));
      await t.runAsync(() => File(sample).writeAsBytes(bytes!));
    });
  }
}
