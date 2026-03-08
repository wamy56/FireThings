import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/icon_map.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/standard_info_box.dart';

// ─── Data Model ─────────────────────────────────────────────────────────────

enum DetectorType { pointSmoke, pointHeatGrade1, pointHeatGrade2 }

enum RoomType { openArea, corridor }

class _DetectorSpec {
  final String label;
  final double radius;
  final double corridorSpacing;
  final double maxCeiling;

  const _DetectorSpec({
    required this.label,
    required this.radius,
    required this.corridorSpacing,
    required this.maxCeiling,
  });
}

const _detectorSpecs = {
  DetectorType.pointSmoke: _DetectorSpec(
    label: 'Point Smoke',
    radius: 7.5,
    corridorSpacing: 15.0,
    maxCeiling: 10.5,
  ),
  DetectorType.pointHeatGrade1: _DetectorSpec(
    label: 'Point Heat (Grade 1)',
    radius: 5.3,
    corridorSpacing: 10.5,
    maxCeiling: 7.5,
  ),
  DetectorType.pointHeatGrade2: _DetectorSpec(
    label: 'Point Heat (Grade 2)',
    radius: 7.5,
    corridorSpacing: 15.0,
    maxCeiling: 9.0,
  ),
};

// ─── Calculation Result ────────────────────────────────────────────────────

class _CalcResult {
  final int detectorCount;
  final int columns;
  final int rows;
  final double gridSpacingX;
  final double gridSpacingY;
  final double wallOffsetX;
  final double wallOffsetY;
  final double coveragePerDetector;
  final double roomArea;
  final List<String> notes;

  const _CalcResult({
    required this.detectorCount,
    required this.columns,
    required this.rows,
    required this.gridSpacingX,
    required this.gridSpacingY,
    required this.wallOffsetX,
    required this.wallOffsetY,
    required this.coveragePerDetector,
    required this.roomArea,
    required this.notes,
  });
}

// ─── Screen ────────────────────────────────────────────────────────────────

class DetectorSpacingCalculatorScreen extends StatefulWidget {
  const DetectorSpacingCalculatorScreen({super.key});

  @override
  State<DetectorSpacingCalculatorScreen> createState() =>
      _DetectorSpacingCalculatorScreenState();
}

class _DetectorSpacingCalculatorScreenState
    extends State<DetectorSpacingCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  DetectorType _detectorType = DetectorType.pointSmoke;
  RoomType _roomType = RoomType.openArea;

  _CalcResult? _result;

  @override
  void dispose() {
    _scrollController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  // ─── Calculation Logic ──────────────────────────────────────────────────

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final length = double.parse(_lengthController.text);
    final width = double.parse(_widthController.text);
    final height = double.parse(_heightController.text);
    final spec = _detectorSpecs[_detectorType]!;
    final notes = <String>[];

    int cols;
    int rows;
    double spacingX;
    double spacingY;
    double wallOffX;
    double wallOffY;

    if (_roomType == RoomType.corridor) {
      // Corridor: single row centred in width
      var corridorSpacing = spec.corridorSpacing;

      // Height adjustment
      if (height > spec.maxCeiling) {
        final excess = height - spec.maxCeiling;
        final reduction = excess * 0.5;
        final adjusted =
            max(corridorSpacing * 0.5, corridorSpacing - reduction);
        notes.add(
          'Ceiling height (${height.toStringAsFixed(1)}m) exceeds maximum '
          '(${spec.maxCeiling}m) for ${spec.label}. Spacing reduced from '
          '${corridorSpacing.toStringAsFixed(1)}m to ${adjusted.toStringAsFixed(1)}m.',
        );
        corridorSpacing = adjusted;
      }

      // Even distribution: wall offset = L/(2*cols), spacing = L/cols
      cols = max(1, (length / corridorSpacing).ceil());
      rows = 1;
      wallOffX = length / (2 * cols);
      spacingX = cols > 1 ? length / cols : 0;
      wallOffY = width / 2;
      spacingY = 0;

      if (width > 2.0) {
        notes.add(
          'Corridor width exceeds 2m. Consider using open-area spacing '
          'instead for better coverage.',
        );
      }
    } else {
      // Open area — minimum-detector search
      var R = spec.radius;

      // Height adjustment (reduces effective radius)
      if (height > spec.maxCeiling) {
        final excess = height - spec.maxCeiling;
        final reduction = excess * 0.5;
        final oldR = R;
        R = max(R * 0.5, R - reduction);
        notes.add(
          'Ceiling height (${height.toStringAsFixed(1)}m) exceeds maximum '
          '(${spec.maxCeiling}m) for ${spec.label}. Effective radius reduced from '
          '${oldR.toStringAsFixed(1)}m to ${R.toStringAsFixed(1)}m.',
        );
      }

      // Very small rooms: 1 detector centered
      if (length < 1.0 || width < 1.0) {
        cols = 1;
        rows = 1;
      } else {
        // Search for minimum cols × rows where worst-case corner distance ≤ R
        // Worst-case: √((L/(2*cols))² + (W/(2*rows))²) ≤ R
        int bestTotal = 999999;
        int bestCols = 1;
        int bestRows = 1;

        final maxCols = length.ceil();
        for (int c = 1; c <= maxCols; c++) {
          final halfCellX = length / (2 * c);
          if (halfCellX > R) continue; // can't cover even in X
          if (halfCellX < 0.5) break; // BS 5839-1 min wall offset

          final remainingR = sqrt(R * R - halfCellX * halfCellX);
          var minRows = max(1, (width / (2 * remainingR)).ceil());

          // Enforce min 0.5m wall offset in Y
          if (width / (2 * minRows) < 0.5) {
            minRows = max(minRows, (width / 1.0).ceil()); // w/(2*rows)>=0.5 → rows<=w
          }

          final total = c * minRows;
          if (total < bestTotal) {
            bestTotal = total;
            bestCols = c;
            bestRows = minRows;
          }
        }

        cols = bestCols;
        rows = bestRows;

        // "Show both" — check if fewer detectors would work within 5% tolerance
        _checkAlternative(length, width, R, cols, rows, notes);
      }

      wallOffX = length / (2 * cols);
      wallOffY = width / (2 * rows);
      spacingX = cols > 1 ? length / cols : 0;
      spacingY = rows > 1 ? width / rows : 0;

      notes.add(
        'Wall offset: ${wallOffX.toStringAsFixed(2)}m (L) × ${wallOffY.toStringAsFixed(2)}m (W), '
        'calculated automatically per BS 5839-1 (minimum 0.5m).',
      );
    }

    final total = cols * rows;
    final area = length * width;
    final coverage = total > 0 ? area / total : 0.0;

    setState(() {
      _result = _CalcResult(
        detectorCount: total,
        columns: cols,
        rows: rows,
        gridSpacingX: spacingX,
        gridSpacingY: spacingY,
        wallOffsetX: wallOffX,
        wallOffsetY: wallOffY,
        coveragePerDetector: coverage,
        roomArea: area,
        notes: notes,
      );
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Check if one fewer column or row would cover with ≤5% overshoot
  void _checkAlternative(
    double length,
    double width,
    double R,
    int cols,
    int rows,
    List<String> notes,
  ) {
    // Try cols-1
    if (cols > 1) {
      final altCols = cols - 1;
      final halfX = length / (2 * altCols);
      final halfY = width / (2 * rows);
      final cornerDist = sqrt(halfX * halfX + halfY * halfY);
      final overshoot = cornerDist - R;
      if (overshoot > 0 && overshoot <= R * 0.05) {
        final altTotal = altCols * rows;
        notes.add(
          'Could use $altTotal detectors (corners ${overshoot.toStringAsFixed(2)}m '
          'outside coverage — engineer\'s discretion).',
        );
      }
    }
    // Try rows-1
    if (rows > 1) {
      final altRows = rows - 1;
      final halfX = length / (2 * cols);
      final halfY = width / (2 * altRows);
      final cornerDist = sqrt(halfX * halfX + halfY * halfY);
      final overshoot = cornerDist - R;
      if (overshoot > 0 && overshoot <= R * 0.05) {
        final altTotal = cols * altRows;
        notes.add(
          'Could use $altTotal detectors (corners ${overshoot.toStringAsFixed(2)}m '
          'outside coverage — engineer\'s discretion).',
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _lengthController.clear();
      _widthController.clear();
      _heightController.clear();
      _detectorType = DetectorType.pointSmoke;
      _roomType = RoomType.openArea;
      _result = null;
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Detector Spacing',
        actions: [
          IconButton(
            icon: Icon(AppIcons.infoCircle),
            onPressed: _showInfoDialog,
            tooltip: 'Information',
          ),
        ],
      ),
      body: KeyboardDismissWrapper(
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildInputSection(),
              const SizedBox(height: 20),
              _buildCalculateButton(),
              if (_result != null) ...[
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 16),
                _buildVisualGrid(),
                if (_result!.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildNotesCard(),
                ],
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.ruler,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Detector Spacing Calculator',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Calculate the number of detectors needed and their layout based on room dimensions per BS 5839-1.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room Dimensions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Length
            TextFormField(
              controller: _lengthController,
              decoration: InputDecoration(
                labelText: 'Room Length (m)',
                prefixIcon: Icon(AppIcons.ruler),
                border: const OutlineInputBorder(),
                suffixText: 'm',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final val = double.tryParse(value);
                if (val == null || val <= 0) return 'Must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Width
            TextFormField(
              controller: _widthController,
              decoration: InputDecoration(
                labelText: 'Room Width (m)',
                prefixIcon: Icon(AppIcons.ruler),
                border: const OutlineInputBorder(),
                suffixText: 'm',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final val = double.tryParse(value);
                if (val == null || val <= 0) return 'Must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Ceiling Height
            TextFormField(
              controller: _heightController,
              decoration: InputDecoration(
                labelText: 'Ceiling Height (m)',
                prefixIcon: Icon(AppIcons.arrowUp),
                border: const OutlineInputBorder(),
                suffixText: 'm',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final val = double.tryParse(value);
                if (val == null || val <= 0) return 'Must be positive';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Detector Type
            Text(
              'Detector Type',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<DetectorType>(
              initialValue: _detectorType,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixIcon: Icon(AppIcons.flash),
              ),
              items: DetectorType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_detectorSpecs[type]!.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _detectorType = value);
              },
            ),
            const SizedBox(height: 20),

            // Room Type
            Text(
              'Room Type',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RoomType>(
              segments: const [
                ButtonSegment(
                  value: RoomType.openArea,
                  label: Text('Open Area'),
                ),
                ButtonSegment(
                  value: RoomType.corridor,
                  label: Text('Corridor'),
                ),
              ],
              selected: {_roomType},
              onSelectionChanged: (selection) {
                setState(() => _roomType = selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculateButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _calculate,
            icon: Icon(AppIcons.calculator),
            label: const Text('Calculate'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: Icon(AppIcons.refresh),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final r = _result!;
    return Card(
      elevation: 4,
      color: Colors.indigo.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(AppIcons.grid, size: 48, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(
              '${r.detectorCount}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            Text(
              r.detectorCount == 1 ? 'Detector Required' : 'Detectors Required',
              style: TextStyle(
                fontSize: 16,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Grid Layout',
              '${r.columns} \u00d7 ${r.rows}',
            ),
            const SizedBox(height: 8),
            if (_roomType == RoomType.openArea) ...[
              _buildSummaryRow(
                'Wall Offset (L \u00d7 W)',
                '${r.wallOffsetX.toStringAsFixed(2)}m \u00d7 ${r.wallOffsetY.toStringAsFixed(2)}m',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Spacing (L \u00d7 W)',
                r.columns > 1 || r.rows > 1
                    ? '${r.gridSpacingX > 0 ? "${r.gridSpacingX.toStringAsFixed(1)}m" : "centered"}'
                      ' \u00d7 '
                      '${r.gridSpacingY > 0 ? "${r.gridSpacingY.toStringAsFixed(1)}m" : "centered"}'
                    : 'centered',
              ),
              const SizedBox(height: 8),
            ] else ...[
              _buildSummaryRow(
                'Wall Offset',
                '${r.wallOffsetX.toStringAsFixed(2)}m',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Spacing Along Corridor',
                r.gridSpacingX > 0
                    ? '${r.gridSpacingX.toStringAsFixed(1)}m'
                    : 'centered',
              ),
              const SizedBox(height: 8),
            ],
            _buildSummaryRow(
              'Coverage per Detector',
              '${r.coveragePerDetector.toStringAsFixed(1)} m\u00b2',
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Room Area',
              '${r.roomArea.toStringAsFixed(1)} m\u00b2',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildVisualGrid() {
    final r = _result!;
    final length = double.parse(_lengthController.text);
    final width = double.parse(_widthController.text);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Layout Preview',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const marginLeft = 44.0;
                  const marginBottom = 44.0;
                  final maxWidth = constraints.maxWidth - 32;
                  const maxHeight = 280.0;

                  // Room area fits inside margins
                  final roomMaxW = maxWidth - marginLeft;
                  final roomMaxH = maxHeight - marginBottom;
                  final aspect = length / width;
                  double roomW;
                  double roomH;
                  if (aspect > roomMaxW / roomMaxH) {
                    roomW = roomMaxW;
                    roomH = roomMaxW / aspect;
                  } else {
                    roomH = roomMaxH;
                    roomW = roomMaxH * aspect;
                  }

                  final totalW = marginLeft + roomW;
                  final totalH = roomH + marginBottom;

                  return CustomPaint(
                    size: Size(totalW, totalH),
                    painter: _DetectorGridPainter(
                      columns: r.columns,
                      rows: r.rows,
                      roomLength: length,
                      roomWidth: width,
                      wallOffsetX: r.wallOffsetX,
                      wallOffsetY: r.wallOffsetY,
                      gridSpacingX: r.gridSpacingX,
                      gridSpacingY: r.gridSpacingY,
                      isCorridor: _roomType == RoomType.corridor,
                      brightness: Theme.of(context).brightness,
                      marginLeft: marginLeft,
                      marginBottom: marginBottom,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${length.toStringAsFixed(1)}m \u00d7 ${width.toStringAsFixed(1)}m',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    final r = _result!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.warning, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final note in r.notes) ...[
              Text('\u2022 $note', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
          title: const Text('BS 5839-1 Spacing Rules'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Detector Coverage Radii',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('\u2022 Point Smoke: 7.5m radius'),
                const Text('\u2022 Point Heat (Grade 1): 5.3m radius'),
                const Text('\u2022 Point Heat (Grade 2): 7.5m radius'),
                const SizedBox(height: 12),
                const Text(
                  'Corridor Spacing',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('\u2022 Point Smoke: 15.0m max'),
                const Text('\u2022 Point Heat (Grade 1): 10.5m max'),
                const Text('\u2022 Point Heat (Grade 2): 15.0m max'),
                const SizedBox(height: 12),
                const Text(
                  'Maximum Ceiling Heights',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('\u2022 Point Smoke: 10.5m'),
                const Text('\u2022 Point Heat (Grade 1): 7.5m'),
                const Text('\u2022 Point Heat (Grade 2): 9.0m'),
                const SizedBox(height: 12),
                const Text(
                  'Key Principles',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '\u2022 No ceiling point may be further than R from the nearest detector\n'
                  '\u2022 Wall offset calculated automatically (minimum 0.5m per BS 5839-1)\n'
                  '\u2022 Algorithm finds minimum detectors for full coverage\n'
                  '\u2022 Spacing reduced for ceilings above max height\n'
                  '\u2022 Corridors \u2264 2m wide use single-row spacing',
                ),
                const SizedBox(height: 12),
                const StandardInfoBox(toolKey: 'detector_spacing'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CustomPaint Painter ──────────────────────────────────────────────────

class _DetectorGridPainter extends CustomPainter {
  final int columns;
  final int rows;
  final double roomLength;
  final double roomWidth;
  final double wallOffsetX;
  final double wallOffsetY;
  final double gridSpacingX;
  final double gridSpacingY;
  final bool isCorridor;
  final Brightness brightness;
  final double marginLeft;
  final double marginBottom;

  _DetectorGridPainter({
    required this.columns,
    required this.rows,
    required this.roomLength,
    required this.roomWidth,
    required this.wallOffsetX,
    required this.wallOffsetY,
    required this.gridSpacingX,
    required this.gridSpacingY,
    required this.isCorridor,
    required this.brightness,
    required this.marginLeft,
    required this.marginBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;

    final roomW = size.width - marginLeft;
    final roomH = size.height - marginBottom;
    final roomOrigin = Offset(marginLeft, 0);

    // Room outline
    final roomPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final roomRect = Rect.fromLTWH(roomOrigin.dx, roomOrigin.dy, roomW, roomH);
    canvas.drawRect(roomRect, roomPaint);

    // Room fill
    final fillPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50
      ..style = PaintingStyle.fill;
    canvas.drawRect(roomRect, fillPaint);

    // Pixel offsets from actual wall offsets
    final pxOffX = (wallOffsetX / roomLength) * roomW;
    final pxOffY = (wallOffsetY / roomWidth) * roomH;

    // Wall offset zone (for open area)
    if (!isCorridor) {
      final offsetPaint = Paint()
        ..color = isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      // Top strip
      canvas.drawRect(
        Rect.fromLTWH(roomOrigin.dx, roomOrigin.dy, roomW, pxOffY),
        offsetPaint,
      );
      // Bottom strip
      canvas.drawRect(
        Rect.fromLTWH(roomOrigin.dx, roomOrigin.dy + roomH - pxOffY, roomW, pxOffY),
        offsetPaint,
      );
      // Left strip
      canvas.drawRect(
        Rect.fromLTWH(roomOrigin.dx, roomOrigin.dy + pxOffY, pxOffX, roomH - 2 * pxOffY),
        offsetPaint,
      );
      // Right strip
      canvas.drawRect(
        Rect.fromLTWH(
          roomOrigin.dx + roomW - pxOffX,
          roomOrigin.dy + pxOffY,
          pxOffX,
          roomH - 2 * pxOffY,
        ),
        offsetPaint,
      );
    }

    // Detector dots
    final dotPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;

    final dotRadius = min(8.0, min(roomW, roomH) / 12);

    final List<Offset> detectorPositions = [];

    if (isCorridor) {
      final y = roomOrigin.dy + roomH / 2;
      for (int c = 0; c < columns; c++) {
        final x = roomOrigin.dx + pxOffX + (columns > 1 ? c * (gridSpacingX / roomLength) * roomW : (roomW / 2 - pxOffX));
        final cx = x.clamp(roomOrigin.dx + dotRadius, roomOrigin.dx + roomW - dotRadius);
        detectorPositions.add(Offset(cx, y));
        canvas.drawCircle(Offset(cx, y), dotRadius, dotPaint);
      }
    } else {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < columns; c++) {
          final x = columns > 1
              ? roomOrigin.dx + pxOffX + c * (gridSpacingX / roomLength) * roomW
              : roomOrigin.dx + roomW / 2;
          final y = rows > 1
              ? roomOrigin.dy + pxOffY + r * (gridSpacingY / roomWidth) * roomH
              : roomOrigin.dy + roomH / 2;
          detectorPositions.add(Offset(x, y));
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }

    // ─── Dimension Annotations ─────────────────────────────────────────
    final dimColor = isDark ? Colors.white70 : Colors.grey.shade700;
    final dimPaint = Paint()
      ..color = dimColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const tickLen = 4.0;
    const dimGap = 6.0; // gap between room edge and dim line

    // ── Bottom annotations (X-axis) ──
    if (!isCorridor) {
      // Wall-to-detector X
      final firstDetX = roomOrigin.dx + pxOffX;
      final dimY = roomOrigin.dy + roomH + dimGap + 8;

      _drawHorizontalDim(
        canvas, dimPaint, dimColor,
        roomOrigin.dx, firstDetX, dimY, tickLen,
        '${wallOffsetX.toStringAsFixed(2)}m',
      );

      // Detector-to-detector X
      if (columns > 1) {
        final secondDetX = roomOrigin.dx + pxOffX + (gridSpacingX / roomLength) * roomW;
        final dimY2 = dimY + 18;
        _drawHorizontalDim(
          canvas, dimPaint, dimColor,
          firstDetX, secondDetX, dimY2, tickLen,
          '${gridSpacingX.toStringAsFixed(2)}m',
        );
      }
    } else {
      // Corridor: wall-to-detector X
      final firstDetX = roomOrigin.dx + pxOffX;
      final dimY = roomOrigin.dy + roomH + dimGap + 8;

      _drawHorizontalDim(
        canvas, dimPaint, dimColor,
        roomOrigin.dx, firstDetX, dimY, tickLen,
        '${wallOffsetX.toStringAsFixed(2)}m',
      );

      if (columns > 1) {
        final secondDetX = roomOrigin.dx + pxOffX + (gridSpacingX / roomLength) * roomW;
        final dimY2 = dimY + 18;
        _drawHorizontalDim(
          canvas, dimPaint, dimColor,
          firstDetX, secondDetX, dimY2, tickLen,
          '${gridSpacingX.toStringAsFixed(2)}m',
        );
      }
    }

    // ── Left annotations (Y-axis, open area only) ──
    if (!isCorridor) {
      final firstDetY = roomOrigin.dy + pxOffY;
      final dimX = roomOrigin.dx - dimGap - 8;

      _drawVerticalDim(
        canvas, dimPaint, dimColor,
        roomOrigin.dy, firstDetY, dimX, tickLen,
        '${wallOffsetY.toStringAsFixed(2)}m',
      );

      if (rows > 1) {
        final secondDetY = roomOrigin.dy + pxOffY + (gridSpacingY / roomWidth) * roomH;
        final dimX2 = dimX - 18;
        _drawVerticalDim(
          canvas, dimPaint, dimColor,
          firstDetY, secondDetY, dimX2, tickLen,
          '${gridSpacingY.toStringAsFixed(2)}m',
        );
      }
    }
  }

  void _drawHorizontalDim(
    Canvas canvas, Paint linePaint, Color textColor,
    double x1, double x2, double y, double tickLen, String label,
  ) {
    // Horizontal line
    canvas.drawLine(Offset(x1, y), Offset(x2, y), linePaint);
    // Left tick
    canvas.drawLine(Offset(x1, y - tickLen), Offset(x1, y + tickLen), linePaint);
    // Right tick
    canvas.drawLine(Offset(x2, y - tickLen), Offset(x2, y + tickLen), linePaint);

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final midX = (x1 + x2) / 2 - tp.width / 2;
    tp.paint(canvas, Offset(midX, y - tp.height - 2));
  }

  void _drawVerticalDim(
    Canvas canvas, Paint linePaint, Color textColor,
    double y1, double y2, double x, double tickLen, String label,
  ) {
    // Vertical line
    canvas.drawLine(Offset(x, y1), Offset(x, y2), linePaint);
    // Top tick
    canvas.drawLine(Offset(x - tickLen, y1), Offset(x + tickLen, y1), linePaint);
    // Bottom tick
    canvas.drawLine(Offset(x - tickLen, y2), Offset(x + tickLen, y2), linePaint);

    // Label (rotated)
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final midY = (y1 + y2) / 2;
    canvas.save();
    canvas.translate(x - 2, midY + tp.width / 2);
    canvas.rotate(-pi / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DetectorGridPainter oldDelegate) {
    return columns != oldDelegate.columns ||
        rows != oldDelegate.rows ||
        roomLength != oldDelegate.roomLength ||
        roomWidth != oldDelegate.roomWidth ||
        wallOffsetX != oldDelegate.wallOffsetX ||
        wallOffsetY != oldDelegate.wallOffsetY ||
        gridSpacingX != oldDelegate.gridSpacingX ||
        gridSpacingY != oldDelegate.gridSpacingY ||
        isCorridor != oldDelegate.isCorridor ||
        brightness != oldDelegate.brightness;
  }
}
