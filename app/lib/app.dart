import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/havala/havala_list_screen.dart';
import 'screens/daily_silak/daily_silak_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'update/providers/update_provider.dart';
import 'update/widgets/update_dialog.dart';

class DV1520App extends ConsumerWidget {
  const DV1520App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'DV.1520',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: authState.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        data: (state) {
          switch (state.status) {
            case AuthStatus.loading:
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            case AuthStatus.loggedOut:
              return const LoginScreen();
            case AuthStatus.loggedIn:
              return const RootShell();
          }
        },
      ),
    );
  }
}

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final updateAvailable = await ref.read(updateAvailableProvider.future);
      if (!updateAvailable || !mounted) return;
      final versionInfo = await ref.read(latestVersionProvider.future);
      if (!mounted) return;
      await showUpdateDialog(context, versionInfo);
    } catch (_) {
      // Update check is best-effort; silently ignore network/server errors
      // so a flaky connection never blocks app startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = ref.watch(authProvider).value?.user?.username;
    final showDailySilak = username == 'Vinay';

    final screens = [
      const DashboardScreen(),
      const HavalaListScreen(),
      if (showDailySilak) const DailySilakListScreen(),
      if (kDebugMode) const SettingsScreen(),
    ];

    if (_index >= screens.length) _index = 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.swap_horiz_outlined), selectedIcon: Icon(Icons.swap_horiz), label: 'Havala'),
          if (showDailySilak)
            const NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Daily Silak'),
          if (kDebugMode) const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
