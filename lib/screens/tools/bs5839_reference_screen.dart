import 'package:flutter/material.dart';
import '../../widgets/premium_dialog.dart';
import '../../utils/icon_map.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/standard_info_box.dart';

class ReferenceItem {
  final String heading;
  final String content;

  const ReferenceItem({required this.heading, required this.content});
}

class ReferenceCard {
  final String title;
  final String category;
  final IconData icon;
  final String summary;
  final List<ReferenceItem> items;

  ReferenceCard({
    required this.title,
    required this.category,
    required this.icon,
    required this.summary,
    required this.items,
  });
}

class BS5839ReferenceScreen extends StatefulWidget {
  const BS5839ReferenceScreen({super.key});

  @override
  State<BS5839ReferenceScreen> createState() => _BS5839ReferenceScreenState();
}

class _BS5839ReferenceScreenState extends State<BS5839ReferenceScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  final _searchController = TextEditingController();

  static const List<String> _categories = [
    'System Categories',
    'Detectors',
    'Detector Siting',
    'Sounders',
    'Call Points',
    'Cables & Wiring',
    'Ancillary Equipment',
    'Void Detection',
    'Testing & Maintenance',
    'Fire Detection Zones',
    'False Alarm Management',
  ];

  static final List<ReferenceCard> _referenceCards = [
    // ── System Categories ──
    ReferenceCard(
      title: 'Category L1 — Full Life Protection',
      category: 'System Categories',
      icon: AppIcons.shield,
      summary:
          'Detection throughout all areas of the building for the earliest possible warning.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection installed throughout all areas of the building, including roof voids and ceiling voids.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Buildings where the highest level of life safety is required. Rarely specified in full due to cost; more common to use L2 with specific L1 additions.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category L2 — Enhanced Life Protection',
      category: 'System Categories',
      icon: AppIcons.shield,
      summary:
          'Detection in defined areas beyond escape routes — high-risk rooms (including sleeping rooms) and areas adjoining escape routes.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection in all areas covered by L3, plus areas of high fire risk and areas adjoining escape routes (e.g. rooms opening onto corridors or stairways). BS 5839-1:2025 now explicitly classifies sleeping rooms as high-risk areas under L2.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Common in residential care homes, HMOs (Houses in Multiple Occupation), and premises where sleeping risk exists but full L1 coverage is not practical.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category L3 — Escape Route Protection',
      category: 'System Categories',
      icon: AppIcons.shield,
      summary:
          'Detection on escape routes to give early warning before routes become impassable.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection installed in all escape routes — corridors, stairways, landings, and any area forming part of an escape route.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Office buildings, shops, factories, and premises where the primary goal is to protect the means of escape.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category L4 — Escape Route Enhancement',
      category: 'System Categories',
      icon: AppIcons.shield,
      summary:
          'Detection within circulation areas forming escape routes, plus detection at the top of lift shafts.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection in circulation areas (corridors, hallways) that form part of escape routes. BS 5839-1:2025 now also requires detection at the top of lift shafts. Minimum level for most commercial premises.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Small commercial premises, offices where fire risk assessment calls for detection in corridors only.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category L5 — Engineered Life Protection',
      category: 'System Categories',
      icon: AppIcons.shield,
      summary:
          'Detection in specific areas identified by fire risk assessment.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection only in areas identified by fire engineering / risk assessment. Bespoke design to satisfy a specific fire strategy.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Any premises where a fire engineer has designed a system to meet specific objectives — often supplements an existing system.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category M — Manual System',
      category: 'System Categories',
      icon: AppIcons.edit,
      summary:
          'Manual call points only — no automatic detection. Relies on occupants to raise the alarm.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'System comprising manual call points (break glass units) only, with no automatic fire detectors. Alarm is raised manually by building occupants.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Premises where occupants are alert, familiar with the building, and a fire would be quickly discovered — e.g. small shops, workshops, some offices.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category P1 — Full Property Protection',
      category: 'System Categories',
      icon: AppIcons.building,
      summary:
          'Detection throughout the building to provide the earliest warning for property protection.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection throughout all areas of the building, including roof voids and ceiling voids, to minimise the time between ignition and the fire being detected.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Heritage buildings, high-value storage, data centres, or where insurance requirements demand comprehensive detection for property protection.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Category P2 — Targeted Property Protection',
      category: 'System Categories',
      icon: AppIcons.building,
      summary:
          'Detection only in defined high-risk areas for property protection.',
      items: [
        ReferenceItem(
          heading: 'Definition',
          content:
              'Automatic fire detection installed only in defined areas of high fire risk, as determined by fire risk assessment, to protect property.',
        ),
        ReferenceItem(
          heading: 'Where it applies',
          content:
              'Warehouses (detection in high-risk electrical rooms), plant rooms, kitchens, or specific areas identified as requiring property protection.',
        ),
      ],
    ),

    // ── Detectors ──
    ReferenceCard(
      title: 'Point Smoke Detector Spacing',
      category: 'Detectors',
      icon: AppIcons.scanner,
      summary:
          'Maximum spacing and coverage for point-type optical and ionisation smoke detectors.',
      items: [
        ReferenceItem(
          heading: 'Flat ceiling ≤ 10.5m height',
          content:
              'Maximum coverage per detector: 100m² (using 7.5m radius).\nMaximum spacing between detectors: 10.6m (centre to centre).\nMaximum distance from any point to nearest detector: 7.5m.',
        ),
        ReferenceItem(
          heading: 'Ceiling height 10.5m–25m',
          content:
              'Smoke detectors are generally not suitable above 10.5m ceiling height. Use beam detectors or aspirating systems instead. If smoke detectors must be used between 10.5m and 12.5m, consult manufacturer guidance for reduced spacing.',
        ),
        ReferenceItem(
          heading: 'Corridor / narrow room (< 5m wide)',
          content:
              'Detectors may be spaced up to 15m apart along the corridor. Maximum distance from end wall to first detector: 7.5m.',
        ),
        ReferenceItem(
          heading: 'Pitched / sloped ceilings',
          content:
              'If slope > 1 in 12 (approx 5°), place detector(s) within 600mm of the apex. Horizontal spacing measured from the apex outward should follow flat-ceiling rules.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Point Heat Detector Spacing',
      category: 'Detectors',
      icon: AppIcons.flash,
      summary:
          'Maximum spacing and coverage for fixed-temperature and rate-of-rise heat detectors.',
      items: [
        ReferenceItem(
          heading: 'Flat ceiling ≤ 7.5m height',
          content:
              'Maximum coverage per detector: 50m² (using 5.3m radius).\nMaximum spacing between detectors: 7.5m.\nMaximum distance from any point to nearest detector: 5.3m.',
        ),
        ReferenceItem(
          heading: 'Ceiling height 7.5m–9.0m',
          content:
              'Heat detectors should not normally be used above 9.0m ceiling height. Between 7.5m and 9.0m, reduced spacing may be needed — consult manufacturer data.',
        ),
        ReferenceItem(
          heading: 'Corridor / narrow room (< 5m wide)',
          content:
              'Detectors may be spaced up to 10m apart. Maximum distance from end wall to first detector: 5m.',
        ),
        ReferenceItem(
          heading: 'High-risk areas (kitchens, plant rooms)',
          content:
              'Consider rate-of-rise detectors where ambient temperature is stable. Fixed-temperature detectors rated at least 30°C above maximum ambient. In kitchens, minimum 90°C rated heads are common.',
        ),
        ReferenceItem(
          heading: 'Sleeping rooms (L2/L3)',
          content:
              'BS 5839-1:2025 prohibits the use of heat detectors in rooms where people sleep under L2 or L3 systems. Smoke detectors or multi-sensor detectors must be used instead, as heat detectors respond too slowly to smouldering fires that may endanger sleeping occupants.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Beam Detector Spacing',
      category: 'Detectors',
      icon: AppIcons.ruler,
      summary:
          'Guidance for optical beam (line-type) smoke detectors in large or high-ceiling areas.',
      items: [
        ReferenceItem(
          heading: 'Ceiling height range',
          content:
              'Suitable for ceiling heights from approx 4m up to 25m (or 40m with special configurations). Ideal for warehouses, atriums, and large open areas.',
        ),
        ReferenceItem(
          heading: 'Mounting position',
          content:
              'Beam should be 500mm to 600mm below ceiling (or below the lowest expected smoke layer). In very high spaces, multiple tiers of beams may be needed.',
        ),
        ReferenceItem(
          heading: 'Spacing',
          content:
              'Maximum lateral spacing between parallel beams: typically 15m. Maximum distance from any wall parallel to beam: 7.5m. Beam length (transmitter to receiver/reflector): manufacturer-dependent, commonly 10m–100m.',
        ),
        ReferenceItem(
          heading: 'Considerations',
          content:
              'Avoid paths subject to steam, fumes, or strong air currents. Ensure stable mounting — structural movement can cause false alarms. Align and test beams at commissioning and after any building work.',
        ),
      ],
    ),

    // ── Detector Siting ──
    ReferenceCard(
      title: 'Detector Siting Restrictions',
      category: 'Detector Siting',
      icon: AppIcons.location,
      summary:
          'Minimum distances from walls, vents, lights, and heat sources when positioning detectors.',
      items: [
        ReferenceItem(
          heading: 'Distance from walls',
          content:
              'Detectors should be mounted at least 500mm from any wall or vertical surface. This avoids dead air pockets at the wall-ceiling junction where smoke may not reach the detector.',
        ),
        ReferenceItem(
          heading: 'Distance from air vents / HVAC diffusers',
          content:
              'Minimum 600mm from air conditioning outlets, HVAC diffusers, or ventilation grilles. Some specifications recommend 1m. Airflow can dilute or deflect smoke away from detectors.',
        ),
        ReferenceItem(
          heading: 'Distance from luminaires / lights',
          content:
              'Minimum 500mm from light fittings. Heat from luminaires can affect heat detectors, and some lighting can cause convection currents that disrupt smoke patterns.',
        ),
        ReferenceItem(
          heading: 'Heat sources and other exclusions',
          content:
              'Do not mount directly above radiators, cookers, boilers, or other heat sources.\nAvoid areas subject to condensation.\nAvoid dead air spaces within 150mm of the wall-ceiling junction in rooms with ceiling beams.\nPitched ceilings: detector(s) within 600mm of the apex if slope > 1:12.',
        ),
        ReferenceItem(
          heading: 'Shadow spots (BS 5839-1:2025)',
          content:
              'Account for structural obstructions near ceiling level (beams, ductwork, cable trays) that may block or deflect smoke travel to detectors. Where obstructions create shadow spots, additional detectors or repositioning may be needed to ensure full coverage.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Effect of Beams & Obstructions',
      category: 'Detector Siting',
      icon: AppIcons.ruler,
      summary:
          'How exposed beams, partitions, and racking affect detector spacing requirements.',
      items: [
        ReferenceItem(
          heading: 'Beams > 150mm deep',
          content:
              'Treat each bay between beams as a separate room for detector spacing purposes. Each bay requires its own detector(s) based on standard spacing rules.',
        ),
        ReferenceItem(
          heading: 'Beams > 10% of ceiling height',
          content:
              'Where beam depth exceeds 10% of the floor-to-ceiling height, detectors are required in each bay formed by the beams.',
        ),
        ReferenceItem(
          heading: 'Beams < 150mm deep',
          content:
              'Beams less than 150mm deep can generally be ignored for detector spacing calculations. Smoke will travel over these shallow obstructions.',
        ),
        ReferenceItem(
          heading: 'Closely-spaced beams (BS 5839-1:2025)',
          content:
              'Beams spaced less than 1m centre-to-centre are now defined as "closely spaced". Where closely-spaced beams are present, detectors should be mounted on the underside of the beams rather than between them.',
        ),
        ReferenceItem(
          heading: 'Partitions and racking',
          content:
              'Partitions or racking greater than 75% of ceiling height may impede smoke travel — additional detection may be needed.\nOpen-plan offices with partitions: consider the smoke travel path and whether partitions create enclosed pockets.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Detector Type Selection Guide',
      category: 'Detector Siting',
      icon: AppIcons.category,
      summary:
          'Quick reference for choosing the right detector type for each environment.',
      items: [
        ReferenceItem(
          heading: 'Optical smoke detectors',
          content:
              'Best for: clean offices, bedrooms, corridors, hotel rooms, communal areas.\nMost common general-purpose detector. Detects visible smoke particles from smouldering fires.',
        ),
        ReferenceItem(
          heading: 'Heat detectors',
          content:
              'Fixed temperature (typically 57°C or 90°C): kitchens (use 90°C min), areas with steam/vapour.\nRate-of-rise: boiler rooms, plant rooms — detects rapid temperature increase.\nGeneral: dusty/dirty environments where smoke detectors would false alarm.',
        ),
        ReferenceItem(
          heading: 'Beam and aspirating detectors',
          content:
              'Beam detectors: high ceilings >10.5m, warehouses, atriums.\nAspirating (e.g. VESDA): server rooms, clean rooms, heritage buildings, voids where sampling pipes are easier to route. Highest sensitivity available.',
        ),
        ReferenceItem(
          heading: 'Multi-sensor and specialist',
          content:
              'Multi-sensor (smoke + heat combined): best general-purpose choice for reducing false alarms. Analyses multiple inputs before triggering.\nCO + heat multi: car parks, areas with exhaust fumes.\nAlways check manufacturer guidance for specific environmental suitability.',
        ),
      ],
    ),

    // ── Sounders ──
    ReferenceCard(
      title: 'Minimum Sound Levels',
      category: 'Sounders',
      icon: AppIcons.volumeHigh,
      summary:
          'BS 5839-1 minimum dB requirements for fire alarm sounders in different risk areas.',
      items: [
        ReferenceItem(
          heading: 'General areas',
          content:
              'Minimum 65 dB(A) at any occupiable point, OR 5 dB(A) above any background noise likely to persist for more than 30 seconds, whichever is greater.',
        ),
        ReferenceItem(
          heading: 'Sleeping risk areas',
          content:
              'Minimum 75 dB(A) at the bed-head. This applies to hotels, residential care, HMOs, sleeping quarters, and any area where occupants may be asleep.',
        ),
        ReferenceItem(
          heading: 'Measurement point',
          content:
              'Measured at 1.3m above floor level in the area to be covered. In sleeping areas, measured at the pillow position with all doors closed between the sounder and the bed.',
        ),
        ReferenceItem(
          heading: 'Additional guidance',
          content:
              'Visual alarm devices (VADs/beacons) should be considered where ambient noise exceeds 90 dB(A) or for hearing-impaired occupants. Vibrating pads or pillow alerts may be needed in sleeping areas for deaf residents.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Sounder Coverage & Placement',
      category: 'Sounders',
      icon: AppIcons.sound,
      summary:
          'Guidelines for positioning and distributing sounders throughout the building.',
      items: [
        ReferenceItem(
          heading: 'Distribution principle',
          content:
              'Sounders should be distributed so that the required sound level is achieved at all occupiable points. Fewer, louder sounders are generally less effective than more, distributed sounders.',
        ),
        ReferenceItem(
          heading: 'Doors and partitions',
          content:
              'A closed fire door typically attenuates sound by 20–30 dB. Sounders should ideally be placed on both sides of fire doors, or a sounder should be within each fire compartment.',
        ),
        ReferenceItem(
          heading: 'Tone and frequency',
          content:
              'All sounders within a system should produce the same tone to avoid confusion. Low-frequency sounders (approx 500 Hz) are more effective at waking sleeping occupants and are now recommended for sleeping risk.',
        ),
        ReferenceItem(
          heading: 'Voice alarm systems',
          content:
              'Where voice alarm (VA) is used, speech intelligibility must be verified. Minimum speech transmission index (STI) of 0.5 is generally expected. VA messages should be clear, pre-recorded, and approved by the building operator.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Visual Alarm Devices (VADs)',
      category: 'Sounders',
      icon: AppIcons.flash,
      summary:
          'EN 54-23 visual alarm devices — when required, coverage categories, and installation guidance.',
      items: [
        ReferenceItem(
          heading: 'When VADs are required',
          content:
              'Where ambient noise exceeds 90 dB(A) and sounders alone cannot achieve required levels.\nWhere hearing-impaired occupants are present or expected.\nIn areas where audible warnings may not be perceived (ear protection zones, noisy machinery areas).',
        ),
        ReferenceItem(
          heading: 'Flash rate and colour',
          content:
              'Flash rate: between 0.5 Hz and 2 Hz (EN 54-23).\nColour: red or white. Red is more visible; white is more commonly installed.\nMust not cause discomfort or trigger photosensitive conditions at the specified flash rate.',
        ),
        ReferenceItem(
          heading: 'Coverage categories (EN 54-23)',
          content:
              'W — Wall-mounted: coverage expressed as a volume from the wall outward.\nC — Ceiling-mounted: coverage expressed as a volume below the ceiling.\nO — Open (free-standing): coverage in all directions.\nManufacturer specifies the coverage volume for each category and mounting height.',
        ),
        ReferenceItem(
          heading: 'Installation considerations',
          content:
              'Power consumption is higher than sounders — factor into PSU and battery calculations.\nMay require larger cable sizes on long runs.\nPosition so the flash is visible from all occupiable points in the coverage area.\nVADs should activate simultaneously with audible alarm devices.',
        ),
      ],
    ),

    // ── Call Points ──
    ReferenceCard(
      title: 'Call Point Positioning',
      category: 'Call Points',
      icon: AppIcons.danger,
      summary:
          'Height, travel distance, and location rules for manual call points (MCPs).',
      items: [
        ReferenceItem(
          heading: 'Mounting height',
          content:
              'Between 1.0m and 1.2m above finished floor level to the operating element (frangible element or push button). Typically 1.4m to centre of unit.',
        ),
        ReferenceItem(
          heading: 'Travel distance',
          content:
              'No person should need to travel more than 45m to reach a manual call point. In practice, place MCPs at every exit from each floor, at every exit to a stairway, and at final exits from the building.',
        ),
        ReferenceItem(
          heading: 'Mandatory locations',
          content:
              'At each storey exit point into a stairway.\nAt each final exit to outside.\nAdditional MCPs as needed to meet the 45m travel distance rule.\nAt the fire alarm panel (if not already at an exit).',
        ),
        ReferenceItem(
          heading: 'Accessibility',
          content:
              'MCPs must be accessible at all times and not obstructed by furniture, stored goods, or locked doors. Where call points are at risk of accidental damage or malicious operation, protective covers (lift-before-break type) may be used.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Call Point Types & Standards',
      category: 'Call Points',
      icon: AppIcons.category,
      summary:
          'Types of manual call points and applicable standards for fire alarm systems.',
      items: [
        ReferenceItem(
          heading: 'Type A — direct operation (break glass)',
          content:
              'Most common in the UK. Single-action operation: break the frangible element to activate. Conforms to BS EN 54-11 Type A. Resettable units use a replaceable plastic element or key-reset mechanism.',
        ),
        ReferenceItem(
          heading: 'Type B — indirect operation (lift cover)',
          content:
              'Two-action operation: lift a hinged cover, then press a button. Conforms to BS EN 54-11 Type B. Less common in UK fire alarm systems but may be specified in environments where accidental activation is a concern.',
        ),
        ReferenceItem(
          heading: 'Addressable vs conventional',
          content:
              'Addressable MCPs report their individual address to the panel, allowing exact location identification. Conventional MCPs trigger a zone circuit — the panel identifies the zone but not the individual device.',
        ),
        ReferenceItem(
          heading: 'Applicable standards',
          content:
              'BS EN 54-11 — Manual call points.\nBS 5839-1 — Design, installation, commissioning and maintenance of fire detection and fire alarm systems in buildings.\nCall points must carry the CE/UKCA mark and be third-party certified.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Call Point Testing & Maintenance',
      category: 'Call Points',
      icon: AppIcons.clipboardTick,
      summary:
          'Weekly, periodic, and annual testing procedures for manual call points.',
      items: [
        ReferenceItem(
          heading: 'Weekly test',
          content:
              'Operate one MCP each week on a rotational basis so that every call point is tested within a 13-week cycle (quarterly) as a minimum — ideally within 52 weeks. Use an approved test key where available to avoid breaking frangible elements.',
        ),
        ReferenceItem(
          heading: 'What to check',
          content:
              'Confirm the panel receives the correct zone/address signal.\nConfirm sounders operate.\nConfirm any ARC (Alarm Receiving Centre) transmission is received.\nCheck the call point is undamaged, clearly visible, and signage is present.',
        ),
        ReferenceItem(
          heading: 'Annual service (BS 5839-1 Cl. 45)',
          content:
              'Every MCP must be functionally tested during the annual service. Verify correct address/zone indication at the panel. Inspect for physical damage, paint contamination, or obstruction. Replace any damaged frangible elements.',
        ),
        ReferenceItem(
          heading: 'Record keeping',
          content:
              'Log the date, call point location/address, test result (pass/fail), and any remedial action taken. Records must be kept in the fire alarm log book on site and available for inspection by the fire authority.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Call Point Signage & Identification',
      category: 'Call Points',
      icon: AppIcons.infoCircle,
      summary:
          'Signage requirements, colour standards, and identification for manual call points.',
      items: [
        ReferenceItem(
          heading: 'Colour',
          content:
              'MCPs must be red (RAL 3000 or similar) to ensure immediate recognition. The operating element should contrast clearly with the body of the unit.',
        ),
        ReferenceItem(
          heading: 'Signage',
          content:
              'A "FIRE ALARM CALL POINT" or "Break Glass — Press Here" sign should be provided adjacent to or above each MCP where it is not immediately obvious. Signage should comply with BS 5499 / ISO 7010 where applicable.',
        ),
        ReferenceItem(
          heading: 'Location labelling',
          content:
              'Each call point should be labelled with its zone number or address to aid identification during testing and fault-finding. Labels should be durable and legible, typically on or immediately adjacent to the device.',
        ),
        ReferenceItem(
          heading: 'Protective covers',
          content:
              'Where vandalism or accidental operation is likely (schools, public buildings, psychiatric units), a hinged protective cover may be fitted. These covers typically trigger a local buzzer when lifted to deter misuse, but must not impede genuine operation.',
        ),
      ],
    ),

    // ── Cables & Wiring ──
    ReferenceCard(
      title: 'Cable Types & Fire Resistance',
      category: 'Cables & Wiring',
      icon: AppIcons.global,
      summary:
          'Standard, enhanced, and fire-resistant cable requirements for fire alarm wiring.',
      items: [
        ReferenceItem(
          heading: 'Standard cables',
          content:
              'For circuits where loss of the cable does not prevent the alarm from sounding (e.g. a loop with short-circuit isolators where alternative path exists). Minimum PVC/PVC to BS 7629 or equivalent.',
        ),
        ReferenceItem(
          heading: 'Fire-resistant cables',
          content:
              'Required for critical circuits — any circuit whose failure would prevent the alarm from operating. Must comply with BS 7629 (category of fire resistance) or BS 8434, and also BS EN 50575 for CPR (Construction Products Regulation) compliance per BS 5839-1:2025. Common types: MICC (mineral insulated), FP200, Firetuf, Firecel.',
        ),
        ReferenceItem(
          heading: 'Enhanced fire-resistant cables',
          content:
              'Required where the cable must survive fire AND water (e.g. sprinkler activation). Must meet BS 8434-2 Category 2 (fire with water). Typically MICC with LSF oversheath.',
        ),
        ReferenceItem(
          heading: 'Cable colour (BS 5839-1:2025)',
          content:
              'All fire alarm cables within a building should be a single common colour to aid identification. Red is the preferred colour for fire alarm cabling.',
        ),
        ReferenceItem(
          heading: 'When fire resistance is required',
          content:
              'All mains supply cables to fire alarm panels.\nCircuits to sounders/notification devices where no alternative path.\nSignal cables where loss would prevent fire detection.\nAny circuit critical to the operation of the fire alarm system.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Cable Segregation & Installation',
      category: 'Cables & Wiring',
      icon: AppIcons.flash,
      summary:
          'Segregation from other services, routing rules, and maximum resistance guidance.',
      items: [
        ReferenceItem(
          heading: 'Segregation from power cables',
          content:
              'Fire alarm cables must be segregated from mains power cables. Minimum 300mm separation in free air, or use separate compartments in trunking/tray. Segregation prevents electrical interference and mutual damage in fire.',
        ),
        ReferenceItem(
          heading: 'Segregation from other systems',
          content:
              'Fire alarm cables should be in dedicated containment separate from other low-voltage systems (CCTV, access control, data) unless the other cables are also fire-resistant.',
        ),
        ReferenceItem(
          heading: 'Routing',
          content:
              'Route cables to avoid areas of high fire risk where possible. Cables passing through fire compartment walls/floors must be fire-stopped. Avoid routing near heat sources, steam pipes, or areas subject to mechanical damage.',
        ),
        ReferenceItem(
          heading: 'Maximum loop resistance',
          content:
              'Varies by panel manufacturer. Typical maximum loop resistance: 40Ω–100Ω for addressable loops. Always check panel documentation. For 1.5mm² FP cable, approximate resistance is 25Ω per km per conductor.',
        ),
      ],
    ),

    // ── Ancillary Equipment ──
    ReferenceCard(
      title: 'Fire Door Holders & Releases',
      category: 'Ancillary Equipment',
      icon: AppIcons.lock,
      summary:
          'Electromagnetic door holders and release mechanisms connected to the fire alarm system.',
      items: [
        ReferenceItem(
          heading: 'Purpose and operation',
          content:
              'Electromagnetic door holders keep fire doors open for convenience and release them automatically on fire alarm activation. Doors close under their own closer force when the electromagnet de-energises (fail-safe).',
        ),
        ReferenceItem(
          heading: 'Connection to fire alarm',
          content:
              'Must be connected to the fire alarm system via a cause-and-effect matrix. Typically release on activation of detectors in the local zone or adjacent zones. BS 7273-4 specifies the actuation requirements.',
        ),
        ReferenceItem(
          heading: 'Rating and positioning',
          content:
              'Door holder must have a holding force that exceeds the door closer force.\nPosition as high as practical on the door or frame for maximum holding leverage.\nSwing-free holders allow doors to be moved but return them to the held-open position.',
        ),
        ReferenceItem(
          heading: 'Testing requirements',
          content:
              'Weekly: visual check that holders are energised and doors are held open.\nQuarterly: functional test — trigger alarm and confirm doors release and close fully.\nCheck door closer is adjusted correctly and door latches properly on release.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Interface Devices & Cause and Effect',
      category: 'Ancillary Equipment',
      icon: AppIcons.settingOutline,
      summary:
          'Interfaces between the fire alarm and other building systems — AOVs, dampers, lifts, HVAC.',
      items: [
        ReferenceItem(
          heading: 'AOVs (Automatic Opening Vents)',
          content:
              'Open on detector activation in the relevant zone to allow smoke venting.\nTypically roof-mounted or high-level window actuators.\nMust be tested as part of quarterly fire alarm inspection.',
        ),
        ReferenceItem(
          heading: 'Fire dampers and gas/oil shutoff',
          content:
              'Fire dampers: close to prevent smoke spread through ductwork.\nGas/oil shutoff valves: close on alarm to remove fuel sources.\nBoth must be documented in the cause-and-effect matrix.',
        ),
        ReferenceItem(
          heading: 'Lift recall and stairwell pressurisation',
          content:
              'Lifts: recall to ground floor, doors open, then disable for normal use. Fire-fighting lift remains operational.\nStairwell pressurisation: activate on alarm to keep escape stairs clear of smoke.\nHVAC: disable on alarm to prevent distributing smoke through the building.',
        ),
        ReferenceItem(
          heading: 'Cause-and-effect matrix',
          content:
              'Document which input device (detector/zone) triggers which output (sounder, door release, AOV, damper, lift recall, etc.).\nEssential for commissioning and ongoing maintenance.\nMust be kept up to date and available at the fire alarm panel.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Power Supply Requirements',
      category: 'Ancillary Equipment',
      icon: AppIcons.flash,
      summary:
          'Mains supply, battery standby, charging, and PSU requirements for fire alarm systems.',
      items: [
        ReferenceItem(
          heading: 'Primary (mains) supply',
          content:
              'Permanent mains connection — not via a switched socket or plug.\nDedicated circuit with fuse or MCB labelled "FIRE ALARM — DO NOT SWITCH OFF".\nCable from mains intake must be fire-resistant if it passes through a fire risk area.',
        ),
        ReferenceItem(
          heading: 'Secondary (battery) supply',
          content:
              'Sealed lead-acid batteries (maintenance-free).\nStandby duration: 24 hours normal operation + 30 minutes in full alarm.\nUnmonitored premises (no ARC): 72 hours standby + 30 minutes alarm.',
        ),
        ReferenceItem(
          heading: 'Charging and replacement',
          content:
              'Charger must bring batteries to 80% capacity within 24 hours of a full discharge.\nReplace batteries every 4 years as standard, or sooner if they fail a load test.\nBattery condition should be checked at every quarterly service.',
        ),
        ReferenceItem(
          heading: 'PSU sizing',
          content:
              'Total quiescent current (all devices in standby) × 24 hours + total alarm current × 0.5 hours.\nAdd margin for future expansion (typically 20–25%).\nFactor in higher-draw devices: VADs, door holders, sounder-beacons.',
        ),
      ],
    ),

    // ── Void Detection ──
    ReferenceCard(
      title: 'Void & Ceiling Space Detection',
      category: 'Void Detection',
      icon: AppIcons.grid,
      summary:
          'When detection is required in ceiling voids, floor voids, and other concealed spaces.',
      items: [
        ReferenceItem(
          heading: 'Voids > 800mm deep',
          content:
              'Generally require detection. Treat as a separate room/compartment for detector spacing. The void may accumulate smoke from cables, equipment, or fire spread from below.',
        ),
        ReferenceItem(
          heading: 'Voids 200mm–800mm deep',
          content:
              'Detection is needed if combustible material is present (e.g. timber joists, plastic pipes) or if cables are routed through the void. Risk assessment determines the requirement.',
        ),
        ReferenceItem(
          heading: 'Voids < 200mm deep',
          content:
              'Generally exempt from detection requirements. Insufficient depth for significant smoke accumulation.',
        ),
        ReferenceItem(
          heading: 'Void barriers and access',
          content:
              'Void barriers at compartment walls must maintain fire resistance — fire can spread unseen through voids.\nAccess panels are required for maintenance of void detectors.\nAspirating detection is often preferred in voids as sampling pipes are easier to route than point detectors.',
        ),
      ],
    ),

    // ── Testing & Maintenance ──
    ReferenceCard(
      title: 'Weekly Testing',
      category: 'Testing & Maintenance',
      icon: AppIcons.calendar,
      summary:
          'BS 5839-1 weekly test requirements — call point test and system check.',
      items: [
        ReferenceItem(
          heading: 'What to test',
          content:
              'Operate one manual call point each week (rotating so that every MCP is tested within a year). Confirm the fire alarm sounders/notification devices operate. Confirm the correct signal is received at any alarm receiving centre (ARC).',
        ),
        ReferenceItem(
          heading: 'Who can do it',
          content:
              'A designated responsible person (building manager, caretaker, etc.) can carry out weekly tests. Does not require a specialist fire alarm engineer.',
        ),
        ReferenceItem(
          heading: 'Recording',
          content:
              'Record the date, time, call point tested (location or address), whether alarm sounded correctly, and any faults. Maintain the log book on site and available for inspection.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Monthly Checks',
      category: 'Testing & Maintenance',
      icon: AppIcons.calendar,
      summary:
          'Monthly visual inspections and basic system checks.',
      items: [
        ReferenceItem(
          heading: 'Visual inspection',
          content:
              'Check the fire alarm panel for any outstanding faults or isolations. Verify all zone/point LEDs are in their normal state. Check that the panel battery charging indicator is healthy.',
        ),
        ReferenceItem(
          heading: 'Building walk-round',
          content:
              'Confirm no detectors have been removed, covered, or obstructed. Check that no call points are blocked or inaccessible. Verify sounders/beacons are present and undamaged. Note any building changes that may affect the system.',
        ),
        ReferenceItem(
          heading: 'Logbook check',
          content:
              'Review the log book for any missed weekly tests. Follow up on any faults reported since last check.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Quarterly (3-Monthly) Inspection',
      category: 'Testing & Maintenance',
      icon: AppIcons.settingOutline,
      summary:
          'Quarterly inspection and test by a competent person — typically a fire alarm engineer.',
      items: [
        ReferenceItem(
          heading: 'Detector testing',
          content:
              'Functionally test at least 25% of all detectors each quarter (so 100% are tested within a year). Use approved test equipment (e.g. solo test kit for smoke detectors). Confirm each tested detector triggers the panel correctly.',
        ),
        ReferenceItem(
          heading: 'System checks',
          content:
              'Test battery standby operation (simulate mains failure). Check cause-and-effect programming (e.g. detector triggers correct sounder zones). Test any ancillary functions (door holders, damper releases, ARC signalling).',
        ),
        ReferenceItem(
          heading: 'Documentation',
          content:
              'Record all devices tested and results. Note any faults found and remedial actions. Provide a service report to the responsible person. Update the system log book.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Annual Inspection & Service',
      category: 'Testing & Maintenance',
      icon: AppIcons.tickCircleBold,
      summary:
          'Full annual inspection — all devices tested, cables checked, system certification.',
      items: [
        ReferenceItem(
          heading: 'Full device test',
          content:
              'Every detector, call point, sounder, and ancillary device must be functionally tested. Confirm correct operation of each device and verify panel indication is accurate for every point.',
        ),
        ReferenceItem(
          heading: 'Cable and wiring checks',
          content:
              'Visual inspection of cable routes for damage. Check fire stopping where cables pass through walls/floors. Verify cable fixings are secure. Insulation resistance testing if problems are suspected.',
        ),
        ReferenceItem(
          heading: 'Battery and PSU',
          content:
              'Battery load test — confirm batteries can sustain the system for the required standby period (typically 24 hours standby + 30 minutes alarm). Replace batteries if over 4 years old or failing load test.',
        ),
        ReferenceItem(
          heading: 'As-installed verification',
          content:
              'Check system against as-installed drawings. Note any additions, removals, or changes since last inspection. Verify zone plans are current and displayed at the panel. Issue a certificate of inspection/service.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Logbook Requirements',
      category: 'Testing & Maintenance',
      icon: AppIcons.note,
      summary:
          'Fire alarm log book requirements — what to record, retention periods, and inspection obligations.',
      items: [
        ReferenceItem(
          heading: 'Requirement',
          content:
              'A fire alarm log book must be kept on the premises at all times. It should be stored near the fire alarm panel and be readily available for inspection by the fire authority, insurers, or the responsible person.',
        ),
        ReferenceItem(
          heading: 'What to record',
          content:
              'All fire alarm events: genuine alarms, false alarms, faults, pre-alarms.\nAll tests: weekly call point tests, quarterly detector tests, annual service.\nAll maintenance: repairs, device replacements, software changes.\nAll modifications: additions, removals, or changes to the system.\nFor weekly tests: date, time, device tested, result, name of tester.',
        ),
        ReferenceItem(
          heading: 'Retention period',
          content:
              'Retain records for a minimum of 3 years. Some fire risk assessments require 6 years.\nRecords should be available for audit by the fire authority at any time.\nBS 5839-1 Clause 44 specifies the minimum record-keeping requirements.',
        ),
        ReferenceItem(
          heading: 'Electronic log books',
          content:
              'Electronic records are acceptable provided they can be accessed on-site, are backed up, and can be printed if required for inspection. Must contain the same information as a paper log book.',
        ),
      ],
    ),

    // ── Fire Detection Zones ──
    ReferenceCard(
      title: 'Zone Size Limits',
      category: 'Fire Detection Zones',
      icon: AppIcons.grid,
      summary:
          'Maximum floor area and dimensions for fire detection zones.',
      items: [
        ReferenceItem(
          heading: 'Maximum zone area',
          content:
              'No zone should exceed 2,000m² in floor area. This ensures fire location can be identified quickly.',
        ),
        ReferenceItem(
          heading: 'Single floor rule',
          content:
              'A zone should not cover more than one floor of a building, except in stairwells or similar vertical features that may form a single zone across floors.',
        ),
        ReferenceItem(
          heading: 'Search distance',
          content:
              'A person searching for a fire should be able to identify the fire location from the zone indication without having to search more than an area visible from a single vantage point, or to walk more than 60m in a zone.',
        ),
        ReferenceItem(
          heading: 'Number of rooms',
          content:
              'Where rooms have doors opening onto corridors, a zone should ideally be limited to 10 rooms maximum if room doors are not individually indicated.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Zone Planning & Identification',
      category: 'Fire Detection Zones',
      icon: AppIcons.location,
      summary:
          'Zone plan requirements and how zones should be identified at the panel.',
      items: [
        ReferenceItem(
          heading: 'Zone plan at the panel',
          content:
              'A clear zone plan must be displayed adjacent to the fire alarm panel. The plan should show the building layout with zone boundaries clearly marked and zone numbers corresponding to the panel indications.',
        ),
        ReferenceItem(
          heading: 'Zone numbering',
          content:
              'Zones should be logically numbered (e.g. by floor and area). Numbering should be intuitive for the fire brigade and building occupants. Avoid gaps in numbering sequences.',
        ),
        ReferenceItem(
          heading: 'Zone identification at the panel',
          content:
              'The panel must clearly indicate which zone is in alarm or fault. For addressable systems, individual device identification is preferred in addition to zone indication. Zone text descriptions should be meaningful (e.g. "Ground Floor — East Wing" not just "Zone 3").',
        ),
        ReferenceItem(
          heading: 'Addressable vs conventional',
          content:
              'Addressable systems identify individual device locations, reducing search time. Conventional systems rely on zone indication only — zone sizing is more critical for rapid fire location in conventional systems.',
        ),
      ],
    ),

    // ── False Alarm Management ──
    ReferenceCard(
      title: 'False Alarm Investigation',
      category: 'False Alarm Management',
      icon: AppIcons.search,
      summary:
          'BS 5839-1 guidance on investigating and recording false alarms.',
      items: [
        ReferenceItem(
          heading: 'Investigation procedure',
          content:
              'Every false alarm should be investigated to determine the cause. Record: date/time, device that activated, zone, weather conditions, building activity at the time, and likely cause. The responsible person should review false alarm trends regularly.',
        ),
        ReferenceItem(
          heading: 'Acceptable false alarm rate',
          content:
              'BS 5839-1 considers more than 1 false alarm per 50 devices per year to be unacceptable. A well-maintained system should achieve significantly fewer. Fire & Rescue Services may charge for repeated false alarm call-outs.',
        ),
        ReferenceItem(
          heading: 'Immediate actions',
          content:
              'Identify and address the triggering device. Do NOT simply isolate the device permanently — this reduces protection. If a detector is repeatedly causing false alarms, investigate root cause: contamination, wrong type for environment, positioning, environmental changes.',
        ),
        ReferenceItem(
          heading: 'Reporting to ARC / Fire Service',
          content:
              'Notify the ARC of false alarms promptly. Some ARCs and Fire Services operate call-challenge or delayed-response policies after repeated false alarms. Excessive false alarms may result in the Fire Service downgrading their response.',
        ),
      ],
    ),
    ReferenceCard(
      title: 'Common False Alarm Causes',
      category: 'False Alarm Management',
      icon: AppIcons.warning,
      summary:
          'Frequent causes of unwanted fire alarms and how to address them.',
      items: [
        ReferenceItem(
          heading: 'Cooking and steam',
          content:
              'Detectors too close to kitchens, kettles, or bathrooms. Solution: relocate detector, change to heat detector, or use combined multi-sensor detector with reduced smoke sensitivity.',
        ),
        ReferenceItem(
          heading: 'Dust and contamination',
          content:
              'Construction work, cleaning, or poor maintenance causing dust ingress into optical detectors. Solution: clean or replace detectors, temporarily cover during planned building work (with formal impairment procedure).',
        ),
        ReferenceItem(
          heading: 'Insects',
          content:
              'Small insects entering detector chamber and scattering light (optical detectors). Solution: insect mesh screens, regular cleaning, consider environmental changes.',
        ),
        ReferenceItem(
          heading: 'Aerosols and vapour',
          content:
              'Spray deodorants, air fresheners, e-cigarettes near detectors. Solution: relocate detector away from likely spray use, use signage, consider heat detector in affected location.',
        ),
        ReferenceItem(
          heading: 'Environmental changes',
          content:
              'Building use changes (new kitchen, partition changes affecting airflow, new HVAC). Solution: review detector type and positioning whenever building modifications occur. The fire alarm system should be reviewed as part of any refurbishment project.',
        ),
      ],
    ),
  ];

  List<ReferenceCard> get _filteredCards {
    return _referenceCards.where((card) {
      if (_selectedCategory != null && card.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (card.title.toLowerCase().contains(q)) return true;
      if (card.summary.toLowerCase().contains(q)) return true;
      for (final item in card.items) {
        if (item.heading.toLowerCase().contains(q)) return true;
        if (item.content.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCards;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'BS 5839 Reference',
        actions: [
          IconButton(
            icon: Icon(AppIcons.infoCircle),
            onPressed: _showInfoDialog,
            tooltip: 'Information',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search references...',
                prefixIcon: Icon(AppIcons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(AppIcons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = selected ? null : cat;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Reference cards list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.searchOff,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No matching references found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildReferenceCard(filtered[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceCard(ReferenceCard card) {
    final color = _categoryColor(card.category);

    return Card(
      key: ValueKey(card.title),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(card.icon, color: color),
        title: Text(
          card.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            card.summary,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: card.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.heading,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    item.content,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'System Categories':
        return Colors.indigo;
      case 'Detectors':
        return Colors.blue;
      case 'Detector Siting':
        return Colors.blue.shade700;
      case 'Sounders':
        return Colors.purple;
      case 'Call Points':
        return Colors.red;
      case 'Cables & Wiring':
        return Colors.orange;
      case 'Ancillary Equipment':
        return Colors.brown;
      case 'Void Detection':
        return Colors.blueGrey;
      case 'Testing & Maintenance':
        return Colors.green;
      case 'Fire Detection Zones':
        return Colors.teal;
      case 'False Alarm Management':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  void _showInfoDialog() {
    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('BS 5839-1 Quick Reference'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const StandardInfoBox(toolKey: 'bs5839_reference'),
              const Text(
                'Quick reference cards for BS 5839-1 fire detection and alarm system requirements.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('How to Use:'),
              const SizedBox(height: 8),
              const Text('1. Search by keyword or browse by category'),
              const Text('2. Tap a category chip to filter cards'),
              const Text('3. Tap a card to expand and see full details'),
              const SizedBox(height: 12),
              const Text('Categories:'),
              const SizedBox(height: 8),
              const Text('\u2022 System Categories (L1\u2013L5, M, P1, P2)'),
              const Text('\u2022 Detectors (spacing & coverage)'),
              const Text('\u2022 Detector Siting (restrictions & type selection)'),
              const Text('\u2022 Sounders (dB levels, placement & VADs)'),
              const Text('\u2022 Call Points (positioning rules)'),
              const Text('\u2022 Cables & Wiring (types & segregation)'),
              const Text('\u2022 Ancillary Equipment (door holders, interfaces, PSU)'),
              const Text('\u2022 Void Detection (ceiling & floor voids)'),
              const Text('\u2022 Testing & Maintenance (intervals & logbook)'),
              const Text('\u2022 Fire Detection Zones (size limits)'),
              const Text('\u2022 False Alarm Management'),
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
