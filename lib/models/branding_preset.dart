import 'pdf_branding.dart';

class BrandingPreset {
  final String id;
  final String name;
  final String description;
  final String primaryColour;
  final String accentColour;
  final CoverStyle suggestedCoverStyle;

  const BrandingPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColour,
    required this.accentColour,
    required this.suggestedCoverStyle,
  });

  static const List<BrandingPreset> all = [
    BrandingPreset(
      id: 'firething',
      name: 'FireThings',
      description: 'Our signature navy and amber.',
      primaryColour: '#1A1A2E',
      accentColour: '#FFB020',
      suggestedCoverStyle: CoverStyle.bold,
    ),
    BrandingPreset(
      id: 'graphite',
      name: 'Graphite',
      description: 'Classic, understated, professional.',
      primaryColour: '#18181B',
      accentColour: '#DC2626',
      suggestedCoverStyle: CoverStyle.bordered,
    ),
    BrandingPreset(
      id: 'forest',
      name: 'Forest',
      description: 'Deep green with copper highlights.',
      primaryColour: '#064E3B',
      accentColour: '#D97706',
      suggestedCoverStyle: CoverStyle.bold,
    ),
    BrandingPreset(
      id: 'slate',
      name: 'Slate',
      description: 'Cool and contemporary.',
      primaryColour: '#334155',
      accentColour: '#0EA5E9',
      suggestedCoverStyle: CoverStyle.minimal,
    ),
    BrandingPreset(
      id: 'heritage',
      name: 'Heritage',
      description: 'Traditional burgundy and gold.',
      primaryColour: '#7C1D12',
      accentColour: '#B45309',
      suggestedCoverStyle: CoverStyle.bordered,
    ),
  ];

  PdfBranding toBranding() => PdfBranding(
        primaryColour: primaryColour,
        accentColour: accentColour,
        coverStyle: suggestedCoverStyle,
        headerStyle: HeaderStyle.minimal,
        updatedAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );
}
