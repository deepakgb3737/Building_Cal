import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_projects.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'pvc_projects_test.dart' show PvcMemoryStorage, pvcProjectFixture;

Future<void> menu(WidgetTester t, String item) async {
  await t.tap(find.byTooltip('PVC projects'));
  await t.pumpAndSettle();
  await t.tap(find.text(item).last);
  await t.pumpAndSettle();
}

Future<void> calculated(WidgetTester t) async {
  await t.pump();
  for (var i = 0;
      i < 150 && find.byType(PvcCeilingResults).evaluate().isEmpty;
      i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  await t.pumpAndSettle();
  expect(find.byType(PvcCeilingResults), findsOneWidget);
}

void main() {
  testWidgets('All saved room shapes restore their fields and selected shape',
      (t) async {
    for (final shape in PvcShape.values) {
      final storage = PvcMemoryStorage(),
          repo = PvcProjectRepository(PvcMemoryStorage());
      final data = PvcProjectData.fromJson(
          {...pvcProjectFixture(shape: shape).toJson(), 'joint': 'automatic'});
      final entry = await repo.save('Room ${shape.name}', data);
      storage.files.addAll((repo.storage as PvcMemoryStorage).files);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: PvcCeilingScreen(
              key: ValueKey(shape), projects: PvcProjectRepository(storage))));
      await menu(t, 'Saved projects');
      await t.tap(find.text(entry.name));
      await calculated(t);
      final layout =
          t.widget<PvcCeilingResults>(find.byType(PvcCeilingResults)).layout!;
      expect(layout.area, data.request.room.area);
      expect(find.text(shape.label), findsOneWidget);
      expect(find.byType(TextFormField),
          findsNWidgets(pvcDimensions(shape).length));
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    }
  });

  for (final size in [const Size(280, 600), const Size(740, 360)]) {
    testWidgets(
        'Save, reopen after restart, confirm replacement and delete at $size',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final storage = PvcMemoryStorage();
      Widget app() => MaterialApp(
          theme: AppTheme.light,
          home: PvcCeilingScreen(projects: PvcProjectRepository(storage)));
      await t.pumpWidget(app());
      final button = find.widgetWithText(FilledButton, 'Calculate');
      await t.ensureVisible(button);
      await t.tap(button);
      await calculated(t);
      await menu(t, 'Save project');
      await t.enterText(
          find.byKey(const ValueKey('pvcProjectName')), 'Site ceiling');
      await t.tap(find.widgetWithText(FilledButton, 'Save project'));
      await t.pumpAndSettle();
      expect(storage.files, hasLength(1));
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await menu(t, 'Saved projects');
      await t.tap(find.text('Site ceiling'));
      await calculated(t);
      expect(find.text('Project: Site ceiling'), findsOneWidget);
      expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '14.5');
      await t.enterText(find.byType(TextFormField).first, '18');
      await t.pumpAndSettle();
      await menu(t, 'Saved projects');
      await t.tap(find.text('Site ceiling'));
      await t.pumpAndSettle();
      expect(find.text('Replace current inputs?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '18');
      await menu(t, 'Saved projects');
      await t.tap(find.text('Site ceiling'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await calculated(t);
      await menu(t, 'Saved projects');
      await t.tap(find.byTooltip('Delete Site ceiling'));
      await t.pumpAndSettle();
      expect(storage.files, hasLength(1));
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Delete Site ceiling'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(storage.files, isEmpty);
      expect(find.text('No saved PVC projects yet.'), findsOneWidget);
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
      expect(find.byType(PvcCeilingResults), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'Saved shape, orientation and custom joint restore selected controls',
      (t) async {
    final storage = PvcMemoryStorage(),
        repo = PvcProjectRepository(PvcMemoryStorage());
    final entry = await repo.save('Custom site', pvcProjectFixture());
    storage.files.addAll((repo.storage as PvcMemoryStorage).files);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: PvcCeilingScreen(projects: PvcProjectRepository(storage))));
    await menu(t, 'Saved projects');
    await t.tap(find.text(entry.name));
    await calculated(t);
    expect(find.text('Along length · A direction'), findsOneWidget);
    expect(find.text('Custom joint position'), findsOneWidget);
    expect(find.text('Right side'), findsOneWidget);
    final distance = find.byKey(const ValueKey('pvcJointDistance'));
    expect(
        t
            .widget<TextFormField>(find.descendant(
                of: distance, matching: find.byType(TextFormField)))
            .controller!
            .text,
        '4');
    expect(t.takeException(), isNull);
  });
  testWidgets('Read and save failures do not discard current inputs',
      (t) async {
    final storage = PvcMemoryStorage()..failRead = true;
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: PvcCeilingScreen(projects: PvcProjectRepository(storage))));
    await menu(t, 'Saved projects');
    expect(find.text('Retry'), findsOneWidget);
    storage.failRead = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    final calculate = find.widgetWithText(FilledButton, 'Calculate');
    await t.ensureVisible(calculate);
    await t.tap(calculate);
    await calculated(t);
    await menu(t, 'Save project');
    await t.enterText(find.byKey(const ValueKey('pvcProjectName')), 'Test');
    storage.failWrite = true;
    await t.tap(find.widgetWithText(FilledButton, 'Save project'));
    await t.pumpAndSettle();
    expect(storage.files, isEmpty);
    expect(find.byType(PvcCeilingResults), findsOneWidget);
    expect(find.textContaining('Could not save project'), findsOneWidget);
    expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '14.5');
    expect(t.takeException(), isNull);
  });
}
