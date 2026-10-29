import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_doors.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/door_dialog.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'document_test_support.dart';
import 'document_interaction_test.dart' as documents;
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'annotation_interaction_test.dart' as actions;

DrawingDoors doors(WidgetTester t) => actions.textView(t).doors!;
Future<void> addDoor(WidgetTester t, Offset at) async {
  await board.expandTools(t);
  await board.tool(t, 'Door');
  await board.collapseTools(t);
  await t.tapAt(t.getTopLeft(board.canvas) + at);
  await t.pumpAndSettle();
  expect(find.byType(DoorDialog), findsOneWidget);
  await t.tap(find.text('Apply'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Saved doors reopen with settings and no leftover undo history',
      (t) async {
    final repository = DocumentRepository(TestDocumentStorage());
    await documents.openWorkspace(t, repository);
    await addDoor(t, const Offset(110, 180));
    await t.tap(find.text('Close door'));
    await t.pumpAndSettle();
    final saved = doors(t).toJson();
    await documents.save(t, 'Door plan');
    await documents.action(t, 'Close Document');
    await t.tap(find.text('Launch EasyFloor'));
    await t.pumpAndSettle();
    await documents.openSaved(t, 'Door plan');
    expect(doors(t).toJson(), saved);
    expect(board.painter(t).model.walls, isEmpty);
    final undo = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Undo'));
    expect(undo.onSelected, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('Cancel door placement or editing keeps the drawing unchanged',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Door');
    await board.collapseTools(t);
    await t.tapAt(t.getTopLeft(board.canvas) + const Offset(110, 180));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(doors(t).items, isEmpty);
    await addDoor(t, const Offset(110, 180));
    final before = doors(t).toJson();
    await t.tap(find.text('Edit door'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('doorWidth')), '0.7');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(doors(t).toJson(), before);
    final door = doors(t).items.values.single, view = board.painter(t);
    final drag = await t.startGesture(t.getTopLeft(board.canvas) +
        view.screen((door.hinge + door.leafEnd) * .5));
    await drag.moveBy(const Offset(30, 20));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(doors(t).toJson(), before);
    expect(board.painter(t).model.walls, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Door placement, open/close, move, edit, delete and Undo preserve walls',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 180), const Offset(260, 180));
    final geometry = board.painter(t).model.toJson();
    await addDoor(t, const Offset(100, 180));
    expect(doors(t).items, hasLength(1));
    final initial = doors(t).items.values.single;
    expect(initial.rotation, 0);
    expect(board.painter(t).model.toJson(), geometry);
    await t.tap(find.text('Close door'));
    await t.pumpAndSettle();
    expect(doors(t).items.values.single.opening, 0);
    await t.tap(find.text('Open door'));
    await t.pumpAndSettle();
    expect(doors(t).items.values.single.opening, 90);
    final view = board.painter(t);
    final at = t.getTopLeft(board.canvas) +
        view.screen((initial.hinge + initial.leafEnd) * .5);
    final drag = await t.startGesture(at);
    await drag.moveBy(const Offset(25, 20));
    await t.pump();
    expect((doors(t).items.values.single.position - initial.position).length,
        greaterThan(0));
    await drag.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.toJson(), geometry);
    final moved = doors(t).toJson();
    await t.tap(find.text('Edit door'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('doorWidth')), '0.8');
    await t.ensureVisible(find.text('Fully open'));
    await t.tap(find.text('Fully open'));
    await t.ensureVisible(find.text('Hinge on right'));
    await t.tap(find.text('Hinge on right'));
    await t.ensureVisible(find.text('Open to other side'));
    await t.tap(find.text('Open to other side'));
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    final edited = doors(t).items.values.single;
    expect(edited.width, 800);
    expect(edited.opening, 180);
    expect(edited.rightHinge, isTrue);
    expect(edited.reverseSwing, isTrue);
    await actions.undo(t, 'Undo');
    expect(doors(t).toJson(), moved);
    await actions.undo(t, 'Redo');
    expect(doors(t).items.values.single.width, 800);
    final current = doors(t).items.values.single;
    final origin = t.getTopLeft(board.canvas);
    final now = board.painter(t);
    final select = await t.startGesture(
        origin + now.screen((current.hinge + current.leafEnd) * .5));
    await select.moveBy(const Offset(0, 15));
    await t.pump();
    await select.up();
    await t.pumpAndSettle();
    final beforeDelete = doors(t).toJson();
    await t.tap(find.byTooltip('Delete selected geometry').last);
    await t.pumpAndSettle();
    expect(doors(t).items, isEmpty);
    expect(board.painter(t).model.toJson(), geometry);
    await actions.undo(t, 'Undo');
    expect(doors(t).toJson(), beforeDelete);
    expect(t.takeException(), isNull);
  });

  testWidgets('Second finger interrupts door drag without moving walls or door',
      (t) async {
    await board.open(t, showLabels: false);
    await addDoor(t, const Offset(110, 180));
    final original = doors(t).toJson();
    final door = doors(t).items.values.single;
    final v = board.painter(t), origin = t.getTopLeft(board.canvas);
    final first = await t
        .startGesture(origin + v.screen((door.hinge + door.leafEnd) * .5));
    await first.moveBy(const Offset(30, 20));
    await t.pump();
    final second =
        await t.startGesture(origin + const Offset(240, 350), pointer: 2);
    await t.pump();
    expect(doors(t).toJson(), original);
    await first.moveBy(const Offset(20, 0));
    await second.moveBy(const Offset(20, 0));
    await t.pump();
    await second.up();
    await first.up();
    await t.pumpAndSettle();
    expect(doors(t).toJson(), original);
    expect(board.painter(t).model.walls, isEmpty);
    await actions.undo(t, 'Undo');
    expect(doors(t).items, isEmpty);
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(240, 420), const Size(740, 360)]) {
    testWidgets(
        'Door form remains usable at $size with keyboard and exact feet width',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      DrawingDoor? result;
      await t.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<DrawingDoor>(
                        context: context,
                        builder: (_) => const DoorDialog(
                            door:
                                DrawingDoor(0, DrawingPoint(0, 0), width: 900),
                            unit: DrawingUnit.feet));
                  },
                  child: const Text('Door')))));
      await t.tap(find.text('Door'));
      await t.pumpAndSettle();
      t.view.viewInsets = FakeViewPadding(bottom: size.height * .4);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('doorWidth')));
      await t.tap(find.byKey(const ValueKey('doorWidth')));
      await t.pumpAndSettle();
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(result!.width, 900);
      expect(t.takeException(), isNull);
    });
  }

  test('Selected door rotation handle maps a drag to the stored angle', () {
    final doors = DrawingDoors()..add(const DrawingDoor(0, DrawingPoint(0, 0)));
    final door = doors.items.values.single;
    expect(doors.hitTestRotation(door.rotationHandle, 1, selected: door.id),
        door.id);
    expect(doors.hitTestRotation(door.rotationHandle, 1), isNull);
    doors.update(door.copyWith(rotation: 90));
    final rotated = doors.items.values.single;
    expect(rotated.rotation, 90);
    expect(rotated.rotationHandle, isNot(door.rotationHandle));
  });
}
