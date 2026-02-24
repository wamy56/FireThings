import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/icon_map.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

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
  final double coveragePerDetector;
  final double roomArea;
  final List<String> notes;

  const _CalcResult({
    required this.detectorCount,
    required this.columns,
    required this.rows,
    required this.gridSpacingX,
    required this.gridSpacingY,
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

    if (_roomType == RoomType.corridor) {
      // Corridor: single row centred in width
      var corridorSpacing = spec.corridorSpacing;

      // Height adjustment
      if (height > spec.maxCeiling) {
        final excess = height - spec.maxCeiling;
        final reduction = excess * 0.5;
        final adjusted = max(corridorSpacing * 0.5, corridorSpacing - reduction);
        notes.add(
          'Ceiling height (${height.toStringAsFixed(1)}m) exceeds maximum '
          '(${spec.maxCeiling}m) for ${spec.label}. Spacing reduced from '
          '${corridorSpacing.toStringAsFixed(1)}m to ${adjusted.toStringAsFixed(1)}m.',
        );
        corridorSpacing = adjusted;
      }

      cols = max(1, (length / corridorSpacing).ceil());
      rows = 1;
      spacingX = cols > 1 ? length / cols : length;
      spacingY = width / 2;

      if (width > 2.0) {
        notes.add(
          'Corridor width exceeds 2m. Consider using open-area spacing '
          'instead for better coverage.',
        );
      }
    } else {
      // Open area
      var gridSpacing = spec.radius * sqrt2;

      // Height adjustment
      if (height > spec.maxCeiling) {
        final excess = height - spec.maxCeiling;
        final reduction = excess * 0.5;
        final adjusted = max(gridSpacing * 0.5, gridSpacing - reduction);
        notes.add(
          'Ceiling height (${height.toStringAsFixed(1)}m) exceeds maximum '
          '(${spec.maxCeiling}m) for ${spec.label}. Spacing reduced from '
          '${gridSpacing.toStringAsFixed(1)}m to ${adjusted.toStringAsFixed(1)}m.',
        );
        gridSpacing = adjusted;
      }

      // Wall offset 0.5m each side
      final effectiveLength = max(0.0, length - 1.0);
      final effectiveWidth = max(0.0, width - 1.0);

      cols = max(1, (effectiveLength / gridSpacing).ceil());
      rows = max(1, (effectiveWidth / gridSpacing).ceil());

      spacingX = cols > 1 ? effectiveLength / (cols - 1) : 0;
      spacingY = rows > 1 ? effectiveWidth / (rows - 1) : 0;

      notes.add(
        'Wall offset of 0.5m applied on each side per BS 5839-1.',
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
              keyboardType: TextInputType.number,
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
              keyboardType: TextInputType.number,
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
              keyboardType: TextInputType.number,
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
                'Spacing (L \u00d7 W)',
                '${r.gridSpacingX.toStringAsFixed(1)}m \u00d7 ${r.gridSpacingY.toStringAsFixed(1)}m',
              ),
              const SizedBox(height: 8),
            ] else ...[
              _buildSummaryRow(
                'Spacing Along Corridor',
                '${r.gridSpacingX.toStringAsFixed(1)}m',
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
                  final maxWidth = constraints.maxWidth - 32;
                  const maxHeight = 220.0;
                  final aspect = length / width;
                  double drawWidth;
                  double drawHeight;
                  if (aspect > maxWidth / maxHeight) {
                    drawWidth = maxWidth;
                    drawHeight = maxWidth / aspect;
                  } else {
                    drawHeight = maxHeight;
                    drawWidth = maxHeight * aspect;
                  }

                  return CustomPaint(
                    size: Size(drawWidth, drawHeight),
                    painter: _DetectorGridPainter(
                      columns: r.columns,
                      rows: r.rows,
                      roomLength: length,
                      roomWidth: width,
                      isCorridor: _roomType == RoomType.corridor,
                      brightness: Theme.of(context).brightness,
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
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
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
                  '\u2022 Grid spacing = radius \u00d7 \u221a2 for open areas\n'
                  '\u2022 0.5m wall offset applied on all sides\n'
                  '\u2022 Spacing reduced for ceilings above max height\n'
                  '\u2022 Corridors \u2264 2m wide use single-row spacing',
                ),
                const SizedBox(height: 12),
                Text(
                  'This calculator provides guidance only. Always refer to '
                  'BS 5839-1 for the full standard and consult with a fire '
                  'engineer for complex installations.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
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
  final bool isCorridor;
  final Brightness brightness;

  _DetectorGridPainter({
    required this.columns,
    required this.rows,
    required this.roomLength,
    required this.roomWidth,
    required this.isCorridor,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;

    // Room outline
    final roomPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final roomRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(roomRect, roomPaint);

    // Room fill
    final fillPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50
      ..style = PaintingStyle.fill;
    canvas.drawRect(roomRect, fillPaint);

    // Wall offset zone (for open area)
    if (!isCorridor) {
      final offsetX = (0.5 / roomLength) * size.width;
      final offsetY = (0.5 / roomWidth) * size.height;
      final offsetPaint = Paint()
        ..color = isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      // Top strip
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, offsetY), offsetPaint);
      // Bottom strip
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - offsetY, size.width, offsetY),
        offsetPaint,
      );
      // Left strip
      canvas.drawRect(
        Rect.fromLTWH(0, offsetY, offsetX, size.height - 2 * offsetY),
        offsetPaint,
      );
      // Right strip
      canvas.drawRect(
        Rect.fromLTWH(
          size.width - offsetX, offsetY, offsetX, size.height - 2 * offsetY,
        ),
        offsetPaint,
      );
    }

    // Detector dots
    final dotPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;

    final dotRadius = min(8.0, min(size.width, size.height) / 12);

    if (isCorridor) {
      // Single row centred vertically
      final y = size.height / 2;
      for (int c = 0; c < columns; c++) {
        final x = columns > 1
            ? (c / (columns - 1)) * size.width
            : size.width / 2;
        // Clamp to keep dots inside
        final cx = x.clamp(dotRadius, size.width - dotRadius);
        canvas.drawCircle(Offset(cx, y), dotRadius, dotPaint);
      }
    } else {
      // Grid: offset from walls
      final offsetX = (0.5 / roomLength) * size.width;
      final offsetY = (0.5 / roomWidth) * size.height;
      final availableW = size.width - 2 * offsetX;
      final availableH = size.height - 2 * offsetY;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < columns; c++) {
          final x = columns > 1
              ? offsetX + (c / (columns - 1)) * availableW
              : size.width / 2;
          final y = rows > 1
              ? offsetY + (r / (rows - 1)) * availableH
              : size.height / 2;
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DetectorGridPainter oldDelegate) {
    return columns != oldDelegate.columns ||
        rows != oldDelegate.rows ||
        roomLength != oldDelegate.roomLength ||
        roomWidth != oldDelegate.roomWidth ||
        isCorridor != oldDelegate.isCorridor ||
        brightness != oldDelegate.brightness;
  }
}
