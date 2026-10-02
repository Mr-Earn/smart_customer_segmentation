import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.onViewSegments,
    required this.onSignOut,
  });

  final VoidCallback onViewSegments;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => AppPage(
    children: [
      BrandHeader(onSignOut: onSignOut),
      const SizedBox(height: 26),
      const Text(
        'Audience,\nat a glance.',
        style: TextStyle(
          color: ink,
          fontSize: 34,
          height: 1.02,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'A clearer view of who comes back.',
        style: TextStyle(color: muted, fontSize: 14),
      ),
      const SizedBox(height: 22),
      const _TotalCustomersCard(),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: MetricTile(
              label: 'AVG. ORDER VALUE',
              value: formatRand(68.40, decimalDigits: 2),
              change: '+4.2%',
              icon: Icons.shopping_bag_outlined,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: MetricTile(
              label: 'RETENTION RATE',
              value: '42.6%',
              change: '+2.1%',
              icon: Icons.autorenew_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 26),
      _SectionHeading(
        title: 'Segment mix',
        action: 'Explore',
        onTap: onViewSegments,
      ),
      const SizedBox(height: 12),
      const SegmentMixPanel(segments: customerSegments),
      const SizedBox(height: 26),
      _SectionHeading(
        title: 'Your segments',
        action: 'See all',
        onTap: onViewSegments,
      ),
      const SizedBox(height: 4),
      for (final segment in [customerSegments[0], customerSegments[2]])
        _SegmentPreview(segment: segment, onTap: onViewSegments),
      const SizedBox(height: 18),
      const _InsightNote(),
    ],
  );
}

class _TotalCustomersCard extends StatelessWidget {
  const _TotalCustomersCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL CUSTOMERS',
                style: TextStyle(
                  color: Color(0xFFB7C9BD),
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '24,860',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 12),
              _GrowthPill(),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const SizedBox(
          width: 104,
          height: 70,
          child: CustomPaint(painter: TrendPainter(color: lime)),
        ),
      ],
    ),
  );
}

class _GrowthPill extends StatelessWidget {
  const _GrowthPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_upward_rounded, size: 12, color: lime),
        SizedBox(width: 3),
        Text(
          '12.8% this month',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: forest,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 36),
        ),
        child: Text(action, style: const TextStyle(fontSize: 12)),
      ),
    ],
  );
}

class _SegmentPreview extends StatelessWidget {
  const _SegmentPreview({required this.segment, required this.onTap});

  final CustomerSegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SegmentIcon(segment: segment, size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${segment.count} customers',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${(segment.count / 24860 * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: muted, size: 19),
        ],
      ),
    ),
  );
}

class _InsightNote extends StatelessWidget {
  const _InsightNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: lime.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome_rounded, color: forest, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'At-risk customers make up 17.6% of your audience. A timely win-back offer could bring them back.',
            style: TextStyle(color: forest, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    ),
  );
}
