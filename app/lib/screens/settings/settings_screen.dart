import 'package:flutter/material.dart';
import 'server_settings_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Server URL'),
            subtitle: const Text('Change the API server address'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showServerSettingsSheet(context),
          ),
        ],
      ),
    );
  }
}
