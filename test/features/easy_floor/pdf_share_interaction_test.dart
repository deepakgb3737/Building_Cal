import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'drawing_screen_test.dart' as board;
import 'endpoint_connection_test.dart' show wall;
import 'annotation_interaction_test.dart' show undo;

void main() {
  const channel = MethodChannel('net.nfet.printing');
  testWidgets('Share PDF is unavailable for an empty plan', (t) async {
    await board.open(t);
    await t.tap(find.byTooltip('Documents'));
    await t.pumpAndSettle();
    final menu = t.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Share PDF'));
    expect(menu.enabled, isFalse);
  });
  testWidgets(
      'Share PDF is unavailable while a sketch is awaiting confirmation',
      (t) async {
    await board.open(t, showLabels: false);
    await board.tool(t, 'Wall');
    await board.collapseTools(t);
    await wall(t, const Offset(60, 340), const Offset(240, 340));
    await board.tool(t, 'Draw');
    await board.collapseTools(t);
    final origin = t.getTopLeft(board.canvas);
    final stroke = await t.startGesture(origin + const Offset(60, 100));
    await stroke.moveTo(origin + const Offset(220, 100));
    await t.pump();
    await stroke.moveTo(origin + const Offset(220, 220));
    await t.pump();
    await stroke.up();
    await t.pumpAndSettle();
    expect(board.painter(t).model.walls, hasLength(1));
    expect(board.painter(t).rawStroke, isNotEmpty);
    await t.tap(find.byTooltip('Documents'));
    await t.pumpAndSettle();
    final menu = t.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Share PDF'));
    expect(menu.enabled, isFalse);
  });
  for (final outcome in ['success', 'cancel', 'failure']) {
    testWidgets('PDF share preserves geometry and Undo, outcome=$outcome',
        (t) async {
      final shared = Completer<MethodCall>();
      final platformReply = Completer<int>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'sharePdf') {
          shared.complete(call);
          if (outcome == 'failure') {
            throw PlatformException(code: 'share_failed');
          }
          return platformReply.future;
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await board.open(t, showLabels: false);
      await board.tool(t, 'Wall');
      await board.collapseTools(t);
      await wall(t, const Offset(60, 180), const Offset(240, 180));
      final original = board.painter(t).model.toJson();
      await t.tap(find.byTooltip('Documents'));
      await t.pumpAndSettle();
      await t.tap(find.text('Share PDF'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      for (var i = 0; i < 100 && !shared.isCompleted; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      expect(shared.isCompleted, isTrue);
      final call = await shared.future;
      if (outcome != 'failure') {
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
            find.byWidgetPredicate(
                (widget) => widget is AbsorbPointer && widget.absorbing),
            findsWidgets);
        platformReply.complete(outcome == 'cancel' ? 0 : 1);
      }
      await t.pumpAndSettle();
      final arguments = call.arguments as Map;
      expect(arguments['doc'], isA<Uint8List>());
      expect((arguments['doc'] as Uint8List).take(5).toList(),
          [37, 80, 68, 70, 45]);
      expect(arguments['name'], 'BuildCalc_Untitled.pdf');
      expect(arguments['w'], greaterThan(0));
      expect(arguments['h'], greaterThan(0));
      expect(board.painter(t).model.toJson(), original);
      if (outcome == 'failure') {
        expect(
            find.textContaining('Could not create or share'), findsOneWidget);
      }
      if (outcome == 'cancel') {
        expect(find.textContaining('PDF sharing was not completed'),
            findsOneWidget);
      }
      await undo(t, 'Undo');
      expect(board.painter(t).model.walls, isEmpty);
      expect(t.takeException(), isNull);
    });
  }
}
