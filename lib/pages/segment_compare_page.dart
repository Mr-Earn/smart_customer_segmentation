import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';

class SegmentComparePage extends StatefulWidget {
  const SegmentComparePage({
    super.key,
    required this.segments,
    required this.customers,
  });

  final List<CustomerSegment> segments;
  final List<Customer> customers;

  @override
  State<SegmentComparePage> createState() => _SegmentComparePageState();
}

class _SegmentComparePageState extends State<SegmentComparePage> {
  late CustomerSegment first;
  late CustomerSegment second;

  @override
  void initState() {
    super.initState();
    first = widget.segments.first;
    second = widget.segments[1];
  }

  @override
  Widget build(BuildContext context) {
    final firstMembers = membersOf(first, widget.customers);
    final secondMembers = membersOf(second, widget.customers);
    final firstRfm = firstMembers.isEmpty
        ? 0
        : (firstMembers.fold<int>(
                    0,
                    (sum, customer) => sum + customer.rfmScore,
                  ) /
                  firstMembers.length)
              .round();
    final secondRfm = secondMembers.isEmpty
        ? 0
        : (secondMembers.fold<int>(
                    0,
                    (sum, customer) => sum + customer.rfmScore,
                  ) /
                  secondMembers.length)
              .round();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare segments')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'AUDIENCE COMPARISON',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compare performance',
            style: TextStyle(
              color: ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _SegmentPicker(
            label: 'First segment',
            segments: widget.segments,
            selected: first,
            onChanged: (value) => setState(() => first = value),
          ),
          const SizedBox(height: 10),
          _SegmentPicker(
            label: 'Second segment',
            segments: widget.segments,
            selected: second,
            onChanged: (value) => setState(() => second = value),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              Expanded(
                child: Text(
                  first.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  second.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CompareRow(
            label: 'Audience size',
            first: '${first.count}',
            second: '${second.count}',
          ),
          _CompareRow(
            label: 'Average spend',
            first: formatRand(first.averageSpend),
            second: formatRand(second.averageSpend),
          ),
          _CompareRow(
            label: 'Sample profiles',
            first: '${firstMembers.length}',
            second: '${secondMembers.length}',
          ),
          _CompareRow(
            label: 'Average RFM score',
            first: '$firstRfm / 15',
            second: '$secondRfm / 15',
          ),
          const SizedBox(height: 12),
          Text(
            'Metrics are calculated from ${widget.customers.length} customer records.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SegmentPicker extends StatelessWidget {
  const _SegmentPicker({
    required this.label,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<CustomerSegment> segments;
  final CustomerSegment selected;
  final ValueChanged<CustomerSegment> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<CustomerSegment>(
        initialValue: selected,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final segment in segments)
            DropdownMenuItem(value: segment, child: Text(segment.name)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.first,
    required this.second,
  });

  final String label;
  final String first;
  final String second;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE1E6DF))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            first,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            second,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
