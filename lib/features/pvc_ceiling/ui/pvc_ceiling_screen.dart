import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_typography.dart';
import '../../../ui/app_widgets.dart';
import '../logic/pvc_ceiling_calculator.dart';
import 'pvc_measurement_guide.dart';
import 'pvc_section.dart';
import 'pvc_ceiling_results.dart';
import 'pvc_pdf_renderer.dart';
import '../../../core/pdf/pdf_export.dart';
import 'package:printing/printing.dart';
import 'pvc_ceiling_painter.dart';
import '../logic/pvc_projects.dart';
import 'pvc_project_dialogs.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_platform_store.dart';

class PvcCeilingScreen extends StatefulWidget {
  const PvcCeilingScreen({super.key, this.projects});
  final PvcProjectRepository? projects;
  @override
  State<PvcCeilingScreen> createState() => _PvcCeilingScreenState();
}

class _PvcCeilingScreenState extends State<PvcCeilingScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _resultsAnchor = GlobalKey();
  final _directionAnchor = GlobalKey();
  late final _projects = widget.projects ??
      PvcProjectRepository(
          createDocumentStorage(namespace: 'pvc_ceiling_projects'));
  PvcProjectEntry? _project;
  String? _savedSignature;
  late final String _initialSignature;
  bool _projectBusy = false, _restoring = false;
  bool _pdfBusy = false;
  bool get _canSharePdf =>
      _calculated && _layout != null && !_busy && !_projectBusy;

  Future<void> _sharePdf() async {
    if (!_canSharePdf) return;
    final layout = _layout!, settings = PvcProjectData.fromJson(_projectJson);
    final name = _project?.name ?? 'PVC Ceiling';
    final box = context.findRenderObject() as RenderBox?;
    final bounds = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _projectBusy = true;
      _pdfBusy = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await BuildCalcPdfExport.buildPages(
          projectName: name,
          pages: PvcPdfRenderer.pages(
              layout: layout, settings: settings, name: name));
      if (!mounted) return;
      final shared = await Printing.sharePdf(
          bytes: bytes,
          filename: BuildCalcPdfExport.filename(name),
          bounds: bounds);
      if (!shared && mounted) {
        _projectMessage('PDF sharing was not completed. You can try again.');
      }
    } catch (error, stack) {
      debugPrint('PVC PDF export failed: $error\n$stack');
      _projectMessage(
          'Could not create or share the PVC PDF. Your calculation is unchanged. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          _projectBusy = false;
          _pdfBusy = false;
        });
      }
    }
  }

  late String _lastInputText;
  String get _inputText => jsonEncode([
        for (final controller in _controllers.values) controller.text,
        _jointDistance.text,
      ]);
  void _inputChanged() {
    if (_lastInputText == _inputText) return;
    _invalidate();
  }

  Map<String, Object> get _projectJson => {
        'shape': _shape.name,
        'values': _values,
        'stock': _mode,
        'corner': _corner,
        'orientation': _orientation.name,
        'joint': _jointMode.name,
        'distance': _jointDistance.text,
        'fromEnd': _fromEnd,
      };
  bool get _projectDirty =>
      jsonEncode(_projectJson) != (_savedSignature ?? _initialSignature);
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
    _lastInputText = _inputText;
    _initialSignature = jsonEncode(_projectJson);
    _jointDistance.addListener(_inputChanged);
    for (final c in _controllers.values) {
      c.addListener(_inputChanged);
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
  void _invalidate() {
    _lastInputText = _inputText;
    if (_restoring) return;
    setState(() {
      ++_token;
      _layout = null;
      _calculated = _busy = false;
      _error = null;
      _inputError = null;
    });
  }

  void _projectMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveProject() async {
    if (_projectBusy) return;
    if (_layout == null || !_calculated || _busy) {
      _projectMessage('Calculate a valid layout before saving your project.');
      return;
    }
    final data = PvcProjectData.fromJson(_projectJson);
    final name = await showDialog<String>(
        context: context,
        builder: (_) => PvcProjectNameDialog(name: _project?.name ?? ''));
    if (name == null || !mounted) return;
    setState(() => _projectBusy = true);
    try {
      final sameName = _project != null &&
          _project!.name.toLowerCase() ==
              PvcProjectRepository.validName(name).toLowerCase();
      final saved =
          await _projects.save(name, data, id: sameName ? _project!.id : null);
      if (!mounted) return;
      setState(() {
        _project = saved;
        _savedSignature = jsonEncode(data.toJson());
      });
      _projectMessage('Project saved on this device.');
    } on FormatException catch (e) {
      _projectMessage(e.message);
    } catch (_) {
      _projectMessage(
          'Could not save project. Please retry; the previous saved copy is unchanged.');
    } finally {
      if (mounted) setState(() => _projectBusy = false);
    }
  }

  Future<void> _openProjects() async {
    if (_projectBusy) return;
    final entry = await showDialog<PvcProjectEntry>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PvcProjectListDialog(
            repository: _projects,
            onDelete: (id) {
              if (mounted && _project?.id == id) {
                setState(() {
                  _project = null;
                  _savedSignature = null;
                });
              }
            }));
    if (entry == null || !mounted) return;
    if (_projectDirty &&
        !await confirmPvcProject(context, 'Replace current inputs?',
            'Unsaved changes will be replaced. Cancel and save first if you want to keep them.')) {
      return;
    }
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _projectBusy = true);
    try {
      final data = await _projects.open(entry.id);
      if (!mounted) return;
      _restoring = true;
      _shape = data.shape;
      _saved[_shape] = data.values;
      _load();
      _mode = data.stock;
      _corner = data.corner;
      _orientation = data.orientation;
      _jointMode = data.jointMode;
      _fromEnd = data.fromEnd;
      _jointDistance.text = data.distance;
      _restoring = false;
      _invalidate();
      setState(() {
        _project = entry;
        _savedSignature = jsonEncode(data.toJson());
      });
      await _calculate();
    } catch (_) {
      _projectMessage(
          'Could not open this project. Check its saved data and retry.');
    } finally {
      _restoring = false;
      if (mounted) setState(() => _projectBusy = false);
    }
  }

  void _selectShape(PvcShape? shape) {
    if (shape == null || shape == _shape) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _saved[_shape] = _values;
    for (final c in _controllers.values) {
      c.removeListener(_inputChanged);
    }
    _shape = shape;
    _load();
    for (final c in _controllers.values) {
      c.addListener(_inputChanged);
    }
    _invalidate();
  }

  @override
  void dispose() {
    _jointDistance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      c.removeListener(_inputChanged);
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
    final jointDirection = _jointMode != PvcJointMode.automatic;
    return Scaffold(
        bottomNavigationBar: _pdfBusy
            ? const SafeArea(top: false, child: LinearProgressIndicator())
            : null,
        appBar: AppBar(title: const Text('PVC Ceiling'), actions: [
          PopupMenuButton<String>(
              tooltip: 'PVC projects',
              icon: const Icon(Icons.folder_open_outlined),
              enabled: !_projectBusy,
              onSelected: (value) {
                if (value == 'pdf') {
                  _sharePdf();
                } else if (value == 'save') {
                  _saveProject();
                } else {
                  _openProjects();
                }
              },
              itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'pdf',
                        enabled: _canSharePdf,
                        child: const Text('Share PDF')),
                    const PopupMenuItem(
                        value: 'save', child: Text('Save project')),
                    const PopupMenuItem(
                        value: 'open', child: Text('Saved projects')),
                  ]),
        ]),
        body: AbsorbPointer(
            absorbing: _projectBusy,
            child: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1040),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_project != null)
                                    Text(
                                        'Project: ${_project!.name}${_projectDirty ? " (unsaved changes)" : ""}',
                                        style: AppTypography.text14Greymuted),
                                  _selectors(),
                                  const SizedBox(height: 12),
                                  KeyedSubtree(
                                      key: _directionAnchor,
                                      child: DropdownButtonFormField<
                                              PvcOrientation>(
                                          key: const ValueKey('pvcOrientation'),
                                          initialValue: _orientation,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                              labelText:
                                                  'Plank installation direction',
                                              filled:
                                                  jointDirection ? true : null,
                                              fillColor: jointDirection
                                                  ? AppColors.blueSurface
                                                  : null,
                                              enabledBorder: jointDirection
                                                  ? Theme.of(context)
                                                      .inputDecorationTheme
                                                      .focusedBorder
                                                  : null,
                                              helperMaxLines: 3,
                                              helperText: !jointDirection
                                                  ? null
                                                  : _orientation ==
                                                          PvcOrientation
                                                              .automatic
                                                      ? 'Choose A or B for the joint line.'
                                                      : 'Joint line follows ${_orientation == PvcOrientation.length ? "A (length)" : "B (width)"}.'),
                                          items: const [
                                            DropdownMenuItem(
                                                value: PvcOrientation.automatic,
                                                child:
                                                    Text('Auto · Best layout')),
                                            DropdownMenuItem(
                                                value: PvcOrientation.length,
                                                child: Text(
                                                    'Along length · A direction')),
                                            DropdownMenuItem(
                                                value: PvcOrientation.width,
                                                child: Text(
                                                    'Across width · B direction')),
                                          ],
                                          onChanged: (value) {
                                            if (value == null ||
                                                value == _orientation) {
                                              return;
                                            }
                                            final recalculate =
                                                _calculated || _busy;
                                            _orientation = value;
                                            _invalidate();
                                            if (recalculate) _calculate();
                                          })),
                                  const SizedBox(height: 6),
                                  _jointControls(room),
                                  PvcSection(
                                      title: 'Room measurements',
                                      first: true,
                                      trailing: PvcMeasurementGuide(
                                          room: room, active: active),
                                      child: Form(
                                          key: _form,
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
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
                                                    alignment:
                                                        Alignment.centerLeft,
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
                                                    onPressed: _busy
                                                        ? null
                                                        : _calculate,
                                                    child: _busy
                                                        ? const SizedBox(
                                                            width: 22,
                                                            height: 22,
                                                            child: CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2.5,
                                                                color: AppColors
                                                                    .white))
                                                        : const Text(
                                                            'Calculate')),
                                              ]))),
                                  if (_error != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(_error!,
                                            style:
                                                AppTypography.text13W600Error)),
                                  if (_calculated)
                                    KeyedSubtree(
                                        key: _resultsAnchor,
                                        child:
                                            PvcCeilingResults(layout: _layout)),
                                ])))))));
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
            if (value != PvcJointMode.automatic) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final target = _directionAnchor.currentContext;
                if (mounted &&
                    target != null &&
                    _jointMode != PvcJointMode.automatic) {
                  Scrollable.ensureVisible(target,
                      alignment: .15,
                      duration: const Duration(milliseconds: 180));
                }
              });
            }
          }),
      if (_jointMode != PvcJointMode.automatic) ...[
        const SizedBox(height: 10),
        const Text(
            'The coloured line '
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
