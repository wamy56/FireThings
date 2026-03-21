import 'package:flutter/material.dart';
import '../../models/pdf_header_config.dart';
import '../../models/pdf_footer_config.dart';
import '../../models/pdf_colour_scheme.dart';
import '../../services/company_pdf_config_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';

class CompanyPdfDesignScreen extends StatefulWidget {
  final String companyId;

  const CompanyPdfDesignScreen({super.key, required this.companyId});

  @override
  State<CompanyPdfDesignScreen> createState() => _CompanyPdfDesignScreenState();
}

class _CompanyPdfDesignScreenState extends State<CompanyPdfDesignScreen> {
  final _service = CompanyPdfConfigService.instance;
  bool _isLoading = true;

  // Current configs for both doc types
  PdfHeaderConfig? _jobsheetHeader;
  PdfHeaderConfig? _invoiceHeader;
  PdfFooterConfig? _jobsheetFooter;
  PdfFooterConfig? _invoiceFooter;
  PdfColourScheme? _jobsheetColour;
  PdfColourScheme? _invoiceColour;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final results = await Future.wait([
      _service.getHeaderConfig(widget.companyId, PdfDocumentType.jobsheet),
      _service.getHeaderConfig(widget.companyId, PdfDocumentType.invoice),
      _service.getFooterConfig(widget.companyId, PdfDocumentType.jobsheet),
      _service.getFooterConfig(widget.companyId, PdfDocumentType.invoice),
      _service.getColourScheme(widget.companyId, PdfDocumentType.jobsheet),
      _service.getColourScheme(widget.companyId, PdfDocumentType.invoice),
    ]);

    if (mounted) {
      setState(() {
        _jobsheetHeader = results[0] as PdfHeaderConfig?;
        _invoiceHeader = results[1] as PdfHeaderConfig?;
        _jobsheetFooter = results[2] as PdfFooterConfig?;
        _invoiceFooter = results[3] as PdfFooterConfig?;
        _jobsheetColour = results[4] as PdfColourScheme?;
        _invoiceColour = results[5] as PdfColourScheme?;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(title: 'Company PDF Branding'),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                Text(
                  'Configure the PDF branding used for jobsheets and invoices created from dispatched jobs.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Jobsheet section
                _buildSectionTitle('Jobsheet PDF', isDark),
                const SizedBox(height: 12),
                _buildConfigCard(
                  isDark,
                  'Header',
                  AppIcons.document,
                  _jobsheetHeader != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editHeader(PdfDocumentType.jobsheet),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Footer',
                  AppIcons.note,
                  _jobsheetFooter != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editFooter(PdfDocumentType.jobsheet),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Colour Scheme',
                  AppIcons.colorSwatch,
                  _jobsheetColour != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editColourScheme(PdfDocumentType.jobsheet),
                ),

                const SizedBox(height: 32),

                // Invoice section
                _buildSectionTitle('Invoice PDF', isDark),
                const SizedBox(height: 12),
                _buildConfigCard(
                  isDark,
                  'Header',
                  AppIcons.document,
                  _invoiceHeader != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editHeader(PdfDocumentType.invoice),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Footer',
                  AppIcons.note,
                  _invoiceFooter != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editFooter(PdfDocumentType.invoice),
                ),
                const SizedBox(height: 8),
                _buildConfigCard(
                  isDark,
                  'Colour Scheme',
                  AppIcons.colorSwatch,
                  _invoiceColour != null ? 'Configured' : 'Not set (uses personal)',
                  () => _editColourScheme(PdfDocumentType.invoice),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildConfigCard(
    bool isDark,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(AppIcons.arrowRight),
        onTap: onTap,
      ),
    );
  }

  Future<void> _editHeader(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetHeader : _invoiceHeader;
    final config = current ?? PdfHeaderConfig.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyHeaderEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialConfig: config,
          title: 'Company $typeName Header',
        ),
      ),
    );
    _loadConfigs();
  }

  Future<void> _editFooter(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetFooter : _invoiceFooter;
    final config = current ?? PdfFooterConfig.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyFooterEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialConfig: config,
          title: 'Company $typeName Footer',
        ),
      ),
    );
    _loadConfigs();
  }

  Future<void> _editColourScheme(PdfDocumentType type) async {
    final typeName = type == PdfDocumentType.jobsheet ? 'Jobsheet' : 'Invoice';
    final current = type == PdfDocumentType.jobsheet ? _jobsheetColour : _invoiceColour;
    final config = current ?? PdfColourScheme.defaults();

    await Navigator.push(
      context,
      adaptivePageRoute(
        builder: (_) => _CompanyColourEditorScreen(
          companyId: widget.companyId,
          docType: type,
          initialScheme: config,
          title: 'Company $typeName Colours',
        ),
      ),
    );
    _loadConfigs();
  }
}

// --- Inline editor screens for company PDF config ---

class _CompanyHeaderEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfHeaderConfig initialConfig;
  final String title;

  const _CompanyHeaderEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<_CompanyHeaderEditorScreen> createState() => _CompanyHeaderEditorState();
}

class _CompanyHeaderEditorState extends State<_CompanyHeaderEditorScreen> {
  late PdfHeaderConfig _config;
  final Map<String, TextEditingController> _leftControllers = {};
  final Map<String, TextEditingController> _centreControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    for (final line in _config.leftLines) {
      _leftControllers[line.key] = TextEditingController(text: line.value);
    }
    for (final line in _config.centreLines) {
      _centreControllers[line.key] = TextEditingController(text: line.value);
    }
  }

  @override
  void dispose() {
    for (final c in _leftControllers.values) {
      c.dispose();
    }
    for (final c in _centreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          const Text(
            'Left Lines',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._config.leftLines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _leftControllers[line.key],
                  decoration: InputDecoration(
                    labelText: line.key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
          const SizedBox(height: 24),
          const Text(
            'Centre Lines',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._config.centreLines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _centreControllers[line.key],
                  decoration: InputDecoration(
                    labelText: line.key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
          if (_config.leftLines.isEmpty && _config.centreLines.isEmpty)
            const Text('No header lines configured. Save to create defaults.'),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updatedLeft = _config.leftLines.map((line) {
        final controller = _leftControllers[line.key];
        return line.copyWith(value: controller?.text ?? line.value);
      }).toList();

      final updatedCentre = _config.centreLines.map((line) {
        final controller = _centreControllers[line.key];
        return line.copyWith(value: controller?.text ?? line.value);
      }).toList();

      final updated = PdfHeaderConfig(
        logoZone: _config.logoZone,
        logoSize: _config.logoSize,
        leftLines: updatedLeft,
        centreLines: updatedCentre,
      );

      await CompanyPdfConfigService.instance.saveHeaderConfig(
        widget.companyId,
        updated,
        widget.docType,
      );

      if (mounted) {
        context.showSuccessToast('Header saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save header');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _CompanyFooterEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfFooterConfig initialConfig;
  final String title;

  const _CompanyFooterEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<_CompanyFooterEditorScreen> createState() => _CompanyFooterEditorState();
}

class _CompanyFooterEditorState extends State<_CompanyFooterEditorScreen> {
  final Map<String, TextEditingController> _leftControllers = {};
  final Map<String, TextEditingController> _centreControllers = {};
  late PdfFooterConfig _config;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    for (final line in _config.leftLines) {
      _leftControllers[line.key] = TextEditingController(text: line.value);
    }
    for (final line in _config.centreLines) {
      _centreControllers[line.key] = TextEditingController(text: line.value);
    }
  }

  @override
  void dispose() {
    for (final c in _leftControllers.values) {
      c.dispose();
    }
    for (final c in _centreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          const Text(
            'Left Lines',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._config.leftLines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _leftControllers[line.key],
                  decoration: InputDecoration(
                    labelText: line.key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
          const SizedBox(height: 24),
          const Text(
            'Centre Lines',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._config.centreLines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _centreControllers[line.key],
                  decoration: InputDecoration(
                    labelText: line.key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
          if (_config.leftLines.isEmpty && _config.centreLines.isEmpty)
            const Text('No footer lines configured. Save to create defaults.'),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updatedLeft = _config.leftLines.map((line) {
        final controller = _leftControllers[line.key];
        return line.copyWith(value: controller?.text ?? line.value);
      }).toList();

      final updatedCentre = _config.centreLines.map((line) {
        final controller = _centreControllers[line.key];
        return line.copyWith(value: controller?.text ?? line.value);
      }).toList();

      final updated = PdfFooterConfig(
        leftLines: updatedLeft,
        centreLines: updatedCentre,
      );

      await CompanyPdfConfigService.instance.saveFooterConfig(
        widget.companyId,
        updated,
        widget.docType,
      );

      if (mounted) {
        context.showSuccessToast('Footer saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save footer');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _CompanyColourEditorScreen extends StatefulWidget {
  final String companyId;
  final PdfDocumentType docType;
  final PdfColourScheme initialScheme;
  final String title;

  const _CompanyColourEditorScreen({
    required this.companyId,
    required this.docType,
    required this.initialScheme,
    required this.title,
  });

  @override
  State<_CompanyColourEditorScreen> createState() => _CompanyColourEditorState();
}

class _CompanyColourEditorState extends State<_CompanyColourEditorScreen> {
  late Color _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = Color(widget.initialScheme.primaryColorValue);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: widget.title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          const Text(
            'Primary Colour',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Colors.blue,
              AppTheme.primaryBlue,
              Colors.indigo,
              Colors.teal,
              Colors.green,
              Colors.orange,
              Colors.red,
              Colors.purple,
              Colors.brown,
              Colors.blueGrey,
            ].map((color) {
              final isSelected = _selectedColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: isDark ? Colors.white : Colors.black,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final scheme = PdfColourScheme(primaryColorValue: _selectedColor.toARGB32());

      await CompanyPdfConfigService.instance.saveColourScheme(
        widget.companyId,
        scheme,
        widget.docType,
      );

      if (mounted) {
        context.showSuccessToast('Colour scheme saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to save colour scheme');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
