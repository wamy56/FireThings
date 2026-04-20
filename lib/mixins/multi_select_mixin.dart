import 'package:flutter/material.dart';

mixin MultiSelectMixin<T extends StatefulWidget> on State<T> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedIds.length;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  bool isSelected(String id) => _selectedIds.contains(id);

  void toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void selectAll(List<String> allIds) {
    setState(() {
      _selectedIds.addAll(allIds);
    });
  }

  void deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }
}
