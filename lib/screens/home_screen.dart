/// VCTCrypt - Home Screen with Adaptive Layout
/// Mobile: BottomNavigationBar | Desktop: NavigationRail
///
/// v1.5.0: fourth tab (Secure Notes) inserted at index 2; desktop
/// keyboard shortcuts Ctrl+1..4 (switch tab) and Ctrl+L (panic lock).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../widgets/onboarding.dart';
import 'encrypt_screen.dart';
import 'decrypt_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final app = VCTCryptApp.of(context);
    // v1.3.0: user-selected start page. v1.5.0: 0..3 (Notes added).
    _currentIndex = app.startTab.clamp(0, 3);
    // v1.3.0: show the onboarding guide once, on first launch.
    if (!app.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showOnboarding(context, firstLaunch: true);
        await VCTCryptApp.of(context).markOnboarded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = VCTCryptApp.of(context);
    final strings = appState.strings;
    final theme = Theme.of(context);

    // Not const: rebuilds when the app state (language, accent color)
    // changes so the screens pick up fresh strings.
    final screens = <Widget>[
      EncryptScreen(),
      DecryptScreen(),
      const NotesScreen(),
      SettingsScreen(strings: strings),
    ];

    // v1.5.0: desktop keyboard shortcuts. CallbackShortcuts takes
    // plain void callbacks (not Intents). `control` maps to Cmd on
    // macOS automatically. Bare digits are NOT bound so typing in
    // password fields can never switch tabs.
    Widget withShortcuts(Widget child) {
      if (Platform.isIOS || Platform.isAndroid) return child;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.digit1, control: true):
              () => _switchTab(0),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true):
              () => _switchTab(1),
          const SingleActivator(LogicalKeyboardKey.digit3, control: true):
              () => _switchTab(2),
          const SingleActivator(LogicalKeyboardKey.digit4, control: true):
              () => _switchTab(3),
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
            VCTCryptApp.of(context).panicLock();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.panicLocked)),
            );
          },
        },
        child: Focus(autofocus: true, child: child),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        if (isDesktop) {
          return withShortcuts(Scaffold(
            body: Row(
              children: [
                ColoredBox(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _currentIndex = i),
                    extended: constraints.maxWidth >= 1100,
                    minExtendedWidth: 220,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 16),
                      child: Column(
                        children: [
                          Icon(Icons.shield,
                              size: 40, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            strings.appName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.lock_outline),
                        selectedIcon: const Icon(Icons.lock),
                        label: Text(strings.navEncrypt),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.lock_open_outlined),
                        selectedIcon: const Icon(Icons.lock_open),
                        label: Text(strings.navDecrypt),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        selectedIcon: const Icon(Icons.sticky_note_2),
                        label: Text(strings.navNotes),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
                        label: Text(strings.navSettings),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: screens[_currentIndex]),
              ],
            ),
          ));
        }

        // Mobile layout
        return withShortcuts(Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) =>
                setState(() => _currentIndex = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.lock_outline),
                selectedIcon: const Icon(Icons.lock),
                label: strings.navEncrypt,
              ),
              NavigationDestination(
                icon: const Icon(Icons.lock_open_outlined),
                selectedIcon: const Icon(Icons.lock_open),
                label: strings.navDecrypt,
              ),
              NavigationDestination(
                icon: const Icon(Icons.sticky_note_2_outlined),
                selectedIcon: const Icon(Icons.sticky_note_2),
                label: strings.navNotes,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: strings.navSettings,
              ),
            ],
          ),
        ));
      },
    );
  }
  void _switchTab(int index) {
    setState(() => _currentIndex = index.clamp(0, 3));
  }
}
