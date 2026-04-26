import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/company_site.dart';
import '../../models/permission.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/remote_config_service.dart';
import '../../theme/web_theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/premium_toast.dart';
import 'dashboard/site_helpers.dart';

class WebSiteDetailPanel extends StatefulWidget {
  final String siteId;
  final VoidCallback onClose;
  final bool animateIn;

  const WebSiteDetailPanel({
    super.key,
    required this.siteId,
    required this.onClose,
    this.animateIn = true,
  });

  @override
  State<WebSiteDetailPanel> createState() => _WebSiteDetailPanelState();
}

class _WebSiteDetailPanelState extends State<WebSiteDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  String? get _companyId => UserProfileService.instance.companyId;
  bool get _canEdit => UserProfileService.instance.hasPermission(AppPermission.sitesEdit);
  bool get _canDelete => UserProfileService.instance.hasPermission(AppPermission.sitesDelete);
  bool get _bs5839Enabled => RemoteConfigService.instance.bs5839ModeEnabled;
  bool get _assetsEnabled => RemoteConfigService.instance.assetRegisterEnabled;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: FtMotion.slow,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: FtMotion.standardCurve,
    ));
    if (widget.animateIn) {
      _slideController.forward();
    } else {
      _slideController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _closePanel() async {
    _slideController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = _companyId;
    if (companyId == null) {
      return const Center(child: Text('No company found'));
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: FtColors.bg,
          boxShadow: FtShadows.lg,
          border: Border(left: BorderSide(color: FtColors.border, width: 1.5)),
        ),
        child: StreamBuilder<List<CompanySite>>(
          stream: CompanyService.instance.getSitesStream(companyId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AdaptiveLoadingIndicator());
            }

            final sites = snapshot.data ?? [];
            final site = sites.cast<CompanySite?>().firstWhere(
              (s) => s!.id == widget.siteId,
              orElse: () => null,
            );

            if (site == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.warning, size: 32, color: FtColors.hint),
                    const SizedBox(height: 8),
                    Text('Site not found', style: FtText.bodySoft),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _closePanel,
                      style: TextButton.styleFrom(foregroundColor: FtColors.fg2),
                      child: Text('Close', style: FtText.button),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildPanelHeader(site),
                Expanded(
                  child: ListView(
                    padding: FtSpacing.cardBody,
                    children: [
                      _buildSection('Site Details', [
                        _detailRow('Name', site.name),
                        _detailRow('Address', site.address),
                        if (site.notes != null && site.notes!.isNotEmpty)
                          _detailRow('Notes', site.notes!),
                        if (site.latitude != null && site.longitude != null)
                          _detailRow('Coordinates', '${site.latitude!.toStringAsFixed(6)}, ${site.longitude!.toStringAsFixed(6)}'),
                        if (site.nextServiceDueDate != null)
                          _detailRow('Next Service', DateFormat('dd MMM yyyy').format(site.nextServiceDueDate!)),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Activity', [
                        _detailRow('Created', DateFormat('dd MMM yyyy, HH:mm').format(site.createdAt)),
                        if (site.updatedAt != null)
                          _detailRow('Updated', DateFormat('dd MMM yyyy, HH:mm').format(site.updatedAt!)),
                      ]),
                      if (_assetsEnabled || (_bs5839Enabled && site.isBs5839Site)) ...[
                        const SizedBox(height: 16),
                        _buildQuickActions(site),
                      ],
                      const SizedBox(height: 24),
                      _buildActionButtons(site),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanelHeader(CompanySite site) {
    return Container(
      padding: FtSpacing.cardHeader,
      decoration: const BoxDecoration(
        color: FtColors.bgAlt,
        border: Border(
          bottom: BorderSide(color: FtColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FtColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(AppIcons.building, size: 16, color: FtColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(site.name, style: FtText.cardTitle),
                Text(site.address, style: FtText.helper, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (site.isBs5839Site) ...[
            bs5839Badge(true),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: _closePanel,
            icon: Icon(AppIcons.close, color: FtColors.fg2),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(CompanySite site) {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: FtColors.fg1,
      side: const BorderSide(color: FtColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      textStyle: FtText.button,
      minimumSize: const Size(double.infinity, 42),
    );

    return _buildSection('Quick Actions', [
      if (_assetsEnabled)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              _closePanel();
              context.go('/sites/${site.id}/assets');
            },
            icon: Icon(AppIcons.box, size: 16),
            label: const Text('View Assets'),
            style: btnStyle,
          ),
        ),
      if (_bs5839Enabled && site.isBs5839Site) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              _closePanel();
              context.go('/sites/${site.id}/assets/bs5839-config',
                  extra: {'siteName': site.name, 'siteAddress': site.address});
            },
            icon: Icon(AppIcons.setting, size: 16),
            label: const Text('System Configuration'),
            style: btnStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              _closePanel();
              context.go('/sites/${site.id}/assets/bs5839-visits',
                  extra: {'siteName': site.name, 'siteAddress': site.address});
            },
            icon: Icon(AppIcons.clipboard, size: 16),
            label: const Text('Inspection Visits'),
            style: btnStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              _closePanel();
              context.go('/sites/${site.id}/assets/bs5839-variations',
                  extra: {'siteName': site.name, 'siteAddress': site.address});
            },
            icon: Icon(AppIcons.warning, size: 16),
            label: const Text('Variations Register'),
            style: btnStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              _closePanel();
              context.go('/sites/${site.id}/assets/bs5839-logbook',
                  extra: {'siteName': site.name, 'siteAddress': site.address});
            },
            icon: Icon(AppIcons.book, size: 16),
            label: const Text('Logbook'),
            style: btnStyle,
          ),
        ),
      ],
    ]);
  }

  Widget _buildActionButtons(CompanySite site) {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: FtColors.fg1,
      side: const BorderSide(color: FtColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
      textStyle: FtText.button,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_canEdit)
          OutlinedButton.icon(
            onPressed: () => _editSite(site),
            icon: Icon(AppIcons.edit, size: 16),
            label: const Text('Edit'),
            style: btnStyle,
          ),
        if (_canDelete)
          OutlinedButton.icon(
            onPressed: () => _deleteSite(site),
            icon: Icon(AppIcons.trash, size: 16),
            label: const Text('Delete'),
            style: btnStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(FtColors.danger),
              side: WidgetStatePropertyAll(BorderSide(color: FtColors.danger.withValues(alpha: 0.3), width: 1.5)),
            ),
          ),
      ],
    );
  }

  Future<void> _editSite(CompanySite site) async {
    final nameController = TextEditingController(text: site.name);
    final addressController = TextEditingController(text: site.address);
    final notesController = TextEditingController(text: site.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Site'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Site Name',
                  prefixIcon: Icon(AppIcons.building),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: addressController,
                  label: 'Address',
                  prefixIcon: Icon(AppIcons.location),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: notesController,
                  label: 'Notes (optional)',
                  prefixIcon: Icon(AppIcons.note),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FtColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameController.text.trim();
    final address = addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      if (mounted) context.showErrorToast('Name and address are required');
      return;
    }

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final notes = notesController.text.trim();
      final updated = site.copyWith(
        name: name,
        address: address,
        notes: notes.isEmpty ? null : notes,
        updatedAt: DateTime.now(),
      );
      await CompanyService.instance.updateSite(
        companyId, updated,
        previousAddress: site.address,
      );
      if (mounted) context.showSuccessToast('Site updated');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to update site');
    }
  }

  Future<void> _deleteSite(CompanySite site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Site?'),
        content: Text('This will permanently delete "${site.name}". This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: FtColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      await CompanyService.instance.deleteSite(companyId, site.id);
      if (mounted) context.showSuccessToast('Site deleted');
      _closePanel();
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to delete site');
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: FtSpacing.cardBody,
      decoration: FtDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: FtText.label),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: FtText.helper),
          ),
          Expanded(
            child: Text(value, style: FtText.inter(size: 13, weight: FontWeight.w500, color: FtColors.fg1)),
          ),
        ],
      ),
    );
  }
}
