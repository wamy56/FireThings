import '../models/models.dart';
import '../utils/templates.dart';
import 'database_helper.dart';

/// Service to manage job templates (preloaded and custom)
class TemplateService {
  // Singleton pattern
  static final TemplateService instance = TemplateService._init();
  TemplateService._init();

  // In-memory cache for custom templates (loaded from database)
  final List<JobTemplate> _customTemplates = [];
  bool _isInitialized = false;

  /// Load custom templates from database
  Future<void> loadCustomTemplates() async {
    if (_isInitialized) return;

    final templates = await DatabaseHelper.instance.getAllJobTemplates();
    _customTemplates.clear();
    _customTemplates.addAll(templates);
    _isInitialized = true;
  }

  /// Get all templates (preloaded + custom)
  List<JobTemplate> getAllTemplates() {
    final preloaded = Templates.getPreloadedTemplates();
    return [...preloaded, ..._customTemplates];
  }

  /// Get only preloaded templates
  List<JobTemplate> getPreloadedTemplates() {
    return Templates.getPreloadedTemplates();
  }

  /// Get only custom templates
  List<JobTemplate> getCustomTemplates() {
    return List.from(_customTemplates);
  }

  /// Get a template by ID
  JobTemplate? getTemplateById(String id) {
    try {
      return getAllTemplates().firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Add a custom template
  Future<void> addCustomTemplate(JobTemplate template) async {
    await DatabaseHelper.instance.insertJobTemplate(template);
    _customTemplates.add(template);
  }

  /// Update a custom template
  Future<bool> updateCustomTemplate(JobTemplate template) async {
    final index = _customTemplates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      await DatabaseHelper.instance.updateJobTemplate(template);
      _customTemplates[index] = template;
      return true;
    }
    return false;
  }

  /// Delete a custom template
  Future<bool> deleteCustomTemplate(String id) async {
    final index = _customTemplates.indexWhere((t) => t.id == id);
    if (index != -1) {
      await DatabaseHelper.instance.deleteJobTemplate(id);
      _customTemplates.removeAt(index);
      return true;
    }
    return false;
  }

  /// Check if a template is custom (not preloaded)
  bool isCustomTemplate(String id) {
    return _customTemplates.any((t) => t.id == id);
  }

  /// Get template statistics
  Map<String, int> getTemplateStats() {
    return {
      'total': getAllTemplates().length,
      'preloaded': getPreloadedTemplates().length,
      'custom': _customTemplates.length,
    };
  }
}
