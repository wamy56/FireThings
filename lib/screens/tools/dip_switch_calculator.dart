import 'dart:async';
import '../../widgets/premium_dialog.dart';
import 'package:flutter/material.dart';
import '../../models/dip_switch_models.dart';
import '../../services/dip_switch_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class DipSwitchCalculatorScreen extends StatefulWidget {
  const DipSwitchCalculatorScreen({super.key});

  @override
  State<DipSwitchCalculatorScreen> createState() =>
      _DipSwitchCalculatorScreenState();
}

class _DipSwitchCalculatorScreenState extends State<DipSwitchCalculatorScreen> {
  final DipSwitchService _service = DipSwitchService();

  // Switch states
  List<bool> _switchStates = List.generate(8, (index) => false);

  // Calculated result
  int _calculatedAddress = 0;

  // View state
  bool _showFavorites = false;
  List<SavedDipConfiguration> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _calculateAddress();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _service.getFavoriteConfigurations();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
    });
  }

  void _onSwitchToggled(int index) {
    setState(() {
      _switchStates[index] = !_switchStates[index];
      _calculateAddress();
    });
  }

  void _resetSwitches() {
    setState(() {
      _switchStates = List.generate(8, (index) => false);
      _calculateAddress();
    });
  }

  void _calculateAddress() {
    int address = 0;
    final values = [1, 2, 4, 8, 16, 32, 64, 128];

    for (int i = 0; i < _switchStates.length; i++) {
      if (_switchStates[i]) {
        address += values[i];
      }
    }

    setState(() {
      _calculatedAddress = address;
    });
  }

  Future<void> _saveFavorite() async {
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;

    final favorite = SavedDipConfiguration(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      manufacturer: 'Universal',
      panelType: 'Binary Calculator',
      switchStates: List.from(_switchStates),
      address: _calculatedAddress,
      zone: '',
      dateCreated: DateTime.now(),
    );

    await _service.saveFavoriteConfiguration(favorite);
    await _loadFavorites();

    if (mounted) {
      context.showSuccessToast('Configuration saved to favorites');
    }
  }

  void _loadFavorite(SavedDipConfiguration favorite) {
    setState(() {
      _switchStates = List.from(favorite.switchStates);
      _calculateAddress();
      _showFavorites = false;
    });
  }

  Future<void> _deleteFavorite(SavedDipConfiguration favorite) async {
    await _service.deleteFavoriteConfiguration(favorite.id);
    await _loadFavorites();

    if (mounted) {
      context.showWarningToast('Favorite deleted');
    }
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();
    return showPremiumDialog<String>(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('Save Favorite'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardAppearance: Brightness.light,
          decoration: const InputDecoration(
            labelText: 'Configuration Name',
            hintText: 'e.g., Zone 1 Detectors',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      )),
    );
  }

  Future<void> _setAddressFromInput() async {
    final controller = TextEditingController(
      text: _calculatedAddress.toString(),
    );

    final result = await showPremiumDialog<int>(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('Set Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter an address (0-255) to automatically set the DIP switches:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardAppearance: Brightness.light,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'e.g., 25',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final address = int.tryParse(value);
                if (address != null && address >= 0 && address <= 255) {
                  Navigator.pop(context, address);
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Valid range: 0-255',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final address = int.tryParse(controller.text);
              if (address != null && address >= 0 && address <= 255) {
                Navigator.pop(context, address);
              } else {
                context.showErrorToast('Please enter a valid address (0-255)');
              }
            },
            child: const Text('Set'),
          ),
        ],
      )),
    );

    if (result != null) {
      _setAddressFromNumber(result);
    }
  }

  void _setAddressFromNumber(int address) {
    setState(() {
      for (int i = 0; i < 8; i++) {
        _switchStates[i] = (address & (1 << i)) != 0;
      }
      _calculateAddress();
    });

    context.showInfoToast('Switches set for address $address');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'DIP Switch Calculator',
        actions: [
          IconButton(
            icon: Badge(
              label: Text(_favorites.length.toString()),
              isLabelVisible: _favorites.isNotEmpty,
              child: Icon(_showFavorites ? AppIcons.calculator : AppIcons.award),
            ),
            onPressed: () {
              setState(() {
                _showFavorites = !_showFavorites;
              });
            },
            tooltip: _showFavorites ? 'Calculator' : 'Favorites',
          ),
        ],
      ),
      body: KeyboardDismissWrapper(child: _showFavorites ? _buildFavoritesView() : _buildCalculatorView()),
    );
  }

  Widget _buildCalculatorView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDipSwitchPanel(),
                const SizedBox(height: AppTheme.listItemSpacing),
                _buildResultPanel(),
                const SizedBox(height: AppTheme.listItemSpacing),
                _buildAddressableChip(),
              ],
            ),
          ),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildDipSwitchPanel() {
    return SimpleCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIP Switch',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _resetSwitches,
                icon: Icon(AppIcons.refresh, size: 14),
                label: const Text('Reset', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // DIP Switches in a single row
          Row(
            children: List.generate(8, (index) {
              return Expanded(child: _buildDipSwitch(index));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDipSwitch(int index) {
    final isOn = _switchStates[index];
    final values = [1, 2, 4, 8, 16, 32, 64, 128];
    final positions = [1, 2, 3, 4, 5, 6, 7, 8];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.darkPrimaryBlue
        : AppTheme.primaryBlue;
    final offBorderColor = isDark ? AppTheme.darkDivider : AppTheme.lightGrey;
    final offBgColor = isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite;
    final offTextColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.mediumGrey;
    final offTrackColor = isDark ? AppTheme.darkTextHint : AppTheme.mediumGrey;
    final offBadgeBg = isDark
        ? AppTheme.darkSurfaceElevated
        : AppTheme.lightGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: AnimatedContainer(
        duration: AppTheme.normalAnimation,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isOn ? primaryColor.withValues(alpha: 0.15) : offBgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isOn ? primaryColor : offBorderColor,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onSwitchToggled(index),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top label - Binary value
                  Text(
                    values[index].toString(),
                    style: TextStyle(
                      color: isOn ? primaryColor : offTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Vertical Toggle Switch
                  Container(
                    width: 16,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isOn ? primaryColor : offTrackColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: isOn
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      child: Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),

                  // ON/OFF state
                  Text(
                    isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: isOn ? primaryColor : offTextColor,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Bottom label - Position number
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isOn
                          ? primaryColor.withValues(alpha: 0.15)
                          : offBadgeBg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      positions[index].toString(),
                      style: TextStyle(
                        color: isOn ? primaryColor : offTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildResultPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.darkPrimaryBlue
        : AppTheme.primaryBlue;

    String binaryString = '';
    for (int i = 7; i >= 0; i--) {
      binaryString += _switchStates[i] ? '1' : '0';
    }

    return PremiumCard(
      onTap: _setAddressFromInput,
      backgroundColor: primaryColor.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.edit, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Text('Address', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              Icon(AppIcons.calculator, color: primaryColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _calculatedAddress.toString(),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Binary: $binaryString',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressableChip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.darkPrimaryBlue
        : AppTheme.primaryBlue;

    return SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.calculator, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'Addressable Chip',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Clean staggered layout
          Center(
            child: Column(
              children: [
                // Top row - values above switches
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSwitchColumn('2', 1),
                    const SizedBox(width: 20),
                    _buildSwitchColumn('8', 3),
                    const SizedBox(width: 20),
                    _buildSwitchColumn('32', 5),
                    const SizedBox(width: 20),
                    _buildSwitchColumn('128', 7),
                  ],
                ),
                const SizedBox(height: 16),

                // Bottom row - values below switches (staggered)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSwitchColumn('1', 0, valueAtBottom: true),
                    const SizedBox(width: 20),
                    _buildSwitchColumn('4', 2, valueAtBottom: true),
                    const SizedBox(width: 20),
                    _buildSwitchColumn('16', 4, valueAtBottom: true),
                    const SizedBox(width: 20),
                    _buildSwitchColumn('64', 6, valueAtBottom: true),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchColumn(
    String value,
    int index, {
    bool valueAtBottom = false,
  }) {
    final isOn = _switchStates[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.darkPrimaryBlue
        : AppTheme.primaryBlue;
    final offTextColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.mediumGrey;
    final offCircleBg = isDark
        ? AppTheme.darkSurfaceElevated
        : AppTheme.lightGrey;
    final offCircleBorder = isDark ? AppTheme.darkDivider : AppTheme.mediumGrey;

    return Column(
      children: [
        // Value at top
        if (!valueAtBottom)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              value,
              style: TextStyle(
                color: isOn ? primaryColor : offTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Rotary switch
        GestureDetector(
          onTap: () => _onSwitchToggled(index),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? primaryColor.withValues(alpha: 0.2) : offCircleBg,
              border: Border.all(
                color: isOn ? primaryColor : offCircleBorder,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOn
                      ? primaryColor.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: isOn ? 8 : 4,
                  spreadRadius: isOn ? 1 : 0,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? primaryColor : offCircleBorder,
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Value at bottom
        if (valueAtBottom)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              value,
              style: TextStyle(
                color: isOn ? primaryColor : offTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetSwitches,
                icon: Icon(AppIcons.refresh, size: 18),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveFavorite,
                icon: Icon(AppIcons.award, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesView() {
    if (_favorites.isEmpty) {
      return const EmptyState(
        icon: AppIcons.award,
        title: 'No Saved Favorites',
        message: 'Save configurations from the calculator',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark
            ? AppTheme.darkPrimaryBlue
            : AppTheme.primaryBlue;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
          child: PremiumCard(
            onTap: () => _loadFavorite(favorite),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.award, color: primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        favorite.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(AppIcons.trash),
                      color: AppTheme.errorRed,
                      onPressed: () => _deleteFavorite(favorite),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Address',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            favorite.address.toString(),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
