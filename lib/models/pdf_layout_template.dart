/// Predefined header layout structures.
///
/// Each template defines which zones exist and how they are arranged.
/// The content of each zone is controlled by [ContentBlock] lists.
enum HeaderLayoutTemplate {
  logoLeftTextRight('Logo Left, Text Right'),
  logoRightTextLeft('Logo Right, Text Left'),
  centeredLogoAboveText('Centered Logo & Text'),
  textOnly('Text Only'),
  twoColumn('Two Column'),
  minimal('Minimal');

  final String displayName;
  const HeaderLayoutTemplate(this.displayName);

  /// Whether this template includes a logo zone.
  bool get hasLogo =>
      this == logoLeftTextRight ||
      this == logoRightTextLeft ||
      this == centeredLogoAboveText;

  /// Whether this template uses a centred layout.
  bool get isCentered => this == centeredLogoAboveText || this == minimal;

  /// Whether this template has separate left and right zones.
  bool get hasTwoColumns => this == twoColumn;

  static HeaderLayoutTemplate fromName(String name) =>
      HeaderLayoutTemplate.values.firstWhere(
        (e) => e.name == name,
        orElse: () => HeaderLayoutTemplate.logoLeftTextRight,
      );
}

/// Predefined footer layout structures.
enum FooterLayoutTemplate {
  leftTextRightPages('Text Left, Pages Right'),
  centeredTextPages('Centered Text & Pages'),
  threeColumn('Three Column'),
  minimal('Pages Only');

  final String displayName;
  const FooterLayoutTemplate(this.displayName);

  /// Whether this template has a centre zone.
  bool get hasCentre =>
      this == centeredTextPages || this == threeColumn;

  static FooterLayoutTemplate fromName(String name) =>
      FooterLayoutTemplate.values.firstWhere(
        (e) => e.name == name,
        orElse: () => FooterLayoutTemplate.leftTextRightPages,
      );
}
