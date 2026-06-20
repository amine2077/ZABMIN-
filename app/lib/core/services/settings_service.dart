import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  double get cpuThreshold => _prefs?.getDouble('cpu_threshold') ?? 85.0;
  double get ramThreshold => _prefs?.getDouble('ram_threshold') ?? 90.0;
  double get diskThreshold => _prefs?.getDouble('disk_threshold') ?? 95.0;
  double get netThresholdMbS => _prefs?.getDouble('net_threshold_mb_s') ?? 10.0;
  int get cpuConsecutiveSeconds =>
      _prefs?.getInt('cpu_consecutive_seconds') ?? 30;

  bool get minimizeToTray => _prefs?.getBool('minimize_to_tray') ?? true;
  bool get toastNotifications => _prefs?.getBool('toast_notifications') ?? true;
  bool get launchAtStartupEnabled =>
      _prefs?.getBool('launch_at_startup') ?? false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setCpuThreshold(double value) async {
    await _prefs?.setDouble('cpu_threshold', value);
    notifyListeners();
  }

  Future<void> setRamThreshold(double value) async {
    await _prefs?.setDouble('ram_threshold', value);
    notifyListeners();
  }

  Future<void> setDiskThreshold(double value) async {
    await _prefs?.setDouble('disk_threshold', value);
    notifyListeners();
  }

  Future<void> setNetThresholdMbS(double value) async {
    await _prefs?.setDouble('net_threshold_mb_s', value);
    notifyListeners();
  }

  Future<void> setCpuConsecutiveSeconds(int value) async {
    await _prefs?.setInt('cpu_consecutive_seconds', value);
    notifyListeners();
  }

  Future<void> setMinimizeToTray(bool value) async {
    await _prefs?.setBool('minimize_to_tray', value);
    notifyListeners();
  }

  Future<void> setToastNotifications(bool value) async {
    await _prefs?.setBool('toast_notifications', value);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    await _prefs?.setBool('launch_at_startup', value);
    notifyListeners();
  }
}
