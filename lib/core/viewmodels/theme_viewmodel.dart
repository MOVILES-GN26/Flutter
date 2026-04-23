import 'dart:async';
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

/// Drives the MaterialApp's [ThemeMode].
///
/// Three user-selectable modes are persisted via [PreferencesService]:
///   * [ThemePreference.auto]  — switches automatically at 06:00 and 18:00.
///   * [ThemePreference.light] — always light.
///   * [ThemePreference.dark]  — always dark.
class ThemeViewModel extends ChangeNotifier {
  static const int _darkStart = 18; // 6 pm
  static const int _lightStart = 6; // 6 am

  Timer? _timer;
  late ThemePreference _preference;
  late bool _isDark;

  ThemeViewModel() {
    _preference = PreferencesService.instance.themePreference;
    _isDark = _computeIsDark();
    if (_preference == ThemePreference.auto) {
      _scheduleNextTransition();
    }
  }

  ThemePreference get preference => _preference;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Change the user's theme preference and persist it.
  /// Cancels/schedules the auto-transition timer as needed.
  Future<void> setPreference(ThemePreference pref) async {
    if (_preference == pref) return;
    _preference = pref;
    await PreferencesService.instance.setThemePreference(pref);

    _timer?.cancel();
    _timer = null;

    _isDark = _computeIsDark();
    if (pref == ThemePreference.auto) {
      _scheduleNextTransition();
    }
    notifyListeners();
  }

  bool _computeIsDark() {
    switch (_preference) {
      case ThemePreference.light:
        return false;
      case ThemePreference.dark:
        return true;
      case ThemePreference.auto:
        final hour = DateTime.now().hour;
        return hour >= _darkStart || hour < _lightStart;
    }
  }

  /// Schedules a one-shot timer that fires at the next 6 am or 6 pm,
  /// then reschedules itself for the following transition.
  /// Only runs while the preference is [ThemePreference.auto].
  void _scheduleNextTransition() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
