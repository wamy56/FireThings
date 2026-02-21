import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dip_switch_models.dart';

class DipSwitchService {
  static const String _favoritesKey = 'dip_switch_favorites';

  // ============================================================================
  // PRESET CONFIGURATIONS DATABASE
  // ============================================================================

  final Map<String, Map<String, DipSwitchConfiguration>> _configurations = {
    'Apollo': {
      'Series 65 Detector': DipSwitchConfiguration(
        manufacturer: 'Apollo',
        panelType: 'Series 65 Detector',
        description: 'Apollo Series 65 Addressable Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 255],
        },
        notes:
            'Binary addressing: Each switch represents a binary value. Add values of ON switches.',
      ),
      'XP95 Detector': DipSwitchConfiguration(
        manufacturer: 'Apollo',
        panelType: 'XP95 Detector',
        description: 'Apollo XP95 Addressable Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 0,
          'binary': true,
          'range': [0, 255],
        },
        notes:
            'Binary addressing starting from 0. Commonly used in UK installations.',
      ),
    },
    'Hochiki': {
      'ESP Protocol': DipSwitchConfiguration(
        manufacturer: 'Hochiki',
        panelType: 'ESP Protocol',
        description: 'Hochiki ESP Intelligent Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 127],
          'inverted': false,
        },
        notes:
            'Standard binary addressing. Max address 127. Switches 1-7 for address.',
      ),
      'FIREwave Protocol': DipSwitchConfiguration(
        manufacturer: 'Hochiki',
        panelType: 'FIREwave Protocol',
        description: 'Hochiki FIREwave Wireless Detector',
        switchCount: 6,
        switchLabels: [
          'Zone 1',
          'Zone 2',
          'Zone 4',
          'Zone 8',
          'Zone 16',
          'Zone 32',
        ],
        calculationType: 'zone',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 63],
        },
        notes:
            'Zone configuration for wireless devices. Binary zone addressing.',
      ),
    },
    'Morley-IAS': {
      'DXc Detector': DipSwitchConfiguration(
        manufacturer: 'Morley-IAS',
        panelType: 'DXc Detector',
        description: 'Morley-IAS DXc Addressable Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 240],
        },
        notes:
            'Binary addressing. Addresses 1-240 available. 241-255 reserved.',
      ),
      'ZX Interface': DipSwitchConfiguration(
        manufacturer: 'Morley-IAS',
        panelType: 'ZX Interface',
        description: 'Morley-IAS ZX Zone Interface',
        switchCount: 8,
        switchLabels: ['A1', 'A2', 'A4', 'A8', 'Z1', 'Z2', 'Z4', 'Z8'],
        calculationType: 'combined',
        calculationRules: {
          'addressBase': 1,
          'zoneBase': 1,
          'binary': true,
          'addressSwitches': [0, 1, 2, 3],
          'zoneSwitches': [4, 5, 6, 7],
        },
        notes: 'First 4 switches (A1-A8) for address, last 4 (Z1-Z8) for zone.',
      ),
    },
    'Advanced': {
      'MX-4400/4200 Detector': DipSwitchConfiguration(
        manufacturer: 'Advanced',
        panelType: 'MX-4400/4200 Detector',
        description: 'Advanced MX Series Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 250],
        },
        notes: 'Standard binary. Valid range 1-250 for detectors.',
      ),
      'MX-4200 Module': DipSwitchConfiguration(
        manufacturer: 'Advanced',
        panelType: 'MX-4200 Module',
        description: 'Advanced MX Input/Output Module',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 255],
        },
        notes: 'Full binary range for modules. Addresses 1-255.',
      ),
    },
    'Notifier': {
      'FSP-851 Detector': DipSwitchConfiguration(
        manufacturer: 'Notifier',
        panelType: 'FSP-851 Detector',
        description: 'Notifier Intelligent Photoelectric Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 159],
        },
        notes: 'CLIP protocol. Binary addressing 1-159 for detectors.',
      ),
      'FAPT-851 Addressable Point': DipSwitchConfiguration(
        manufacturer: 'Notifier',
        panelType: 'FAPT-851 Addressable Point',
        description: 'Notifier Addressable Input Module',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 198],
        },
        notes: 'Input modules use addresses 160-198 in CLIP protocol.',
      ),
    },
    'Kentec': {
      'Syncro AS Detector': DipSwitchConfiguration(
        manufacturer: 'Kentec',
        panelType: 'Syncro AS Detector',
        description: 'Kentec Syncro AS Addressable Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 250],
        },
        notes: 'Standard binary addressing. Up to 250 devices per loop.',
      ),
    },
    'C-TEC': {
      'Addressable Detector': DipSwitchConfiguration(
        manufacturer: 'C-TEC',
        panelType: 'Addressable Detector',
        description: 'C-TEC Addressable Detector',
        switchCount: 8,
        switchLabels: ['1', '2', '4', '8', '16', '32', '64', '128'],
        calculationType: 'address',
        calculationRules: {
          'base': 1,
          'binary': true,
          'range': [1, 240],
        },
        notes: 'Binary addressing 1-240. Compatible with XFP/CFP panels.',
      ),
    },
  };

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  List<String> getManufacturers() {
    return _configurations.keys.toList()..sort();
  }

  List<String> getPanelTypes(String manufacturer) {
    return _configurations[manufacturer]?.keys.toList() ?? [];
  }

  DipSwitchConfiguration? getConfiguration(
    String manufacturer,
    String panelType,
  ) {
    return _configurations[manufacturer]?[panelType];
  }

  Map<String, dynamic> calculateAddress(
    List<bool> switchStates,
    DipSwitchConfiguration config,
  ) {
    final rules = config.calculationRules;

    switch (config.calculationType) {
      case 'address':
        return _calculateBinaryAddress(switchStates, rules);

      case 'zone':
        return _calculateZone(switchStates, rules);

      case 'combined':
        return _calculateCombined(switchStates, rules);

      default:
        return {'address': 0};
    }
  }

  Map<String, dynamic> _calculateBinaryAddress(
    List<bool> switchStates,
    Map<String, dynamic> rules,
  ) {
    int address = 0;
    final int base = (rules['base'] as num?)?.toInt() ?? 0;
    final inverted = rules['inverted'] ?? false;

    for (int i = 0; i < switchStates.length; i++) {
      bool state = inverted ? !switchStates[i] : switchStates[i];
      if (state) {
        address += (1 << i); // Binary: 2^i
      }
    }

    address += base;

    // Validate range
    final range = rules['range'] as List?;
    if (range != null) {
      final int minRange = (range[0] as num).toInt();
      final int maxRange = (range[1] as num).toInt();
      address = address.clamp(minRange, maxRange);
    }

    return {
      'address': address,
      'zone': '',
      'settings': {
        'Binary Value': address - base,
        'Range': range != null ? '${range[0]}-${range[1]}' : 'Unlimited',
      },
    };
  }

  Map<String, dynamic> _calculateZone(
    List<bool> switchStates,
    Map<String, dynamic> rules,
  ) {
    int zone = 0;
    final int base = (rules['base'] as num?)?.toInt() ?? 1;

    for (int i = 0; i < switchStates.length; i++) {
      if (switchStates[i]) {
        zone += (1 << i);
      }
    }

    zone += base;

    return {'address': zone, 'zone': 'Zone $zone', 'settings': {}};
  }

  Map<String, dynamic> _calculateCombined(
    List<bool> switchStates,
    Map<String, dynamic> rules,
  ) {
    final addressSwitches = rules['addressSwitches'] as List<int>;
    final zoneSwitches = rules['zoneSwitches'] as List<int>;
    final int addressBase = (rules['addressBase'] as num?)?.toInt() ?? 1;
    final int zoneBase = (rules['zoneBase'] as num?)?.toInt() ?? 1;

    int address = 0;
    for (int i = 0; i < addressSwitches.length; i++) {
      if (switchStates[addressSwitches[i]]) {
        address += (1 << i);
      }
    }
    address += addressBase;

    int zone = 0;
    for (int i = 0; i < zoneSwitches.length; i++) {
      if (switchStates[zoneSwitches[i]]) {
        zone += (1 << i);
      }
    }
    zone += zoneBase;

    return {
      'address': address,
      'zone': 'Zone $zone',
      'settings': {'Address': address, 'Zone': zone},
    };
  }

  // ============================================================================
  // FAVORITES MANAGEMENT
  // ============================================================================

  Future<List<SavedDipConfiguration>> getFavoriteConfigurations() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);

    if (favoritesJson == null) return [];

    final List<dynamic> favoritesList = json.decode(favoritesJson);
    return favoritesList
        .map((item) => SavedDipConfiguration.fromJson(item))
        .toList();
  }

  Future<void> saveFavoriteConfiguration(SavedDipConfiguration config) async {
    final favorites = await getFavoriteConfigurations();
    favorites.add(config);

    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = json.encode(
      favorites.map((f) => f.toJson()).toList(),
    );
    await prefs.setString(_favoritesKey, favoritesJson);
  }

  Future<void> deleteFavoriteConfiguration(String id) async {
    final favorites = await getFavoriteConfigurations();
    favorites.removeWhere((f) => f.id == id);

    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = json.encode(
      favorites.map((f) => f.toJson()).toList(),
    );
    await prefs.setString(_favoritesKey, favoritesJson);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  String getBinaryString(List<bool> switchStates) {
    return switchStates.reversed.map((state) => state ? '1' : '0').join('');
  }

  List<bool> fromBinaryString(String binary) {
    return binary.split('').reversed.map((char) => char == '1').toList();
  }

  List<bool> fromAddress(int address, int switchCount) {
    List<bool> states = List.generate(switchCount, (index) => false);
    for (int i = 0; i < switchCount; i++) {
      states[i] = (address & (1 << i)) != 0;
    }
    return states;
  }
}
