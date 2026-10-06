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
    required this.onRunSegmentation,
    required this.onImport,
    required this.onCreateCampaign,
    required this.onViewSegments,
    required this.onSignOut,
  });

  final List<Customer> customers;
  final List<CustomerSegment> segments;
  final SegmentationSettings settings;
  final Future<SegmentationRunReport> Function() onRunSegmentation;
  final VoidCallback onImport;
  final ValueChanged<Campaign> onCreateCampaign;
  final VoidCallback onViewSegments;
  final VoidCallback onSignOut;

  @override
  State<AnalystWorkspacePage> createState() => _AnalystWorkspacePageState();
}

class _AnalystWorkspacePageState extends State<AnalystWorkspacePage> {
  bool hasRunModel = false;
  bool isRunningModel = false;
  SegmentationRunReport? runReport;
  String? modelError;
  late double scenarioHighValueSpend;
  late double scenarioAtRiskDays;
  late SegmentationAlgorithm scenarioAlgorithm;

  @override
  void initState() {
    super.initState();
    scenarioHighValueSpend = widget.settings.highValueSpend.toDouble();
    scenarioAtRiskDays = widget.settings.atRiskDays.toDouble();
    scenarioAlgorithm = widget.settings.algorithm;
  }

  @override
  void didUpdateWidget(covariant AnalystWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      scenarioHighValueSpend = widget.settings.highValueSpend.toDouble();
      scenarioAtRiskDays = widget.settings.atRiskDays.toDouble();
      scenarioAlgorithm = widget.settings.algorithm;
    }
  }

  SegmentationSettings get scenarioSettings => widget.settings.copyWith(
    algorithm: scenarioAlgorithm,
    highValueSpend: scenarioHighValueSpend.round(),
    atRiskDays: scenarioAtRiskDays.round(),
  );

  Map<String, int> get scenarioSegmentCounts => {
    for (final segment in customerSegments)
      segment.name: widget.customers
          .where(
            (customer) =>
                classifyCustomer(customer, scenarioSettings) == segment.name,
          )
          .length,
  };

  int get scenarioChangedCount => widget.customers
      .where(
        (customer) =>
            classifyCustomer(customer, widget.settings) !=
            classifyCustomer(customer, scenarioSettings),
      )
      .length;

  Future<void> runSegmentation() async {
    setState(() {
      isRunningModel = true;
      modelError = null;
    });
    try {
      final report = await widget.onRunSegmentation();
      if (!mounted) return;
      setState(() {
        hasRunModel = true;
        runReport = report;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => modelError = 'Segmentation failed: $error');
    } finally {
      if (mounted) setState(() => isRunningModel = false);
    }
  }

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
      for (final segment in widget.segments)
        segment.name: widget.customers.where(segment.matches).length,
    };
    final qualityIssues = _findDataQualityIssues(
      widget.customers,
      widget.segments,
    );

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
          onPressed: isRunningModel ? null : runSegmentation,
          icon: isRunningModel
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
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
            '${widget.settings.algorithm == SegmentationAlgorithm.rfm ? 'RFM scoring' : 'Rule-based segmentation'} updated ${runReport!.updatedRecords} records; ${runReport!.changes.length} segment assignment${runReport!.changes.length == 1 ? '' : 's'} changed.',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          if (runReport case final report?) ...[
            const SizedBox(height: 8),
            _SegmentationRunReport(report: report),
          ],
        ],
        if (modelError != null) ...[
          const SizedBox(height: 8),
          Text(modelError!, style: const TextStyle(color: coral, fontSize: 11)),
        ],
        const SizedBox(height: 18),
        _DataQualityPanel(issues: qualityIssues),
        const SizedBox(height: 8),
        _scenarioPanel(),
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

  Widget _scenarioPanel() => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: const ValueKey('analyst-scenario-simulator'),
      leading: const Icon(Icons.tune_rounded, color: forest),
      title: const Text(
        'Threshold scenario preview',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '$scenarioChangedCount customer ${scenarioChangedCount == 1 ? 'record' : 'records'} would be reclassified',
        style: const TextStyle(fontSize: 10),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hypothetical segment counts',
                style: TextStyle(
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('analyst-reset-scenario'),
              tooltip: 'Reset scenario to current settings',
              onPressed: () => setState(() {
                scenarioHighValueSpend = widget.settings.highValueSpend
                    .toDouble();
                scenarioAtRiskDays = widget.settings.atRiskDays.toDouble();
                scenarioAlgorithm = widget.settings.algorithm;
              }),
              icon: const Icon(Icons.restart_alt_rounded, size: 19),
            ),
          ],
        ),
        _ScenarioSlider(
          key: const ValueKey('analyst-scenario-spend-slider'),
          label: 'High-value spend',
          value: scenarioHighValueSpend,
          min: 100,
          max: 2000,
          divisions: 19,
          valueLabel: formatRand(scenarioHighValueSpend.round()),
          onChanged: (value) => setState(() => scenarioHighValueSpend = value),
        ),
        _ScenarioSlider(
          key: const ValueKey('analyst-scenario-recency-slider'),
          label: 'At-risk inactivity',
          value: scenarioAtRiskDays,
          min: 14,
          max: 180,
          divisions: 33,
          valueLabel: '${scenarioAtRiskDays.round()} days',
          onChanged: (value) => setState(() => scenarioAtRiskDays = value),
        ),
        const SizedBox(height: 8),
        SegmentedButton<SegmentationAlgorithm>(
          key: const ValueKey('analyst-scenario-algorithm'),
          segments: const [
            ButtonSegment(value: SegmentationAlgorithm.rfm, label: Text('RFM')),
            ButtonSegment(
              value: SegmentationAlgorithm.ruleBased,
              label: Text('Rule-based'),
            ),
          ],
          selected: {scenarioAlgorithm},
          onSelectionChanged: (selection) =>
              setState(() => scenarioAlgorithm = selection.first),
        ),
        const SizedBox(height: 7),
        for (final segment in customerSegments)
          _ScenarioCountRow(
            label: segment.name,
            currentCount: widget.customers
                .where(
                  (customer) =>
                      classifyCustomer(customer, widget.settings) ==
                      segment.name,
                )
                .length,
            scenarioCount: scenarioSegmentCounts[segment.name] ?? 0,
          ),
        const SizedBox(height: 7),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'PREVIEW ONLY',
            style: TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScenarioSlider extends StatelessWidget {
  const _ScenarioSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ink, fontSize: 10),
            ),
          ),
          Text(
            valueLabel,
            style: const TextStyle(
              color: forest,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: forest,
        onChanged: onChanged,
      ),
    ],
  );
}

class _ScenarioCountRow extends StatelessWidget {
  const _ScenarioCountRow({
    required this.label,
    required this.currentCount,
    required this.scenarioCount,
  });

  final String label;
  final int currentCount;
  final int scenarioCount;

  @override
  Widget build(BuildContext context) {
    final difference = scenarioCount - currentCount;
    final differenceLabel = difference == 0
        ? 'no change'
        : '${difference > 0 ? '+' : ''}$difference';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ),
          Text(
            '$currentCount → $scenarioCount  ($differenceLabel)',
            style: const TextStyle(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentationRunReport extends StatelessWidget {
  const _SegmentationRunReport({required this.report});

  final SegmentationRunReport report;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: const ValueKey('analyst-run-report'),
      leading: const Icon(Icons.analytics_outlined, color: forest),
      title: const Text(
        'Run report',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${report.changes.length} assignment${report.changes.length == 1 ? '' : 's'} changed',
        style: const TextStyle(fontSize: 10),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final entry in report.segmentCounts.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (report.changes.isNotEmpty) ...[
          const Divider(height: 16),
          for (final change in report.changes.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${change.customerName}: ${change.previousSegment} → ${change.currentSegment}',
                  style: const TextStyle(color: ink, fontSize: 10),
                ),
              ),
            ),
          if (report.changes.length > 8)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+ ${report.changes.length - 8} more changes',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All customers remain in their current segment.',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ),
          ),
      ],
    ),
  );
}

List<_DataQualityIssue> _findDataQualityIssues(
  List<Customer> customers,
  List<CustomerSegment> segments,
) {
  final byEmail = <String, List<Customer>>{};
  for (final customer in customers) {
    final email = customer.email.trim().toLowerCase();
    byEmail.putIfAbsent(email, () => []).add(customer);
  }
  final knownSegments = {
    for (final segment in segments) segment.name.trim().toLowerCase(),
  };
  final issues = <_DataQualityIssue>[
    _DataQualityIssue(
      label: 'Missing name or invalid email',
      customers: customers
          .where(
            (customer) =>
                customer.name.trim().isEmpty ||
                !RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                ).hasMatch(customer.email.trim()),
          )
          .toList(),
    ),
    _DataQualityIssue(
      label: 'Duplicate email addresses',
      customers: [
        for (final group in byEmail.values)
          if (group.length > 1) ...group,
      ],
    ),
    _DataQualityIssue(
      label: 'Unrecognized segment',
      customers: customers
          .where(
            (customer) =>
                customer.segmentName.trim().isEmpty ||
                !knownSegments.contains(
                  customer.segmentName.trim().toLowerCase(),
                ),
          )
          .toList(),
    ),
    _DataQualityIssue(
      label: 'Spend recorded with zero orders',
      customers: customers
          .where(
            (customer) =>
                customer.lifetimeSpend > 0 && customer.orderCount == 0,
          )
          .toList(),
    ),
  ];
  return issues.where((issue) => issue.customers.isNotEmpty).toList();
}

class _DataQualityIssue {
  const _DataQualityIssue({required this.label, required this.customers});

  final String label;
  final List<Customer> customers;
}

class _DataQualityPanel extends StatelessWidget {
  const _DataQualityPanel({required this.issues});

  final List<_DataQualityIssue> issues;

  @override
  Widget build(BuildContext context) {
    final flaggedRecordCount = issues.fold<int>(
      0,
      (total, issue) => total + issue.customers.length,
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('analyst-data-quality'),
        leading: Icon(
          issues.isEmpty ? Icons.verified_outlined : Icons.fact_check_outlined,
          color: issues.isEmpty ? forest : coral,
        ),
        title: const Text(
          'Data quality review',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          issues.isEmpty
              ? 'No checks flagged'
              : '$flaggedRecordCount record flags across ${issues.length} checks',
          style: const TextStyle(fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (issues.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No data quality checks need review.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${issue.label} (${issue.customers.length})',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final customer in issue.customers.take(3))
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 8),
                      child: Text(
                        '${customer.name.isEmpty ? 'Unnamed record' : customer.name} | ${customer.email.isEmpty ? 'No email' : customer.email}',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  if (issue.customers.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 8),
                      child: Text(
                        '+ ${issue.customers.length - 3} more records',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
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
