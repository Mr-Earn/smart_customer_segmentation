import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({
    super.key,
    required this.customer,
    this.isFavorite = false,
    this.initialNote = '',
    this.onToggleFavorite,
    this.onSaveNote,
  });

  final Customer customer;
  final bool isFavorite;
  final String initialNote;
  final VoidCallback? onToggleFavorite;
  final Future<void> Function(String note)? onSaveNote;

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  late final TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final segment = customerSegments.firstWhere(
      (item) => item.name == customer.segmentName,
    );
    final initials = customer.name
        .split(' ')
        .map((part) => part[0])
        .take(2)
        .join();
    final recommendation = switch (customer.segmentName) {
      'Champions' => 'Thank them with early access to your next launch.',
      'Regulars' => 'Reward their consistency with a loyalty milestone.',
      'At risk' => 'Try a personal win-back offer before they lapse.',
      _ => 'Welcome them with a second-purchase incentive.',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer profile'),
        actions: [
          if (widget.onToggleFavorite != null)
            IconButton(
              tooltip: widget.isFavorite
                  ? 'Remove from saved'
                  : 'Save customer',
              onPressed: widget.onToggleFavorite,
              icon: Icon(
                widget.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: segment.color.withValues(alpha: 0.45),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: forest,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  customer.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  customer.email,
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: segment.color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    segment.name,
                    style: const TextStyle(
                      color: forest,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const PageHeading(
            eyebrow: 'RFM SNAPSHOT',
            title: 'Customer value',
            subtitle: 'Recency, frequency, and monetary value.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ProfileMetric(
                  label: 'LIFETIME SPEND',
                  value: formatRand(customer.lifetimeSpend),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileMetric(
                  label: 'ORDERS',
                  value: '${customer.orderCount}',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProfileMetric(
            label: 'DAYS SINCE LAST PURCHASE',
            value: '${customer.daysSincePurchase} days',
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 10),
          _ProfileMetric(
            label: 'RFM SCORE',
            value: '${customer.rfmScore} / 15 - ${customer.rfmTier}',
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 10),
          _ProfileMetric(
            label: 'CHURN RISK',
            value: '${customer.churnRiskScore}% - ${customer.churnRiskTier}',
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lime.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: forest, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested next action',
                        style: TextStyle(
                          color: forest,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        recommendation,
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
          const Text(
            'Customer notes',
            style: TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Add a private note about this customer',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.onSaveNote == null
                  ? null
                  : () async {
                      await widget.onSaveNote!(noteController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note saved on this device.'),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save note'),
              style: FilledButton.styleFrom(backgroundColor: forest),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: forest, size: 19),
        const SizedBox(width: 10),
        Expanded(
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
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
