import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';
import '../../../ui/app_widgets.dart';
import '../logic/pvc_ceiling_calculator.dart';
import 'pvc_measurement_guide.dart';
import 'pvc_section.dart';
import 'pvc_ceiling_results.dart';
import 'pvc_ceiling_painter.dart';

class PvcCeilingScreen extends StatefulWidget {
  const PvcCeilingScreen({super.key});
  @override
  State<PvcCeilingScreen> createState() => _PvcCeilingScreenState();
}

class _PvcCeilingScreenState extends State<PvcCeilingScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _resultsAnchor = GlobalKey();
  final _controllers = {
    for (final key in ['A', 'B', 'C', 'D', 'E']) key: TextEditingController()
  };
  final _focus = {
    for (final key in ['A', 'B', 'C', 'D', 'E']) key: FocusNode()
  };
  final _anchors = {
    for (final key in ['A', 'B', 'C', 'D', 'E']) key: GlobalKey()
  };
  bool _revealQueued = false;
  final _saved = {
    for (final shape in PvcShape.values) shape: pvcDefaults(shape)
  };
  PvcShape _shape = PvcShape.rectangle;
  String _mode = 'mix', _corner = 'tr';
  PvcOrientation _orientation = PvcOrientation.automatic;
  PvcJointMode _jointMode = PvcJointMode.automatic;
  bool _fromEnd = false;
  final _jointDistance = TextEditingController();
  PvcJointRule get _jointRule => PvcJointRule(
      mode: _jointMode,
      distanceFt: double.tryParse(_jointDistance.text.replaceAll(',', '.')),
      fromEnd: _fromEnd);
  Layout? _layout;
  bool _calculated = false, _busy = false;
  int _token = 0;
  String? _error;
  PvcInputError? _inputError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _jointDistance.addListener(_invalidate);
    for (final c in _controllers.values) {
      c.addListener(_invalidate);
    }
    for (final f in _focus.values) {
      f.addListener(_focusChanged);
    }
  }

  void _focusChanged() {
    if (mounted) {
      setState(() {});
      _revealFocused();
    }
  }

  @override
  void didChangeMetrics() => _revealFocused();

  void _revealFocused() {
    if (_revealQueued) return;
    _revealQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealQueued = false;
      if (!mounted) return;
      final active =
          _focus.entries.where((e) => e.value.hasFocus).firstOrNull?.key;
      var target = _anchors[active]?.currentContext;
      if (target == null) return;
      final box = target.findRenderObject();
      final viewport = Scrollable.maybeOf(target)?.position.viewportDimension;
      if (box is RenderBox && viewport != null && box.size.height > viewport) {
        target = _focus[active]?.context ?? target;
      }
      Scrollable.ensureVisible(target, alignment: .2);
    });
  }

  void _load() {
    for (final key in _controllers.keys) {
      _controllers[key]!.text = _saved[_shape]![key] ?? '';
    }
  }

  Map<String, String> get _values =>
      {for (final f in pvcDimensions(_shape)) f.key: _controllers[f.key]!.text};
  void _invalidate() => setState(() {
        ++_token;
        _layout = null;
        _calculated = _busy = false;
        _error = null;
        _inputError = null;
      });
  void _selectShape(PvcShape? shape) {
    if (shape == null || shape == _shape) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _saved[_shape] = _values;
    for (final c in _controllers.values) {
      c.removeListener(_invalidate);
    }
    _shape = shape;
    _load();
    for (final c in _controllers.values) {
      c.addListener(_invalidate);
    }
    _invalidate();
  }

  @override
  void dispose() {
    _jointDistance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      c.removeListener(_invalidate);
      c.dispose();
    }
    for (final f in _focus.values) {
      f.removeListener(_focusChanged);
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_busy) return;
    _inputError = null;
    if (!_form.currentState!.validate()) {
      final invalid = pvcDimensions(_shape).firstWhere(
          (f) => pvcFieldError(_shape, f, _controllers[f.key]!.text) != null);
      _focus[invalid.key]!.requestFocus();
      return;
    }
    PvcRoom room;
    try {
      room = buildPvcRoom(_shape, _values, corner: _corner);
    } on PvcInputError catch (e) {
      setState(() => _inputError = e);
      _form.currentState!.validate();
      _focus[e.field]?.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final token = ++_token;
    setState(() {
      _busy = true;
      _calculated = false;
      _error = null;
    });
    try {
      pvcJointPosition(room.points, _orientation, _jointRule);
      final result = await compute(
          runPvcCalculation,
          PvcCalculation(room, _mode,
              orientation: _orientation, jointRule: _jointRule));
      if (!mounted || token != _token) return;
      setState(() {
        _layout = result;
        _calculated = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _resultsAnchor.currentContext;
        if (mounted && token == _token && target != null) {
          Scrollable.ensureVisible(target,
              alignment: 0, duration: const Duration(milliseconds: 180));
        }
      });
    } on ArgumentError catch (e) {
      if (mounted && token == _token) {
        setState(() => _error = '${e.message}');
      }
    } catch (_) {
      if (mounted && token == _token) {
        setState(() =>
            _error = 'Unable to calculate this layout. Please try again.');
      }
    } finally {
      if (mounted && token == _token) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    PvcRoom? room;
    String? previewError;
    try {
      room = buildPvcRoom(_shape, _values, corner: _corner);
    } on PvcInputError {
      previewError = 'Preview unavailable. Check the entered dimensions.';
    }
    final active =
        _focus.entries.where((e) => e.value.hasFocus).firstOrNull?.key;
    return Scaffold(
        appBar: AppBar(title: const Text('PVC Ceiling')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _selectors(),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<PvcOrientation>(
                                  key: const ValueKey('pvcOrientation'),
                                  initialValue: _orientation,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Plank installation direction'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: PvcOrientation.automatic,
                                        child: Text('Auto · Best layout')),
                                    DropdownMenuItem(
                                        value: PvcOrientation.length,
                                        child:
                                            Text('Along length · A direction')),
                                    DropdownMenuItem(
                                        value: PvcOrientation.width,
                                        child:
                                            Text('Across width · B direction')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null ||
                                        value == _orientation) {
                                      return;
                                    }
                                    final recalculate = _calculated || _busy;
                                    _orientation = value;
                                    _invalidate();
                                    if (recalculate) _calculate();
                                  }),
                              const SizedBox(height: 6),
                              _jointControls(room),
                              PvcSection(
                                  title: 'Room measurements',
                                  first: true,
                                  trailing: PvcMeasurementGuide(
                                      room: room, active: active),
                                  child: Form(
                                      key: _form,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (previewError != null)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 10),
                                                  child: Text(previewError,
                                                      style: AppTypography
                                                          .text13W600Error)),
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxWidth: 640),
                                                    child: LayoutBuilder(
                                                        builder: (context,
                                                                fieldsBox) =>
                                                            _fields(fieldsBox
                                                                .maxWidth)))),
                                            const SizedBox(height: 16),
                                            FilledButton(
                                                onPressed:
                                                    _busy ? null : _calculate,
                                                child: _busy
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2.5,
                                                                color: AppColors
                                                                    .white))
                                                    : const Text('Calculate')),
                                          ]))),
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(_error!,
                                        style: AppTypography.text13W600Error)),
                              if (_calculated)
                                KeyedSubtree(
                                    key: _resultsAnchor,
                                    child: PvcCeilingResults(layout: _layout)),
                            ]))))));
  }

  Widget _jointControls(PvcRoom? room) {
    double? joint;
    String? issue;
    if (_jointMode != PvcJointMode.automatic && room != null) {
      try {
        joint = pvcJointPosition(room.points, _orientation, _jointRule);
      } on ArgumentError catch (e) {
        issue = '${e.message}';
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      DropdownButtonFormField<PvcJointMode>(
          key: const ValueKey('pvcJointMode'),
          initialValue: _jointMode,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Joint placement (optional)'),
          items: const [
            DropdownMenuItem(
                value: PvcJointMode.automatic,
                child: Text('Auto · Existing optimization')),
            DropdownMenuItem(
                value: PvcJointMode.centre, child: Text('Centre of room')),
            DropdownMenuItem(
                value: PvcJointMode.custom,
                child: Text('Custom joint position')),
          ],
          onChanged: (value) {
            if (value == null) return;
            _jointMode = value;
            _invalidate();
          }),
      if (_jointMode != PvcJointMode.automatic) ...[
        const SizedBox(height: 10),
        const Text(
            'Choose A or B installation direction above. The coloured line '
            'is the joint; left/right refer to the original room diagram, '
            'top/bottom for B. More material or joints may be required.',
            style: AppTypography.text14Greymuted),
        if (_jointMode == PvcJointMode.custom) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<bool>(
              key: const ValueKey('pvcJointSide'),
              initialValue: _fromEnd,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Measure from room side'),
              items: [
                DropdownMenuItem(
                    value: false,
                    child: Text(_orientation == PvcOrientation.width
                        ? 'Top side'
                        : 'Left side')),
                DropdownMenuItem(
                    value: true,
                    child: Text(_orientation == PvcOrientation.width
                        ? 'Bottom side'
                        : 'Right side')),
              ],
              onChanged: (value) {
                if (value == null) return;
                _fromEnd = value;
                _invalidate();
              }),
          const SizedBox(height: 10),
          AppNumberField(
              key: const ValueKey('pvcJointDistance'),
              validator: (_) => null,
              label: 'Distance to joint',
              unit: 'ft',
              compact: true,
              controller: _jointDistance),
        ],
        if (issue != null) Text(issue, style: AppTypography.text13W600Error),
        if (joint != null && room != null)
          PvcShapePreview(room: room, joint: joint, orientation: _orientation),
      ],
    ]);
  }

  Widget _selectors() => LayoutBuilder(builder: (context, box) {
        final controls = <Widget>[
          DropdownButtonFormField<PvcShape>(
              key: const ValueKey('pvcShape'),
              initialValue: _shape,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Room shape'),
              items: [
                for (final shape in PvcShape.values)
                  DropdownMenuItem(value: shape, child: Text(shape.label))
              ],
              onChanged: _selectShape),
          DropdownButtonFormField<String>(
              key: const ValueKey('pvcStock'),
              initialValue: _mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Planks to use'),
              items: const [
                DropdownMenuItem(
                    value: 'mix', child: Text('Mix 10 ft + 12 ft')),
                DropdownMenuItem(value: '10', child: Text('Only 10 ft')),
                DropdownMenuItem(value: '12', child: Text('Only 12 ft'))
              ],
              onChanged: (value) {
                if (value == null || value == _mode) return;
                _invalidate();
                setState(() => _mode = value);
              }),
        ];
        if (box.maxWidth >= 620) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: controls[0]),
            const SizedBox(width: 14),
            Expanded(child: controls[1])
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [controls[0], const SizedBox(height: 12), controls[1]]);
      });

  Widget _fields(double width) {
    final fields = pvcDimensions(_shape);
    final twoColumns =
        width >= 280 * MediaQuery.textScalerOf(context).scale(16) / 16;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_shape == PvcShape.t || _shape == PvcShape.u)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Leave E empty to center the stem or opening.',
                style: AppTypography.text14Greymuted)),
      Wrap(spacing: 12, runSpacing: 10, children: [
        for (var i = 0; i < fields.length; i++)
          SizedBox(
              key: _anchors[fields[i].key],
              width: twoColumns ? (width - 12) / 2 : width,
              child: AppNumberField(
                  key: ValueKey('pvcField${_shape.name}${fields[i].key}'),
                  label: fields[i].label,
                  leadingLabel: fields[i].key,
                  unit: 'ft',
                  compact: true,
                  textAlign: TextAlign.end,
                  controller: _controllers[fields[i].key]!,
                  focusNode: _focus[fields[i].key],
                  labelAbove: true,
                  textInputAction: i == fields.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onFieldSubmitted: (_) {
                    if (i == fields.length - 1) {
                      _calculate();
                    } else {
                      _focus[fields[i + 1].key]!.requestFocus();
                    }
                  },
                  validator: (text) =>
                      pvcFieldError(_shape, fields[i], text ?? '') ??
                      (_inputError?.field == fields[i].key
                          ? _inputError?.message
                          : null)))
      ]),
      if (_shape == PvcShape.l)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
                initialValue: _corner,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Room steps in at'),
                items: const [
                  DropdownMenuItem(value: 'tr', child: Text('Top right')),
                  DropdownMenuItem(value: 'tl', child: Text('Top left')),
                  DropdownMenuItem(value: 'br', child: Text('Bottom right')),
                  DropdownMenuItem(value: 'bl', child: Text('Bottom left'))
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _invalidate();
                  setState(() => _corner = value);
                })),
    ]);
  }
}
