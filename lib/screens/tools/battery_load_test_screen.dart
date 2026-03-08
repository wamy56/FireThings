import 'package:flutter/material.dart';
import '../../widgets/premium_dialog.dart';
import 'package:flutter/services.dart';
import '../../utils/icon_map.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/standard_info_box.dart';

class BatteryLoadTestScreen extends StatefulWidget {
  const BatteryLoadTestScreen({super.key});

  @override
  State<BatteryLoadTestScreen> createState() => _BatteryLoadTestScreenState();
}

class _BatteryLoadTestScreenState extends State<BatteryLoadTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Input controllers
  final _batteryCapacityController = TextEditingController(text: '7');
  final _standbyCurrentController = TextEditingController(text: '0.1');
  final _alarmCurrentController = TextEditingController(text: '0.5');

  // Results
  double _requiredStandbyTime = 24; // hours (T1)
  double _requiredCapacity = 0; // Cmin
  bool _passesTest = false;
  bool _calculated = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _batteryCapacityController.dispose();
    _standbyCurrentController.dispose();
    _alarmCurrentController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final batteryCapacity = double.parse(_batteryCapacityController.text);
    final standbyCurrent = double.parse(_standbyCurrentController.text);
    final alarmCurrent = double.parse(_alarmCurrentController.text);

    setState(() {
      // BS 5839-1:2025 Annex E formula
      // Cmin = 1.25 × ((T1 × I1) + D × (I2 × T2))
      const ageingFactor = 1.25;
      const deratingFactor = 1.75; // D — battery inefficiency under alarm load
      const alarmDuration = 0.5; // T2 — 30 minutes in hours

      final cMin = ageingFactor *
          ((_requiredStandbyTime * standbyCurrent) +
              (deratingFactor * alarmCurrent * alarmDuration));

      _requiredCapacity = cMin;
      _passesTest = batteryCapacity >= cMin;
      _calculated = true;
    });

    // Scroll to show results after a short delay
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
      _batteryCapacityController.text = '7';
      _standbyCurrentController.text = '0.1';
      _alarmCurrentController.text = '0.5';
      _requiredStandbyTime = 24;
      _calculated = false;
    });
  }

  Color _getResultColor() {
    if (!_calculated) return Colors.grey;
    return _passesTest ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Battery Load Test',
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
              if (_calculated) ...[const SizedBox(height: 24), _buildResults()],
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
                  AppIcons.batteryCharging,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Minimum Battery Capacity Calculator',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Calculate the minimum required battery capacity (Cmin) per BS 5839-1 and compare against the installed battery.',
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
              'Battery Specifications',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Battery Capacity
            TextFormField(
              controller: _batteryCapacityController,
              decoration: InputDecoration(
                labelText: 'Installed Battery Capacity (Ah)',
                prefixIcon: Icon(AppIcons.batteryFull),
                border: OutlineInputBorder(),
                suffixText: 'Ah',
                helperText: 'e.g., 7Ah, 12Ah, 17Ah',
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

            Text(
              'System Load',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Standby Current
            TextFormField(
              controller: _standbyCurrentController,
              decoration: InputDecoration(
                labelText: 'Standby Current I\u2081 (A)',
                prefixIcon: Icon(AppIcons.flash),
                border: OutlineInputBorder(),
                suffixText: 'A',
                helperText: 'Total quiescent current',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final val = double.tryParse(value);
                if (val == null || val < 0) return 'Must be positive or zero';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Alarm Current
            TextFormField(
              controller: _alarmCurrentController,
              decoration: InputDecoration(
                labelText: 'Alarm Current I\u2082 (A)',
                prefixIcon: Icon(AppIcons.notification),
                border: OutlineInputBorder(),
                suffixText: 'A',
                helperText: 'Total current during alarm',
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

            // Required Standby Time
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Required Standby Time (T\u2081)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                DropdownButton<double>(
                  value: _requiredStandbyTime,
                  items: const [
                    DropdownMenuItem(value: 24.0, child: Text('24 hours')),
                    DropdownMenuItem(value: 72.0, child: Text('72 hours')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _requiredStandbyTime = value!;
                    });
                  },
                ),
              ],
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

  Widget _buildResults() {
    final resultColor = _getResultColor();
    final batteryCapacity = double.parse(_batteryCapacityController.text);
    final standbyCurrent = double.parse(_standbyCurrentController.text);
    final alarmCurrent = double.parse(_alarmCurrentController.text);
    final margin = batteryCapacity - _requiredCapacity;

    // Formula component breakdowns
    final standbyComponent = _requiredStandbyTime * standbyCurrent;
    const deratingFactor = 1.75;
    const alarmDuration = 0.5;
    final alarmComponent = deratingFactor * alarmCurrent * alarmDuration;
    final subtotal = standbyComponent + alarmComponent;

    return Column(
      children: [
        // Pass/Fail Card
        Card(
          elevation: 4,
          color: resultColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  _passesTest ? AppIcons.tickCircle : AppIcons.danger,
                  size: 64,
                  color: resultColor,
                ),
                const SizedBox(height: 12),
                Text(
                  _passesTest ? 'PASS' : 'FAIL',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: resultColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _passesTest
                      ? 'Battery meets BS 5839 requirements'
                      : 'Battery does NOT meet requirements',
                  style: TextStyle(fontSize: 14, color: resultColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Calculation Breakdown
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculation Breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _buildResultRow(
                  'Required Capacity (Cmin)',
                  '${_requiredCapacity.toStringAsFixed(2)} Ah',
                  null,
                ),
                const Divider(height: 24),
                _buildResultRow(
                  'Installed Capacity',
                  '${batteryCapacity.toStringAsFixed(1)} Ah',
                  null,
                ),
                const Divider(height: 24),
                _buildResultRow(
                  'Margin',
                  '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(2)} Ah',
                  margin >= 0,
                ),
                const Divider(height: 24),

                // Formula breakdown
                Text(
                  'Formula: Cmin = 1.25 \u00d7 ((T\u2081 \u00d7 I\u2081) + D \u00d7 (I\u2082 \u00d7 T\u2082))',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFormulaRow(
                  'Standby component',
                  'T\u2081 \u00d7 I\u2081 = ${_requiredStandbyTime.toStringAsFixed(0)} \u00d7 ${standbyCurrent.toStringAsFixed(3)}',
                  '${standbyComponent.toStringAsFixed(2)} Ah',
                ),
                const SizedBox(height: 6),
                _buildFormulaRow(
                  'Alarm component',
                  'D \u00d7 I\u2082 \u00d7 T\u2082 = 1.75 \u00d7 ${alarmCurrent.toStringAsFixed(3)} \u00d7 0.5',
                  '${alarmComponent.toStringAsFixed(2)} Ah',
                ),
                const SizedBox(height: 6),
                _buildFormulaRow(
                  'Subtotal',
                  '',
                  '${subtotal.toStringAsFixed(2)} Ah',
                ),
                const SizedBox(height: 6),
                _buildFormulaRow(
                  'With ageing factor',
                  '\u00d7 1.25',
                  '${_requiredCapacity.toStringAsFixed(2)} Ah (Cmin)',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Recommendations
        if (!_passesTest) _buildRecommendations(),
      ],
    );
  }

  Widget _buildResultRow(String label, String value, bool? passes) {
    final Color valueColor;
    if (passes == null) {
      valueColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    } else {
      valueColor = passes ? Colors.green : Colors.red;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            if (passes != null) ...[
              const SizedBox(width: 8),
              Icon(
                passes ? AppIcons.tickCircle : AppIcons.danger,
                color: valueColor,
                size: 20,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFormulaRow(String label, String formula, String result) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Text(
            formula,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Text(
          result,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
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
                Icon(AppIcons.lamp, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '\u2022 Minimum required capacity: ${_requiredCapacity.toStringAsFixed(2)} Ah',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '\u2022 Consider upgrading to ${_findNextBatterySize(_requiredCapacity)} Ah battery',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              '\u2022 Reduce standby current by disconnecting unnecessary devices',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              '\u2022 Reduce alarm current by limiting active sounders/devices',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  int _findNextBatterySize(double required) {
    const commonSizes = [7, 12, 17, 24, 38, 50, 65, 75, 100];
    for (var size in commonSizes) {
      if (size > required) return size;
    }
    return (required * 1.2).ceil();
  }

  void _showInfoDialog() {
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('Battery Load Test Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BS 5839-1 Formula',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cmin = 1.25 \u00d7 ((T\u2081 \u00d7 I\u2081) + D \u00d7 (I\u2082 \u00d7 T\u2082))',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const Text(
                'Where:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('\u2022 1.25 = ageing factor (5% per year over 4 years)'),
              const Text('\u2022 T\u2081 = standby period (24h or 72h)'),
              const Text('\u2022 I\u2081 = standby/quiescent current (A)'),
              const Text('\u2022 D = 1.75 derating factor (battery inefficiency under high alarm load)'),
              const Text('\u2022 I\u2082 = alarm current (A)'),
              const Text('\u2022 T\u2082 = alarm duration (0.5h / 30 min)'),
              const SizedBox(height: 12),
              const Text(
                'Standby Requirements',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('\u2022 24 hours — typical systems'),
              const Text('\u2022 72 hours — critical systems / no monitored link'),
              const Text('\u2022 30 minutes alarm operation'),
              const SizedBox(height: 12),
              const Text(
                'Common Battery Sizes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('\u2022 7 Ah — Small panels'),
              const Text('\u2022 12 Ah — Medium panels'),
              const Text('\u2022 17 Ah — Large panels'),
              const Text('\u2022 24 Ah — Very large systems'),
              const SizedBox(height: 12),
              const Text(
                'Typical Current Draw',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('\u2022 Standby: 0.05 - 0.2 A'),
              const Text('\u2022 Alarm: 0.3 - 2.0 A'),
              const SizedBox(height: 12),
              const StandardInfoBox(toolKey: 'battery_load_test'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      )),
    );
  }
}
