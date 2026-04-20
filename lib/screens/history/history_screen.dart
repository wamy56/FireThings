import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../services/template_pdf_service.dart';
import '../../utils/pdf_form_templates.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/animate_helpers.dart';
import '../../mixins/multi_select_mixin.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/selection_app_bar.dart';
import '../../widgets/selectable_avatar.dart';
import '../pdf_forms/pdf_form_fill_screen.dart';
import '../pdf_forms/minor_works_form_fill_screen.dart';
import 'edit_jobsheet_screen.dart';
import 'job_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with MultiSelectMixin {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Jobsheet> _allJobsheets = [];
  List<Jobsheet> _filteredJobsheets = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadJobsheets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobsheets() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final jobsheets = await _dbHelper.getJobsheetsByEngineerId(user.uid);
      final completedJobsheets = jobsheets
          .where((j) => j.status == JobsheetStatus.completed)
          .toList();

      setState(() {
        _allJobsheets = completedJobsheets;
        _filteredJobsheets = completedJobsheets;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading jobsheets: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterJobsheets(String query) {
    if (isSelectionMode) exitSelectionMode();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredJobsheets = _allJobsheets;
      } else {
        _filteredJobsheets = _allJobsheets.where((jobsheet) {
          return jobsheet.customerName.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              jobsheet.jobNumber.toLowerCase().contains(query.toLowerCase()) ||
              jobsheet.siteAddress.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _generateAndSharePDF(Jobsheet jobsheet) async {
    try {
      context.showInfoToast('Generating PDF...');

      if (PdfFormTemplates.isPdfCertificateTemplate(jobsheet.templateType)) {
        final pdfTemplate = PdfFormTemplates.getByName(jobsheet.templateType);
        if (pdfTemplate != null) {
          final pdfBytes = await TemplatePdfService.generateOverlayPdf(
            template: pdfTemplate,
            fieldValues: jobsheet.formData,
          );
          await TemplatePdfService.sharePdf(
            pdfBytes,
            '${jobsheet.templateType.replaceAll(' ', '_')}_${jobsheet.jobNumber}.pdf',
          );
        }
      } else {
        final pdfBytes = await PDFService.generateJobsheetPDF(jobsheet);
        await PDFService.sharePDF(pdfBytes, 'jobsheet_${jobsheet.jobNumber}.pdf');
      }
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Error generating PDF: $e');
    }
  }

  Future<void> _editJobsheet(Jobsheet jobsheet) async {
    if (PdfFormTemplates.isPdfCertificateTemplate(jobsheet.templateType)) {
      final pdfTemplate = PdfFormTemplates.getByName(jobsheet.templateType);
      if (pdfTemplate != null) {
        if (jobsheet.templateType == 'IQ Minor Works & Call Out Certificate') {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => MinorWorksFormFillScreen(
                template: pdfTemplate,
                existingJobsheet: jobsheet,
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => PdfFormFillScreen(
                template: pdfTemplate,
                existingJobsheet: jobsheet,
              ),
            ),
          );
        }
      }
    } else {
      await Navigator.push(
        context,
        adaptivePageRoute(
          builder: (_) => EditJobsheetScreen(jobsheet: jobsheet),
        ),
      );
    }
    _loadJobsheets();
  }

  Future<void> _deleteJobsheet(Jobsheet jobsheet) async {
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Jobsheet',
      message: 'Are you sure you want to delete the jobsheet for ${jobsheet.customerName}?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      await _dbHelper.deleteJobsheet(jobsheet.id);

      if (!mounted) return;
      context.showWarningToast('Jobsheet deleted');

      _loadJobsheets();
    }
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
                isAllSelected: _filteredJobsheets.isNotEmpty &&
                    selectedCount == _filteredJobsheets.length,
                onClose: exitSelectionMode,
                onSelectAll: (selectAll) {
                  if (selectAll) {
                    this.selectAll(
                        _filteredJobsheets.map((j) => j.id).toList());
                  } else {
                    deselectAll();
                  }
                },
                onDelete: _bulkDelete,
              )
            : AdaptiveNavigationBar(
                title: 'Job History',
                actions: [
                  TextButton(
                    onPressed: _filteredJobsheets.isEmpty
                        ? null
                        : enterSelectionMode,
                    child: const Text('Select'),
                  ),
                ],
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search jobsheets...',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(AppIcons.close),
                          onPressed: () {
                            _searchController.clear();
                            _filterJobsheets('');
                          },
                        )
                      : null,
                ),
                onChanged: _filterJobsheets,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredJobsheets.length} jobsheet${_filteredJobsheets.length == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SkeletonList(itemCount: 6, showLeading: true),
                    )
                  : _filteredJobsheets.isEmpty
                      ? _buildEmptyState()
                      : AdaptiveRefreshIndicator(
                          onRefresh: _loadJobsheets,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredJobsheets.length,
                            itemBuilder: (context, index) {
                              final jobsheet = _filteredJobsheets[index];
                              return _buildJobsheetCard(jobsheet)
                                  .animateListItem(index);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsheetCard(Jobsheet jobsheet) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = isSelected(jobsheet.id);

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
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: SelectableAvatar(
            isSelectionMode: isSelectionMode,
            isSelected: selected,
            child: CircleAvatar(
              backgroundColor:
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                jobsheet.customerName.isNotEmpty
                    ? jobsheet.customerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            jobsheet.customerName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                jobsheet.siteAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                '${jobsheet.jobNumber} \u2022 ${jobsheet.templateType}',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                dateFormat.format(jobsheet.date),
                style: TextStyle(fontSize: 11, color: AppTheme.textHint),
              ),
            ],
          ),
          trailing: isSelectionMode
              ? null
              : IconButton(
                  icon: Icon(AppIcons.more),
                  onPressed: () => showAdaptiveActionSheet(
                    context: context,
                    options: [
                      ActionSheetOption(
                        label: 'View Details',
                        icon: AppIcons.eye,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            adaptivePageRoute(
                              builder: (_) =>
                                  JobDetailScreen(jobsheet: jobsheet),
                            ),
                          );
                          _loadJobsheets();
                        },
                      ),
                      ActionSheetOption(
                        label: 'Edit',
                        icon: AppIcons.edit,
                        onTap: () => _editJobsheet(jobsheet),
                      ),
                      ActionSheetOption(
                        label: 'Generate PDF',
                        icon: AppIcons.document,
                        onTap: () => _generateAndSharePDF(jobsheet),
                      ),
                      ActionSheetOption(
                        label: 'Delete',
                        icon: AppIcons.trash,
                        isDestructive: true,
                        onTap: () => _deleteJobsheet(jobsheet),
                      ),
                    ],
                  ),
                ),
          onTap: () {
            if (isSelectionMode) {
              toggleSelection(jobsheet.id);
            } else {
              Navigator.push(
                context,
                adaptivePageRoute(
                  builder: (_) => JobDetailScreen(jobsheet: jobsheet),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? AppIcons.briefcaseOutline
                  : AppIcons.searchOff,
              size: 64,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No Jobsheets Yet' : 'No Results Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Your completed jobsheets will appear here'
                  : 'Try a different search term',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final count = selectedCount;
    final confirm = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete $count Jobsheet${count == 1 ? '' : 's'}',
      message:
          'Are you sure you want to delete $count selected ${count == 1 ? 'item' : 'items'}? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteJobsheets(selectedIds.toList());
        if (mounted) {
          exitSelectionMode();
          _loadJobsheets();
          context.showSuccessToast(
              '$count jobsheet${count == 1 ? '' : 's'} deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorToast('Error deleting jobsheets: $e');
        }
      }
    }
  }
}
