class Bs5839Clause {
  final String reference;
  final String title;
  final String body;
  final String section;
  final List<String> keywords;
  final bool changedFrom2017;
  final String? renumberedFrom;

  const Bs5839Clause({
    required this.reference,
    required this.title,
    required this.body,
    required this.section,
    this.keywords = const [],
    this.changedFrom2017 = false,
    this.renumberedFrom,
  });
}

const String referenceDataVersion = '2026-04-21';

class Bs5839ClauseReference {
  final String clause;
  final String title;
  final String summary;
  final String? category;

  const Bs5839ClauseReference({
    required this.clause,
    required this.title,
    required this.summary,
    this.category,
  });
}

class Bs58392025Reference {
  Bs58392025Reference._();

  static const String standardVersion = 'BS 5839-1:2025';
  static const String effectiveDate = '30 April 2025';

  static const Map<String, String> clauseRenumberingMap = {
    '13': '14',
    '14': '15',
    '15': '16',
    '16': '17',
    '17': '18',
    '17.2': '18.2',
    '19': '20',
    '21': '22',
    '24': '25',
    '24.4': '25.4',
    '25.2': '26.2',
    '32': '33',
    '32.2': '33.2',
    '32.4': '33.4',
    '44': '45',
    '44.3': '45.3',
    '46': '47',
    '47': '48',
    '48': '49',
  };

  static String? get2025ClauseFor2017(String clause2017) {
    return clauseRenumberingMap[clause2017];
  }

  static String? get2017ClauseFor2025(String clause2025) {
    for (final entry in clauseRenumberingMap.entries) {
      if (entry.value == clause2025) return entry.key;
    }
    return null;
  }

  static const List<Bs5839Clause> versioned = [
    // Scope and definitions
    Bs5839Clause(
      reference: '1',
      title: 'Scope',
      body: 'Covers fire detection and fire alarm systems in and around '
          'non-domestic premises. Does not cover domestic dwellings '
          '(see BS 5839-6).',
      section: 'General',
      keywords: ['scope', 'non-domestic', 'application'],
    ),
    Bs5839Clause(
      reference: '3.13',
      title: 'Competent Person',
      body: 'Person with sufficient training, experience, knowledge, and '
          'other qualities to undertake the required activity. New formal '
          'definition in 2025 with CPD expectation.',
      section: 'Definitions',
      keywords: ['competent', 'cpd', 'training', 'qualification'],
      changedFrom2017: true,
    ),

    // System categories
    Bs5839Clause(
      reference: '5',
      title: 'System Categories',
      body: 'L1–L5 (life protection), P1–P2 (property protection), '
          'M (manual). Category determines minimum coverage and '
          'compliance requirements. L1–L5 definitions clarified; L4 now '
          'includes lift shaft top detection; L2 sleeping risk consideration '
          'strengthened.',
      section: 'Design',
      keywords: ['category', 'L1', 'L2', 'L3', 'L4', 'L5', 'P1', 'P2', 'M'],
      changedFrom2017: true,
    ),

    // Variations
    Bs5839Clause(
      reference: '6',
      title: 'Variations from the Standard',
      body: 'Permissible variations must be agreed with the purchaser '
          'and documented. Clause 6.6 lists prohibited variations that '
          'cannot be permitted under any circumstances.',
      section: 'Design',
      keywords: ['variation', 'deviation', 'permissible', 'agreement'],
    ),
    Bs5839Clause(
      reference: '6.6',
      title: 'Prohibited Variations',
      body: 'Certain variations are prohibited: absence of zone plan in '
          'multi-zone sleeping buildings, heat detectors in sleeping rooms '
          '(L2/L3), absence of ARC signalling in residential care. '
          'These result in an unsatisfactory declaration.',
      section: 'Design',
      keywords: ['prohibited', 'unsatisfactory', 'zone plan', 'sleeping'],
      changedFrom2017: true,
    ),

    // Detection
    Bs5839Clause(
      reference: '14',
      title: 'Smoke Detectors',
      body: 'Point, beam, and aspirating types. Preferred for sleeping '
          'areas. Coverage and spacing rules per room geometry. Smoke '
          'detectors preferred in sleeping rooms — heat detectors not '
          'permitted for L2/L3.',
      section: 'Detection',
      keywords: ['smoke', 'optical', 'ionisation', 'aspirating', 'sleeping'],
      changedFrom2017: true,
      renumberedFrom: '13',
    ),
    Bs5839Clause(
      reference: '15',
      title: 'Heat Detectors',
      body: 'Point and line types. Must NOT be installed in sleeping '
          'rooms for L2/L3 systems (2025 change). Suitable for kitchens, '
          'boiler rooms, dusty environments.',
      section: 'Detection',
      keywords: ['heat', 'fixed temperature', 'rate of rise', 'sleeping'],
      changedFrom2017: true,
      renumberedFrom: '14',
    ),
    Bs5839Clause(
      reference: '14.8',
      title: 'Beam Detectors — Closely Spaced Beams',
      body: 'Closely spaced beams defined as <1m centre-to-centre '
          '(2025 clarification). When beams are closely spaced, mount '
          'detectors on the underside of beams rather than between them. '
          'Affects obstruction rules and detector positioning.',
      section: 'Detection',
      keywords: ['beam', 'closely spaced', 'obstruction', 'ceiling'],
      changedFrom2017: true,
    ),
    Bs5839Clause(
      reference: '14.10',
      title: 'Obstructions',
      body: 'Items <250mm from ceiling and gaps >300mm between storage '
          'tops and ceiling clarified in 2025. Storage items within 300mm '
          'of the ceiling may impede smoke travel to detectors.',
      section: 'Detection',
      keywords: ['obstruction', 'storage', 'ceiling', 'gap'],
      changedFrom2017: true,
    ),
    Bs5839Clause(
      reference: '16',
      title: 'Sounders and Visual Alarm Devices',
      body: 'Minimum 65 dB(A) or ambient +5 dB(A). dB readings required '
          'at 1m and furthest reasonable point. Tone differentiation '
          'now required when the system shares alerts with non-fire '
          'signals such as class change or lockdown (2025 change). '
          'Class change alerts limited to 10 seconds duration.',
      section: 'Alarm Devices',
      keywords: ['sounder', 'dB', 'vad', 'beacon', 'tone', 'class change'],
      changedFrom2017: true,
      renumberedFrom: '15',
    ),
    Bs5839Clause(
      reference: '18',
      title: 'Detection in Common Areas',
      body: 'Stairway lobbies now require automatic detection for L1 and '
          'L2 systems (new 2025 requirement). Previously only circulation '
          'areas specified. Applies to lobbies between stairways and '
          'corridors where fire could impede escape.',
      section: 'Detection',
      keywords: ['stairway', 'lobby', 'common area', 'circulation'],
      changedFrom2017: true,
      renumberedFrom: '17',
    ),

    // Manual call points
    Bs5839Clause(
      reference: '20',
      title: 'Manual Call Points',
      body: 'Mounting height 1.2m–1.6m to operating element (clarified '
          'in 2025, previously 1.0m–1.2m). Maximum 45m to nearest MCP '
          'on escape route. 25% rotation testing per visit.',
      section: 'Manual Devices',
      keywords: ['mcp', 'call point', 'break glass', 'mounting height'],
      changedFrom2017: true,
      renumberedFrom: '19',
    ),

    // Cyber security — NEW
    Bs5839Clause(
      reference: '22',
      title: 'Cyber Security — Remote Access',
      body: 'New 2025 requirement. Remote access to fire alarm systems '
          'must require authentication. All network-connected panel ports '
          'must use tamper-resistant fittings. Network connection points '
          'must be clearly labelled with purpose and responsibility.',
      section: 'Cyber Security',
      keywords: [
        'cyber', 'security', 'remote access', 'authentication',
        'network', 'tamper', 'labelling',
      ],
      changedFrom2017: true,
      renumberedFrom: '21',
    ),
    Bs5839Clause(
      reference: '22.2',
      title: 'Cyber Security — Access Controls',
      body: 'Systems with remote diagnostic or configuration access must '
          'implement role-based access control. Passwords must not be '
          'default factory settings. Audit logs of remote access sessions '
          'should be maintained.',
      section: 'Cyber Security',
      keywords: ['access control', 'password', 'audit log', 'remote'],
      changedFrom2017: true,
    ),
    Bs5839Clause(
      reference: '22.3',
      title: 'Cyber Security — Network Labelling',
      body: 'All network connections to fire alarm systems must be labelled '
          'with: purpose (e.g. "ARC signalling", "remote diagnostics"), '
          'responsible party, and date of installation. Labels must be '
          'tamper-evident.',
      section: 'Cyber Security',
      keywords: ['labelling', 'network', 'connection', 'tamper-evident'],
      changedFrom2017: true,
    ),

    // Power supplies
    Bs5839Clause(
      reference: '25',
      title: 'Power Supplies',
      body: 'Mains supply + standby batteries. Battery capacity for '
          '24h standby + 30min alarm (72h for unmonitored premises). '
          'Load test voltages must be recorded at each service visit.',
      section: 'Power',
      keywords: ['power', 'battery', 'mains', 'standby', 'psu'],
      renumberedFrom: '24',
    ),
    Bs5839Clause(
      reference: '25.4',
      title: 'Battery Testing',
      body: 'Resting and loaded voltage readings required at each service. '
          'Battery condition assessed under load using Annex E formula. '
          'Record readings for audit trail. Replace batteries at 4 years '
          'or sooner if failing load test.',
      section: 'Power',
      keywords: ['battery', 'load test', 'voltage', 'annex E'],
      renumberedFrom: '24.4',
    ),

    // Earth fault
    Bs5839Clause(
      reference: '26.2',
      title: 'Earth Fault Monitoring',
      body: 'Earth fault loop impedance reading in kΩ. System must '
          'signal an earth fault condition. Reading should be recorded '
          'at each service visit.',
      section: 'Wiring',
      keywords: ['earth fault', 'impedance', 'monitoring'],
      renumberedFrom: '25.2',
    ),

    // Commissioning and handover
    Bs5839Clause(
      reference: '33',
      title: 'Commissioning and Handover',
      body: 'Full system test, cause-and-effect verification, logbook '
          'creation, zone plan provision, as-fitted documentation. '
          'Cause-and-effect matrix must be provided at handover '
          '(2025 emphasis).',
      section: 'Commissioning',
      keywords: ['commissioning', 'handover', 'as-fitted'],
      changedFrom2017: true,
      renumberedFrom: '32',
    ),
    Bs5839Clause(
      reference: '33.2',
      title: 'ARC Label at Panel',
      body: 'Where system is connected to ARC, a label showing ARC '
          'details (provider name, account reference, transmission method) '
          'must be displayed adjacent to the control panel.',
      section: 'Commissioning',
      keywords: ['arc', 'label', 'panel', 'provider'],
      renumberedFrom: '32.2',
    ),
    Bs5839Clause(
      reference: '33.4',
      title: 'Cause-and-Effect Documentation',
      body: 'Cause-and-effect matrix must be included in handover '
          'documentation. Required for commissioning visits in 2025 edition. '
          'Matrix must show every trigger device and its expected outputs.',
      section: 'Commissioning',
      keywords: ['cause and effect', 'matrix', 'handover', 'documentation'],
      changedFrom2017: true,
      renumberedFrom: '32.4',
    ),

    // Routine servicing
    Bs5839Clause(
      reference: '45',
      title: 'Routine Inspection and Servicing',
      body: 'Six-monthly service visits with ±1 month tolerance (5–7 '
          'month window). Logbook review, visual inspection, functional '
          'testing of all devices. 25% MCP rotation per visit.',
      section: 'Servicing',
      keywords: ['service', 'inspection', 'six-monthly', 'routine'],
      changedFrom2017: true,
      renumberedFrom: '44',
    ),
    Bs5839Clause(
      reference: '45.3',
      title: 'Service Tolerance Window',
      body: 'Service intervals may vary by ±1 month around the nominal '
          '6-month cycle, giving a 5–7 month window (2025 change). '
          'Services outside this window should be flagged as overdue.',
      section: 'Servicing',
      keywords: ['tolerance', 'window', 'interval', '5 months', '7 months'],
      changedFrom2017: true,
      renumberedFrom: '44.3',
    ),

    // ARC signalling — NEW category
    Bs5839Clause(
      reference: '47',
      title: 'ARC Signal Transmission',
      body: 'Maximum transmission times specified for L and P category '
          'systems. All-IP transition expected by 2027 as PSTN/ISDN '
          'networks are decommissioned. Signal types: fire, fault, '
          'pre-alarm. Each signal type has specific maximum transmission '
          'times.',
      section: 'ARC Signalling',
      keywords: ['arc', 'transmission', 'signal', 'ip', 'pstn'],
      changedFrom2017: true,
      renumberedFrom: '46',
    ),
    Bs5839Clause(
      reference: '47.2',
      title: 'ARC — Maximum Transmission Times',
      body: 'Fire signal: must be received by ARC within 60 seconds of '
          'panel activation. Fault signal: within 100 seconds. '
          'Pre-alarm: within 100 seconds. Systems using legacy PSTN '
          'paths must plan migration to IP-based signalling before 2027.',
      section: 'ARC Signalling',
      keywords: ['transmission time', '60 seconds', 'fault', 'pre-alarm'],
      changedFrom2017: true,
    ),
    Bs5839Clause(
      reference: '47.3',
      title: 'ARC — Fault Reporting',
      body: 'ARC signalling equipment must report its own faults '
          '(communication path failure, tamper, power loss) to the ARC '
          'within the specified timeframe. Dual-path systems must report '
          'single-path failure as a fault condition.',
      section: 'ARC Signalling',
      keywords: ['fault reporting', 'dual path', 'communication failure'],
      changedFrom2017: true,
    ),
    Bs5839Clause(
      reference: '47.4',
      title: 'ARC — All-IP Transition',
      body: 'With the decommissioning of PSTN and ISDN networks, all '
          'ARC signalling must transition to IP-based communication. '
          'Engineers should assess existing PSTN-dependent signalling '
          'equipment during service visits and advise on migration.',
      section: 'ARC Signalling',
      keywords: ['ip', 'pstn', 'isdn', 'migration', 'decommissioning'],
      changedFrom2017: true,
    ),

    // Certificates
    Bs5839Clause(
      reference: '48',
      title: 'Certificates',
      body: 'Commissioning certificate, maintenance certificate, '
          'modification certificate. Must reference BS 5839-1:2025 '
          '(not 2017). Satisfactory / satisfactory with variations / '
          'unsatisfactory declaration.',
      section: 'Certificates',
      keywords: ['certificate', 'declaration', 'satisfactory'],
      renumberedFrom: '47',
    ),

    // Logbook
    Bs5839Clause(
      reference: '49',
      title: 'Logbook',
      body: 'Record of all events: alarms, faults, tests, disablements, '
          'service visits, modifications. Must be reviewed at every '
          'service visit. Electronic logbooks are acceptable.',
      section: 'Documentation',
      keywords: ['logbook', 'record', 'events', 'log'],
      renumberedFrom: '48',
    ),

    // Void detection
    Bs5839Clause(
      reference: '19',
      title: 'Ceiling Void Detection',
      body: 'Updated guidance on when void detection is required. '
          'Voids >800mm deep generally require detection. '
          'Voids 200–800mm require risk assessment. '
          'Voids <200mm generally exempt. Aspirating detection preferred '
          'in voids where sampling pipes are easier to route.',
      section: 'Detection',
      keywords: ['void', 'ceiling', 'concealed space'],
      changedFrom2017: true,
    ),
  ];

  static const List<Bs5839ClauseReference> clauses = [
    Bs5839ClauseReference(
      clause: '1',
      title: 'Scope',
      summary: 'Covers fire detection and fire alarm systems in and around '
          'non-domestic premises. Does not cover domestic dwellings '
          '(see BS 5839-6).',
      category: 'General',
    ),
    Bs5839ClauseReference(
      clause: '3.13',
      title: 'Competent Person',
      summary: 'Person with sufficient training, experience, knowledge, and '
          'other qualities to undertake the required activity. New formal '
          'definition in 2025 with CPD expectation.',
      category: 'Definitions',
    ),
    Bs5839ClauseReference(
      clause: '5',
      title: 'System Categories',
      summary: 'L1–L5 (life protection), P1–P2 (property protection), '
          'M (manual). Category determines minimum coverage and '
          'compliance requirements.',
      category: 'Design',
    ),
    Bs5839ClauseReference(
      clause: '6',
      title: 'Variations from the Standard',
      summary: 'Permissible variations must be agreed with the purchaser '
          'and documented. Clause 6.6 lists prohibited variations that '
          'cannot be permitted under any circumstances.',
      category: 'Design',
    ),
    Bs5839ClauseReference(
      clause: '6.6',
      title: 'Prohibited Variations',
      summary: 'Certain variations are prohibited: absence of zone plan in '
          'multi-zone sleeping buildings, heat detectors in sleeping rooms '
          '(L2/L3), absence of ARC signalling in residential care. '
          'These result in an unsatisfactory declaration.',
      category: 'Design',
    ),
    Bs5839ClauseReference(
      clause: '14',
      title: 'Smoke Detectors',
      summary: 'Point, beam, and aspirating types. Preferred for sleeping '
          'areas. Coverage and spacing rules per room geometry.',
      category: 'Detection',
    ),
    Bs5839ClauseReference(
      clause: '15',
      title: 'Heat Detectors',
      summary: 'Point and line types. Must NOT be installed in sleeping '
          'rooms for L2/L3 systems (2025 change). Suitable for kitchens, '
          'boiler rooms, dusty environments.',
      category: 'Detection',
    ),
    Bs5839ClauseReference(
      clause: '16',
      title: 'Sounders and Visual Alarm Devices',
      summary: 'Minimum 65 dB(A) or ambient +5 dB(A). dB readings required '
          'at 1m and furthest reasonable point. Tone differentiation '
          'required if site has non-fire alerts (2025 change).',
      category: 'Alarm Devices',
    ),
    Bs5839ClauseReference(
      clause: '18',
      title: 'Detection in Common Areas',
      summary: 'Stairway lobbies now require automatic detection for L1 and '
          'L2 systems (new 2025 requirement). Previously only circulation '
          'areas specified.',
      category: 'Detection',
    ),
    Bs5839ClauseReference(
      clause: '20',
      title: 'Manual Call Points',
      summary: 'Mounting height 1.2m–1.6m (clarified in 2025). Maximum 45m '
          'to nearest MCP on escape route. 25% rotation testing per visit.',
      category: 'Manual Devices',
    ),
    Bs5839ClauseReference(
      clause: '22',
      title: 'Cyber Security',
      summary: 'New 2025 requirement. Remote access to fire alarm systems '
          'must require authentication. Tamper-resistant fittings on '
          'network connections. Labelling required.',
      category: 'Cyber Security',
    ),
    Bs5839ClauseReference(
      clause: '25',
      title: 'Power Supplies',
      summary: 'Mains supply + standby batteries. Battery capacity for '
          '24h standby + 30min alarm. Load test voltages must be recorded.',
      category: 'Power',
    ),
    Bs5839ClauseReference(
      clause: '25.4',
      title: 'Battery Testing',
      summary: 'Resting and loaded voltage readings required. Battery '
          'condition assessed under load. Record readings for audit trail.',
      category: 'Power',
    ),
    Bs5839ClauseReference(
      clause: '26.2',
      title: 'Earth Fault Monitoring',
      summary: 'Earth fault loop impedance reading in kΩ. System must '
          'signal an earth fault condition.',
      category: 'Wiring',
    ),
    Bs5839ClauseReference(
      clause: '33',
      title: 'Commissioning and Handover',
      summary: 'Full system test, cause-and-effect verification, logbook '
          'creation, zone plan provision, as-fitted documentation. '
          'Cause-and-effect matrix must be provided (2025 emphasis).',
      category: 'Commissioning',
    ),
    Bs5839ClauseReference(
      clause: '33.2',
      title: 'ARC Label at Panel',
      summary: 'Where system is connected to ARC, a label showing ARC '
          'details must be displayed adjacent to the control panel.',
      category: 'Commissioning',
    ),
    Bs5839ClauseReference(
      clause: '33.4',
      title: 'Cause-and-Effect Documentation',
      summary: 'Cause-and-effect matrix must be included in handover '
          'documentation. Required for commissioning visits in 2025 edition.',
      category: 'Commissioning',
    ),
    Bs5839ClauseReference(
      clause: '45',
      title: 'Routine Inspection and Servicing',
      summary: 'Six-monthly service visits with ±1 month tolerance (5–7 '
          'month window). Logbook review, visual inspection, functional '
          'testing of all devices.',
      category: 'Servicing',
    ),
    Bs5839ClauseReference(
      clause: '45.3',
      title: 'Service Tolerance Window',
      summary: 'Service intervals may vary by ±1 month around the nominal '
          '6-month cycle, giving a 5–7 month window (2025 change).',
      category: 'Servicing',
    ),
    Bs5839ClauseReference(
      clause: '47',
      title: 'ARC Signal Transmission',
      summary: 'Maximum transmission times specified for L and P category '
          'systems. All-IP transition by 2027. Signal types: fire, fault, '
          'pre-alarm.',
      category: 'ARC',
    ),
    Bs5839ClauseReference(
      clause: '48',
      title: 'Certificates',
      summary: 'Commissioning certificate, maintenance certificate, '
          'modification certificate. Must reference BS 5839-1:2025 '
          '(not 2017). Satisfactory / satisfactory with variations / '
          'unsatisfactory declaration.',
      category: 'Certificates',
    ),
    Bs5839ClauseReference(
      clause: '49',
      title: 'Logbook',
      summary: 'Record of all events: alarms, faults, tests, disablements, '
          'service visits, modifications. Must be reviewed at every '
          'service visit.',
      category: 'Documentation',
    ),
    Bs5839ClauseReference(
      clause: '14.8',
      title: 'Beam Detectors — Closely Spaced Beams',
      summary: 'Closely spaced beams defined as <1m centre-to-centre '
          '(2025 clarification). Affects obstruction rules.',
      category: 'Detection',
    ),
    Bs5839ClauseReference(
      clause: '14.10',
      title: 'Obstructions',
      summary: 'Items <250mm from ceiling and gaps >300mm between storage '
          'tops and ceiling clarified in 2025.',
      category: 'Detection',
    ),
  ];

  static List<Bs5839ClauseReference> search(String query) {
    final lower = query.toLowerCase();
    return clauses.where((c) {
      return c.clause.toLowerCase().contains(lower) ||
          c.title.toLowerCase().contains(lower) ||
          c.summary.toLowerCase().contains(lower) ||
          (c.category?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  static List<Bs5839Clause> searchVersioned(String query) {
    final lower = query.toLowerCase();
    return versioned.where((c) {
      return c.reference.toLowerCase().contains(lower) ||
          c.title.toLowerCase().contains(lower) ||
          c.body.toLowerCase().contains(lower) ||
          c.section.toLowerCase().contains(lower) ||
          c.keywords.any((k) => k.toLowerCase().contains(lower)) ||
          (c.renumberedFrom?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  static List<Bs5839ClauseReference> getByCategory(String category) {
    return clauses.where((c) => c.category == category).toList();
  }

  static List<Bs5839Clause> getBySection(String section) {
    return versioned.where((c) => c.section == section).toList();
  }

  static List<String> get categories {
    return clauses
        .map((c) => c.category)
        .whereType<String>()
        .toSet()
        .toList();
  }

  static List<String> get sections {
    final seen = <String>{};
    final result = <String>[];
    for (final c in versioned) {
      if (seen.add(c.section)) result.add(c.section);
    }
    return result;
  }
}
