import 'package:flutter/material.dart';
import 'export_pdf_screen.dart';
import 'manage_categories_screen.dart';
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
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            subtitle: const Text('Add, edit, or remove income/expense categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export Customer Statement'),
            subtitle: const Text('Generate a PDF statement for a customer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportPdfScreen()),
            ),
          ),
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
