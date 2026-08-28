/// VCTCrypt - Flutter GUI Version
/// Author: Tommy
/// Material Design 3 + Adaptive Layout (mobile & desktop)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
  // v1.3.0 personalization.
  final seedColorValue = prefs.getInt('seedColor');
  var startTab = prefs.getInt('startTab') ?? 0;
  // v1.5.0 migration: a Notes tab was inserted at index 2, Settings
  // moved to 3. Remap old stored "2 = Settings" to 3.
  if (startTab == 2 && !prefs.containsKey('startTab.v15')) {
    startTab = 3;
    await prefs.setInt('startTab', 3);
  }
  await prefs.setBool('startTab.v15', true);
  // v1.6.0 migration: the Keys tab was inserted at index 2 - Notes
  // moved to 3 and Settings to 4. Remap the stored v1.5 values.
  if (!prefs.containsKey('startTab.v16')) {
    if (startTab == 2) startTab = 3; // was Notes
    if (startTab == 3) startTab = 4; // was Settings
    await prefs.setInt('startTab', startTab);
    await prefs.setBool('startTab.v16', true);
  }
  final clipboardClearSeconds = prefs.getInt('clipClear') ?? 30;
  final onboarded = prefs.getBool('onboarded') ?? false;

  runApp(VCTCryptApp(
    initialLang:
        langCode == 'zh' ? AppLanguage.chinese : AppLanguage.english,
    initialThemeIndex: themeIndex,
    initialAutoLockMinutes: autoLockMinutes,
    initialSeedColor:
        seedColorValue == null ? null : Color(seedColorValue),
    initialStartTab: startTab,
    initialClipboardClearSeconds: clipboardClearSeconds,
    initialOnboarded: onboarded,
  ));
}

class VCTCryptApp extends StatefulWidget {
  final AppLanguage initialLang;
  final int initialThemeIndex;
  final int initialAutoLockMinutes;
  final Color? initialSeedColor;
  final int initialStartTab;
  final int initialClipboardClearSeconds;
  final bool initialOnboarded;

  const VCTCryptApp({
    super.key,
    required this.initialLang,
    required this.initialThemeIndex,
    required this.initialAutoLockMinutes,
    this.initialSeedColor,
    this.initialStartTab = 0,
    this.initialClipboardClearSeconds = 30,
    this.initialOnboarded = false,
  });

  @override
  State<VCTCryptApp> createState() => _VCTCryptAppState();

  static _VCTCryptAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_VCTCryptAppState>()!;
  }
}

class _VCTCryptAppState extends State<VCTCryptApp> {
  static const Color _defaultSeedColor = Color(0xFF4A148C);

  late AppLanguage _lang;
  late int _themeIndex;
  late int _autoLockMinutes;
  Color? _seedColor;
  late int _startTab;
  late int _clipboardClearSeconds;
  late bool _onboarded;
  late SharedPreferences _prefs;
  Timer? _idleTimer;
  Timer? _clipboardTimer;

  /// Pulses whenever the auto-lock fires. Screens listen to this and
  /// clear any password fields they hold.
  final ValueNotifier<int> lockPulse = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
    _themeIndex = widget.initialThemeIndex;
    _autoLockMinutes = widget.initialAutoLockMinutes;
    _seedColor = widget.initialSeedColor;
    _startTab = widget.initialStartTab;
    _clipboardClearSeconds = widget.initialClipboardClearSeconds;
    _onboarded = widget.initialOnboarded;
    _loadPrefs();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _clipboardTimer?.cancel();
    lockPulse.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppLanguage get lang => _lang;
  int get themeIndex => _themeIndex;
  int get autoLockMinutes => _autoLockMinutes;
  Color? get seedColor => _seedColor;
  int get startTab => _startTab;
  int get clipboardClearSeconds => _clipboardClearSeconds;
  bool get onboarded => _onboarded;
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

  /// v1.3.0: change the accent (seed) color; null resets to default.
  Future<void> setSeedColor(Color? color) async {
    setState(() => _seedColor = color);
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove('seedColor');
    } else {
      await prefs.setInt('seedColor', color.value);
    }
  }

  /// v1.3.0: which tab the app opens on (0=encrypt, 1=decrypt, 2=settings).
  Future<void> setStartTab(int index) async {
    setState(() => _startTab = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('startTab', index);
  }

  /// v1.3.0: clipboard auto-clear delay in seconds; -1 = off.
  Future<void> setClipboardClearSeconds(int seconds) async {
    setState(() => _clipboardClearSeconds = seconds);
    if (seconds <= 0) _clipboardTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clipClear', seconds);
  }

  /// v1.3.0: mark the onboarding as seen (stored locally).
  Future<void> markOnboarded() async {
    if (_onboarded) return;
    _onboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
  }

  /// v1.3.0: KeePass-style clipboard protection - after copying a
  /// generated password, wipe the clipboard once the delay elapses.
  void armClipboardClear() {
    _clipboardTimer?.cancel();
    if (_clipboardClearSeconds <= 0) return;
    _clipboardTimer = Timer(Duration(seconds: _clipboardClearSeconds), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
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
    // M3 color scheme - user-selectable seed (v1.3.0), deep indigo default
    final seed = _seedColor ?? _defaultSeedColor;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: strings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        // v2.0.0: bundle Noto Sans SC so Chinese renders consistently
        // on every Windows install (no OS font fallback mismatch).
        fontFamily: 'Noto Sans SC',
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
        // v2.0.0: bundle Noto Sans SC so Chinese renders consistently
        // on every Windows install (no OS font fallback mismatch).
        fontFamily: 'Noto Sans SC',
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
        // Not const so app-state changes (language, accent color)
        // propagate down to the screens immediately.
        child: HomeScreen(),
      ),
    );
  }
}
