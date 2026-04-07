import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/asset_type.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_type_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';

class AssetTypeConfigScreen extends StatefulWidget {
  final String basePath;
  final bool canEdit;
  final String? siteId;

  const AssetTypeConfigScreen({
    super.key,
    required this.basePath,
    this.canEdit = true,
    this.siteId,
  });

  @override
  State<AssetTypeConfigScreen> createState() => _AssetTypeConfigScreenState();
}

class _AssetTypeConfigScreenState extends State<AssetTypeConfigScreen> {
  List<AssetType> _types = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() => _loading = true);
    final types =
        await AssetTypeService.instance.getAssetTypes(widget.basePath);
    if (mounted) {
      setState(() {
        _types = types;
        _loading = false;
      });
    }
  }

  IconData _iconForName(String iconName) {
    switch (iconName) {
      case 'cpu':
        return AppIcons.cpu;
      case 'radar':
        return AppIcons.radar;
      case 'danger':
        return AppIcons.danger;
      case 'volumeHigh':
        return AppIcons.volumeHigh;
      case 'securitySafe':
        return AppIcons.securitySafe;
      case 'lampCharge':
        return AppIcons.lampCharge;
      case 'wind':
        return AppIcons.wind;
      case 'drop':
        return AppIcons.drop;
      case 'box':
        return AppIcons.box;
      case 'radar_heat':
        return AppIcons.radar;
      case 'door':
        return AppIcons.securitySafe;
      case 'flash':
        return AppIcons.flash;
      case 'batteryCharging':
        return AppIcons.batteryCharging;
      case 'slider':
        return AppIcons.slider;
      case 'microphone':
        return AppIcons.microphone;
      case 'call':
        return AppIcons.call;
      case 'notification':
        return AppIcons.notification;
      default:
        return AppIcons.setting;
    }
  }

  void _editType(AssetType type) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => _AssetTypeEditScreen(
          basePath: widget.basePath,
          type: type,
          canEdit: widget.canEdit,
        ),
      ),
    )
        .then((_) => _loadTypes());
  }

  void _addType() {
    final newType = AssetType(
      id: const Uuid().v4(),
      name: '',
      iconName: 'setting',
      defaultColor: '#607D8B',
      isBuiltIn: false,
    );

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => _AssetTypeEditScreen(
          basePath: widget.basePath,
          type: newType,
          isNew: true,
          canEdit: true,
        ),
      ),
    )
        .then((_) => _loadTypes());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Types'),
        leading: kIsWeb && widget.siteId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/sites/${widget.siteId}/assets'),
              )
            : null,
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: _addType,
              icon: const Icon(AppIcons.add),
              label: const Text('Add Type'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: _loading
              ? const AdaptiveLoadingIndicator()
              : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _types.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final type = _types[index];
                final color = Color(
                    int.parse(type.defaultColor.replaceFirst('#', '0xFF')));
                final isBuiltIn = DefaultAssetTypes.getById(type.id) != null;

                return GestureDetector(
                  onTap: () => _editType(type),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceElevated
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardRadius),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_iconForName(type.iconName),
                              color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      type.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isBuiltIn) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (type.category != null) type.category!,
                                  '${type.variants.length} variants',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.arrowRight,
                          size: 18,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ),
      ),
    );
  }
}

// ── Edit Screen ──

class _AssetTypeEditScreen extends StatefulWidget {
  final String basePath;
  final AssetType type;
  final bool isNew;
  final bool canEdit;

  const _AssetTypeEditScreen({
    required this.basePath,
    required this.type,
    this.isNew = false,
    this.canEdit = true,
  });

  @override
  State<_AssetTypeEditScreen> createState() => _AssetTypeEditScreenState();
}

class _AssetTypeEditScreenState extends State<_AssetTypeEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _lifespanController;
  late String _selectedIcon;
  late String _selectedColor;
  late List<String> _variants;
  bool _saving = false;

  static const _iconOptions = [
    'cpu',
    'radar',
    'radar_heat',
    'danger',
    'volumeHigh',
    'securitySafe',
    'lampCharge',
    'door',
    'wind',
    'drop',
    'box',
    'flash',
    'batteryCharging',
    'slider',
    'microphone',
    'call',
    'notification',
    'setting',
  ];

  static const _colorOptions = [
    '#D32F2F',
    '#E91E63',
    '#9C27B0',
    '#673AB7',
    '#3F51B5',
    '#2196F3',
    '#00BCD4',
    '#009688',
    '#4CAF50',
    '#8BC34A',
    '#FF9800',
    '#795548',
    '#607D8B',
    '#F97316',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.type.name);
    _categoryController =
        TextEditingController(text: widget.type.category ?? '');
    _lifespanController = TextEditingController(
        text: widget.type.defaultLifespanYears?.toString() ?? '');
    _selectedIcon = widget.type.iconName;
    _selectedColor = widget.type.defaultColor;
    _variants = List.from(widget.type.variants);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _lifespanController.dispose();
    super.dispose();
  }

  IconData _iconForName(String iconName) {
    switch (iconName) {
      case 'cpu':
        return AppIcons.cpu;
      case 'radar':
        return AppIcons.radar;
      case 'danger':
        return AppIcons.danger;
      case 'volumeHigh':
        return AppIcons.volumeHigh;
      case 'securitySafe':
        return AppIcons.securitySafe;
      case 'lampCharge':
        return AppIcons.lampCharge;
      case 'wind':
        return AppIcons.wind;
      case 'drop':
        return AppIcons.drop;
      case 'box':
        return AppIcons.box;
      case 'radar_heat':
        return AppIcons.radar;
      case 'door':
        return AppIcons.securitySafe;
      case 'flash':
        return AppIcons.flash;
      case 'batteryCharging':
        return AppIcons.batteryCharging;
      case 'slider':
        return AppIcons.slider;
      case 'microphone':
        return AppIcons.microphone;
      case 'call':
        return AppIcons.call;
      case 'notification':
        return AppIcons.notification;
      default:
        return AppIcons.setting;
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showErrorToast('Name is required');
      return;
    }

    setState(() => _saving = true);

    try {
      final lifespan = int.tryParse(_lifespanController.text.trim());
      final isBuiltIn = DefaultAssetTypes.getById(widget.type.id) != null;

      final updated = AssetType(
        id: widget.type.id,
        name: name,
        category: _categoryController.text.trim().isNotEmpty
            ? _categoryController.text.trim()
            : null,
        iconName: _selectedIcon,
        defaultColor: _selectedColor,
        variants: _variants,
        defaultLifespanYears: lifespan,
        isBuiltIn: isBuiltIn,
      );

      await AssetTypeService.instance
          .saveCustomType(widget.basePath, updated);

      if (widget.isNew) {
        AnalyticsService.instance.logAssetTypeCreated(
          typeName: name,
          isCustom: !isBuiltIn,
        );
      }

      if (mounted) {
        context.showSuccessToast('Asset type saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showErrorToast('Failed to save');
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Asset Type'),
        content: Text('Delete "${widget.type.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AssetTypeService.instance
          .deleteCustomType(widget.basePath, widget.type.id);
      if (mounted) {
        context.showSuccessToast('Asset type deleted');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to delete');
    }
  }

  void _addVariant() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Variant'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Optical, Heat A1R'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _variants.add(text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBuiltIn = DefaultAssetTypes.getById(widget.type.id) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New Asset Type' : widget.type.name),
        actions: [
          if (widget.canEdit && !isBuiltIn && !widget.isNew)
            IconButton(
              icon: const Icon(AppIcons.trash, color: Colors.red),
              onPressed: _delete,
            ),
          if (widget.canEdit)
            IconButton(
              icon: const Icon(AppIcons.save),
              onPressed: _saving ? null : _save,
            ),
        ],
      ),
      body: _saving
          ? const Center(child: AdaptiveLoadingIndicator())
          : KeyboardDismissWrapper(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Name & Category
                  if (!isBuiltIn || widget.isNew) ...[
                    CustomTextField(
                      controller: _nameController,
                      label: 'Type Name',
                      enabled: widget.canEdit,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _categoryController,
                      label: 'Category (optional)',
                      enabled: widget.canEdit,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _lifespanController,
                      label: 'Default Lifespan (years)',
                      keyboardType: TextInputType.number,
                      enabled: widget.canEdit,
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    // Built-in: show read-only info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceElevated
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.cardRadius),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Icon(_iconForName(widget.type.iconName),
                              size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.type.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                                if (widget.type.category != null)
                                  Text(widget.type.category!,
                                      style: TextStyle(
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Default',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Icon picker (custom types only)
                  if (!isBuiltIn && widget.canEdit) ...[
                    Text('Icon',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : AppTheme.textPrimary,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconOptions.map((iconName) {
                        final selected = _selectedIcon == iconName;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIcon = iconName),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primaryBlue
                                      .withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppTheme.darkSurfaceElevated
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: selected
                                  ? Border.all(
                                      color: AppTheme.primaryBlue, width: 2)
                                  : null,
                            ),
                            child: Icon(_iconForName(iconName), size: 22),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Colour picker (custom types only)
                  if (!isBuiltIn && widget.canEdit) ...[
                    Text('Colour',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : AppTheme.textPrimary,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorOptions.map((hex) {
                        final color =
                            Color(int.parse(hex.replaceFirst('#', '0xFF')));
                        final selected = _selectedColor == hex;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      width: 3)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Variants section
                  if (widget.canEdit) ...[
                    Row(
                      children: [
                        Text('Variants',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            )),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addVariant,
                          icon: const Icon(AppIcons.add, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_variants.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No variants defined',
                            style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary)),
                      )
                    else
                      ..._variants.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(entry.value,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textPrimary)),
                              ),
                              IconButton(
                                icon: const Icon(AppIcons.close, size: 18),
                                onPressed: () => setState(
                                    () => _variants.removeAt(entry.key)),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
