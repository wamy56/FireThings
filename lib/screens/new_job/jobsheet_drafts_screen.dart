import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_helper.dart';
import '../../services/auth_service.dart';
import '../../services/template_service.dart';
import '../../utils/pdf_form_templates.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/premium_dialog.dart';
import '../pdf_forms/pdf_form_fill_screen.dart';
import '../pdf_forms/minor_works_form_fill_screen.dart';
import 'job_form_screen.dart';

class JobsheetDraftsScreen extends StatefulWidget {
  const JobsheetDraftsScreen({super.key});

  @override
  State<JobsheetDraftsScreen> createState() => _JobsheetDraftsScreenState();
}

class _JobsheetDraftsScreenState extends State<JobsheetDraftsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();
  final _templateService = TemplateService.instance;

  List<Jobsheet> _drafts = [];
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
        final drafts = await _dbHelper.getDraftJobsheetsByEngineerId(user.uid);
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
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(itemCount: 5, showLeading: true),
            )
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
              'Draft jobsheets will appear here when you save them',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];

        return _buildDraftCard(draft).animateListItem(index);
      },
    );
  }

  Widget _buildDraftCard(Jobsheet draft) {
    final dateFormat = DateFormat('dd/MM/yyyy');

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
              draft.customerName.isNotEmpty ? draft.customerName : 'No customer',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.templateType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (draft.jobNumber.isNotEmpty) ...[
                      Text(
                        draft.jobNumber,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      dateFormat.format(draft.createdAt),
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
  }

  Future<void> _openDraft(Jobsheet draft) async {
    if (PdfFormTemplates.isPdfCertificateTemplate(draft.templateType)) {
      final pdfTemplate = PdfFormTemplates.getByName(draft.templateType);
      if (pdfTemplate != null) {
        if (draft.templateType == 'IQ Minor Works & Call Out Certificate') {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => MinorWorksFormFillScreen(
                template: pdfTemplate,
                existingJobsheet: draft,
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => PdfFormFillScreen(
                template: pdfTemplate,
                existingJobsheet: draft,
              ),
            ),
          );
        }
      }
    } else {
      // Find the template by name
      final templates = _templateService.getAllTemplates();
      final template = templates.firstWhere(
        (t) => t.name == draft.templateType,
        orElse: () => templates.first,
      );

      await Navigator.push(
        context,
        adaptivePageRoute(
          builder: (_) => JobFormScreen(
            template: template,
            existingDraft: draft,
          ),
        ),
      );
    }
    // Reload list when returning
    _loadDrafts();
  }

  void _confirmDelete(Jobsheet draft) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Draft',
      message: 'Are you sure you want to delete the draft for "${draft.customerName.isNotEmpty ? draft.customerName : 'this job'}"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteJobsheet(draft.id);
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
