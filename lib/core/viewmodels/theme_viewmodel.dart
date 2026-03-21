import 'dart:async';
import 'package:flutter/material.dart';

/// Switches between light and dark theme based on the time of day.
/// Dark mode is active from 18:00 to 05:59 (inclusive).
class ThemeViewModel extends ChangeNotifier {
  static const int _darkStart = 18; // 6 pm
  static const int _lightStart = 6; //  6 am

  Timer? _timer;
  late bool _isDark;

  ThemeViewModel() {
    _isDark = _computeIsDark();
    _scheduleNextTransition();
  }

  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  static bool _computeIsDark() {
    final hour = DateTime.now().hour;
    return hour >= _darkStart || hour < _lightStart;
  }

  /// Schedules a one-shot timer that fires at the next 6 am or 6 pm,
  /// then reschedules itself for the following transition.
  void _scheduleNextTransition() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Candidate transition times today
    final todayLight = today.add(const Duration(hours: _lightStart));
    final todayDark = today.add(const Duration(hours: _darkStart));

    DateTime next;
    if (now.isBefore(todayLight)) {
      next = todayLight;
    } else if (now.isBefore(todayDark)) {
      next = todayDark;
    } else {
      next = todayLight.add(const Duration(days: 1));
    }

    final delay = next.difference(now);
    _timer = Timer(delay, () {
      _isDark = _computeIsDark();
      notifyListeners();
      _scheduleNextTransition();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
