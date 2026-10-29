import 'package:flutter/material.dart';
import '../logic/drawing_doors.dart';
import '../logic/drawing_point.dart';
import 'door_painter.dart';

class DoorDialog extends StatefulWidget {
  const DoorDialog({super.key, required this.door, required this.unit});
  final DrawingDoor door;
  final DrawingUnit unit;
  @override
  State<DoorDialog> createState() => _DoorDialogState();
}

class _DoorDialogState extends State<DoorDialog> {
  final _form = GlobalKey<FormState>();
  late final _initialWidth =
      widget.unit.input(widget.door.width, decimalPlaces: 2);
  late final _width = TextEditingController(text: _initialWidth);
  late DrawingDoor _door = widget.door;
  @override
  void dispose() {
    _width.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = DrawingDoors()
      ..add(_door.copyWith(position: const DrawingPoint(0, 0)));
    final previewDoor = preview.items.values.single;
    final factor = 55 / _door.width;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(12),
      title: Text(widget.door.id == 0 ? 'Add door' : 'Edit door'),
      content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                height: 126,
                width: 220,
                child: CustomPaint(
                    painter: DoorPainter(
                        doors: preview,
                        origin: Offset(110 - previewDoor.hinge.x * factor,
                            63 - previewDoor.hinge.y * factor),
                        scale: factor))),
            TextFormField(
                key: const ValueKey('doorWidth'),
                controller: _width,
                onChanged: (text) {
                  final mm = text == _initialWidth
                      ? widget.door.width
                      : widget.unit.readMm(text);
                  if (mm != null && mm.isFinite && mm >= 100 && mm <= 5000) {
                    setState(() => _door = _door.copyWith(width: mm));
                  }
                },
                keyboardType: widget.unit == DrawingUnit.feetInches
                    ? TextInputType.text
                    : const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                    labelText: 'Door width', suffixText: widget.unit.symbol),
                validator: (value) {
                  final mm = widget.unit.readMm(value ?? '');
                  return mm == null || !mm.isFinite || mm < 100 || mm > 5000
                      ? 'Use ${widget.unit.format(100)} to ${widget.unit.format(5000)}'
                      : null;
                }),
            const Text('Drag the round handle on the door to rotate it.'),
            Text('Opening ${_door.opening.round()}°'),
            Slider(
                key: const ValueKey('doorOpening'),
                value: _door.opening,
                min: 0,
                max: 180,
                divisions: 180,
                label: '${_door.opening.round()}°',
                onChanged: (v) =>
                    setState(() => _door = _door.copyWith(opening: v))),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: () =>
                      setState(() => _door = _door.copyWith(opening: 0)),
                  child: const Text('Closed')),
              TextButton(
                  onPressed: () =>
                      setState(() => _door = _door.copyWith(opening: 90)),
                  child: const Text('90°')),
              TextButton(
                  onPressed: () =>
                      setState(() => _door = _door.copyWith(opening: 180)),
                  child: const Text('Fully open')),
            ]),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hinge on right'),
                value: _door.rightHinge,
                onChanged: (v) =>
                    setState(() => _door = _door.copyWith(rightHinge: v))),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open to other side'),
                value: _door.reverseSwing,
                onChanged: (v) =>
                    setState(() => _door = _door.copyWith(reverseSwing: v))),
          ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(
                  context,
                  _door.copyWith(
                      width: _width.text == _initialWidth
                          ? widget.door.width
                          : widget.unit.readMm(_width.text)!));
            },
            child: const Text('Apply')),
      ],
    );
  }
}
