import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'segment_builder_page.dart';
import 'segment_compare_page.dart';
import 'segment_detail_page.dart';

class SegmentsPage extends StatelessWidget {
  const SegmentsPage({
    super.key,
    required this.customSegments,
    required this.onSegmentCreated,
    required this.onSignOut,
    required this.customers,
    required this.settings,
  });

  final List<CustomerSegment> customSegments;
  final ValueChanged<CustomerSegment> onSegmentCreated;
  final VoidCallback onSignOut;
  final List<Customer> customers;
  final SegmentationSettings settings;

  Future<void> openBuilder(BuildContext context) async {
    final segment = await Navigator.of(context).push<CustomerSegment>(
      MaterialPageRoute<CustomerSegment>(
        builder: (_) => SegmentBuilderPage(customers: customers),
      ),
    );
    if (segment != null) onSegmentCreated(segment);
  }

  void openDetails(BuildContext context, CustomerSegment segment) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            SegmentDetailPage(segment: segment, customers: customers),
      ),
    );
  }

  void openComparison(BuildContext context, List<CustomerSegment> segments) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            SegmentComparePage(segments: segments, customers: customers),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSegments = [...customerSegments, ...customSegments];
    final totalCustomers = customers.length;
    return AppPage(
      children: [
        BrandHeader(onSignOut: onSignOut),
        const SizedBox(height: 28),
        const PageHeading(
          eyebrow: 'AUDIENCE GROUPS',
          title: 'Segments',
          subtitle: 'Explore customer value and build precise audiences.',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CORE AUDIENCE',
                      style: TextStyle(
                        color: Color(0xFFB7C9BD),
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '$totalCustomers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'using ${settings.algorithm == SegmentationAlgorithm.rfm ? 'RFM scoring' : 'rule-based segmentation'}',
                      style: const TextStyle(
                        color: Color(0xFFB7C9BD),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.donut_large_rounded, color: lime, size: 36),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => openBuilder(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Build a segment'),
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: allSegments.length < 2
              ? null
              : () => openComparison(context, allSegments),
          icon: const Icon(Icons.compare_arrows_rounded),
          label: const Text('Compare segments'),
          style: OutlinedButton.styleFrom(
            foregroundColor: forest,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final segment in allSegments)
          _SegmentTile(
            segment: segment,
            customerCount: membersOf(segment, customers).length,
            onTap: () => openDetails(context, segment),
          ),
        if (customSegments.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Custom segment sizes are based on the 8 sample profiles.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    required this.customerCount,
    required this.onTap,
  });

  final CustomerSegment segment;
  final int customerCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SegmentIcon(segment: segment),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.name,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      segment.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$customerCount customers',
                      style: const TextStyle(
                        color: forest,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRand(segment.averageSpend),
                    style: const TextStyle(
                      color: forest,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'avg. spend',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: muted, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}
