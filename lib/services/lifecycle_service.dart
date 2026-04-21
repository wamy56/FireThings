import 'package:flutter/material.dart' show DateUtils;

import '../models/asset.dart';
import '../models/asset_type.dart';

class LifecycleService {
  LifecycleService._();
  static final LifecycleService instance = LifecycleService._();

  DateTime? calculateNextServiceDue({
    required DateTime lastServiceDate,
    required AssetType? assetType,
  }) {
    final months = assetType?.defaultServiceIntervalMonths;
    if (months == null) return null;
    return _addMonthsSafely(lastServiceDate, months);
  }

  ({DateTime start, DateTime end})? calculateServiceWindow({
    required DateTime lastServiceDate,
    required AssetType? assetType,
  }) {
    final months = assetType?.defaultServiceIntervalMonths;
    if (months == null) return null;
    return (
      start: _addMonthsSafely(lastServiceDate, months - 1),
      end: _addMonthsSafely(lastServiceDate, months + 1),
    );
  }

  bool isServiceOverdue({
    required Asset asset,
    required AssetType? assetType,
  }) {
    if (asset.lastServiceDate == null) return false;
    final window = calculateServiceWindow(
      lastServiceDate: asset.lastServiceDate!,
      assetType: assetType,
    );
    if (window == null) return false;
    return DateTime.now().isAfter(window.end);
  }

  ({DateTime start, DateTime end}) calculateBs5839ServiceWindow(
      DateTime lastServiceDate) {
    return (
      start: _addMonthsSafely(lastServiceDate, 5),
      end: _addMonthsSafely(lastServiceDate, 7),
    );
  }

  bool isBs5839ServiceOverdue(DateTime? lastServiceDate) {
    if (lastServiceDate == null) return false;
    final window = calculateBs5839ServiceWindow(lastServiceDate);
    return DateTime.now().isAfter(window.end);
  }

  bool isEndOfLifeApproaching({
    required Asset asset,
    required AssetType? assetType,
  }) {
    final lifespanYears =
        asset.expectedLifespanYears ?? assetType?.defaultLifespanYears;
    if (lifespanYears == null || asset.installDate == null) return false;
    final ageYears =
        DateTime.now().difference(asset.installDate!).inDays / 365.25;
    return ageYears > (lifespanYears - 1);
  }

  DateTime _addMonthsSafely(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final newYear = date.year + (totalMonths ~/ 12);
    final newMonth = (totalMonths % 12) + 1;
    final daysInNewMonth = DateUtils.getDaysInMonth(newYear, newMonth);
    final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
  }
}
