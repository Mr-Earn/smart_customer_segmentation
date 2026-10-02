import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'customer_profile_page.dart';
import 'campaign_draft_page.dart';

class SegmentDetailPage extends StatelessWidget {
  const SegmentDetailPage({
    super.key,
    required this.segment,
    required this.customers,
  });

  final CustomerSegment segment;
  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    final members = membersOf(segment, customers);
    final suggestion = switch (segment.name) {
      'Champions' => 'Offer early access or a referral reward.',
      'Regulars' => 'Use a loyalty milestone to encourage the next visit.',
      'At risk' =>
        'Send a personal win-back offer while the relationship is warm.',
      'New customers' =>
        'Make the second purchase easy with a welcome incentive.',
      _ => 'Review this group and tailor a message to its defining rule.',
    };

    return Scaffold(
      appBar: AppBar(title: Text(segment.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              SegmentIcon(segment: segment, size: 52),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.name,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      segment.description,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SegmentMetric(
                  label: 'AUDIENCE SIZE',
                  value: '${segment.count}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SegmentMetric(
                  label: 'AVG. SPEND',
                  value: formatRand(segment.averageSpend),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SegmentMetric(
            label: 'SAMPLE PROFILES MATCHING',
            value: '${members.length} of ${customers.length}',
          ),
          if (segment.rule case final rule?) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rule: ${rule.summary}',
                style: const TextStyle(
                  color: forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: lime.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: forest, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested play',
                        style: TextStyle(
                          color: forest,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion,
                        style: const TextStyle(
                          color: forest,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CampaignDraftPage(segment: segment),
              ),
            ),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Draft a campaign'),
            style: OutlinedButton.styleFrom(
              foregroundColor: forest,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sample members',
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy member emails',
                onPressed: members.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: members.map((item) => item.email).join('\n'),
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${members.length} emails copied.'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.content_copy_rounded),
              ),
              IconButton(
                tooltip: 'Copy member CSV',
                onPressed: members.isEmpty
                    ? null
                    : () async {
                        final csv = [
                          'name,email,segment,lifetime_spend_zar,orders,days_since_purchase',
                          for (final customer in members)
                            [
                              _csvField(customer.name),
                              _csvField(customer.email),
                              _csvField(segment.name),
                              customer.lifetimeSpend,
                              customer.orderCount,
                              customer.daysSincePurchase,
                            ].join(','),
                        ].join('\n');
                        await Clipboard.setData(ClipboardData(text: csv));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Member CSV copied.')),
                          );
                        }
                      },
                icon: const Icon(Icons.table_view_rounded),
              ),
            ],
          ),
          for (final customer in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: segment.color.withValues(alpha: 0.4),
                child: Text(
                  customer.name
                      .split(' ')
                      .map((part) => part[0])
                      .take(2)
                      .join(),
                  style: const TextStyle(
                    color: forest,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(customer.name),
              subtitle: Text(customer.email),
              trailing: Text(formatRand(customer.lifetimeSpend)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CustomerProfilePage(customer: customer),
                ),
              ),
            ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No sample profiles match this segment yet.',
                style: TextStyle(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentMetric extends StatelessWidget {
  const _SegmentMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

String _csvField(String value) => '"${value.replaceAll('"', '""')}"';
