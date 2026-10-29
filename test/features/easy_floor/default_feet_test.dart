import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_annotations.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/floor_document.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/wall_network.dart';
import 'document_test_support.dart';
import 'document_interaction_test.dart' as documents;
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;

void main() {
  test('New plan settings default to feet; stored metre settings remain metres',
      () {
    expect(const DocumentSettings().unit, DrawingUnit.feet);
    final original = FloorDocument(WallNetwork(), DrawingAnnotations(),
        const DocumentSettings(unit: DrawingUnit.metres));
    expect(FloorDocument.fromJson(original.toJson()).settings.unit,
        DrawingUnit.metres);
  });
  testWidgets('New workspace displays feet and exact length entry uses feet',
      (t) async {
    await documents.openWorkspace(t, DocumentRepository(TestDocumentStorage()));
    expect(board.painter(t).unit, DrawingUnit.feet);
    expect(find.text('ft'), findsOneWidget);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 300), const Offset(240, 300));
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(150, 300));
    await t.pumpAndSettle();
    await t.tap(find.text('Enter length'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '6');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    final model = board.painter(t).model;
    expect(model.length(model.walls.keys.single), closeTo(1828.8, .001));
    expect(board.painter(t).unit, DrawingUnit.feet);
    expect(t.takeException(), isNull);
  });
  testWidgets('Opening metric plan keeps units; New Document resets to feet',
      (t) async {
    final repository = DocumentRepository(TestDocumentStorage());
    final model = WallNetwork()
      ..addPolyline([const DrawingPoint(0, 0), const DrawingPoint(2000, 0)]);
    final saved = await repository.save(
        FloorDocument(model, DrawingAnnotations(),
            const DocumentSettings(unit: DrawingUnit.metres)),
        'Metric plan');
    await documents.openWorkspace(t, repository);
    expect(board.painter(t).unit, DrawingUnit.feet);
    await documents.openSaved(t, 'Metric plan');
    expect(board.painter(t).unit, DrawingUnit.metres);
    expect(board.painter(t).model.toJson(), model.toJson());
    await documents.action(t, 'New Document');
    expect(board.painter(t).unit, DrawingUnit.feet);
    expect(board.painter(t).model.walls, isEmpty);
    expect(
        (await repository.open(saved.id)).$2.settings.unit, DrawingUnit.metres);
    expect(t.takeException(), isNull);
  });
}
