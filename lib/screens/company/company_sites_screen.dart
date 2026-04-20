import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/company_site.dart';
import '../../services/company_service.dart';
import '../../models/permission.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../mixins/multi_select_mixin.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/card_action_button.dart';
import '../../widgets/selection_app_bar.dart';
import '../../widgets/selectable_avatar.dart';
import '../../services/remote_config_service.dart';
import '../assets/site_asset_register_screen.dart';

class CompanySitesScreen extends StatefulWidget {
  final String companyId;

  const CompanySitesScreen({super.key, required this.companyId});

  @override
  State<CompanySitesScreen> createState() => _CompanySitesScreenState();
}

class _CompanySitesScreenState extends State<CompanySitesScreen>
    with MultiSelectMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<CompanySite> _currentFiltered = [];

  bool get _canCreate => UserProfileService.instance.hasPermission(AppPermission.sitesCreate);
  bool get _canEdit => UserProfileService.instance.hasPermission(AppPermission.sitesEdit);
  bool get _canDelete => UserProfileService.instance.hasPermission(AppPermission.sitesDelete);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exitSelectionMode();
      },
      child: Scaffold(
        appBar: isSelectionMode
            ? SelectionAppBar(
                selectedCount: selectedCount,
                isAllSelected: _currentFiltered.isNotEmpty &&
                    selectedCount == _currentFiltered.length,
                onClose: exitSelectionMode,
                onSelectAll: (selectAll) {
                  if (selectAll) {
                    this.selectAll(
                        _currentFiltered.map((s) => s.id).toList());
                  } else {
                    deselectAll();
                  }
                },
                onDelete: _bulkDelete,
              )
            : AppBar(
                title: const Text('Shared Sites'),
                actions: [
                  if (_canDelete)
                    TextButton(
                      onPressed: _currentFiltered.isEmpty
                          ? null
                          : enterSelectionMode,
                      child: const Text('Select'),
                    ),
                ],
              ),
        floatingActionButton: isSelectionMode
            ? null
            : _canCreate && MediaQuery.of(context).viewInsets.bottom == 0
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
                              if (isSelectionMode) exitSelectionMode();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    if (isSelectionMode) exitSelectionMode();
                    setState(() => _searchQuery = val);
                  },
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

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _currentFiltered.length != filtered.length) {
                        setState(() => _currentFiltered = filtered);
                      } else {
                        _currentFiltered = filtered;
                      }
                    });

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
                                      : _canCreate
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
      ),
    );
  }

  Widget _buildSiteCard(CompanySite site) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = isSelected(site.id);

    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      curve: AppTheme.defaultCurve,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected
            ? (isDark
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : AppTheme.primaryBlue.withValues(alpha: 0.06))
            : null,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: isSelectionMode
              ? () => toggleSelection(site.id)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SelectableAvatar(
                  isSelectionMode: isSelectionMode,
                  isSelected: selected,
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    child: Icon(AppIcons.building, color: AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
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
                    ],
                  ),
                ),
                if (!isSelectionMode) ...[
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (RemoteConfigService.instance.assetRegisterEnabled) ...[
                          CardActionButton(
                            label: 'Assets',
                            onPressed: () => _viewAssets(site),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (_canEdit)
                          CardActionButton(
                            label: 'Edit',
                            onPressed: () => _showSiteDialog(site: site),
                          ),
                        if (_canEdit && _canDelete)
                          const SizedBox(height: 6),
                        if (_canDelete)
                          CardActionButton(
                            label: 'Delete',
                            onPressed: () => _confirmDelete(site),
                            isDestructive: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        await CompanyService.instance.updateSite(
          widget.companyId, updated,
          previousAddress: site.address,
        );
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

  Future<void> _bulkDelete() async {
    final count = selectedCount;
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete $count Site${count == 1 ? '' : 's'}',
      message:
          'Are you sure you want to delete $count selected ${count == 1 ? 'item' : 'items'}? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await CompanyService.instance.deleteSites(
          widget.companyId,
          selectedIds.toList(),
        );
        if (mounted) {
          exitSelectionMode();
          context.showSuccessToast(
              '$count site${count == 1 ? '' : 's'} deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error deleting sites: $e');
        }
      }
    }
  }
}
