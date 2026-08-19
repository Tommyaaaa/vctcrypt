/// VCTCrypt - Home Screen with Adaptive Layout
/// Mobile: BottomNavigationBar | Desktop: NavigationRail

import 'package:flutter/material.dart';

import '../main.dart';
import 'encrypt_screen.dart';
import 'decrypt_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = VCTCryptApp.of(context);
    final strings = appState.strings;
    final theme = Theme.of(context);

    final screens = <Widget>[
      const EncryptScreen(),
      const DecryptScreen(),
      SettingsScreen(strings: strings),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        if (isDesktop) {
          return Scaffold(
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
          );
        }

        // Mobile layout
        return Scaffold(
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
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: strings.navSettings,
              ),
            ],
          ),
        );
      },
    );
  }
}
