import 'package:grid_ceiling_calculator/core/theme/build_calc_colors.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/ceiling_material_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grid_ceiling_calculator/features/grid_ceiling/logic/grid_ceiling_calculator.dart';
import 'dart:math' as math;
import '../logic/cross_t_spans.dart';
import '../../../ui/app_typography.dart';
import '../../../ui/app_styles.dart';
import 'ceiling_label_placement.dart';

class EnhancedRoomLayoutScreen extends StatefulWidget {
  final GridCeilingResult result;
  final double width;
  final double length;
  final bool embedded;
  final ValueChanged<bool>? onInteractionChanged;

  const EnhancedRoomLayoutScreen({
    super.key,
    required this.result,
    required this.width,
    required this.length,
    this.embedded = false,
    this.onInteractionChanged,
  });

  @override
  State<EnhancedRoomLayoutScreen> createState() =>
      _EnhancedRoomLayoutScreenState();
}

class _EnhancedRoomLayoutScreenState extends State<EnhancedRoomLayoutScreen> {
  double _yawDeg = 35;
  double _pitchDeg = -28;
  double _zoom = 1.0;
  double _zoomAtScaleStart = 1.0;
  bool _showMeasurements = true;
  bool _isManipulating3D = false;
  bool _show3D = true;

  // Local design tokens (kept here so the screen is self-contained).
  static const double _cardRadius = 14;
  static const _edgeJunctionNotice =
      'Edge split quantities assume compatible 2ft-to-2ft junctions at the existing dividers. Confirm with your grid supplier before ordering.';

  _Palette get _c => _Palette.of(context);

  TextStyle _ts(double size, {FontWeight w = FontWeight.w400, Color? color}) =>
      TextStyle(fontSize: size, fontWeight: w, color: color ?? _c.textPrimary);

  GridCeilingResult get result => widget.result;
  double get width => widget.width;
  double get length => widget.length;

  // ---------------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------------
  double get _areaM2 => (width * length) / 1000000.0;
  double get _areaSqFt => _areaM2 * 10.7639;
  double get _diagonalMm => math.sqrt((width * width) + (length * length));

  List<double> get _mains =>
      result.mainRunnersWidth.map<double>((e) => e.toDouble()).toList();
  List<double> get _twoFoot =>
      result.twoFootCrossT.map<double>((e) => e.toDouble()).toList();
  List<double> get _cross =>
      result.crossTLength.map<double>((e) => e.toDouble()).toList();

  double? _spacing(List<double> v) => v.length >= 2 ? (v[1] - v[0]) : null;

  String _mm(num v) => '${v.round()} mm';

  String _feetInches(double mm) {
    final totalInches = mm / 25.4;
    var feet = (totalInches / 12).floor();
    var inches = (totalInches - (feet * 12)).round();
    if (inches == 12) {
      feet += 1;
      inches = 0;
    }
    return '$feet\u2032 $inches\u2033';
  }

  bool get _isOneSide => result.placementMode == PlacementMode.oneSide;

  String get _modeLabel => result.placementMode == PlacementMode.centerBased
      ? 'Centered layout'
      : 'Started from one wall';

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 760;

    const scale = 10.0;
    final scaledWidth = width / scale;
    final scaledLength = length / scale;
    const jointSpacing = CeilingMaterialService.runnerLengthMm;
    final gap = isCompact ? 12.0 : 16.0;

    final drawingCard = _card(
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      child: _buildRoomLayout(
          scaledWidth, scaledLength, scale, jointSpacing, isCompact),
    );

    final details = _card(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 18),
      child: Column(children: [
        _detailSection('Measurements', 'Starting points and spacing',
            _buildPlacementsCard(isCompact),
            icon: Icons.straighten, expanded: true),
        _thinDivider(),
        _detailSection('Runner cutting', 'Lengths to cut for each row',
            _buildCuttingCard(isCompact),
            icon: Icons.content_cut),
        _thinDivider(),
        _detailSection('Installation steps', 'Recommended order of work',
            _buildNotesCard(isCompact),
            icon: Icons.format_list_numbered),
      ]),
    );

    final mq = MediaQuery.of(context);
    final content = MediaQuery(
        // Keep layout intact for users with very large system font sizes.
        data: mq.copyWith(
            textScaler:
                mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1120),
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              SizedBox(height: gap),
              _buildMaterialsCard(isCompact),
              SizedBox(height: gap),
              drawingCard,
              SizedBox(height: gap),
              _groupLabel('Install details'),
              details,
              SizedBox(height: gap),
            ],
          ),
        ));

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ceiling layout'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 10.0 : 20.0),
          physics: _isManipulating3D
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: content,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable building blocks
  // ---------------------------------------------------------------------------
  Widget _card({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? _c.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: borderColor ?? _c.border),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _c.textPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: _c.textPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(title, style: _ts(17, w: FontWeight.w700)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: _ts(12, color: _c.textMuted)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _dot(Color color, {double size = 10}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ---------------------------------------------------------------------------
  // Header + stats + navigation
  // ---------------------------------------------------------------------------
  Widget _eyebrow(String text) => Text(
        text.toUpperCase(),
        style: _ts(11, w: FontWeight.w700, color: _c.textMuted)
            .copyWith(letterSpacing: 0.9),
      );

  Widget _buildHeader() {
    Widget dimension(String label, double mm) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow(label),
              const SizedBox(height: 4),
              Text('${mm.round()} mm', style: _ts(18, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_feetInches(mm), style: _ts(13, color: _c.textMuted)),
            ],
          ),
        );

    return _card(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _eyebrow('Ceiling area'),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _c.surfaceSubtle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _isOneSide
                              ? Icons.align_horizontal_left
                              : Icons.filter_center_focus,
                          size: 14,
                          color: _c.textSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(_modeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(12,
                                w: FontWeight.w600, color: _c.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _areaSqFt.toStringAsFixed(2),
                    style: _ts(40, w: FontWeight.w800)
                        .copyWith(height: 1.0, letterSpacing: -1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('sq ft',
                    style:
                        _ts(16, w: FontWeight.w600, color: _c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_areaM2.toStringAsFixed(2)} m²',
              style: _ts(14, color: _c.textMuted)),
          const SizedBox(height: 16),
          Divider(height: 1, color: _c.border),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dimension('Width', width),
              Container(
                  width: 1,
                  height: 52,
                  margin: const EdgeInsets.only(right: 16),
                  color: _c.border),
              dimension('Length', length),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(text.toUpperCase(),
            style: _ts(12, w: FontWeight.w700, color: _c.textMuted)
                .copyWith(letterSpacing: 0.8)),
      );

  Widget _detailSection(String title, String subtitle, Widget child,
          {IconData? icon, bool expanded = false}) =>
      ExpansionTile(
        key: PageStorageKey('ceiling-$title'),
        initiallyExpanded: expanded,
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: icon == null
            ? null
            : Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _c.textPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _c.textPrimary),
              ),
        title: Text(title, style: _ts(15, w: FontWeight.w700)),
        subtitle: Text(subtitle, style: _ts(12, color: _c.textMuted)),
        children: [child],
      );

  // ---------------------------------------------------------------------------
  // Drawing (3D / 2D)
  // ---------------------------------------------------------------------------
  Widget _buildRoomLayout(double scaledWidth, double scaledLength, double scale,
      double jointSpacing, bool isCompact) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTiny = screenWidth < 390;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          Icons.architecture,
          _show3D ? '3D preview' : '2D technical plan',
          subtitle: _show3D
              ? 'Drag to rotate · pinch to zoom · long-press to reset'
              : 'Pinch to zoom · drag to pan · all values in mm',
          trailing: _show3D
              ? null
              : IconButton(
                  tooltip: 'Open full screen',
                  onPressed: _openFullscreenPlan,
                  icon: const Icon(Icons.fullscreen, size: 24),
                ),
        ),
        SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('3D view'),
                    icon: Icon(Icons.threed_rotation, size: 18)),
                ButtonSegment(
                    value: false,
                    label: Text('2D plan'),
                    icon: Icon(Icons.grid_on, size: 18)),
              ],
              selected: {_show3D},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _show3D = selection.single),
            )),
        const SizedBox(height: 12),
        if (_show3D) ...[
          _buildIsometricPreview(isCompact),
          SizedBox(height: isTiny ? 4 : 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  _yawDeg = 35;
                  _pitchDeg = -28;
                  _zoom = 1.0;
                }),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset view'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Measurement labels',
                      style: _ts(13, w: FontWeight.w600)
                          .copyWith(fontSize: isTiny ? 12 : 13),
                    ),
                  ),
                  Switch.adaptive(
                    value: _showMeasurements,
                    onChanged: (value) =>
                        setState(() => _showMeasurements = value),
                  ),
                ],
              ),
            ],
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: isTiny ? 340 : (isCompact ? 420 : 540),
            child: _build2DViewer(scale, jointSpacing, isTiny),
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: _c.border),
        const SizedBox(height: 12),
        _buildLegend(isCompact),
      ],
    );
  }

  Widget _build2DViewer(double scale, double jointSpacing, bool isTiny) {
    final occupiedLabels = <Rect>[];
    final typeLabels = <Widget>[];
    final scaledWidth = width / scale;
    final scaledLength = length / scale;
    final labelLines = <(Offset, Offset)>[
      (const Offset(120, 50), Offset(120 + scaledWidth, 50)),
      (
        Offset(120, 50 + scaledLength),
        Offset(120 + scaledWidth, 50 + scaledLength)
      ),
      for (final x in [
        0.0,
        ...result.mainRunnersWidth,
        ...result.twoFootCrossT,
        width
      ])
        (
          Offset(120 + x / scale, 50),
          Offset(120 + x / scale, 50 + scaledLength)
        ),
      for (final y in result.crossTLength)
        (
          Offset(120, 50 + y / scale),
          Offset(120 + scaledWidth, 50 + y / scale)
        ),
    ];
    final dynamicTopBuffer = isTiny ? 70.0 : 80.0;
    final dynamicBottomBuffer = (isTiny ? 120.0 : 140.0) +
        math.min(80.0, result.mainRunnersWidth.length * 8.0);
    final containerWidth = scaledWidth + (isTiny ? 240 : 300);
    final containerHeight =
        scaledLength + dynamicTopBuffer + dynamicBottomBuffer;
    final crossFontSize =
        scaledLength > 300 ? 10.0 : (scaledLength > 150 ? 9.0 : 8.0);
    final widestMeasurement = result.crossTLength.fold<double>(
        0,
        (widest, p) => math.max(
            widest, _estimateTextWidth('${p.round()} mm', crossFontSize)));
    final leftInset = math.max(0.0, widestMeasurement + 20 - 120);
    const topInset = 30.0; // Reserve the existing upper measurement lanes.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 64,
        onInteractionStart: (_) {
          setState(() => _isManipulating3D = true);
          widget.onInteractionChanged?.call(true);
        },
        onInteractionEnd: (_) {
          setState(() => _isManipulating3D = false);
          widget.onInteractionChanged?.call(false);
        },
        child: SizedBox.expand(
            child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            key: const ValueKey('ceiling2DCanvas'),
            width: containerWidth + leftInset,
            height: containerHeight + topInset,
            child: Padding(
                padding: EdgeInsets.only(left: leftInset, top: topInset),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Room container
                    Positioned(
                      left: 120,
                      top: 50,
                      child: Container(
                        width: scaledWidth,
                        height: scaledLength,
                        decoration: BoxDecoration(
                          border: Border.all(color: _c.textPrimary, width: 3),
                          color: _c.surfaceSubtle,
                        ),
                      ),
                    ),
                    // Wall angles
                    ..._buildWallAngles(scaledWidth, scaledLength),
                    // Main runners with joints and labels
                    ..._buildMainRunners(scale, scaledWidth, scaledLength,
                        jointSpacing, occupiedLabels, typeLabels, labelLines),
                    // Cross Ts with labels
                    ..._buildCrossTs(scale, scaledWidth, scaledLength,
                        occupiedLabels, typeLabels, labelLines),
                    // 2ft Cross Ts with labels
                    ..._buildTwoFootTs(scale, scaledWidth, scaledLength,
                        occupiedLabels, typeLabels, labelLines),
                    // Dimension labels
                    ..._buildDimensionLabels(scaledWidth, scaledLength),
                    ...typeLabels,
                  ],
                )),
          ),
        )),
      ),
    );
  }

  void _openFullscreenPlan() {
    const scale = 10.0;
    final isTiny = MediaQuery.sizeOf(context).width < 390;
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('2D plan · pinch to zoom')),
        body: SafeArea(
          child: SizedBox.expand(
            child: _build2DViewer(
                scale, CeilingMaterialService.runnerLengthMm, isTiny),
          ),
        ),
      ),
    ));
  }

  Widget _buildLegend(bool isCompact) {
    Widget item(Color color, String label, {bool joint = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: joint ? 14 : 22,
              height: joint ? 14 : 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(joint ? 7 : 2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
                child: Text(label,
                    style: _ts(14).copyWith(fontSize: isCompact ? 12 : 13))),
          ],
        );

    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item(_c.mainRunner, 'Main runner · 10ft'),
        item(_c.crossRunner, 'Cross T · 4ft'),
        item(_c.shortRunner, 'Cross T · 2ft'),
        item(_c.wallAngle, 'Wall angle · 10ft'),
        item(_c.mainRunner, 'Runner joint', joint: true),
      ],
    );
  }

  Widget _buildIsometricPreview(bool isCompact) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTiny = screenWidth < 390;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTiny ? 6 : (isCompact ? 8 : 12)),
      decoration: BoxDecoration(
        color: _c.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _c.borderStrong),
      ),
      child: AspectRatio(
        aspectRatio: isTiny ? 1.18 : (isCompact ? 1.45 : 1.7),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) {
            setState(() => _isManipulating3D = true);
            widget.onInteractionChanged?.call(true);
            _zoomAtScaleStart = _zoom;
          },
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount == 1) {
                _yawDeg = (_yawDeg + details.focalPointDelta.dx * 0.35) % 360;
                _pitchDeg = (_pitchDeg - details.focalPointDelta.dy * 0.25)
                    .clamp(-85.0, 85.0);
              }
              _zoom = (_zoomAtScaleStart * details.scale).clamp(0.6, 2.2);
            });
          },
          onScaleEnd: (_) {
            setState(() => _isManipulating3D = false);
            widget.onInteractionChanged?.call(false);
          },
          onDoubleTap: () {
            setState(() => _showMeasurements = !_showMeasurements);
          },
          onLongPress: () {
            setState(() {
              _yawDeg = 35;
              _pitchDeg = -28;
              _zoom = 1.0;
            });
          },
          child: CustomPaint(
            painter: _IsometricCeilingPainter(
              roomWidthMm: width,
              roomLengthMm: length,
              mainRunnerPositionsMm: result.mainRunnersWidth,
              twoFootPositionsMm: result.twoFootCrossT,
              crossPositionsMm: result.crossTLength,
              crossSpans: result.crossTSpans,
              palette: _c,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              yawDegrees: _yawDeg,
              pitchDegrees: _pitchDeg,
              zoom: _zoom,
              showMeasurements: _showMeasurements,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWallAngles(double scaledWidth, double scaledLength) {
    return [
      // Top wall angle
      Positioned(
        left: 120,
        top: 50,
        child: Container(
          width: scaledWidth,
          height: 4,
          color: _c.wallAngle,
        ),
      ),
      // Bottom wall angle
      Positioned(
        left: 120,
        top: 50 + scaledLength - 4,
        child: Container(
          width: scaledWidth,
          height: 4,
          color: _c.wallAngle,
        ),
      ),
      // Left wall angle
      Positioned(
        left: 120,
        top: 50,
        child: Container(
          width: 4,
          height: scaledLength,
          color: _c.wallAngle,
        ),
      ),
      // Right wall angle
      Positioned(
        left: 120 + scaledWidth - 4,
        top: 50,
        child: Container(
          width: 4,
          height: scaledLength,
          color: _c.wallAngle,
        ),
      ),
    ];
  }

  List<Widget> _buildMainRunners(
      double scale,
      double scaledWidth,
      double scaledLength,
      double jointSpacing,
      List<Rect> occupiedLabels,
      List<Widget> typeLabels,
      List<(Offset, Offset)> labelLines) {
    List<Widget> widgets = [];

    final runnerCount = result.mainRunnersWidth.length;
    final previousX = <double>[];
    final measurementLanes = <int>[];

    for (int i = 0; i < runnerCount; i++) {
      final pos = result.mainRunnersWidth[i];
      final leftPos = 120 + (pos / scale);

      // Main runner line
      widgets.add(Positioned(
        left: leftPos - 1,
        top: 50,
        child: Container(
          width: 2,
          height: scaledLength,
          color: _c.mainRunner,
        ),
      ));
      if (i == 0) {
        typeLabels.add(_typeLabel(
            '10f',
            ceilingSectionLabelAnchor(
                Offset(leftPos, 50), Offset(leftPos, 50 + scaledLength)),
            _c.mainRunner,
            occupiedLabels,
            lines: labelLines,
            vertical: true,
            key: ValueKey('mainType-$i')));
      }

      // Joint markers and labels
      double currentHeight = jointSpacing;
      while (currentHeight < length) {
        final jointTop = 50 + (currentHeight / scale);

        // Joint marker
        widgets.add(Positioned(
          left: leftPos - 5,
          top: jointTop - 5,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _c.mainRunner,
              shape: BoxShape.circle,
            ),
          ),
        ));
        // Joint label
        widgets.add(Positioned(
          left: leftPos + 15,
          top: jointTop - 5,
          child: Text(
            '⚡',
            style: _ts(16, w: FontWeight.w700, color: _c.mainRunner),
          ),
        ));

        currentHeight += jointSpacing;
      }

      final labelFontSize =
          scaledWidth > 400 ? 10.0 : (scaledWidth > 200 ? 9.0 : 8.0);

      final measurementText = '${pos.round()} mm';
      final measurementLane = _resolveLane(
        center: leftPos,
        previousCenters: previousX,
        previousLanes: measurementLanes,
        collisionDistance:
            _estimateTextWidth(measurementText, labelFontSize) + 12,
        maxLanes: 5,
      );
      final measurementTop = 50 + scaledLength + 28 + (measurementLane * 12);

      // Measurement label at bottom
      widgets.add(Positioned(
        left:
            leftPos - (_estimateTextWidth(measurementText, labelFontSize) / 2),
        top: measurementTop,
        child: Text(
          measurementText,
          style: _ts(12, w: FontWeight.w700, color: _c.mainRunner)
              .copyWith(fontSize: labelFontSize),
        ),
      ));

      previousX.add(leftPos);
      measurementLanes.add(measurementLane);
    }

    return widgets;
  }

  List<Widget> _buildCrossTs(
      double scale,
      double scaledWidth,
      double scaledLength,
      List<Rect> occupiedLabels,
      List<Widget> typeLabels,
      List<(Offset, Offset)> labelLines) {
    List<Widget> widgets = [];

    final crossTCount = result.crossTLength.length;
    final previousY = <double>[];
    final measurementLanes = <int>[];
    final spans = result.crossTSpans;
    final labelledSpans = ceilingStockLabelSpans(spans);

    for (int i = 0; i < crossTCount; i++) {
      final pos = result.crossTLength[i];
      final topPos = 50 + (pos / scale);
      for (var s = 0; s < spans.length; s++) {
        final span = spans[s];
        widgets.add(Positioned(
          key: ValueKey('crossT-$i-$s-${span.usesTwoFoot ? '2ft' : '4ft'}'),
          left: 120 + span.startMm / scale,
          top: topPos - 1,
          child: Container(
            width: (span.endMm - span.startMm) / scale,
            height: 2,
            color: span.usesTwoFoot ? _c.shortRunner : _c.crossRunner,
          ),
        ));
        if (i == (span.usesTwoFoot ? 0 : crossTCount ~/ 2) &&
            labelledSpans.contains(s)) {
          typeLabels.add(_typeLabel(
              span.usesTwoFoot ? '2f' : '4f',
              ceilingSectionLabelAnchor(
                  Offset(120 + span.startMm / scale, topPos),
                  Offset(120 + span.endMm / scale, topPos),
                  atEnd: span.endMm == width),
              span.usesTwoFoot ? _c.shortRunner : _c.crossRunner,
              occupiedLabels,
              lines: labelLines,
              key: ValueKey('crossType-$i-$s')));
        }
      }
      final labelFontSize =
          scaledLength > 300 ? 10.0 : (scaledLength > 150 ? 9.0 : 8.0);

      final measurementText = '${pos.round()} mm';
      final measurementLane = _resolveLane(
        center: topPos,
        previousCenters: previousY,
        previousLanes: measurementLanes,
        collisionDistance: 18,
        maxLanes: 3,
      );

      // Measurement label to the left - show for ALL positions
      widgets.add(Positioned(
        left: (120 - 8 - (measurementLane * 6)) -
            _estimateTextWidth(measurementText, labelFontSize),
        top: topPos - (labelFontSize / 2),
        child: Text(
          measurementText,
          style: _ts(12, w: FontWeight.w700, color: _c.crossRunner)
              .copyWith(fontSize: labelFontSize),
        ),
      ));

      previousY.add(topPos);
      measurementLanes.add(measurementLane);
    }

    return widgets;
  }

  List<Widget> _buildTwoFootTs(
      double scale,
      double scaledWidth,
      double scaledLength,
      List<Rect> occupiedLabels,
      List<Widget> typeLabels,
      List<(Offset, Offset)> labelLines) {
    List<Widget> widgets = [];

    final twoFootTCount = result.twoFootCrossT.length;
    final previousX = <double>[];
    final measurementLanes = <int>[];

    for (int i = 0; i < twoFootTCount; i++) {
      final pos = result.twoFootCrossT[i];
      final leftPos = 120 + (pos / scale);

      // 2ft Cross T line
      widgets.add(Positioned(
        left: leftPos - 1,
        top: 50,
        child: Container(
          width: 2,
          height: scaledLength,
          color: _c.shortRunner,
        ),
      ));
      if (i == 0) {
        typeLabels.add(_typeLabel(
            '2f',
            ceilingSectionLabelAnchor(
                Offset(leftPos, 50), Offset(leftPos, 50 + scaledLength),
                atEnd: true),
            _c.shortRunner,
            occupiedLabels,
            lines: labelLines,
            vertical: true,
            key: ValueKey('dividerType-$i')));
      }

      final labelFontSize =
          scaledWidth > 400 ? 9.0 : (scaledWidth > 200 ? 8.0 : 7.0);

      final measurementText = '${pos.round()} mm';
      final measurementLane = _resolveLane(
        center: leftPos,
        previousCenters: previousX,
        previousLanes: measurementLanes,
        collisionDistance:
            _estimateTextWidth(measurementText, labelFontSize) + 10,
        maxLanes: 5,
      );

      widgets.add(Positioned(
        left:
            leftPos - (_estimateTextWidth(measurementText, labelFontSize) / 2),
        top: 50 - 28 - (measurementLane * 13),
        child: Text(
          measurementText,
          style: _ts(12, w: FontWeight.w700, color: _c.shortRunner)
              .copyWith(fontSize: labelFontSize),
        ),
      ));

      previousX.add(leftPos);
      measurementLanes.add(measurementLane);
    }

    return widgets;
  }

  Widget _typeLabel(
      String text, Offset anchor, Color color, List<Rect> occupied,
      {required Key key,
      required List<(Offset, Offset)> lines,
      bool vertical = false}) {
    final style =
        AppTypography.text12W700Text.copyWith(fontSize: 10, color: color);
    // Diagram tags must fit a grid bay; pinch zoom remains available.
    final textScaler =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: textScaler,
        textDirection: TextDirection.ltr)
      ..layout();
    final rect = placeCeilingLabel(
        anchor: anchor,
        size: Size(painter.width + 8, painter.height + 4),
        bounds: Rect.fromLTWH(120, 50, width / 10, length / 10).deflate(3),
        occupied: occupied,
        lines: lines,
        vertical: vertical);
    if (rect == null) return const SizedBox.shrink();
    final group =
        rect.expandToInclude(Rect.fromCircle(center: anchor, radius: 1));
    return Positioned.fromRect(
      key: key,
      rect: group,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _TypeLabelLeaderPainter(
              anchor - group.topLeft, rect.center - group.topLeft, color),
          child: Stack(children: [
            Positioned.fromRect(
                rect: rect.shift(-group.topLeft),
                child: ColoredBox(
                    color: _c.surface,
                    child: Center(
                        child: Text(text,
                            style: style,
                            textScaler: textScaler,
                            maxLines: 1)))),
          ]),
        ),
      ),
    );
  }

  int _resolveLane({
    required double center,
    required List<double> previousCenters,
    required List<int> previousLanes,
    required double collisionDistance,
    required int maxLanes,
  }) {
    final occupiedLanes = <int>{};
    for (int i = 0; i < previousCenters.length; i++) {
      if ((center - previousCenters[i]).abs() < collisionDistance) {
        occupiedLanes.add(previousLanes[i]);
      }
    }

    for (int lane = 0; lane < maxLanes; lane++) {
      if (!occupiedLanes.contains(lane)) {
        return lane;
      }
    }
    return previousLanes.isEmpty ? 0 : (previousLanes.last + 1) % maxLanes;
  }

  double _estimateTextWidth(String text, double fontSize) {
    return (TextPainter(
            text: TextSpan(
                text: text,
                style: _ts(fontSize, w: FontWeight.w700).copyWith(
                    fontFamily:
                        Theme.of(context).textTheme.bodyMedium?.fontFamily)),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: TextDirection.ltr)
          ..layout())
        .width;
  }

  List<Widget> _buildDimensionLabels(double scaledWidth, double scaledLength) {
    // Calculate dynamic positions based on room size
    final widthLabelTop = 50 + scaledLength + 60;
    final lengthLabelLeft = 120 + scaledWidth + 35;

    return [
      // Width dimension - positioned dynamically
      Positioned(
        left: 120,
        top: widthLabelTop,
        child: SizedBox(
          width: scaledWidth,
          child: Center(
            child: Text(
              'Width',
              style: _ts(16, w: FontWeight.w700),
            ),
          ),
        ),
      ),
      Positioned(
        left: 120,
        top: widthLabelTop + 20,
        child: SizedBox(
          width: scaledWidth,
          child: Center(
            child: Text(
              '${width.round()} mm',
              style: _ts(16, w: FontWeight.w700),
            ),
          ),
        ),
      ),
      // Length dimension - positioned dynamically
      Positioned(
        left: lengthLabelLeft.toDouble(),
        top: 50,
        child: SizedBox(
          height: scaledLength,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'Length',
                style: _ts(16, w: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: (lengthLabelLeft + 20).toDouble(),
        top: 50,
        child: SizedBox(
          height: scaledLength,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                '${length.round()} mm',
                style: _ts(16, w: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Materials
  // ---------------------------------------------------------------------------
  Widget _orderRow(
    String label,
    String value, {
    String? note,
    bool emphasized = false,
    Color? dotColor,
    bool isCompact = false,
  }) {
    final valueStyle = _ts(14, w: FontWeight.w700).copyWith(
      fontSize: emphasized ? 16 : (isCompact ? 13 : 14),
      color: _c.textPrimary,
    );
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: emphasized ? 12 : 9, horizontal: emphasized ? 12 : 0),
      decoration: emphasized
          ? BoxDecoration(
              color: _c.brandSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _c.brand, width: 1.5),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dotColor != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 10),
              child: _dot(dotColor),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _ts(14, w: FontWeight.w500)
                      .copyWith(fontSize: isCompact ? 13 : 14),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note, style: _ts(12, color: _c.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.right, style: valueStyle),
        ],
      ),
    );
  }

  Widget _thinDivider() => Divider(height: 1, thickness: 1, color: _c.border);

  String _orderListText() {
    final b = StringBuffer()
      ..writeln('Ceiling grid order list')
      ..writeln(
          'Room: ${width.round()} x ${length.round()} mm (${_areaM2.toStringAsFixed(2)} m2)')
      ..writeln('')
      ..writeln('10ft main runners: ${result.mainRunnerPieces} pcs')
      ..writeln('4ft cross Ts: ${result.optimizedFourFootT} pcs')
      ..writeln('2ft cross Ts: ${result.optimizedTwoFootCrossT} pcs')
      ..writeln(
          'Wall angle: ${CeilingMaterialService.wallAnglePieces(width, length)} pcs')
      ..writeln(
          'Hanger wires: ${CeilingMaterialService.hangerWires(width, length)} pcs')
      ..writeln(
          'Ceiling tiles (${GridCeilingResult.tileSizeMm} mm): ${result.optimizedTilesRequired} pcs');
    if (result.requiresPerimeterJunction) {
      b.writeln(_edgeJunctionNotice);
    }
    return b.toString();
  }

  Future<void> _copyOrderList() async {
    await Clipboard.setData(ClipboardData(text: _orderListText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order list copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _materialLine(String label, int qty, Color color,
      {required String spec}) {
    return Padding(
      key: ValueKey('ceiling-material-$label'),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _ts(15, w: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(spec, style: _ts(12, color: _c.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$qty', style: _ts(22, w: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('pcs', style: _ts(12, w: FontWeight.w600, color: _c.textMuted)),
        ],
      ),
    );
  }

  Widget _tileHero() {
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('Ceiling tiles'),
        const SizedBox(height: 6),
        Text(
            '${GridCeilingResult.tileSizeMm} × ${GridCeilingResult.tileSizeMm} mm · estimate',
            style: _ts(13, color: _c.textSecondary)),
      ],
    );
    final quantity = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${result.optimizedTilesRequired}',
          style: _ts(34, w: FontWeight.w800).copyWith(height: 1.0)),
      const SizedBox(width: 5),
      Text('pcs', style: _ts(13, w: FontWeight.w600, color: _c.textSecondary)),
    ]);
    return Container(
      key: const ValueKey('ceiling-material-Ceiling tiles'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _c.brandSoft,
          borderRadius: AppRadii.r10,
          border: Border.all(color: _c.brand, width: 1.5)),
      child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 360
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [description, const SizedBox(height: 12), quantity])
              : Row(children: [
                  Expanded(child: description),
                  const SizedBox(width: 12),
                  quantity
                ])),
    );
  }

  Widget _infoNote(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: _c.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    _ts(12.5, color: _c.textSecondary).copyWith(height: 1.4)),
          ),
        ],
      );

  Widget _tileSplitBar() {
    final total = result.tilesRequired.toDouble();
    final full = result.fullTilesRequired.toDouble();
    final fraction = total > 0 ? (full / total).clamp(0.0, 1.0) : 0.0;
    Widget legend(Color color, String label, Object count) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(color, size: 9),
            const SizedBox(width: 6),
            Text('$label ', style: _ts(13, color: _c.textSecondary)),
            Text('$count', style: _ts(13, w: FontWeight.w700)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(
                      child:
                          ColoredBox(color: _c.brand.withValues(alpha: 0.25))),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: ColoredBox(color: _c.brand),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              legend(_c.brand, 'Full tiles', result.fullTilesRequired),
              legend(_c.brand.withValues(alpha: 0.25), 'Cut tiles',
                  result.cutTilesRequired),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsCard(bool isCompact) {
    final wallAnglePieces =
        CeilingMaterialService.wallAnglePieces(width, length);
    final hangerWires = CeilingMaterialService.hangerWires(width, length);

    return _card(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            Icons.inventory_2_outlined,
            'What to buy',
            subtitle: 'Order list for this room',
            trailing: Tooltip(
                message: 'Copy order list',
                child: TextButton.icon(
                  onPressed: _copyOrderList,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy list'),
                )),
          ),
          _tileHero(),
          const SizedBox(height: 4),
          _materialLine(
              '10ft main runners', result.mainRunnerPieces, _c.mainRunner,
              spec: '3048 mm stock'),
          _thinDivider(),
          _materialLine(
              '4ft cross Ts', result.optimizedFourFootT, _c.crossRunner,
              spec: '4ft stock'),
          _thinDivider(),
          _materialLine(
              '2ft cross Ts', result.optimizedTwoFootCrossT, _c.shortRunner,
              spec: 'Includes short edge pieces'),
          _thinDivider(),
          _materialLine('Wall angles', wallAnglePieces, _c.wallAngle,
              spec: '3048 mm stock'),
          _thinDivider(),
          _materialLine('Hanger wires', hangerWires, _c.measurement,
              spec: '12 gauge'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _c.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoNote(Icons.info_outline,
                    'Estimated quantities. Confirm stock lengths and fittings with your supplier.'),
                if (result.requiresPerimeterJunction) ...[
                  const SizedBox(height: 8),
                  _infoNote(Icons.warning_amber_rounded, _edgeJunctionNotice),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          _thinDivider(),
          _detailSection(
              'Tile breakdown',
              'Full tiles and edge cuts',
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _tileSplitBar(),
                _infoNote(Icons.info_outline,
                    'These are fitted pieces, not extra tiles to buy. The purchase estimate above accounts for reused offcuts.'),
                const SizedBox(height: 8),
                _orderRow('Total tile positions', '${result.tilesRequired} pcs',
                    isCompact: isCompact),
                if (result.widthEdgeCutPieces > 0) ...[
                  _thinDivider(),
                  _orderRow(
                      'Width edge cut', '${result.widthEdgeCutPieces} pcs',
                      note: 'Cut to ${result.widthEdgeCutSizeMm} mm',
                      isCompact: isCompact),
                ],
                if (result.lengthEdgeCutPieces > 0) ...[
                  _thinDivider(),
                  _orderRow(
                      'Length edge cut', '${result.lengthEdgeCutPieces} pcs',
                      note: 'Cut to ${result.lengthEdgeCutSizeMm} mm',
                      isCompact: isCompact),
                ],
                if (result.cornerOverlapPieces > 0) ...[
                  _thinDivider(),
                  _orderRow(
                      'Corner overlap', '${result.cornerOverlapPieces} pcs',
                      note:
                          'Corner tiles are counted in both edge cuts — already adjusted in the purchase estimate',
                      isCompact: isCompact),
                ],
              ])),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Placement measurements
  // ---------------------------------------------------------------------------
  Widget _factRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                flex: 3,
                child: Text(label, style: _ts(14, color: _c.textSecondary))),
            const SizedBox(width: 12),
            Flexible(
                flex: 2,
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: _ts(15, w: FontWeight.w700))),
          ],
        ),
      );

  Widget _factList(List<Widget> rows) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) _thinDivider(),
            rows[i],
          ],
        ],
      );
  Widget _positionChips(List<double> values, Color color) {
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('—', style: _ts(12, color: _c.textMuted)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < values.length; i++)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: _c.onAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text('${values[i].round()} mm',
                    style: _ts(14, w: FontWeight.w700).copyWith(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _placementGroup({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    List<Widget> facts = const [],
    List<Widget> children = const [],
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _c.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(icon, size: 18, color: _c.textPrimary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: _ts(16, w: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  style: _ts(12, color: _c.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _factList(facts),
                    ],
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subLabel(String text, {String? hint}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          Text(text, style: _ts(13, w: FontWeight.w700)),
          if (hint != null) Text(hint, style: _ts(12, color: _c.textMuted)),
        ]),
      );

  Widget _buildPlacementsCard(bool isCompact) {
    final mains = _mains;
    final twoFoot = _twoFoot;
    final cross = _cross;
    final mainSpacing = _spacing(mains);
    final crossSpacing = _spacing(cross);

    final widthFacts = <Widget>[
      if (!_isOneSide)
        _factRow('First T placement', '${result.tPlacementWidth} mm'),
      if (mains.isNotEmpty) ...[
        _factRow('Left wall → first main runner', _mm(mains.first)),
        _factRow('Last main runner → right wall', _mm(width - mains.last)),
      ],
      if (mainSpacing != null)
        _factRow('Main runner spacing (c/c)', _mm(mainSpacing)),
      if (result.edgeUsesTwoFootLeft || result.edgeUsesTwoFootRight)
        _factRow(
          'Edge bays use 2ft Ts',
          result.edgeUsesTwoFootLeft && result.edgeUsesTwoFootRight
              ? 'Left & right'
              : (result.edgeUsesTwoFootLeft ? 'Left' : 'Right'),
        ),
    ];

    final lengthFacts = <Widget>[
      if (!_isOneSide)
        _factRow('First T placement', '${result.tPlacementLength} mm'),
      if (cross.isNotEmpty) ...[
        _factRow('Top wall → first cross T', _mm(cross.first)),
        _factRow('Last cross T → bottom wall', _mm(length - cross.last)),
      ],
      if (crossSpacing != null)
        _factRow('Cross T spacing (c/c)', _mm(crossSpacing)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _placementGroup(
          icon: Icons.swap_horiz,
          title: 'Along width',
          subtitle:
              'Main runners and 2ft cross Ts · ${_mm(width)} (${_feetInches(width)})',
          color: _c.mainRunner,
          facts: widthFacts,
          children: [
            _subLabel('10ft main runners (${mains.length})',
                hint: 'from left wall'),
            _positionChips(mains, _c.mainRunner),
            if (twoFoot.isNotEmpty) ...[
              _subLabel('2ft cross Ts (${twoFoot.length})',
                  hint: 'from left wall'),
              _positionChips(twoFoot, _c.shortRunner),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _placementGroup(
          icon: Icons.swap_vert,
          title: 'Along length',
          subtitle: '4ft cross Ts · ${_mm(length)} (${_feetInches(length)})',
          color: _c.crossRunner,
          facts: lengthFacts,
          children: [
            _subLabel('4ft cross T lines (${cross.length})',
                hint: 'from top wall'),
            _positionChips(cross, _c.crossRunner),
          ],
        ),
        const SizedBox(height: 12),
        _placementGroup(
          icon: Icons.straighten,
          title: 'Squareness check',
          subtitle: 'Measure both diagonals before fixing the grid',
          color: _c.measurement,
          facts: [_factRow('Expected diagonal', _mm(_diagonalMm))],
          children: [
            const SizedBox(height: 4),
            Text(
              'If the two diagonals differ by more than ~3 mm, adjust the wall angle before hanging runners.',
              style: _ts(12.5, color: _c.textMuted).copyWith(height: 1.4),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Runner cutting
  // ---------------------------------------------------------------------------
  Widget _buildCuttingCard(bool isCompact) {
    final remainingLength = CeilingMaterialService.runnerCutMm(length);
    final fullPieces = CeilingMaterialService.fullRunnerPieces(length);
    final hasCut = remainingLength > 0;

    Widget stat(String label, String value, String sub) => Expanded(
          child: Container(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            decoration: BoxDecoration(
              color: _c.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow(label),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: _ts(20, w: FontWeight.w700)),
                ),
                const SizedBox(height: 2),
                Text(sub, style: _ts(12, color: _c.textMuted)),
              ],
            ),
          ),
        );

    final formula = hasCut
        ? '$fullPieces × 3048 mm  +  1 × ${remainingLength.toInt()} mm (cut)'
        : '$fullPieces × 3048 mm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stat('Rows', '${result.numMainRunners}', 'main runner lines'),
            const SizedBox(width: 8),
            stat('Full / row', '$fullPieces pcs', '3048 mm each'),
            const SizedBox(width: 8),
            stat(
              'Cut / row',
              hasCut ? '${remainingLength.toInt()} mm' : 'None',
              hasCut ? '1 piece' : 'No cut needed',
            ),
          ],
        )),
        const SizedBox(height: 12),
        _buildEnhancedCuttingDiagram(fullPieces, remainingLength, isCompact),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(isCompact ? 12 : 14),
          decoration: BoxDecoration(
            color: _c.brandSoft,
            border: Border.all(color: _c.brand, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow('Each row'),
              const SizedBox(height: 6),
              Text(formula, style: _ts(15, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Repeat for all ${result.numMainRunners} rows (room length ${length.toInt()} mm).',
                style: _ts(13, color: _c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedCuttingDiagram(
      int fullPieces, double remainingLength, bool isCompact) {
    final pieceWidth = isCompact ? 72.0 : 96.0;
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: _c.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('One row, wall to wall', style: _ts(15, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Runners sit end to end. Only the last piece is cut.',
              style: _ts(12, color: _c.textMuted)),
          SizedBox(height: isCompact ? 8 : 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: EdgeInsets.all(isCompact ? 10 : 12),
              height: isCompact ? 92 : 106,
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _c.border, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: double.infinity,
                    color: _c.wallAngle,
                  ),
                  ...List.generate(fullPieces, (_) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _runnerChip('3048', pieceWidth, isCompact),
                    );
                  }),
                  if (remainingLength > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _runnerChip(
                        '${remainingLength.toInt()}',
                        (remainingLength /
                                CeilingMaterialService.runnerLengthMm) *
                            pieceWidth,
                        isCompact,
                        isCut: true,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: double.infinity,
                    color: _c.wallAngle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _runnerChip(String label, double widthValue, bool isCompact,
      {bool isCut = false}) {
    final barWidth = widthValue.clamp(24.0, 160.0).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: barWidth,
          height: isCompact ? 6 : 8,
          color: _c.mainRunner,
        ),
        const SizedBox(height: 4),
        Text(
          '$label mm${isCut ? ' cut' : ''}',
          style: _ts(14, w: isCut ? FontWeight.w700 : FontWeight.w400)
              .copyWith(fontSize: isCompact ? 10 : 11),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Installation steps
  // ---------------------------------------------------------------------------
  Widget _buildNotesCard(bool isCompact) {
    final hangerWires = CeilingMaterialService.hangerWires(width, length);
    final steps = <(IconData, String, String)>[
      (
        Icons.border_outer,
        'Fix the wall angle',
        'Install 10′ wall angle molding around the full perimeter.'
      ),
      (
        Icons.vertical_align_top,
        'Hang the main runners',
        'Use 12-gauge wire at 4′ intervals ($hangerWires wires total).'
      ),
      (
        Icons.straighten,
        'Check squareness',
        'Both diagonals should measure about ${_diagonalMm.round()} mm.'
      ),
      (
        Icons.table_rows_outlined,
        'Add the cross Ts',
        'Install the 4ft cross Ts, then the 2ft cross Ts between them at alternate spacing.'
      ),
      (
        Icons.horizontal_rule,
        'Level the grid',
        'Level and square the grid before placing tiles.'
      ),
      if (result.cutTilesRequired > 0)
        (
          Icons.content_cut,
          'Cut edge tiles last',
          'Measure the actual opening of each border bay before cutting.'
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _c.brand, shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: _ts(13,
                                w: FontWeight.w700, color: _c.onAccent)),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: _c.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: 5, bottom: i < steps.length - 1 ? 18 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(steps[i].$1, size: 16, color: _c.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(steps[i].$2,
                                  style: _ts(15, w: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          steps[i].$3,
                          style: _ts(14, color: _c.textSecondary).copyWith(
                              fontSize: isCompact ? 13 : 13.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _infoNote(Icons.info_outline, 'All values are in millimeters (mm).'),
      ],
    );
  }
}

/// Theme-aware view over the central [BuildCalcColors] tokens.
/// Every color on this screen comes from here, so light/dark follow the app theme.
class _Palette {
  const _Palette({
    required this.isDark,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.brand,
    required this.brandSoft,
    required this.onAccent,
    required this.success,
    required this.measurement,
    required this.mainRunner,
    required this.crossRunner,
    required this.shortRunner,
    required this.wallAngle,
    required this.lineShadow,
    required this.lineHighlight,
  });

  final bool isDark;
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color brand;
  final Color brandSoft;
  final Color onAccent;
  final Color success;
  final Color measurement;

  // Grid elements (chart series colors of the palette).
  final Color mainRunner;
  final Color crossRunner;
  final Color shortRunner;
  final Color wallAngle;

  // 3D line shading.
  final Color lineShadow;
  final Color lineHighlight;

  static const light = _Palette(
    isDark: false,
    surface: BuildCalcColors.lightSurface,
    surfaceSubtle: BuildCalcColors.lightSurfaceSubtle,
    textPrimary: BuildCalcColors.lightTextPrimary,
    textSecondary: BuildCalcColors.lightTextSecondary,
    textMuted: BuildCalcColors.lightTextMuted,
    border: BuildCalcColors.lightBorder,
    borderStrong: BuildCalcColors.lightBorderStrong,
    brand: BuildCalcColors.brand,
    brandSoft: BuildCalcColors.brandSoft,
    onAccent: BuildCalcColors.brandOn,
    success: BuildCalcColors.success,
    measurement: BuildCalcColors.measurement,
    mainRunner: BuildCalcColors.chartPrimary,
    crossRunner: BuildCalcColors.chartSecondary,
    shortRunner: BuildCalcColors.chartTertiary,
    wallAngle: BuildCalcColors.concrete,
    lineShadow: BuildCalcColors.lightTextPrimary,
    lineHighlight: BuildCalcColors.lightSurface,
  );

  static const dark = _Palette(
    isDark: true,
    surface: BuildCalcColors.darkSurface,
    surfaceSubtle: BuildCalcColors.darkSurfaceSubtle,
    textPrimary: BuildCalcColors.darkTextPrimary,
    textSecondary: BuildCalcColors.darkTextSecondary,
    textMuted: BuildCalcColors.darkTextMuted,
    border: BuildCalcColors.darkBorder,
    borderStrong: BuildCalcColors.darkBorderStrong,
    brand: BuildCalcColors.darkBrand,
    brandSoft: BuildCalcColors.darkSelection,
    onAccent: BuildCalcColors.darkBrandOn,
    success: BuildCalcColors.successOnDark,
    measurement: BuildCalcColors.darkFocus,
    mainRunner: BuildCalcColors.darkBrand,
    crossRunner: BuildCalcColors.darkFocus,
    shortRunner: BuildCalcColors.successOnDark,
    wallAngle: BuildCalcColors.darkTextMuted,
    lineShadow: BuildCalcColors.darkBackground,
    lineHighlight: BuildCalcColors.darkTextPrimary,
  );

  static _Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class _IsometricCeilingPainter extends CustomPainter {
  final double roomWidthMm;
  final double roomLengthMm;
  final List<double> mainRunnerPositionsMm;
  final List<double> twoFootPositionsMm;
  final List<double> crossPositionsMm;
  final List<CrossTSpan> crossSpans;
  final double yawDegrees;
  final double pitchDegrees;
  final double zoom;
  final bool showMeasurements;
  final _Palette palette;
  final String? fontFamily;

  _IsometricCeilingPainter({
    required this.roomWidthMm,
    required this.roomLengthMm,
    required this.mainRunnerPositionsMm,
    required this.twoFootPositionsMm,
    required this.crossPositionsMm,
    required this.crossSpans,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    required this.showMeasurements,
    required this.palette,
    required this.fontFamily,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.surfaceSubtle);
    if (roomWidthMm <= 0 || roomLengthMm <= 0) {
      return;
    }

    final yaw = yawDegrees * math.pi / 180.0;
    final pitch = pitchDegrees * math.pi / 180.0;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    _Projected project(_Vec3 p) {
      final x1 = (p.x * cosYaw) - (p.z * sinYaw);
      final z1 = (p.x * sinYaw) + (p.z * cosYaw);
      final y2 = (p.y * cosPitch) - (z1 * sinPitch);
      final z2 = (p.y * sinPitch) + (z1 * cosPitch);

      final maxSpan = math.max(roomWidthMm, roomLengthMm);
      final cameraDistance = maxSpan * 1.4;
      final perspective =
          cameraDistance / (cameraDistance + z2 + (maxSpan * 0.1));
      final baseScale =
          (math.min(size.width, size.height) / (maxSpan * 1.05)) * zoom;

      return _Projected(
        offset: Offset(
          (size.width * 0.5) + (x1 * baseScale * perspective),
          (size.height * 0.52) + (y2 * baseScale * perspective),
        ),
        depth: z2,
        perspective: perspective,
      );
    }

    _Vec3 gridPoint(double xMm, double zMm, [double yMm = 0]) {
      return _Vec3(
        x: xMm - (roomWidthMm / 2),
        y: yMm,
        z: zMm - (roomLengthMm / 2),
      );
    }

    final segments = <_LineSegment>[
      _LineSegment(
        a: gridPoint(0, 0),
        b: gridPoint(roomWidthMm, 0),
        color: palette.textSecondary,
        width: 3.0,
      ),
      _LineSegment(
        a: gridPoint(roomWidthMm, 0),
        b: gridPoint(roomWidthMm, roomLengthMm),
        color: palette.textSecondary,
        width: 3.0,
      ),
      _LineSegment(
        a: gridPoint(roomWidthMm, roomLengthMm),
        b: gridPoint(0, roomLengthMm),
        color: palette.textSecondary,
        width: 3.0,
      ),
      _LineSegment(
        a: gridPoint(0, roomLengthMm),
        b: gridPoint(0, 0),
        color: palette.textSecondary,
        width: 3.0,
      ),
    ];

    final validMainPositions =
        mainRunnerPositionsMm.where((v) => v > 0 && v < roomWidthMm).toList();

    final labelledSpans = ceilingStockLabelSpans(crossSpans);
    for (final y in crossPositionsMm.where((v) => v > 0 && v < roomLengthMm)) {
      for (var index = 0; index < crossSpans.length; index++) {
        final span = crossSpans[index];
        segments.add(_LineSegment(
          a: gridPoint(span.startMm, y),
          b: gridPoint(span.endMm, y),
          color: span.usesTwoFoot ? palette.shortRunner : palette.crossRunner,
          width: span.usesTwoFoot ? 2.1 : 2.5,
          labelAtEnd: span.endMm == roomWidthMm,
          label: y ==
                      crossPositionsMm[span.usesTwoFoot
                          ? 0
                          : crossPositionsMm.length ~/ 2] &&
                  labelledSpans.contains(index)
              ? (span.usesTwoFoot ? '2f' : '4f')
              : null,
        ));
      }
    }

    for (final x in validMainPositions) {
      segments.add(_LineSegment(
        a: gridPoint(x, 0),
        b: gridPoint(x, roomLengthMm),
        color: palette.mainRunner,
        width: 3.1,
        label: x == validMainPositions.first ? '10f' : null,
      ));
    }

    for (final x in twoFootPositionsMm.where((v) => v > 0 && v < roomWidthMm)) {
      segments.add(_LineSegment(
        a: gridPoint(x, 0),
        b: gridPoint(x, roomLengthMm),
        color: palette.shortRunner,
        width: 2.0,
        label: x == twoFootPositionsMm.first ? '2f' : null,
        labelAtEnd: true,
      ));
    }

    for (int r = 0; r < crossPositionsMm.length; r += 2) {
      final y = crossPositionsMm[r];
      if (y <= 0 || y >= roomLengthMm) {
        continue;
      }
      for (final x in validMainPositions) {
        segments.add(_LineSegment(
          a: gridPoint(x, y, 0),
          b: gridPoint(x, y, -420),
          color: palette.textMuted,
          width: 1.2,
        ));
      }
    }

    final projected = segments.map((s) {
      final pa = project(s.a);
      final pb = project(s.b);
      return _ProjectedLine(
        a: pa,
        b: pb,
        color: s.color,
        width: s.width * ((pa.perspective + pb.perspective) / 2),
        depth: (pa.depth + pb.depth) / 2,
        label: s.label,
        labelAnchor: ceilingSectionLabelAnchor(pa.offset, pb.offset,
            atEnd: s.labelAtEnd),
      );
    }).toList()
      ..sort((a, b) => b.depth.compareTo(a.depth));

    for (final seg in projected) {
      _draw3DLine(
        canvas,
        seg.a.offset,
        seg.b.offset,
        seg.color,
        seg.width.clamp(0.8, 5.0),
      );
    }

    final labelLines = [for (final s in projected) (s.a.offset, s.b.offset)];
    final typeLabels = <Rect>[];
    for (final seg in projected.where((s) => s.label != null)) {
      _drawTypeLabel(
          canvas, seg.label!, seg.labelAnchor, seg.color, size, typeLabels,
          lines: labelLines,
          vertical: (seg.b.offset.dy - seg.a.offset.dy).abs() >
              (seg.b.offset.dx - seg.a.offset.dx).abs());
    }

    if (showMeasurements) {
      final p00 = project(gridPoint(0, 0)).offset;
      final p10 = project(gridPoint(roomWidthMm, 0)).offset;
      final p11 = project(gridPoint(roomWidthMm, roomLengthMm)).offset;
      final p01 = project(gridPoint(0, roomLengthMm)).offset;
      final projectedCenter =
          Offset((p00.dx + p11.dx) / 2, (p00.dy + p11.dy) / 2);

      final widthNormal = _edgeOutwardNormal(p01, p11, projectedCenter);
      final lengthNormal = _edgeOutwardNormal(p10, p11, projectedCenter);
      final occupied = typeLabels.map((rect) => rect.center).toList();

      // Overall room dimensions.
      _drawMeasurementLabel(
        canvas,
        'Width: ${roomWidthMm.round()} mm',
        _resolveLabelCollision(
          ((p01 + p11) / 2) + (widthNormal * 24),
          widthNormal,
          occupied,
        ),
        palette.textPrimary,
        isPrimary: true,
      );
      _drawMeasurementLabel(
        canvas,
        'Length: ${roomLengthMm.round()} mm',
        _resolveLabelCollision(
          ((p10 + p11) / 2) + (lengthNormal * 24),
          lengthNormal,
          occupied,
        ),
        palette.textPrimary,
        isPrimary: true,
      );

      // Exact measurement labels from calculator outputs only.
      final topNormal = _edgeOutwardNormal(p00, p10, projectedCenter);
      final mainPositions = _sortedUnique(mainRunnerPositionsMm
          .where((v) => v > 0 && v < roomWidthMm)
          .toList());
      final twoFootPositions = _sortedUnique(
          twoFootPositionsMm.where((v) => v > 0 && v < roomWidthMm).toList());
      final crossPositions = _sortedUnique(
          crossPositionsMm.where((v) => v > 0 && v < roomLengthMm).toList());

      for (int i = 0; i < mainPositions.length; i++) {
        final x = mainPositions[i];
        final anchor = project(gridPoint(x, roomLengthMm)).offset;
        final base = anchor + (widthNormal * (16 + ((i % 3) * 8)));
        _drawMeasurementLabel(
          canvas,
          '${x.round()} mm',
          _resolveLabelCollision(base, widthNormal, occupied),
          palette.mainRunner,
        );
      }

      for (int i = 0; i < twoFootPositions.length; i++) {
        final x = twoFootPositions[i];
        final anchor = project(gridPoint(x, 0)).offset;
        final base = anchor + (topNormal * (16 + ((i % 3) * 8)));
        _drawMeasurementLabel(
          canvas,
          '${x.round()} mm',
          _resolveLabelCollision(base, topNormal, occupied),
          palette.shortRunner,
        );
      }

      for (int i = 0; i < crossPositions.length; i++) {
        final y = crossPositions[i];
        final anchor = project(gridPoint(roomWidthMm, y)).offset;
        final base = anchor + (lengthNormal * (16 + ((i % 3) * 8)));
        _drawMeasurementLabel(
          canvas,
          '${y.round()} mm',
          _resolveLabelCollision(base, lengthNormal, occupied),
          palette.crossRunner,
        );
      }
    }
  }

  void _draw3DLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Color baseColor,
    double strokeWidth,
  ) {
    final base = Paint()
      ..color = baseColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = palette.lineShadow.withValues(alpha: 0.12)
      ..strokeWidth = strokeWidth + 1.1
      ..strokeCap = StrokeCap.round;
    final highlight = Paint()
      ..color =
          palette.lineHighlight.withValues(alpha: palette.isDark ? 0.30 : 0.60)
      ..strokeWidth = math.max(1.0, strokeWidth - 1.5)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      start + const Offset(0.7, 1.0),
      end + const Offset(0.7, 1.0),
      shadow,
    );
    canvas.drawLine(start, end, base);
    canvas.drawLine(
      start + const Offset(-0.7, -0.7),
      end + const Offset(-0.7, -0.7),
      highlight,
    );
  }

  void _drawTypeLabel(Canvas canvas, String label, Offset anchor, Color color,
      Size size, List<Rect> occupied,
      {required List<(Offset, Offset)> lines, bool vertical = false}) {
    final text = TextPainter(
        text: TextSpan(
            text: label,
            style: AppTypography.text12W700Text
                .copyWith(fontSize: 10, color: color, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr)
      ..layout();
    final rect = placeCeilingLabel(
        anchor: anchor,
        size: Size(text.width + 6, text.height + 4),
        bounds: (Offset.zero & size).deflate(2),
        occupied: occupied,
        lines: lines,
        vertical: vertical);
    if (rect == null) return;
    canvas.drawLine(
        anchor,
        rect.center,
        Paint()
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = .7);
    canvas.drawRect(rect, Paint()..color = palette.surface);
    text.paint(canvas, rect.topLeft + const Offset(3, 2));
  }

  void _drawMeasurementLabel(
    Canvas canvas,
    String text,
    Offset centerPos,
    Color color, {
    bool isPrimary = false,
  }) {
    final fontSize = isPrimary ? 11.0 : 9.0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
            color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padding = isPrimary ? 5.0 : 4.0;
    final rect = Rect.fromLTWH(
      centerPos.dx - (textPainter.width / 2) - padding,
      centerPos.dy - (textPainter.height / 2) - padding,
      textPainter.width + (padding * 2),
      textPainter.height + (padding * 2),
    );
    final bgPaint = Paint()..color = palette.surface.withValues(alpha: 0.90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(
        centerPos.dx - (textPainter.width / 2),
        centerPos.dy - (textPainter.height / 2),
      ),
    );
  }

  Offset _edgeOutwardNormal(Offset edgeStart, Offset edgeEnd, Offset center) {
    final edge = edgeEnd - edgeStart;
    final length = edge.distance;
    if (length < 0.001) {
      return const Offset(0, -1);
    }
    Offset normal = Offset(edge.dy / length, -edge.dx / length);
    final mid = (edgeStart + edgeEnd) / 2;
    if (((mid - center).dx * normal.dx) + ((mid - center).dy * normal.dy) < 0) {
      normal = Offset(-normal.dx, -normal.dy);
    }
    return normal;
  }

  Offset _resolveLabelCollision(
    Offset base,
    Offset outward,
    List<Offset> occupied,
  ) {
    var candidate = base;
    for (int i = 0; i < 6; i++) {
      final collide = occupied.any((p) => (p - candidate).distance < 24);
      if (!collide) {
        occupied.add(candidate);
        return candidate;
      }
      candidate = base + (outward * (10.0 * (i + 1)));
    }
    occupied.add(candidate);
    return candidate;
  }

  List<double> _sortedUnique(List<double> values) {
    final filtered = values.where((v) => v.isFinite && v >= 0).toList()..sort();
    final result = <double>[];
    const epsilon = 0.5;
    for (final v in filtered) {
      if (result.isEmpty || (v - result.last).abs() > epsilon) {
        result.add(v);
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _IsometricCeilingPainter oldDelegate) {
    return oldDelegate.roomWidthMm != roomWidthMm ||
        oldDelegate.roomLengthMm != roomLengthMm ||
        oldDelegate.yawDegrees != yawDegrees ||
        oldDelegate.pitchDegrees != pitchDegrees ||
        oldDelegate.zoom != zoom ||
        oldDelegate.showMeasurements != showMeasurements ||
        oldDelegate.palette != palette ||
        !_sameSeries(
            oldDelegate.mainRunnerPositionsMm, mainRunnerPositionsMm) ||
        !_sameSeries(oldDelegate.twoFootPositionsMm, twoFootPositionsMm) ||
        !_sameSeries(oldDelegate.crossPositionsMm, crossPositionsMm) ||
        oldDelegate.crossSpans != crossSpans;
  }

  bool _sameSeries(List<double> a, List<double> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.001) {
        return false;
      }
    }
    return true;
  }
}

class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3({
    required this.x,
    required this.y,
    required this.z,
  });
}

class _Projected {
  final Offset offset;
  final double depth;
  final double perspective;

  const _Projected({
    required this.offset,
    required this.depth,
    required this.perspective,
  });
}

class _LineSegment {
  final _Vec3 a;
  final _Vec3 b;
  final Color color;
  final double width;
  final String? label;
  final bool labelAtEnd;

  const _LineSegment({
    required this.a,
    required this.b,
    required this.color,
    required this.width,
    this.label,
    this.labelAtEnd = false,
  });
}

class _ProjectedLine {
  final _Projected a;
  final _Projected b;
  final Color color;
  final double width;
  final double depth;
  final String? label;
  final Offset labelAnchor;

  const _ProjectedLine({
    required this.a,
    required this.b,
    required this.color,
    required this.width,
    required this.depth,
    this.label,
    required this.labelAnchor,
  });
}

class _TypeLabelLeaderPainter extends CustomPainter {
  const _TypeLabelLeaderPainter(this.from, this.to, this.color);
  final Offset from, to;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .5)
        ..strokeWidth = .7);
  @override
  bool shouldRepaint(covariant _TypeLabelLeaderPainter old) =>
      old.from != from || old.to != to || old.color != color;
}
