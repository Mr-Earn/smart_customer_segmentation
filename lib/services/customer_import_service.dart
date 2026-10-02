import 'dart:convert';

import 'package:csv/csv.dart';

import '../models.dart';

class CustomerImportService {
  List<Customer> parseCsv(String source) {
    final rows = Csv(autoDetect: true).decode(source);
    if (rows.length < 2) {
      throw const FormatException(
        'The CSV needs a header and at least one row.',
      );
    }
    final headers = rows.first
        .map((cell) => _normalizeHeader(cell.toString()))
        .toList();
    if (!headers.contains('name') || !headers.contains('email')) {
      throw const FormatException('CSV must include name and email columns.');
    }

    final customers = <Customer>[];
    for (final row in rows.skip(1)) {
      final values = <String, String>{};
      for (
        var index = 0;
        index < headers.length && index < row.length;
        index++
      ) {
        values[headers[index]] = row[index]?.toString().trim() ?? '';
      }
      final name = _first(values, ['name', 'fullname', 'customername']);
      final email = _first(values, ['email', 'emailaddress']).toLowerCase();
      if (name.isEmpty || !email.contains('@')) continue;

      customers.add(
        Customer(
          name: name,
          email: email,
          segmentName: _first(values, [
            'segmentname',
            'segment',
          ], fallback: 'New customers'),
          lifetimeSpend: _number(values, [
            'lifetimespend',
            'spend',
            'totalspend',
          ]),
          orderCount: _number(values, ['ordercount', 'orders', 'frequency']),
          daysSincePurchase: _number(values, [
            'dayssincepurchase',
            'recencydays',
            'recency',
          ]),
        ),
      );
    }
    if (customers.isEmpty) {
      throw const FormatException('No valid customer rows were found.');
    }
    return customers;
  }

  List<Customer> parseJson(String source) {
    final decoded = jsonDecode(source);
    final records = switch (decoded) {
      List<dynamic> list => list,
      Map<String, dynamic> object when object['customers'] is List<dynamic> =>
        object['customers'] as List<dynamic>,
      _ => throw const FormatException(
        'API JSON must be a customer array or contain a customers array.',
      ),
    };
    final customers = <Customer>[];
    for (final record in records) {
      if (record is! Map<String, dynamic>) continue;
      final normalized = {
        for (final entry in record.entries)
          _normalizeHeader(entry.key): entry.value?.toString().trim() ?? '',
      };
      final name = _first(normalized, ['name', 'fullname', 'customername']);
      final email = _first(normalized, ['email', 'emailaddress']).toLowerCase();
      if (name.isEmpty || !email.contains('@')) continue;
      customers.add(
        Customer(
          name: name,
          email: email,
          segmentName: _first(normalized, [
            'segmentname',
            'segment',
          ], fallback: 'New customers'),
          lifetimeSpend: _number(normalized, [
            'lifetimespend',
            'spend',
            'totalspend',
          ]),
          orderCount: _number(normalized, [
            'ordercount',
            'orders',
            'frequency',
          ]),
          daysSincePurchase: _number(normalized, [
            'dayssincepurchase',
            'recencydays',
            'recency',
          ]),
        ),
      );
    }
    if (customers.isEmpty) {
      throw const FormatException(
        'The API response contains no valid customers.',
      );
    }
    return customers;
  }

  String _normalizeHeader(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  String _first(
    Map<String, String> values,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = values[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  int _number(Map<String, String> values, List<String> keys) {
    final raw = _first(values, keys).replaceAll(RegExp(r'[^0-9.-]'), '');
    return (double.tryParse(raw) ?? 0).round().clamp(0, 1000000000);
  }
}
