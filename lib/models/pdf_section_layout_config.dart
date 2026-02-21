import 'dart:convert';

/// Identifies each section in the PDF body.
enum PdfSectionId { jobInfo, siteDetails, workDetails, notes, defects, compliance, signatures }

/// How Job Info and Site Details are arranged relative to each other.
enum SectionLayoutMode { sideBySide, stacked }

/// A single entry in the section order list.
class PdfSectionEntry {
  final PdfSectionId id;
  final bool visible;

  const PdfSectionEntry({required this.id, this.visible = true});

  Map<String, dynamic> toJson() => {
        'id': id.name,
        'visible': visible,
      };

  factory PdfSectionEntry.fromJson(Map<String, dynamic> json) =>
      PdfSectionEntry(
        id: PdfSectionId.values.firstWhere(
          (e) => e.name == json['id'],
          orElse: () => PdfSectionId.workDetails,
        ),
        visible: json['visible'] as bool? ?? true,
      );

  PdfSectionEntry copyWith({PdfSectionId? id, bool? visible}) =>
      PdfSectionEntry(
        id: id ?? this.id,
        visible: visible ?? this.visible,
      );
}

/// Full layout configuration for PDF body sections.
class PdfSectionLayoutConfig {
  final List<PdfSectionEntry> sections;
  final SectionLayoutMode jobSiteLayout;

  const PdfSectionLayoutConfig({
    required this.sections,
    this.jobSiteLayout = SectionLayoutMode.sideBySide,
  });

  /// Default layout matching the current hardcoded order.
  factory PdfSectionLayoutConfig.defaults() => const PdfSectionLayoutConfig(
        sections: [
          PdfSectionEntry(id: PdfSectionId.jobInfo),
          PdfSectionEntry(id: PdfSectionId.siteDetails),
          PdfSectionEntry(id: PdfSectionId.workDetails),
          PdfSectionEntry(id: PdfSectionId.notes),
          PdfSectionEntry(id: PdfSectionId.defects),
          PdfSectionEntry(id: PdfSectionId.compliance),
          PdfSectionEntry(id: PdfSectionId.signatures),
        ],
        jobSiteLayout: SectionLayoutMode.sideBySide,
      );

  Map<String, dynamic> toJson() => {
        'sections': sections.map((s) => s.toJson()).toList(),
        'jobSiteLayout': jobSiteLayout.name,
      };

  factory PdfSectionLayoutConfig.fromJson(Map<String, dynamic> json) {
    final parsed = (json['sections'] as List<dynamic>?)
            ?.map((e) => PdfSectionEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        PdfSectionLayoutConfig.defaults().sections.toList();

    // Forward-compatibility: append any missing section IDs
    final presentIds = parsed.map((e) => e.id).toSet();
    for (final id in PdfSectionId.values) {
      if (!presentIds.contains(id)) {
        parsed.add(PdfSectionEntry(id: id));
      }
    }

    return PdfSectionLayoutConfig(
      sections: parsed,
      jobSiteLayout: SectionLayoutMode.values.firstWhere(
        (e) => e.name == json['jobSiteLayout'],
        orElse: () => SectionLayoutMode.sideBySide,
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PdfSectionLayoutConfig.fromJsonString(String jsonString) =>
      PdfSectionLayoutConfig.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);

  PdfSectionLayoutConfig copyWith({
    List<PdfSectionEntry>? sections,
    SectionLayoutMode? jobSiteLayout,
  }) =>
      PdfSectionLayoutConfig(
        sections: sections ?? this.sections,
        jobSiteLayout: jobSiteLayout ?? this.jobSiteLayout,
      );
}
