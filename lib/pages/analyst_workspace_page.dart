import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'campaign_draft_page.dart';

class AnalystWorkspacePage extends StatefulWidget {
  const AnalystWorkspacePage({
    super.key,
    required this.customers,
    required this.segments,
    required this.settings,
    required this.onImport,
    required this.onCreateCampaign,
    required this.onViewSegments,
    required this.onSignOut,
  });

  final List<Customer> customers;
  final List<CustomerSegment> segments;
  final SegmentationSettings settings;
  final VoidCallback onImport;
  final ValueChanged<Campaign> onCreateCampaign;
  final VoidCallback onViewSegments;
  final VoidCallback onSignOut;

  @override
  State<AnalystWorkspacePage> createState() => _AnalystWorkspacePageState();
}

class _AnalystWorkspacePageState extends State<AnalystWorkspacePage> {
  bool hasRunModel = false;

  void openCampaignDraft(BuildContext context, CustomerSegment segment) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CampaignDraftPage(
          segment: segment,
          onSaveCampaign: widget.onCreateCampaign,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highValueCount = widget.customers
        .where(
          (customer) =>
              customer.lifetimeSpend >= widget.settings.highValueSpend,
        )
        .length;
    final atRiskCount = widget.customers
        .where(
          (customer) =>
              customer.daysSincePurchase >= widget.settings.atRiskDays,
        )
        .length;
    final segmentCounts = {
      for (final segment in customerSegments)
        segment.name: widget.customers
            .where((customer) => customer.segmentName == segment.name)
            .length,
    };

    return AppPage(
      children: [
        BrandHeader(onSignOut: widget.onSignOut),
        const SizedBox(height: 24),
        const PageHeading(
          eyebrow: 'ANALYST WORKSPACE',
          title: 'Audience intelligence',
          subtitle: 'Import, score, and report on your customer data.',
        ),
        const SizedBox(height: 18),
        Container(
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
                      'CUSTOMER RECORDS',
                      style: TextStyle(
                        color: Color(0xFFB7C9BD),
                        fontSize: 10,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your current dataset',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.customers.length}',
                style: const TextStyle(
                  color: lime,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricSummary(
                label: 'HIGH VALUE',
                value: '$highValueCount',
                detail:
                    'Spend >= ${formatRand(widget.settings.highValueSpend)}',
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricSummary(
                label: 'AT RISK',
                value: '$atRiskCount',
                detail: '${widget.settings.atRiskDays}+ inactive days',
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => setState(() => hasRunModel = true),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            hasRunModel ? 'Refresh segmentation' : 'Run segmentation',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        if (hasRunModel) ...[
          const SizedBox(height: 9),
          Text(
            '${widget.settings.algorithm == SegmentationAlgorithm.rfm ? 'RFM scoring' : 'Rule-based segmentation'} refreshed for ${widget.customers.length} records.',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Segment report',
                style: TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onViewSegments,
              child: const Text('Open segments'),
            ),
          ],
        ),
        for (final segment in widget.segments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SegmentIcon(segment: segment, size: 36),
            title: Text(segment.name),
            subtitle: Text('${segmentCounts[segment.name]} records'),
            onTap: () => openCampaignDraft(context, segment),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.customers.isEmpty
                      ? '0%'
                      : '${((segmentCounts[segment.name] ?? 0) / widget.customers.length * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'Draft for ${segment.name}',
                  onPressed: () => openCampaignDraft(context, segment),
                  icon: const Icon(Icons.campaign_outlined, color: forest),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onImport,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Import CSV or connect API'),
          style: OutlinedButton.styleFrom(
            foregroundColor: forest,
            minimumSize: const Size.fromHeight(46),
          ),
        ),
      ],
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: forest, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 9,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(detail, style: const TextStyle(color: muted, fontSize: 9)),
      ],
    ),
  );
}
