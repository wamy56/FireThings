import 'package:flutter/material.dart';
import '../../widgets/premium_dialog.dart';
import '../../utils/icon_map.dart';
import '../../widgets/adaptive_app_bar.dart';

class SymptomTroubleshooterScreen extends StatefulWidget {
  const SymptomTroubleshooterScreen({super.key});

  @override
  State<SymptomTroubleshooterScreen> createState() =>
      _SymptomTroubleshooterScreenState();
}

class _SymptomTroubleshooterScreenState
    extends State<SymptomTroubleshooterScreen> {
  String? _selectedCategory;
  String? _selectedSymptom;
  TroubleshootingGuide? _currentGuide;

  final Map<String, List<String>> _symptomCategories = {
    'Loop/Wiring Faults': [
      'Intermittent loop fault',
      'Loop fault only at night',
      'Loop fault in wet weather',
      'Loop fault after building work',
      'Random device faults',
      'Loop short circuit',
      'Open circuit fault',
    ],
    'Earth/Electrical Issues': [
      'Earth fault appears at night',
      'Earth fault in wet weather',
      'Earth fault intermittent',
      'Mains failure frequent trips',
      'PSU overheating',
      'Battery not charging',
    ],
    'Device Issues': [
      'Unwanted alarms at night',
      'Detector going into fault',
      'Multiple detectors faulty same zone',
      'Device not responding',
      'New device not working',
      'Detector drift/contamination',
    ],
    'System Behavior': [
      'Panel keeps resetting',
      'Slow loop polling',
      'Network communication fault',
      'Sounder circuit fault',
      'Panel beeping/buzzer',
      'Display showing fault but no details',
    ],
    'Environmental': [
      'Faults only in cold weather',
      'Faults only in hot weather',
      'Faults after cleaning',
      'Faults in kitchen area',
      'Faults in bathroom/shower areas',
    ],
  };

  final Map<String, TroubleshootingGuide> _troubleshootingDatabase = {
    'Intermittent loop fault': TroubleshootingGuide(
      symptom: 'Intermittent loop fault',
      description: 'Loop fault appears randomly, clears itself, then returns',
      likelyCauses: [
        'Loose connection at device terminals',
        'Damaged cable flexing/moving',
        'Poor joint in junction box',
        'Isolator module failing',
        'Device at end of life intermittently failing',
        'Water ingress intermittent (condensation)',
      ],
      isolationSteps: [
        '1. Check panel log - note frequency and timing of faults',
        '2. Identify the specific loop or device address if shown',
        '3. If address shown, go directly to that device first',
        '4. Check all isolator modules - toggle them and check for poor contacts',
        '5. Divide loop in half using isolators to narrow down section',
        '6. In problem section, check all junction boxes for loose connections',
        '7. Flex cables gently while monitoring panel for fault',
        '8. Check terminations at each device are tight',
        '9. Look for signs of water damage or corrosion',
        '10. If isolated to one device, swap it with known good device',
      ],
      testingTips: [
        'Leave panel running overnight to see if fault repeats at specific times',
        'Take insulation resistance readings when fault present vs when clear',
        'Use thermal camera to spot poor connections (will show heat)',
        'Wiggle test - gently move cables and devices while watching panel',
      ],
      preventiveMeasures: [
        'Ensure all terminations are properly tightened',
        'Seal junction boxes to prevent moisture',
        'Use strain relief on cables',
        'Replace devices over 10 years old',
      ],
    ),
    'Earth fault appears at night': TroubleshootingGuide(
      symptom: 'Earth fault appears at night',
      description: 'Earth fault occurs overnight, clears during day',
      likelyCauses: [
        'Condensation in junction boxes',
        'Temperature causing cable insulation to contract',
        'Heating system turning off causing damp',
        'Cable routed near cold external wall',
        'Device in unheated area',
        'Poor cable jointing allowing moisture in',
      ],
      isolationSteps: [
        '1. Note exact time fault appears (check panel log)',
        '2. Check building schedule - heating on/off times',
        '3. Use insulation tester: test loop to earth resistance morning vs evening',
        '4. Look for areas that get cold overnight (external walls, roof spaces)',
        '5. Check all junction boxes in cold areas for condensation',
        '6. Isolate sections systematically to find problem area',
        '7. In problem area, open devices and check for moisture',
        '8. Check cables passing through external walls',
        '9. Inspect roof space cable runs for condensation',
      ],
      testingTips: [
        'Test insulation resistance first thing in morning when fault present',
        'Compare readings across multiple mornings',
        'Use moisture meter on suspect junction boxes',
        'Seal one suspect area at a time and monitor over several nights',
      ],
      preventiveMeasures: [
        'Seal all junction boxes with IP-rated enclosures',
        'Use silica gel packs in problematic junction boxes',
        'Ensure cables in roof spaces are above insulation',
        'Route cables away from cold external walls',
        'Use proper external grade cable for outside runs',
      ],
    ),
    'Loop fault in wet weather': TroubleshootingGuide(
      symptom: 'Loop fault in wet weather',
      description: 'Faults only appear when raining or after rain',
      likelyCauses: [
        'Water ingress in external junction box',
        'Cable entry point not sealed properly',
        'Damaged external cable sheath',
        'Device in exposed location (canopy, loading bay)',
        'Roof leak affecting cables in ceiling void',
        'Conduit filling with water',
      ],
      isolationSteps: [
        '1. Identify all external or exposed devices on the loop',
        '2. Check all external junction boxes for water',
        '3. Inspect cable glands and entries for proper sealing',
        '4. Check devices in loading bays, canopies, covered areas',
        '5. In ceiling voids, look for water stains on tiles',
        '6. Follow conduit runs - check for low points where water collects',
        '7. Isolate external sections first',
        '8. Test each external device individually',
        '9. Check roof penetrations for cable runs',
        '10. Inspect external device backboxes for water entry',
      ],
      testingTips: [
        'Test during/just after rainfall for accurate diagnosis',
        'Use water spray test on suspect devices (low pressure)',
        'Check IP ratings of external devices are suitable',
        'Insulation test when dry vs when wet',
      ],
      preventiveMeasures: [
        'Use IP65 rated devices in exposed areas',
        'Seal all cable entries with proper glands',
        'Use weatherproof junction boxes externally',
        'Drill weep holes in bottom of external boxes',
        'Check and renew seals annually',
      ],
    ),
    'Unwanted alarms at night': TroubleshootingGuide(
      symptom: 'Unwanted alarms at night',
      description: 'Detectors activating overnight with no real fire',
      likelyCauses: [
        'Detector contamination/dust buildup',
        'Insects entering detector',
        'Steam/condensation from heating system startup',
        'Temperature inversion at night',
        'Detector too sensitive for location',
        'Air movement from HVAC changes',
      ],
      isolationSteps: [
        '1. Check panel log - note which device(s) and exact times',
        '2. Check if multiple detectors or always same one',
        '3. Inspect the activating detector - look for dust, insects',
        '4. Check detector age and service history',
        '5. Review detector type vs location suitability',
        '6. Check for steam sources (kitchen, bathroom)',
        '7. Note correlation with HVAC operation times',
        '8. Check building schedules - any cleaning/maintenance at that time',
        '9. Temperature check - is area getting cold then heating quickly',
        '10. Review analogue values/contamination levels if available',
      ],
      testingTips: [
        'Check analogue value history if panel supports it',
        'Clean detector and monitor for improvement',
        'Temporarily increase alarm threshold to test sensitivity',
        'Install test detector of different type to compare',
      ],
      preventiveMeasures: [
        'Regular detector cleaning (annually minimum)',
        'Use heat detectors in high steam areas',
        'Install mesh/insect screens on detectors',
        'Relocate detectors away from air vents',
        'Adjust sensitivity settings if available',
        'Replace detectors over 10 years old',
      ],
    ),
    'Loop short circuit': TroubleshootingGuide(
      symptom: 'Loop short circuit',
      description: 'Panel showing short circuit on loop',
      likelyCauses: [
        'Cable damage from building work',
        'Nail/screw through cable',
        'Water in junction box causing short',
        'Crushed cable in trunking',
        'Failed device causing internal short',
        'Loose wires touching in backbox',
      ],
      isolationSteps: [
        '1. Disconnect loop at panel - confirm fault clears',
        '2. Use isolators to divide loop in half',
        '3. Test each half for short circuit',
        '4. Continue halving the problem section',
        '5. When down to small section, disconnect devices one by one',
        '6. Once section identified, inspect all cables visually',
        '7. Check for recent building work/drilling in that area',
        '8. Open junction boxes and check for water or loose wires',
        '9. Use insulation tester: line to line should be >2MΩ',
        '10. Replace or repair damaged section',
      ],
      testingTips: [
        'Insulation test between loop wires (disconnect from panel first)',
        'Visual inspection of cable routes in problem area',
        'Ask building staff about recent work',
        'Megger test each cable section individually',
      ],
      preventiveMeasures: [
        'Install cable in proper containment',
        'Use warning tape above buried cables',
        'Document cable routes clearly',
        'Use armored cable in vulnerable areas',
        'Regular visual inspections',
      ],
    ),
    'Earth fault in wet weather': TroubleshootingGuide(
      symptom: 'Earth fault in wet weather',
      description: 'Earth fault only when raining or damp',
      likelyCauses: [
        'Water in external junction box',
        'Damaged cable sheath allowing water in',
        'Poorly sealed cable gland',
        'Conduit acting as water pipe',
        'Device in damp location',
        'Roof leak affecting cables',
      ],
      isolationSteps: [
        '1. Test during wet weather for accurate fault finding',
        '2. Check all external junction boxes for water',
        '3. Inspect cable glands and seals',
        '4. Follow conduit runs checking for low spots',
        '5. Check devices in exposed locations',
        '6. Test insulation resistance loop to earth',
        '7. Isolate in sections to narrow down',
        '8. In problem area, open all accessories',
        '9. Look for water damage, green corrosion',
        '10. Check roof spaces for leaks',
      ],
      testingTips: [
        'Test immediately after rain starts',
        'Compare insulation readings wet vs dry',
        'Spray test suspect areas (low pressure)',
        'Use moisture meter on backboxes',
      ],
      preventiveMeasures: [
        'Use IP65 devices externally',
        'Seal all cable entries properly',
        'Drill weep holes in low points of conduit',
        'Check and replace perished seals',
        'Annual inspection of external equipment',
      ],
    ),
    'Device not responding': TroubleshootingGuide(
      symptom: 'Device not responding',
      description: 'Single device not communicating with panel',
      likelyCauses: [
        'Device removed or stolen',
        'Wiring disconnected at device',
        'Device completely failed',
        'Wrong address programmed',
        'Isolator activated blocking device',
        'Loop break before device',
      ],
      isolationSteps: [
        '1. Check device address in panel - confirm expected location',
        '2. Go to physical location - is device present?',
        '3. Check device base is properly seated',
        '4. Remove device and check base terminals',
        '5. Check isolator module before this device',
        '6. Test continuity through to next device',
        '7. Try swapping device with known good one',
        '8. Check address setting if DIL switches present',
        '9. Measure voltage at device base (should be ~24V)',
        '10. If new device, re-learn loop on panel',
      ],
      testingTips: [
        'Swap with identical device to test device vs wiring',
        'Check voltage at device - proves wiring OK',
        'Try device at different address to test device',
        'Check for physical damage to device',
      ],
      preventiveMeasures: [
        'Label all devices clearly',
        'Secure devices with tamper locks if theft risk',
        'Annual check all devices present',
        'Keep spare devices on site',
        'Update panel database after device changes',
      ],
    ),
    'Panel keeps resetting': TroubleshootingGuide(
      symptom: 'Panel keeps resetting',
      description: 'Panel reboots or resets unexpectedly',
      likelyCauses: [
        'Power supply issue (mains unstable)',
        'Battery connection poor',
        'Battery failed',
        'PSU output voltage unstable',
        'Firmware corruption',
        'Overheating due to blocked ventilation',
        'Faulty panel card/CPU',
      ],
      isolationSteps: [
        '1. Check event log for reset pattern/timing',
        '2. Measure mains voltage - should be stable 230V',
        '3. Check battery voltage - should be 13.8V for 12V battery',
        '4. Check battery terminals - clean and tight?',
        '5. Measure PSU output voltage under load',
        '6. Check panel for overheating - feel temperature',
        '7. Verify ventilation not blocked',
        '8. Check for loose cards - reseat all cards',
        '9. Look for brown-out events in electrical system',
        '10. Try different battery to test',
      ],
      testingTips: [
        'Log voltage over 24 hours with data logger',
        'Check for correlation with equipment starting (lifts, chillers)',
        'Thermal imaging of panel internals',
        'Monitor during reset to see if voltage drops',
      ],
      preventiveMeasures: [
        'Install dedicated fire alarm circuit',
        'Use voltage stabilizer if mains unstable',
        'Replace batteries every 4 years',
        'Keep panel ventilation clear',
        'Clean panel interior annually',
        'Update firmware to latest version',
      ],
    ),
    'Battery not charging': TroubleshootingGuide(
      symptom: 'Battery not charging',
      description: 'Battery voltage low, not reaching 13.8V',
      likelyCauses: [
        'Battery at end of life',
        'Poor battery connections',
        'Blown fuse in charging circuit',
        'Failed charger circuit',
        'Battery disconnected',
        'Incorrect battery size (too large)',
      ],
      isolationSteps: [
        '1. Measure battery voltage at terminals',
        '2. Check battery age (if >4 years, likely failed)',
        '3. Check battery terminals - tight and clean?',
        '4. Check for blown fuse on charging circuit',
        '5. Measure charging voltage at battery (should be 13.8V)',
        '6. Check battery connections for corrosion',
        '7. Load test battery if less than 4 years old',
        '8. Try known good battery to test charger',
        '9. Check panel PSU output voltage',
        '10. Review panel configuration for battery settings',
      ],
      testingTips: [
        'Disconnect and charge battery externally to test',
        'Check battery voltage under load',
        'Measure charging current',
        'Check for battery bulging/damage',
      ],
      preventiveMeasures: [
        'Replace batteries every 4 years maximum',
        'Clean terminals annually',
        'Use correct capacity battery',
        'Keep battery cool',
        'Check charging voltage monthly',
      ],
    ),
    'Multiple detectors faulty same zone': TroubleshootingGuide(
      symptom: 'Multiple detectors faulty same zone',
      description: 'Several detectors on same loop showing fault',
      likelyCauses: [
        'Loop power supply issue',
        'High loop impedance',
        'Common junction box fault',
        'Cable damage affecting multiple devices',
        'Environmental issue affecting all (steam, dust)',
        'Isolator fault affecting multiple devices',
      ],
      isolationSteps: [
        '1. Check loop voltage at panel',
        '2. Measure loop current draw',
        '3. Check voltage at affected devices',
        '4. Look for common junction box serving all devices',
        '5. Check isolator modules in the path',
        '6. Test cable impedance',
        '7. Check for environmental issues (all in kitchen?)',
        '8. Test devices individually at panel',
        '9. Check for recent work affecting that area',
        '10. Measure voltage drop along loop',
      ],
      testingTips: [
        'Measure voltage at each device - should be >18V',
        'Check all devices same age/type',
        'Test devices on different loop',
        'Look for common failure mode',
      ],
      preventiveMeasures: [
        'Keep loop loading within limits',
        'Use adequate cable size',
        'Install loop power supplies if needed',
        'Regular maintenance all devices',
        'Replace devices on schedule',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Troubleshooter',
        actions: [
          IconButton(
            icon: Icon(AppIcons.infoCircle),
            onPressed: _showInfoDialog,
            tooltip: 'Information',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildSelectionCard(),
            if (_currentGuide != null) ...[
              const SizedBox(height: 24),
              _buildTroubleshootingGuide(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor.withValues(alpha:0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              AppIcons.search,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Symptom-Based Troubleshooting',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select symptom for step-by-step isolation guide',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Symptom',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(AppIcons.category),
                border: OutlineInputBorder(),
              ),
              items: _symptomCategories.keys.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                  _selectedSymptom = null;
                  _currentGuide = null;
                });
              },
            ),

            if (_selectedCategory != null) ...[
              const SizedBox(height: 16),

              // Symptom Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSymptom,
                decoration: InputDecoration(
                  labelText: 'Symptom',
                  prefixIcon: Icon(AppIcons.warning),
                  border: OutlineInputBorder(),
                ),
                items: _symptomCategories[_selectedCategory]!.map((symptom) {
                  return DropdownMenuItem(value: symptom, child: Text(symptom));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSymptom = value;
                    _currentGuide = _troubleshootingDatabase[value];
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingGuide() {
    if (_currentGuide == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Description
        Card(
          elevation: 3,
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.document, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currentGuide!.description,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Likely Causes
        _buildSection(
          'Likely Causes',
          AppIcons.search,
          Colors.orange,
          _currentGuide!.likelyCauses,
        ),
        const SizedBox(height: 16),

        // Isolation Steps
        _buildSection(
          'Step-by-Step Isolation',
          AppIcons.task,
          Colors.purple,
          _currentGuide!.isolationSteps,
          numbered: true,
        ),
        const SizedBox(height: 16),

        // Testing Tips
        _buildSection(
          'Testing Tips',
          AppIcons.lamp,
          Colors.amber,
          _currentGuide!.testingTips,
        ),
        const SizedBox(height: 16),

        // Preventive Measures
        _buildSection(
          'Preventive Measures',
          AppIcons.shield,
          Colors.green,
          _currentGuide!.preventiveMeasures,
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<String> items, {
    bool numbered = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (numbered)
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12, top: 2),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(top: 8, right: 12),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }),
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
        title: const Text('Symptom-Based Troubleshooter'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This tool provides systematic troubleshooting based on real-world symptoms.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('How to Use:'),
              SizedBox(height: 8),
              Text('1. Select symptom category'),
              Text('2. Select specific symptom'),
              Text('3. Follow step-by-step isolation guide'),
              Text('4. Use testing tips for accurate diagnosis'),
              Text('5. Apply preventive measures'),
              SizedBox(height: 12),
              Text('Categories:'),
              SizedBox(height: 8),
              Text('• Loop/Wiring Faults'),
              Text('• Earth/Electrical Issues'),
              Text('• Device Issues'),
              Text('• System Behavior'),
              Text('• Environmental'),
              SizedBox(height: 12),
              Text(
                'Each guide includes likely causes, systematic isolation steps, testing tips, and prevention advice.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
      )),
    );
  }
}

class TroubleshootingGuide {
  final String symptom;
  final String description;
  final List<String> likelyCauses;
  final List<String> isolationSteps;
  final List<String> testingTips;
  final List<String> preventiveMeasures;

  TroubleshootingGuide({
    required this.symptom,
    required this.description,
    required this.likelyCauses,
    required this.isolationSteps,
    required this.testingTips,
    required this.preventiveMeasures,
  });
}
