import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/company_site.dart';
import '../../services/company_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Sites')),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () => _showSiteDialog(),
              child: Icon(AppIcons.add),
            )
          : null,
      body: KeyboardDismissWrapper(
        child: Column(
          children: [
            // Search bar
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

            // Stream content
            Expanded(
              child: StreamBuilder<List<CompanySite>>(
                stream: CompanyService.instance.getSitesStream(
                  widget.companyId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: AdaptiveLoadingIndicator());
                  }

                  final sites = snapshot.data ?? [];
                  final filtered = _searchQuery.isEmpty
                      ? sites
                      : sites.where((s) {
                          final q = _searchQuery.toLowerCase();
                          return s.name.toLowerCase().contains(q) ||
                              s.address.toLowerCase().contains(q);
                        }).toList();

                  // Count label + list
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
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _searchQuery.isNotEmpty
                                          ? AppIcons.searchOff
                                          : AppIcons.building,
                                      size: 64,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.mediumGrey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No Results Found'
                                          : 'No shared sites yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.mediumGrey,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try a different search term',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textHint,
                                        ),
                                      ),
                                    ] else if (_canEdit) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap + to add a site',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textHint,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(
                                  AppTheme.screenPadding,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final site = filtered[index];
                                  return _buildSiteCard(site, isDark);
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
    );
  }

  Widget _buildSiteCard(CompanySite site, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.building,
            size: 20,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.mediumGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  site.address,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.mediumGrey,
                  ),
                ),
                if (site.notes != null && site.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    site.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_canEdit)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showSiteDialog(site: site);
                } else if (value == 'delete') {
                  _confirmDelete(site);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(AppIcons.edit, size: 18),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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
        content: KeyboardDismissWrapper(
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
