import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/company_site.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../services/remote_config_service.dart';
import '../assets/site_asset_register_screen.dart';

class CompanySitesScreen extends StatefulWidget {
  final String companyId;

  const CompanySitesScreen({super.key, required this.companyId});

  @override
  State<CompanySitesScreen> createState() => _CompanySitesScreenState();
}

class _CompanySitesScreenState extends State<CompanySitesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _canEdit => UserProfileService.instance.isDispatcherOrAdmin;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared Sites')),
      floatingActionButton: _canEdit && MediaQuery.of(context).viewInsets.bottom == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showSiteDialog(),
              icon: Icon(AppIcons.add),
              label: const Text('Add Site'),
            )
          : null,
      body: KeyboardDismissWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search sites...',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(AppIcons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CompanySite>>(
                stream: CompanyService.instance.getSitesStream(
                  widget.companyId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator();
                  }

                  final sites = snapshot.data ?? [];
                  final filtered = _searchQuery.isEmpty
                      ? sites
                      : sites.where((s) {
                          final q = _searchQuery.toLowerCase();
                          return s.name.toLowerCase().contains(q) ||
                              s.address.toLowerCase().contains(q);
                        }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} site${filtered.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? EmptyState(
                                icon: _searchQuery.isNotEmpty
                                    ? AppIcons.searchOff
                                    : AppIcons.building,
                                title: _searchQuery.isNotEmpty
                                    ? 'No Results Found'
                                    : 'No Shared Sites',
                                message: _searchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : _canEdit
                                        ? 'Tap + to add a site'
                                        : 'No sites have been added yet',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final site = filtered[index];
                                  return _buildSiteCard(site).animateListItem(index);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard(CompanySite site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          child: Icon(AppIcons.building, color: AppTheme.primaryBlue),
        ),
        title: Text(
          site.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              site.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (site.notes != null && site.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                site.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (RemoteConfigService.instance.assetRegisterEnabled)
                  _ActionButton(
                    label: 'View Assets',
                    onPressed: () => _viewAssets(site),
                  ),
                if (_canEdit)
                  _ActionButton(
                    label: 'Edit',
                    onPressed: () => _showSiteDialog(site: site),
                  ),
                if (_canEdit)
                  _ActionButton(
                    label: 'Delete',
                    onPressed: () => _confirmDelete(site),
                    isDestructive: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewAssets(CompanySite site) {
    if (kIsWeb) {
      context.go('/sites/${site.id}/assets');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SiteAssetRegisterScreen(
            siteId: site.id,
            siteName: site.name,
            siteAddress: site.address,
            basePath: 'companies/${widget.companyId}',
          ),
        ),
      );
    }
  }

  Future<void> _showSiteDialog({CompanySite? site}) async {
    final nameController = TextEditingController(text: site?.name ?? '');
    final addressController = TextEditingController(text: site?.address ?? '');
    final notesController = TextEditingController(text: site?.notes ?? '');
    final isEdit = site != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Site' : 'Add Site'),
        content: SizedBox(
          width: 500,
          child: KeyboardDismissWrapper(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isEdit ? 'Save' : 'Add'),
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

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final notes = notesController.text.trim();

      if (isEdit) {
        final updated = site.copyWith(
          name: name,
          address: address,
          notes: notes.isEmpty ? null : notes,
          updatedAt: now,
        );
        await CompanyService.instance.updateSite(widget.companyId, updated);
        if (mounted) context.showSuccessToast('Site updated');
      } else {
        final newSite = CompanySite(
          id: const Uuid().v4(),
          name: name,
          address: address,
          notes: notes.isEmpty ? null : notes,
          createdBy: uid,
          createdAt: now,
        );
        await CompanyService.instance.createSite(widget.companyId, newSite);
        if (mounted) context.showSuccessToast('Site added');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save site');
    }
  }

  Future<void> _confirmDelete(CompanySite site) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Site',
      message:
          'Are you sure you want to delete "${site.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await CompanyService.instance.deleteSite(widget.companyId, site.id);
      if (mounted) context.showWarningToast('Site deleted');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to delete site');
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : AppTheme.primaryBlue;
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }
}
