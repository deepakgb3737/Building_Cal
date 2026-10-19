import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/core/input_validation.dart';
import 'package:grid_ceiling_calculator/ui/app_widgets.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/ui/app_styles.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/ui/enhanced_room_layout.dart';
import '../logic/l_shape/l_ceiling_calculator.dart';
import '../logic/l_shape/l_ceiling_result.dart';
import '../logic/l_shape/l_ceiling_room.dart';
import 'l_shape/l_ceiling_inputs.dart';
import 'l_shape/l_ceiling_results.dart';

class GridCeilingCalculatorScreen extends StatefulWidget {
  // Disabled by default; retained for opt-in development and regression tests.
  static const lShapeEnabled = bool.fromEnvironment('BUILDCALC_ENABLE_L_SHAPE');
  const GridCeilingCalculatorScreen({super.key});

  @override
  State<GridCeilingCalculatorScreen> createState() =>
      _GridCeilingCalculatorScreenState();
}

class _GridCeilingCalculatorScreenState
    extends State<GridCeilingCalculatorScreen> {
  final _widthController = TextEditingController();
  final _lengthController = TextEditingController();
  final _armController = TextEditingController();
  final _depthController = TextEditingController();
  final _dimensionFocus =
      List.generate(4, (i) => FocusNode(debugLabel: 'L-${'ABCD'[i]}'));
  final _formKey = GlobalKey<FormState>();
  GridCeilingResult? _result;
  LCeilingResult? _lResult;
  bool _selectedLShape = false;
  bool get _lShape =>
      GridCeilingCalculatorScreen.lShapeEnabled && _selectedLShape;
  MissingCorner _corner = MissingCorner.topRight;
  double _calculatedWidth = 0;
  double _calculatedLength = 0;
  bool _interactingWithDrawing = false;
  PlacementMode _placementMode = PlacementMode.centerBased;

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_invalidateResult);
    _lengthController.addListener(_invalidateResult);
    _armController.addListener(_invalidateResult);
    _depthController.addListener(_invalidateResult);
  }

  void _invalidateResult() {
    if (_result == null && _lResult == null) return;
    setState(() {
      _result = null;
      _lResult = null;
      _interactingWithDrawing = false;
    });
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final width = double.parse(_widthController.text);
    final length = double.parse(_lengthController.text);
    final result = _lShape
        ? null
        : GridCeilingCalculator.calculate(width, length, mode: _placementMode);
    final lResult = !_lShape
        ? null
        : LCeilingCalculator.calculate(
            LCeilingRoom(
                widthMm: width,
                lengthMm: length,
                verticalArmWidthMm: double.parse(_armController.text),
                horizontalArmDepthMm: double.parse(_depthController.text),
                missingCorner: _corner),
            mode: _placementMode);
    setState(() {
      _result = result;
      _lResult = lResult;
      _calculatedWidth = width;
      _calculatedLength = length;
    });
  }

  void _reset() {
    _formKey.currentState?.reset();
    _widthController.clear();
    _lengthController.clear();
    _armController.clear();
    _depthController.clear();
    setState(() {
      _result = null;
      _lResult = null;
      _selectedLShape = false;
      _corner = MissingCorner.topRight;
      _placementMode = PlacementMode.centerBased;
      _interactingWithDrawing = false;
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _lengthController.dispose();
    _armController.dispose();
    _depthController.dispose();
    for (final node in _dimensionFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Grid Ceiling'), actions: [
          TextButton(onPressed: _reset, child: const Text('Reset')),
        ]),
        body: SafeArea(
            child: SingleChildScrollView(
          physics: _interactingWithDrawing
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (GridCeilingCalculatorScreen.lShapeEnabled) ...[
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                      value: false, label: Text('Rectangle')),
                                  ButtonSegment(
                                      value: true, label: Text('L-shape')),
                                ],
                                selected: {_lShape},
                                onSelectionChanged: (selection) => setState(() {
                                  _selectedLShape = selection.single;
                                  _result = null;
                                  _lResult = null;
                                  _interactingWithDrawing = false;
                                }),
                              ),
                              const SizedBox(height: 20),
                            ],
                            const Text('Room measurements',
                                style: AppTypography.text20BoldInk),
                            const SizedBox(height: 6),
                            const Text('Enter width and length in millimetres.',
                                style: AppTypography.text14Secondarytext),
                            const SizedBox(height: 20),
                            LayoutBuilder(builder: (context, constraints) {
                              final widthField = AppNumberField(
                                  label: _lShape
                                      ? 'A · Overall width (mm)'
                                      : 'Width (mm)',
                                  labelAbove: _lShape,
                                  controller: _widthController,
                                  focusNode: _dimensionFocus[0],
                                  integerOnly: true,
                                  validator: (value) =>
                                      InputValidation.roomDimension(
                                          value, 'Width'));
                              final lengthField = AppNumberField(
                                  label: _lShape
                                      ? 'B · Overall length (mm)'
                                      : 'Length (mm)',
                                  labelAbove: _lShape,
                                  controller: _lengthController,
                                  focusNode: _dimensionFocus[1],
                                  integerOnly: true,
                                  validator: (value) =>
                                      InputValidation.roomDimension(
                                          value, 'Length'));
                              return constraints.maxWidth >= 520
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          Expanded(child: widthField),
                                          const SizedBox(width: 16),
                                          Expanded(child: lengthField)
                                        ])
                                  : Column(children: [
                                      widthField,
                                      const SizedBox(height: 16),
                                      lengthField
                                    ]);
                            }),
                            if (_lShape)
                              LCeilingInputs(
                                width: _widthController,
                                length: _lengthController,
                                arm: _armController,
                                depth: _depthController,
                                dimensionFocus: _dimensionFocus,
                                corner: _corner,
                                onCornerChanged: (corner) => setState(() {
                                  _corner = corner;
                                  _lResult = null;
                                  _interactingWithDrawing = false;
                                }),
                              ),
                            const SizedBox(height: 24),
                            const Text('Grid placement',
                                style: AppTypography.text16W700Text),
                            const SizedBox(height: 8),
                            RadioGroup<PlacementMode>(
                                groupValue: _placementMode,
                                onChanged: (mode) {
                                  if (mode == null) return;
                                  setState(() {
                                    _placementMode = mode;
                                    _result = null;
                                    _lResult = null;
                                    _interactingWithDrawing = false;
                                  });
                                },
                                child: IntrinsicHeight(
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                      Expanded(
                                          child: RadioListTile<PlacementMode>(
                                              value: PlacementMode.centerBased,
                                              selected: _placementMode ==
                                                  PlacementMode.centerBased,
                                              shape:
                                                  const RoundedRectangleBorder(
                                                      borderRadius:
                                                          AppRadii.r10),
                                              selectedTileColor:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              title: const Text('Centered',
                                                  style: AppTypography
                                                      .text14W600Text))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: RadioListTile<PlacementMode>(
                                              value: PlacementMode.oneSide,
                                              selected: _placementMode ==
                                                  PlacementMode.oneSide,
                                              shape:
                                                  const RoundedRectangleBorder(
                                                      borderRadius:
                                                          AppRadii.r10),
                                              selectedTileColor:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              title: const Text('From one wall',
                                                  style: AppTypography
                                                      .text14W600Text))),
                                    ]))),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _calculate,
                                child: const Text('Calculate layout')),
                          ])),
                  if (_result != null) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    EnhancedRoomLayoutScreen(
                        key: ValueKey(_result),
                        result: _result!,
                        width: _calculatedWidth,
                        length: _calculatedLength,
                        embedded: true,
                        onInteractionChanged: (active) {
                          if (_interactingWithDrawing == active) return;
                          setState(() => _interactingWithDrawing = active);
                        }),
                  ],
                  if (_lShape && _lResult != null) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    LCeilingResults(
                        key: ValueKey(_lResult),
                        result: _lResult!,
                        onInteractionChanged: (active) {
                          if (active != _interactingWithDrawing) {
                            setState(() => _interactingWithDrawing = active);
                          }
                        }),
                  ],
                ]),
          )),
        )),
      );
}
