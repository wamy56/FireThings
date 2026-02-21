import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';

class SitePickerScreen extends StatefulWidget {
  const SitePickerScreen({super.key});

  @override
  State<SitePickerScreen> createState() => _SitePickerScreenState();
}

class _SitePickerScreenState extends State<SitePickerScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<SavedSite> _allSites = [];
  List<SavedSite> _filteredSites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Select Site'),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search sites...',
                prefixIcon: Icon(AppIcons.search),
              ),
              onChanged: _filterSites,
              autofocus: true,
            ),
          ),

          // Sites list
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _filteredSites.isEmpty
                ? EmptyState(
                    icon: AppIcons.location,
                    title: 'No Sites Found',
                    message: 'Add saved sites in Settings to use this feature',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredSites.length,
                    itemBuilder: (context, index) {
                      final site = _filteredSites[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha:
                              0.1,
                            ),
                            child: Icon(
                              AppIcons.location,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          title: Text(
                            site.siteName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            site.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, site),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
