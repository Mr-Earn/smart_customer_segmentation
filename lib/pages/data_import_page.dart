import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../models.dart';
import '../services/customer_import_service.dart';

class DataImportPage extends StatefulWidget {
  const DataImportPage({super.key, required this.onImport});

  final Future<void> Function(List<Customer> customers, String source) onImport;

  @override
  State<DataImportPage> createState() => _DataImportPageState();
}

class _DataImportPageState extends State<DataImportPage> {
  final endpointController = TextEditingController();
  final tokenController = TextEditingController();
  final importer = CustomerImportService();
  bool isLoading = false;
  List<Customer> preview = [];
  String? source;
  String? error;

  @override
  void dispose() {
    endpointController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> pickCsv() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    await _parse(() async {
      final contents = utf8.decode(await file.readAsBytes());
      return (importer.parseCsv(contents), file.name);
    });
  }

  Future<void> fetchApi() async {
    final uri = Uri.tryParse(endpointController.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      setState(() => error = 'Use an HTTPS endpoint or a localhost URL.');
      return;
    }

    await _parse(() async {
      final token = tokenController.text.trim();
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json, text/csv',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException('API returned HTTP ${response.statusCode}.');
      }
      final contentType = response.headers['content-type'] ?? '';
      final customers = contentType.contains('csv')
          ? importer.parseCsv(response.body)
          : importer.parseJson(response.body);
      return (customers, uri.host);
    });
  }

  Future<void> _parse(
    Future<(List<Customer>, String)> Function() operation,
  ) async {
    setState(() {
      isLoading = true;
      error = null;
      preview = [];
    });
    try {
      final result = await operation();
      if (!mounted) return;
      setState(() {
        preview = result.$1;
        source = result.$2;
      });
    } on FormatException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Could not read the source. Check the file or endpoint.',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> commitImport() async {
    await widget.onImport(preview, source ?? 'Import');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${preview.length} customers imported.')),
    );
    setState(() => preview = []);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import customers')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'DATA INTAKE',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bring your audience in.',
          style: TextStyle(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'CSV needs name and email columns. Spend, orders, recency, and segment are optional.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 20),
        _ImportAction(
          icon: Icons.upload_file_rounded,
          title: 'Upload CSV',
          subtitle: 'Choose a .csv file from this device',
          onTap: isLoading ? null : pickCsv,
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR CONNECT AN API',
                style: TextStyle(color: muted, fontSize: 9, letterSpacing: 0.7),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: endpointController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'HTTPS endpoint',
            hintText: 'https://api.example.com/customers',
            prefixIcon: Icon(Icons.link_rounded),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: tokenController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Bearer token (optional)',
            prefixIcon: Icon(Icons.key_rounded),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: isLoading ? null : fetchApi,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Fetch customers'),
          style: FilledButton.styleFrom(backgroundColor: forest),
        ),
        if (isLoading) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(error!, style: const TextStyle(color: Color(0xFFAD4A31))),
        ],
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${preview.length} ready to import',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                source ?? '',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final customer in preview.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded, color: forest),
              title: Text(customer.name),
              subtitle: Text('${customer.email}  |  ${customer.segmentName}'),
              trailing: Text(formatRand(customer.lifetimeSpend)),
            ),
          FilledButton.icon(
            onPressed: commitImport,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Import preview'),
            style: FilledButton.styleFrom(
              backgroundColor: forest,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ImportAction extends StatelessWidget {
  const _ImportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: forest, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    ),
  );
}
