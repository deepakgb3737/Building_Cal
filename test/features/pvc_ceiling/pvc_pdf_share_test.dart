import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_screen.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/ui/pvc_ceiling_results.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_projects.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'pvc_projects_test.dart' show PvcMemoryStorage;
import 'pvc_projects_ui_test.dart' show calculated;
import 'pvc_pdf_export_test.dart' show layoutSignature;

void main() {
  testWidgets(
      'Share PDF is disabled before calculation and after any input changes',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: PvcCeilingScreen(
            projects: PvcProjectRepository(PvcMemoryStorage()))));
    Future<bool> enabled() async {
      await t.tap(find.byTooltip('PVC projects'));
      await t.pumpAndSettle();
      final item = t.widget<PopupMenuItem<String>>(
          find.widgetWithText(PopupMenuItem<String>, 'Share PDF'));
      final result = item.enabled;
      await t.tapAt(const Offset(10, 150));
      await t.pumpAndSettle();
      return result;
    }

    expect(await enabled(), isFalse);
    final button = find.widgetWithText(FilledButton, 'Calculate');
    await t.ensureVisible(button);
    await t.tap(button);
    await calculated(t);
    expect(await enabled(), isTrue);
    await t.ensureVisible(find.byType(TextFormField).first);
    await t.enterText(find.byType(TextFormField).first, '16');
    await t.pumpAndSettle();
    expect(await enabled(), isFalse);
    expect(t.takeException(), isNull);
  });
  for (final outcome in ['success', 'cancel', 'failure']) {
    testWidgets('PVC PDF sharing keeps calculated result and inputs: $outcome',
        (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const channel = MethodChannel('net.nfet.printing');
      final callReady = Completer<MethodCall>(), reply = Completer<int>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'sharePdf') {
          callReady.complete(call);
          if (outcome == 'failure') {
            throw PlatformException(code: 'pvc_share_failed');
          }
          return reply.future;
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final storage = PvcMemoryStorage();
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: PvcCeilingScreen(projects: PvcProjectRepository(storage))));
      final calculate = find.widgetWithText(FilledButton, 'Calculate');
      await t.ensureVisible(calculate);
      await t.tap(calculate);
      await calculated(t);
      final layout =
          t.widget<PvcCeilingResults>(find.byType(PvcCeilingResults)).layout!;
      final before = layoutSignature(layout);
      final fields = [
        for (final element in find.byType(TextFormField).evaluate())
          (element.widget as TextFormField).controller!.text
      ];
      await t.tap(find.byTooltip('PVC projects'));
      await t.pumpAndSettle();
      await t.tap(find.text('Share PDF'));
      await t.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 200 && !callReady.isCompleted; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      expect(callReady.isCompleted, isTrue);
      final call = await callReady.future;
      if (outcome != 'failure') {
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
            t
                .widget<PopupMenuButton<String>>(
                    find.byType(PopupMenuButton<String>))
                .enabled,
            isFalse);
        reply.complete(outcome == 'cancel' ? 0 : 1);
      }
      await t.pumpAndSettle();
      final args = call.arguments as Map;
      expect(args['name'], 'BuildCalc_PVC Ceiling.pdf');
      expect((args['doc'] as Uint8List).take(5), [37, 80, 68, 70, 45]);
      expect(args['w'], greaterThan(0));
      expect(
          layoutSignature(t
              .widget<PvcCeilingResults>(find.byType(PvcCeilingResults))
              .layout!),
          before);
      expect([
        for (final element in find.byType(TextFormField).evaluate())
          (element.widget as TextFormField).controller!.text
      ], fields);
      expect(storage.files, isEmpty);
      if (outcome == 'failure') {
        expect(find.textContaining('Could not create or share the PVC PDF'),
            findsOneWidget);
      }
      if (outcome == 'cancel') {
        expect(find.textContaining('PDF sharing was not completed'),
            findsOneWidget);
      }
      expect(
          t
              .widget<PopupMenuButton<String>>(
                  find.byType(PopupMenuButton<String>))
              .enabled,
          isTrue);
      expect(t.takeException(), isNull);
    });
  }
}
