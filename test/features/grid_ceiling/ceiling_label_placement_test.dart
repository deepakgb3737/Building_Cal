import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/ceiling_label_placement.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';

void main() {
  test('Section tags stay near their chosen ends at every direction', () {
    for (final end in [
      const Offset(200, 0),
      const Offset(0, 200),
      const Offset(-120, 160),
    ]) {
      final startTag = ceilingSectionLabelAnchor(Offset.zero, end);
      final endTag = ceilingSectionLabelAnchor(Offset.zero, end, atEnd: true);
      expect(startTag.distance, closeTo(20, .001));
      expect((endTag - end).distance, closeTo(20, .001));
      expect((startTag + endTag - end).distance, closeTo(0, .001));
    }
    expect(ceilingSectionLabelAnchor(Offset.zero, const Offset(12, 0)),
        const Offset(6, 0));
    expect(ceilingSectionLabelAnchor(Offset.zero, Offset.zero), Offset.zero);
  });
  test('Stock examples stay bounded as ceiling size grows', () {
    for (final mode in PlacementMode.values) {
      for (final width in [2438.0, 4567.0, 40000.0]) {
        final result = GridCeilingCalculator.calculate(width, 3445, mode: mode);
        final spans = result.crossTSpans;
        final labels = ceilingStockLabelSpans(spans);
        expect(labels.length, lessThanOrEqualTo(3));
        expect(labels.where((i) => !spans[i].usesTwoFoot).length, 1);
        if (spans.first.usesTwoFoot) expect(labels, contains(0));
        if (spans.last.usesTwoFoot) {
          expect(labels, contains(spans.length - 1));
        }
      }
    }
  });
  test('Stock labels avoid own and neighbouring grid lines', () {
    for (final vertical in [false, true]) {
      final lines = <(Offset, Offset)>[
        (const Offset(0, 100), const Offset(300, 100)),
        (const Offset(100, 0), const Offset(100, 300)),
        (const Offset(0, 0), const Offset(300, 300)),
      ];
      final rect = placeCeilingLabel(
          anchor: const Offset(100, 100),
          size: const Size(30, 16),
          bounds: const Rect.fromLTWH(0, 0, 300, 300),
          occupied: [],
          lines: lines,
          vertical: vertical);
      expect(rect, isNotNull);
      for (final line in lines) {
        expect(ceilingLineCrossesLabel(line, rect!.inflate(3)), isFalse);
      }
    }
  });
  test('Diagonal clearance uses segments, not their bounding rectangles', () {
    const line = (Offset(0, 0), Offset(100, 100));
    expect(ceilingLineCrossesLabel(line, const Rect.fromLTWH(10, 70, 20, 10)),
        isFalse);
    expect(ceilingLineCrossesLabel(line, const Rect.fromLTWH(40, 40, 20, 10)),
        isTrue);
    expect(
        ceilingLineCrossesLabel(
            (line.$2, line.$1), const Rect.fromLTWH(40, 40, 20, 10)),
        isTrue);
    expect(ceilingLineCrossesLabel(line, const Rect.fromLTWH(110, 110, 10, 10)),
        isFalse);
  });
  test('Shared placement separates crowded labels and stays deterministic', () {
    List<Rect> layout() {
      final occupied = <Rect>[];
      for (var i = 0; i < 8; i++) {
        final rect = placeCeilingLabel(
            anchor: const Offset(120, 100),
            size: const Size(44, 24),
            bounds: const Rect.fromLTWH(0, 0, 300, 220),
            occupied: occupied,
            vertical: i.isEven);
        expect(rect, isNotNull);
      }
      for (var i = 0; i < occupied.length; i++) {
        for (var j = 0; j < i; j++) {
          expect(occupied[i].overlaps(occupied[j]), isFalse);
        }
      }
      return occupied;
    }

    expect(layout(), layout());
  });
  test('Nearest clear position is preferred along the section direction', () {
    for (final vertical in [false, true]) {
      final rect = placeCeilingLabel(
          anchor: const Offset(100, 100),
          size: const Size(40, 20),
          bounds: const Rect.fromLTWH(0, 0, 300, 300),
          occupied: [],
          vertical: vertical)!;
      expect(
          (rect.center - const Offset(100, 100)).distance, vertical ? 24 : 14);
    }
  });
  test('Edges do not clamp several labels into the same corner', () {
    final occupied = <Rect>[];
    const bounds = Rect.fromLTWH(0, 0, 220, 180);
    for (final anchor in [
      const Offset(219, 5),
      const Offset(218, 6),
      const Offset(220, 7)
    ]) {
      final rect = placeCeilingLabel(
          anchor: anchor,
          size: const Size(48, 24),
          bounds: bounds,
          occupied: occupied)!;
      expect(bounds.contains(rect.topLeft), isTrue);
      expect(bounds.contains(rect.bottomRight), isTrue);
    }
    expect(occupied.toSet().length, 3);
  });
  test('No clear space omits a label instead of clipping or overlapping it',
      () {
    final occupied = <Rect>[];
    expect(
        placeCeilingLabel(
            anchor: const Offset(5, 5),
            size: const Size(40, 20),
            bounds: const Rect.fromLTWH(0, 0, 10, 10),
            occupied: occupied),
        isNull);
    expect(occupied, isEmpty);
  });

  for (final (screen, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(740, 360), 1.4),
  ]) {
    for (final (width, mode) in [
      (4567.0, PlacementMode.oneSide),
      (3001.0, PlacementMode.oneSide),
      (2438.0, PlacementMode.centerBased),
    ]) {
      testWidgets('$screen text $scale width $width: stock labels stay clear',
          (t) async {
        t.view.physicalSize = screen;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final result = GridCeilingCalculator.calculate(width, 3445, mode: mode);
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: EnhancedRoomLayoutScreen(
                result: result, width: width, length: 3445)));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('2D plan'));
        await t.tap(find.text('2D plan'));
        await t.pumpAndSettle();
        final labels = find.byWidgetPredicate((w) {
          if (w is! Positioned || w.key is! ValueKey<String>) return false;
          final key = (w.key! as ValueKey<String>).value;
          return key.startsWith('mainType-') ||
              key.startsWith('crossType-') ||
              key.startsWith('dividerType-');
        });
        final rects = <Rect>[];
        expect(labels.evaluate().length, lessThanOrEqualTo(5));
        final texts = <String>{};
        final room = t.getRect(find
            .descendant(
                of: find.byWidgetPredicate((w) =>
                    w is Positioned &&
                    w.left == 120 &&
                    w.top == 50 &&
                    w.child is Container &&
                    (w.child as Container).decoration is BoxDecoration),
                matching: find.byType(Container))
            .first);
        final gridLines = <(Offset, Offset)>[
          for (final x in [
            0.0,
            ...result.mainRunnersWidth,
            ...result.twoFootCrossT,
            width
          ])
            (
              Offset(room.left + x / width * room.width, room.top),
              Offset(room.left + x / width * room.width, room.bottom)
            ),
          for (final y in [0.0, ...result.crossTLength, 3445.0])
            (
              Offset(room.left, room.top + y / 3445 * room.height),
              Offset(room.right, room.top + y / 3445 * room.height)
            ),
        ];
        for (var i = 0; i < labels.evaluate().length; i++) {
          final text =
              find.descendant(of: labels.at(i), matching: find.byType(Text));
          texts.add(t.widget<Text>(text).data!);
          final rect = t.getRect(text);
          final labelKey =
              (t.widget<Positioned>(labels.at(i)).key! as ValueKey<String>)
                  .value;
          if (labelKey.startsWith('mainType-')) {
            expect(rect.center.dy, lessThan(room.top + room.height / 4));
          }
          if (labelKey.startsWith('dividerType-')) {
            expect(rect.center.dy, greaterThan(room.bottom - room.height / 4));
          }
          final background = t.getRect(find.descendant(
              of: labels.at(i), matching: find.byType(ColoredBox)));
          expect(
              gridLines
                  .any((line) => ceilingLineCrossesLabel(line, background)),
              isFalse,
              reason: 'Stock text must not cover a grid line');
          for (final other in rects) {
            expect(rect.overlaps(other), isFalse);
          }
          rects.add(rect);
        }
        expect(texts, containsAll(['2f', '4f', '10f']));
        final measurements = find.descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byWidgetPredicate(
                (w) => w is Text && RegExp(r'\d+ mm$').hasMatch(w.data ?? '')));
        for (var i = 0; i < measurements.evaluate().length; i++) {
          final rect = t.getRect(measurements.at(i));
          expect(rects.any((r) => r.overlaps(rect)), isFalse);
          final canvas =
              t.getRect(find.byKey(const ValueKey('ceiling2DCanvas')));
          expect(canvas.contains(rect.topLeft), isTrue);
          expect(canvas.contains(rect.bottomRight), isTrue);
        }
        if (width == 4567 && scale == 1) {
          final center = t.getCenter(find.byType(InteractiveViewer));
          final first =
              await t.startGesture(center + const Offset(-20, 0), pointer: 1);
          final second =
              await t.startGesture(center + const Offset(20, 0), pointer: 2);
          await first.moveTo(center + const Offset(-45, 0));
          await second.moveTo(center + const Offset(45, 0));
          await t.pump();
          await first.up();
          await second.up();
          await t.pumpAndSettle();
          final zoomed = <Rect>[];
          for (var i = 0; i < labels.evaluate().length; i++) {
            final text =
                find.descendant(of: labels.at(i), matching: find.byType(Text));
            final rect = t.getRect(text);
            expect(zoomed.any((other) => other.overlaps(rect)), isFalse);
            zoomed.add(rect);
          }
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
