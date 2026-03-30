import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../widgets/widgets.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../utils/adaptive_widgets.dart';
import '../../services/remote_config_service.dart';
import '../assets/site_asset_register_screen.dart';

class SavedSitesScreen extends StatefulWidget {
  const SavedSitesScreen({super.key});

  @override
  State<SavedSitesScreen> createState() => _SavedSitesScreenState();
}

class _SavedSitesScreenState extends State<SavedSitesScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<SavedSite> _allSites = [];
  List<SavedSite> _filteredSites = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSavedSites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSites() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final sites = await _dbHelper.getSavedSitesByEngineerId(user.uid);

      setState(() {
        _allSites = sites;
        _filteredSites = sites;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading sites: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterSites(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSites = _allSites;
      } else {
        _filteredSites = _allSites.where((site) {
          return site.siteName.toLowerCase().contains(query.toLowerCase()) ||
              site.address.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _showSiteDialog({SavedSite? site}) async {
    final nameController = TextEditingController(text: site?.siteName ?? '');
    final addressController = TextEditingController(text: site?.address ?? '');
    final notesController = TextEditingController(text: site?.notes ?? '');
    final isEdit = site != null;

    final result = await showPremiumDialog<bool>(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Site' : 'Add Site'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Site Name *',
                hint: 'e.g., Tesco Superstore',
                prefixIcon: const Icon(AppIcons.building),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: addressController,
                label: 'Address *',
                hint: 'Full address',
                maxLines: 3,
                prefixIcon: const Icon(AppIcons.location),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: notesController,
                label: 'Notes',
                hint: 'Access codes, contact info, etc.',
                maxLines: 2,
                prefixIcon: const Icon(AppIcons.note),
              ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  addressController.text.trim().isEmpty) {
                showValidationBanner(context: context, message: 'Site name and address are required');
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      )),
    );

    if (result == true) {
      final user = _authService.currentUser;
      if (user == null) return;

      try {
        if (isEdit) {
          final updated = site.copyWith(
            siteName: nameController.text.trim(),
            address: addressController.text.trim(),
            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          );
          await _dbHelper.updateSavedSite(updated);
          if (!mounted) return;
          context.showSuccessToast('Site updated');
        } else {
          final newSite = SavedSite(
            id: const Uuid().v4(),
            engineerId: user.uid,
            siteName: nameController.text.trim(),
            address: addressController.text.trim(),
            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
            createdAt: DateTime.now(),
          );
          await _dbHelper.insertSavedSite(newSite);
          AnalyticsService.instance.logSiteSaved();
          if (!mounted) return;
          context.showSuccessToast('Site saved successfully');
        }
        _loadSavedSites();
      } catch (e) {
        if (!mounted) return;
        context.showErrorToast('Error saving site: $e');
      }
    }
  }

  Future<void> _deleteSite(SavedSite site) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Site',
      message: 'Are you sure you want to delete "${site.siteName}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteSavedSite(site.id);

        if (!mounted) return;
        context.showWarningToast('Site deleted');

        _loadSavedSites();
      } catch (e) {
        if (!mounted) return;
        context.showErrorToast('Error deleting site: $e');
      }
    }
  }

  void _viewAssets(SavedSite site) {
    final user = _authService.currentUser;
    if (user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteAssetRegisterScreen(
          siteId: site.id,
          siteName: site.siteName,
          siteAddress: site.address,
          basePath: 'users/${user.uid}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Saved Sites'),
      body: KeyboardDismissWrapper(child: Column(
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
                          _filterSites('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterSites,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredSites.length} site${_filteredSites.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _filteredSites.isEmpty
                ? EmptyState(
                    icon: _searchQuery.isEmpty
                        ? AppIcons.locationSlash
                        : AppIcons.searchOff,
                    title: _searchQuery.isEmpty
                        ? 'No Saved Sites'
                        : 'No Results Found',
                    message: _searchQuery.isEmpty
                        ? 'Save frequently visited sites for quick access'
                        : 'Try a different search term',
                  )
                : AdaptiveRefreshIndicator(
                    onRefresh: _loadSavedSites,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSites.length,
                      itemBuilder: (context, index) {
                        final site = _filteredSites[index];
                        return _buildSiteCard(site).animateListItem(index);
                      },
                    ),
                  ),
          ),
        ],
      )),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showSiteDialog(),
              icon: const Icon(AppIcons.add),
              label: const Text('Add Site'),
            ),
    );
  }

  Widget _buildSiteCard(SavedSite site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              child: Icon(AppIcons.building, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.siteName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    site.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (site.notes != null) ...[
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
                  CardActionButton(
                    label: 'Edit',
                    onPressed: () => _showSiteDialog(site: site),
                  ),
                  const SizedBox(height: 6),
                  CardActionButton(
                    label: 'Delete',
                    onPressed: () => _deleteSite(site),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
