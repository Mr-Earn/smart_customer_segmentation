import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: forest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.scatter_plot_rounded, color: lime, size: 23),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MOSAIC',
              style: TextStyle(
                color: ink,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'CUSTOMER INTELLIGENCE',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You are all caught up.'))),
        icon: const Icon(Icons.notifications_none_rounded, color: ink),
      ),
      PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: (value) {
          if (value == 'sign-out') onSignOut?.call();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'sign-out',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 18),
                SizedBox(width: 10),
                Text('Sign out'),
              ],
            ),
          ),
        ],
        child: const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFE6EADD),
          child: Text(
            'A',
            style: TextStyle(color: forest, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: muted,
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 31,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
    ],
  );
}

class SegmentIcon extends StatelessWidget {
  const SegmentIcon({super.key, required this.segment, this.size = 42});

  final CustomerSegment segment;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: segment.color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(segment.icon, size: size * 0.5, color: forest),
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
  });

  final String label;
  final String value;
  final String change;
  final IconData icon;

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
        Row(
          children: [
            Icon(icon, color: muted, size: 15),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 23,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '$change vs last month',
          style: const TextStyle(color: forest, fontSize: 10),
        ),
      ],
    ),
  );
}

class SegmentMixPanel extends StatelessWidget {
  const SegmentMixPanel({super.key, required this.segments});

  final List<CustomerSegment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.count);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 106,
            height: 106,
            child: CustomPaint(painter: DonutPainter(segments: segments)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < segments.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  _SegmentLegend(
                    segment: segments[index],
                    percentage: total == 0
                        ? 0
                        : segments[index].count / total * 100,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentLegend extends StatelessWidget {
  const _SegmentLegend({required this.segment, required this.percentage});

  final CustomerSegment segment;
  final double percentage;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: segment.color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          segment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ink, fontSize: 11),
        ),
      ),
      Text(
        '${percentage.toStringAsFixed(1)}%',
        style: const TextStyle(
          color: ink,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class DonutPainter extends CustomPainter {
  const DonutPainter({required this.segments});

  final List<CustomerSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.count);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.42);
    var startAngle = -1.5708;
    if (total > 0) {
      for (final segment in segments) {
        final sweep = segment.count / total * 6.2832;
        canvas.drawArc(
          rect,
          startAngle,
          sweep - 0.035,
          false,
          Paint()
            ..color = segment.color
            ..strokeWidth = 13
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
        startAngle += sweep;
      }
    }
    final label = TextPainter(
      text: TextSpan(
        text: total == 0 ? '0' : '${(total / 1000).toStringAsFixed(1)}k',
        style: const TextStyle(
          color: ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(center.dx - label.width / 2, center.dy - label.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class TrendPainter extends CustomPainter {
  const TrendPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const values = [0.75, 0.58, 0.66, 0.35, 0.48, 0.22, 0.3, 0.08];
    final points = [
      for (var index = 0; index < values.length; index++)
        Offset(
          size.width * index / (values.length - 1),
          size.height * values[index],
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant TrendPainter oldDelegate) =>
      color != oldDelegate.color;
}
