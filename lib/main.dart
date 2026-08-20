/// VCTCrypt - Flutter GUI Version
/// Author: Tommy
/// Material Design 3 + Adaptive Layout (mobile & desktop)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n/strings.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final langCode = prefs.getString('lang') ?? 'en';
  final themeIndex = prefs.getInt('theme') ?? 2; // 0=light, 1=dark, 2=system
  // Auto-lock: minutes of inactivity before clearing entered passwords.
  // -1 = off. Default: 5 minutes.
  final autoLockMinutes = prefs.getInt('autolock') ?? 5;

  runApp(VCTCryptApp(
    initialLang:
        langCode == 'zh' ? AppLanguage.chinese : AppLanguage.english,
    initialThemeIndex: themeIndex,
    initialAutoLockMinutes: autoLockMinutes,
  ));
}

class VCTCryptApp extends StatefulWidget {
  final AppLanguage initialLang;
  final int initialThemeIndex;
  final int initialAutoLockMinutes;

  const VCTCryptApp({
    super.key,
    required this.initialLang,
    required this.initialThemeIndex,
    required this.initialAutoLockMinutes,
  });

  @override
  State<VCTCryptApp> createState() => _VCTCryptAppState();

  static _VCTCryptAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_VCTCryptAppState>()!;
  }
}

class _VCTCryptAppState extends State<VCTCryptApp> {
  late AppLanguage _lang;
  late int _themeIndex;
  late int _autoLockMinutes;
  late SharedPreferences _prefs;
  Timer? _idleTimer;

  /// Pulses whenever the auto-lock fires. Screens listen to this and
  /// clear any password fields they hold.
  final ValueNotifier<int> lockPulse = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
    _themeIndex = widget.initialThemeIndex;
    _autoLockMinutes = widget.initialAutoLockMinutes;
    _loadPrefs();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    lockPulse.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppLanguage get lang => _lang;
  int get themeIndex => _themeIndex;
  int get autoLockMinutes => _autoLockMinutes;
  AppStrings get strings => AppStrings.of(_lang);

  Future<void> changeLanguage(AppLanguage lang) async {
    setState(() => _lang = lang);
    await _prefs.setString('lang', lang.code);
  }

  Future<void> changeTheme(int index) async {
    setState(() => _themeIndex = index);
    await _prefs.setInt('theme', index);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    setState(() => _autoLockMinutes = minutes);
    await _prefs.setInt('autolock', minutes);
    _resetIdleTimer();
  }

  /// Call on any user activity (pointer events) to postpone auto-lock.
  void registerActivity() {
    if (_autoLockMinutes > 0) {
      _resetIdleTimer();
    }
  }

  /// v1.2.0 panic lock: immediately clear every password field in the
  /// app (same pulse the auto-lock uses, fired on demand).
  void panicLock() {
    _resetIdleTimer();
    lockPulse.value++;
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_autoLockMinutes <= 0) return;
    _idleTimer = Timer(Duration(minutes: _autoLockMinutes), () {
      lockPulse.value++;
    });
  }

  ThemeMode get themeMode {
    switch (_themeIndex) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    // M3 color scheme - deep indigo seed for "crypto/security" aesthetic
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A148C),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A148C),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: strings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
      ),
      themeMode: themeMode,
      // Pointer activity anywhere in the app postpones the auto-lock.
      home: Listener(
        onPointerDown: (_) => registerActivity(),
        onPointerHover: (_) => registerActivity(),
        child: const HomeScreen(),
      ),
    );
  }
}
