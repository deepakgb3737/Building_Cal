import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_pdf_export.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_doors.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/floor_pdf_renderer.dart';
import 'package:grid_ceiling_calculator/ui/app_typography.dart';

FloorDocument plan({bool portrait = false, double cameraScale = .1}) {
  const p = DrawingPoint.new;
  final w = portrait ? 3000.0 : 8000.0, h = portrait ? 9000.0 : 4000.0;
  final walls = WallNetwork()
    ..addPolyline([p(0, 0), p(w, 0), p(w, h), p(0, h), p(0, 0)]);
  walls.addPolyline([p(w * .5, 0), p(w * .5, h)], dashed: true);
  walls.lockLength(walls.walls.values.first.id);
  final notes = DrawingAnnotations()..add('Room A\nSite notes', p(500, 700));
  final doors = DrawingDoors()..add(DrawingDoor(0, p(1600, 0), width: 900));
  return FloorDocument(
      walls,
      notes,
      DocumentSettings(
          scale: cameraScale,
          originX: -90000,
          originY: 42000,
          unit: DrawingUnit.feetInches),
      doors: doors);
}

void main() {
  test('PDF filenames are bounded and cannot escape a share directory', () {
    expect(FloorPdfExport.filename('  '), 'BuildCalc_Floor_plan.pdf');
    final name = FloorPdfExport.filename('../../Room: A?\\draft\u0000');
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('\\')));
    expect(name, isNot(contains('\u0000')));
    expect(name.endsWith('.pdf'), isTrue);
    expect(FloorPdfExport.filename(List.filled(200, '😀').join()).runes.length,
        lessThan(100));
    expect(
        utf8
            .encode(FloorPdfExport.filename(List.filled(200, '😀').join()))
            .length,
        lessThanOrEqualTo(255));
  });
  test('PDF engine rejects empty or invalid images', () async {
    await expectLater(
        FloorPdfExport.build(
            png: Uint8List(0), projectName: 'Plan', landscape: true),
        throwsArgumentError);
  });
  for (final portrait in [false, true]) {
    testWidgets(
        'Export includes complete plan at paper orientation portrait=$portrait',
        (t) async {
      final doc = plan(portrait: portrait),
          original = jsonEncode(plan(portrait: portrait).toJson());
      final rendered = await t
          .runAsync(() => FloorPdfRenderer.render(doc, 'Site plan - Room A'));
      expect(rendered!.landscape, !portrait);
      final codec =
          await t.runAsync(() => ui.instantiateImageCodec(rendered.png));
      final frame = await t.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, portrait ? 1684 : 2380);
      expect(frame.image.height, portrait ? 2380 : 1684);
      frame.image.dispose();
      codec!.dispose();
      final bytes = await FloorPdfExport.build(
          png: rendered.png,
          projectName: 'Site plan - Room A',
          landscape: rendered.landscape);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      expect(jsonEncode(doc.toJson()), original);
    });
  }
  testWidgets(
      'PDF rendering ignores viewport zoom/pan and rejects an empty drawing',
      (t) async {
    final a = await t.runAsync(() => FloorPdfRenderer.render(plan(), 'Plan'));
    final b = await t.runAsync(
        () => FloorPdfRenderer.render(plan(cameraScale: 1.8), 'Plan'));
    expect(a!.png, b!.png);
    await expectLater(
        FloorPdfRenderer.render(
            FloorDocument(
                WallNetwork(), DrawingAnnotations(), const DocumentSettings()),
            'Empty'),
        throwsArgumentError);
  });
  testWidgets('Door-only and note-only plans can be exported', (t) async {
    final notes = DrawingAnnotations()
      ..add('Kitchen', const DrawingPoint(-500, 200));
    final doors = DrawingDoors()
      ..add(const DrawingDoor(0, DrawingPoint(5000, -3000),
          rotation: 137, opening: 180));
    for (final document in [
      FloorDocument(WallNetwork(), notes, const DocumentSettings()),
      FloorDocument(
          WallNetwork(), DrawingAnnotations(), const DocumentSettings(),
          doors: doors),
    ]) {
      final rendered =
          await t.runAsync(() => FloorPdfRenderer.render(document, 'Symbols'));
      expect(rendered!.png, isNotEmpty);
    }
  });
  const output = String.fromEnvironment('EASYFLOOR_PDF_SAMPLE');
  testWidgets('Optional visual-inspection PDF sample', (t) async {
    const font = String.fromEnvironment('EASYFLOOR_PDF_FONT');
    if (font.isNotEmpty) {
      await t.runAsync(() async {
        final loader = FontLoader(AppTypography.fontFamily)
          ..addFont(File(font)
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)));
        await loader.load();
      });
    }
    final rendered = await t
        .runAsync(() => FloorPdfRenderer.render(plan(), 'Site plan - Room A'));
    final bytes = await FloorPdfExport.build(
        png: rendered!.png,
        projectName: 'Site plan',
        landscape: rendered.landscape);
    await t.runAsync(() => File(output).writeAsBytes(bytes));
  }, skip: output.isEmpty);
}
