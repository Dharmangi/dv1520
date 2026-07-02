import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/havala/havala_list_screen.dart';
import 'screens/daily_silak/daily_silak_list_screen.dart';
import 'screens/settings/settings_screen.dart';

class DV1520App extends StatelessWidget {
  const DV1520App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DV1520',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    HavalaListScreen(),
    DailySilakListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.swap_horiz_outlined), selectedIcon: Icon(Icons.swap_horiz), label: 'Havala'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Daily Silak'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
