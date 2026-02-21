import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../utils/icon_map.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../../utils/adaptive_widgets.dart';
import 'invoice_screen.dart';

class SavedDraftsScreen extends StatefulWidget {
  const SavedDraftsScreen({super.key});

  @override
  State<SavedDraftsScreen> createState() => _SavedDraftsScreenState();
}

class _SavedDraftsScreenState extends State<SavedDraftsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();

  List<Invoice> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final drafts = await _dbHelper.getDraftInvoicesByEngineerId(user.uid);
        setState(() {
          _drafts = drafts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showErrorToast('Error loading drafts: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Saved Drafts',
      ),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : _drafts.isEmpty
              ? _buildEmptyState()
              : _buildDraftList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.editNote, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Saved Drafts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Draft invoices will appear here when you save them',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftList() {
    final currencyFormat = NumberFormat.currency(symbol: '\u00A3', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        final total = draft.total;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Icon(
                AppIcons.document,
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: Text(
              draft.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.customerName.isNotEmpty ? draft.customerName : 'No customer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      currencyFormat.format(total),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(draft.date),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: Icon(AppIcons.more),
              onPressed: () => showAdaptiveActionSheet(
                context: context,
                options: [
                  ActionSheetOption(
                    label: 'Edit',
                    icon: AppIcons.edit,
                    onTap: () => _openDraft(draft),
                  ),
                  ActionSheetOption(
                    label: 'Delete',
                    icon: AppIcons.trash,
                    isDestructive: true,
                    onTap: () => _confirmDelete(draft),
                  ),
                ],
              ),
            ),
            onTap: () => _openDraft(draft),
          ),
        );
      },
    );
  }

  Future<void> _openDraft(Invoice draft) async {
    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => InvoiceScreen(existingInvoice: draft),
      ),
    );
    // Reload list when returning
    _loadDrafts();
  }

  void _confirmDelete(Invoice draft) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Draft',
      message: 'Are you sure you want to delete "${draft.invoiceNumber}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteInvoice(draft.id);
        if (mounted) {
          _loadDrafts();
          context.showSuccessToast('Draft deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error: $e');
        }
      }
    }
  }
}
