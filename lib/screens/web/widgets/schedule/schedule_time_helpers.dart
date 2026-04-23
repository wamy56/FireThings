import 'package:flutter/material.dart';

TimeOfDay? parseScheduledTime(String? time) {
  if (time == null || time.trim().isEmpty) return null;
  final t = time.trim().toUpperCase();

  final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
  if (match24 != null) {
    final h = int.parse(match24.group(1)!);
    final m = int.parse(match24.group(2)!);
    if (h >= 0 && h < 24 && m >= 0 && m < 60) {
      return TimeOfDay(hour: h, minute: m);
    }
  }

  final match12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(t);
  if (match12 != null) {
    var h = int.parse(match12.group(1)!);
    final m = int.parse(match12.group(2)!);
    final ampm = match12.group(3)!;
    if (ampm == 'PM' && h != 12) h += 12;
    if (ampm == 'AM' && h == 12) h = 0;
    if (h >= 0 && h < 24 && m >= 0 && m < 60) {
      return TimeOfDay(hour: h, minute: m);
    }
  }

  return null;
}

int parseDurationMinutes(String? duration) {
  if (duration == null || duration.trim().isEmpty) return 60;
  final d = duration.trim().toLowerCase();

  final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m').firstMatch(d);
  if (hm != null) {
    return int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2)!);
  }

  final decimalHours = RegExp(r'(\d+\.?\d*)\s*h').firstMatch(d);
  if (decimalHours != null) {
    return (double.parse(decimalHours.group(1)!) * 60).round();
  }

  final mins = RegExp(r'(\d+)\s*min').firstMatch(d);
  if (mins != null) {
    return int.parse(mins.group(1)!);
  }

  final wordHours = RegExp(r'(\d+\.?\d*)\s*hour').firstMatch(d);
  if (wordHours != null) {
    return (double.parse(wordHours.group(1)!) * 60).round();
  }

  return 60;
}
