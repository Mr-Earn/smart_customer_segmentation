import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'campaign_draft_page.dart';

class AnalystWorkspacePage extends StatefulWidget {
  const AnalystWorkspacePage({
    super.key,
    required this.customers,
    required this.segments,
    this.orders = const [],
    required this.settings,
    required this.onRunSegmentation,
    required this.onImport,
    required this.onCreateCampaign,
    required this.onViewSegments,
    required this.onSignOut,
  });

  final List<Customer> customers;
  final List<CustomerSegment> segments;
  final List<CustomerOrder> orders;
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
        const Text(
          'Live intelligence',
          style: TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _SegmentationDashboard(
          customers: widget.customers,
          segments: widget.segments,
          orders: widget.orders,
          hasRunModel: hasRunModel,
          report: runReport,
        ),
        const SizedBox(height: 12),
        _PersonalRecommendations(
          customers: widget.customers,
          orders: widget.orders,
        ),
        const SizedBox(height: 12),
        _PurchasePredictions(
          customers: widget.customers,
          orders: widget.orders,
        ),
        const SizedBox(height: 12),
        _BehaviourAnomalies(customers: widget.customers, orders: widget.orders),
        const SizedBox(height: 12),
        _AnalystChat(
          customers: widget.customers,
          segments: widget.segments,
          orders: widget.orders,
        ),
        const SizedBox(height: 12),
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

class _SegmentationDashboard extends StatelessWidget {
  const _SegmentationDashboard({
    required this.customers,
    required this.segments,
    required this.orders,
    required this.hasRunModel,
    required this.report,
  });

  final List<Customer> customers;
  final List<CustomerSegment> segments;
  final List<CustomerOrder> orders;
  final bool hasRunModel;
  final SegmentationRunReport? report;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final segment in segments)
        segment.name: customers.where(segment.matches).length,
    };
    final highestCount = counts.values.fold<int>(0, (maximum, value) {
      return value > maximum ? value : maximum;
    });

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('analyst-live-dashboard'),
        initiallyExpanded: true,
        leading: const Icon(Icons.dashboard_rounded, color: forest),
        title: const Text(
          'Segmentation dashboard',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          hasRunModel
              ? '${report?.changes.length ?? 0} assignment changes in the latest run'
              : 'Live customer segment distribution',
          style: const TextStyle(fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (final segment in segments)
            Builder(
              builder: (context) {
                final group = customers.where(segment.matches).toList();
                final averageSpend = group.isEmpty
                    ? 0.0
                    : group.fold<int>(
                            0,
                            (sum, customer) => sum + customer.lifetimeSpend,
                          ) /
                          group.length;
                final averagePurchases = group.isEmpty
                    ? 0.0
                    : group.fold<int>(
                            0,
                            (sum, customer) => sum + customer.orderCount,
                          ) /
                          group.length;
                final averageRecency = group.isEmpty
                    ? 0.0
                    : group.fold<int>(
                            0,
                            (sum, customer) => sum + customer.daysSincePurchase,
                          ) /
                          group.length;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment.name,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DashboardKpi(
                            label: 'Customers',
                            value: '${group.length}',
                          ),
                          _DashboardKpi(
                            label: 'Avg. spend',
                            value: formatRand(averageSpend.round()),
                          ),
                          _DashboardKpi(
                            label: 'Avg. purchases',
                            value: averagePurchases.toStringAsFixed(1),
                          ),
                          _DashboardKpi(
                            label: 'Avg. recency',
                            value: '${averageRecency.round()} days',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          for (final segment in segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          segment.name,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${counts[segment.name] ?? 0}',
                        style: const TextStyle(
                          color: forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: highestCount == 0
                          ? 0
                          : (counts[segment.name] ?? 0) / highestCount,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE8EEE9),
                      color: lime,
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

class _DashboardKpi extends StatelessWidget {
  const _DashboardKpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 112),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: forest,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _BehaviourPrediction {
  const _BehaviourPrediction({
    required this.customer,
    required this.score,
    required this.historySummary,
    this.confidence = 0,
    this.likelyProduct,
    this.nextPurchaseDays,
    this.spendTrend = 0,
    this.factors = const [],
  });

  final Customer customer;
  final int score;
  final String historySummary;
  final int confidence;
  final String? likelyProduct;
  final int? nextPurchaseDays;
  final double spendTrend;
  final List<String> factors;
}

class _ProductPrediction {
  const _ProductPrediction({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

List<_BehaviourPrediction> _rankCustomersByBehaviour(
  List<Customer> customers,
  List<CustomerOrder> orders,
) {
  final now = DateTime.now().toUtc();
  final predictions = <_BehaviourPrediction>[];

  for (final customer in customers) {
    final email = customer.email.trim().toLowerCase();
    final history =
        orders
            .where(
              (order) =>
                  order.status != CustomerOrderStatus.cancelled &&
                  order.customerEmail.trim().toLowerCase() == email,
            )
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );

    if (history.isEmpty) {
      predictions.add(
        _BehaviourPrediction(
          customer: customer,
          score: customer.purchaseLikelihoodScore,
          historySummary:
              '${customer.segmentName}  |  ${formatRand(customer.lifetimeSpend)} spent',
          confidence: 35,
          factors: const ['Profile-only estimate; no order history available'],
        ),
      );
      continue;
    }

    final latestOrder = history.first;
    final inactivityDays = now.difference(latestOrder.createdAt.toUtc()).inDays;
    final totalSpent = history.fold<int>(0, (sum, order) => sum + order.total);
    final averageOrder = history.isEmpty ? 0 : totalSpent ~/ history.length;
    final recencyScore = inactivityDays <= 30
        ? 30
        : inactivityDays <= 60
        ? 24
        : inactivityDays <= 90
        ? 18
        : inactivityDays <= 180
        ? 10
        : 4;
    final frequencyScore = history.length >= 6
        ? 25
        : history.length >= 4
        ? 22
        : history.length >= 2
        ? 16
        : 10;
    final spendScore = averageOrder >= 1000
        ? 25
        : averageOrder >= 500
        ? 20
        : averageOrder >= 250
        ? 15
        : 9;
    final topProduct = _rankProducts(history).firstOrNull;
    final repeatScore = topProduct != null && topProduct.quantity >= 2
        ? 20
        : 12;
    final score = (recencyScore + frequencyScore + spendScore + repeatScore)
        .clamp(0, 100)
        .toInt();
    final intervals = <int>[
      for (var index = 1; index < history.length; index++)
        history[index - 1].createdAt
            .difference(history[index].createdAt)
            .inDays
            .abs(),
    ];
    final averageInterval = intervals.isEmpty
        ? 45
        : intervals.fold<int>(0, (sum, value) => sum + value) ~/ intervals.length;
    final nextPurchaseDays = (averageInterval - inactivityDays).clamp(
      0,
      365,
    );
    final confidence = (history.length >= 6 ? 90 : history.length * 12)
        .clamp(35, 90);
    final midpoint = history.length ~/ 2;
    final recentTotal = history.take(midpoint == 0 ? 1 : midpoint).fold<int>(
      0,
      (sum, order) => sum + order.total,
    );
    final recentAverage = midpoint == 0 ? 0.0 : recentTotal / midpoint;
    final older = history.skip(midpoint).toList();
    final olderAverage = older.isEmpty
        ? recentAverage
        : older.fold<int>(0, (sum, order) => sum + order.total) /
              older.length;
    final spendTrend = olderAverage == 0
        ? 0.0
        : ((recentAverage - olderAverage) / olderAverage) * 100;
    final factors = <String>[
      'Recency: $inactivityDays days since last order',
      'Frequency: ${history.length} recent orders',
      'Spend: ${formatRand(averageOrder)} average order',
      if (topProduct != null) 'Affinity: ${topProduct.name}',
      if (spendTrend.abs() >= 10)
        'Trend: ${spendTrend >= 0 ? 'spending increased' : 'spending decreased'} by ${spendTrend.abs().round()}%',
    ];

    predictions.add(
      _BehaviourPrediction(
        customer: customer,
        score: score,
        confidence: confidence,
        likelyProduct: topProduct?.name,
        nextPurchaseDays: nextPurchaseDays.toInt(),
        spendTrend: spendTrend,
        factors: factors,
        historySummary: topProduct == null
            ? '${history.length} orders  |  ${formatRand(averageOrder)} avg.'
            : '${topProduct.name} · ${topProduct.quantity}  |  '
                  '${formatRand(averageOrder)} avg.  |  '
                  '${DateFormat('MMM d').format(latestOrder.createdAt)}',
      ),
    );
  }

  predictions.sort((first, second) => second.score.compareTo(first.score));
  return predictions;
}

List<_ProductPrediction> _rankProducts(List<CustomerOrder> orders) {
  final quantities = <String, int>{};
  final names = <String, String>{};
  for (final order in orders) {
    if (order.status == CustomerOrderStatus.cancelled) continue;
    for (final item in order.items) {
      final key = item.productId.trim().toLowerCase();
      quantities[key] = (quantities[key] ?? 0) + item.quantity;
      names[key] = item.productName.trim().isEmpty
          ? item.productId
          : item.productName.trim();
    }
  }

  final predictions = [
    for (final entry in quantities.entries)
      _ProductPrediction(
        name: names[entry.key] ?? entry.key,
        quantity: entry.value,
      ),
  ];
  predictions.sort(
    (first, second) => second.quantity.compareTo(first.quantity),
  );
  return predictions;
}

class _PersonalRecommendations extends StatelessWidget {
  const _PersonalRecommendations({
    required this.customers,
    required this.orders,
  });

  final List<Customer> customers;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final recommendations = customers.take(6).map((customer) {
      final history = orders
          .where(
            (order) =>
                order.status != CustomerOrderStatus.cancelled &&
                order.customerEmail.toLowerCase().trim() ==
                    customer.email.toLowerCase().trim(),
          )
          .toList();
      final product = _rankProducts(history).firstOrNull;
      final discount = customer.daysSincePurchase >= 60
          ? '20% win-back special'
          : customer.churnRiskScore >= 40
          ? '15% return special'
          : customer.rfmScore >= 13
          ? 'VIP early-access offer'
          : 'Free delivery special';
      return (customer: customer, product: product?.name, discount: discount);
    }).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('analyst-personal-recommendations'),
        initiallyExpanded: true,
        leading: const Icon(Icons.recommend_rounded, color: forest),
        title: const Text(
          'Personalized recommendations',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Customer-specific products and specials',
          style: TextStyle(fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final item in recommendations)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F7),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customer.name,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.product == null
                        ? 'Recommend ${item.customer.segmentName.toLowerCase()} collection · ${item.discount}'
                        : 'Recommend ${item.product} again · ${item.discount}',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BehaviourAnomaly {
  const _BehaviourAnomaly({
    required this.customer,
    required this.reason,
    required this.severity,
  });

  final Customer customer;
  final String reason;
  final String severity;
}

List<_BehaviourAnomaly> _detectAnomalies(
  List<Customer> customers,
  List<CustomerOrder> orders,
) {
  final anomalies = <_BehaviourAnomaly>[];
  for (final customer in customers) {
    final history =
        orders
            .where(
              (order) =>
                  order.status != CustomerOrderStatus.cancelled &&
                  order.customerEmail.toLowerCase().trim() ==
                      customer.email.toLowerCase().trim(),
            )
            .toList()
          ..sort(
            (first, second) => first.createdAt.compareTo(second.createdAt),
          );
    if (history.length >= 3) {
      final totals = history.map((order) => order.total).toList();
      final average =
          totals.fold<int>(0, (sum, value) => sum + value) / totals.length;
      final latest = totals.last;
      if (latest > average * 1.75) {
        anomalies.add(
          _BehaviourAnomaly(
            customer: customer,
            reason:
                'Latest order spend is ${(latest / average).toStringAsFixed(1)}x their normal order value.',
            severity: 'High',
          ),
        );
        continue;
      }
      if (latest < average * 0.35) {
        anomalies.add(
          _BehaviourAnomaly(
            customer: customer,
            reason:
                'Latest order spend dropped sharply below their usual value.',
            severity: 'Medium',
          ),
        );
        continue;
      }
    }
    if (customer.daysSincePurchase >= 120 &&
        customer.orderCount >= 5 &&
        customer.lifetimeSpend >= 500) {
      anomalies.add(
        _BehaviourAnomaly(
          customer: customer,
          reason:
              'Frequent valuable customer became inactive for ${customer.daysSincePurchase} days.',
          severity: 'High',
        ),
      );
    }
  }
  return anomalies.take(6).toList();
}

class _BehaviourAnomalies extends StatelessWidget {
  const _BehaviourAnomalies({required this.customers, required this.orders});

  final List<Customer> customers;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final anomalies = _detectAnomalies(customers, orders);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('analyst-behaviour-anomalies'),
        leading: const Icon(Icons.crisis_alert_rounded, color: coral),
        title: const Text(
          'Behaviour anomalies',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          anomalies.isEmpty
              ? 'No unusual behaviour detected'
              : '${anomalies.length} unusual customer changes',
          style: const TextStyle(fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (anomalies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No spending spikes, drops, or inactivity anomalies are currently detected.',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            )
          else
            for (final anomaly in anomalies)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  anomaly.severity == 'High'
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  color: anomaly.severity == 'High' ? coral : sky,
                  size: 20,
                ),
                title: Text(
                  anomaly.customer.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  anomaly.reason,
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
                trailing: Text(
                  anomaly.severity,
                  style: TextStyle(
                    color: anomaly.severity == 'High' ? coral : sky,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AnalystChatMessage {
  const _AnalystChatMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

class _AnalystChat extends StatefulWidget {
  const _AnalystChat({
    required this.customers,
    required this.segments,
    required this.orders,
  });

  final List<Customer> customers;
  final List<CustomerSegment> segments;
  final List<CustomerOrder> orders;

  @override
  State<_AnalystChat> createState() => _AnalystChatState();
}

class _AnalystChatState extends State<_AnalystChat> {
  final _controller = TextEditingController();
  final _messages = <_AnalystChatMessage>[
    const _AnalystChatMessage(
      isUser: false,
      text: 'Ask about customer groups, likely buyers, or segment comparisons.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _answer(String question) {
    final query = question.toLowerCase();
    final predictions = _rankCustomersByBehaviour(
      widget.customers,
      widget.orders,
    );
    final matchedSegment = widget.segments
        .where((segment) => query.contains(segment.name.toLowerCase()))
        .firstOrNull;

    if (query.contains('compare') ||
        (query.contains('segment') && query.contains('which'))) {
      final stats = widget.segments.map((segment) {
        final group = widget.customers.where(segment.matches).toList();
        final averageSpend = group.isEmpty
            ? 0
            : group.fold<int>(
                    0,
                    (sum, customer) => sum + customer.lifetimeSpend,
                  ) /
                  group.length;
        final averageRecency = group.isEmpty
            ? 0
            : group.fold<int>(
                    0,
                    (sum, customer) => sum + customer.daysSincePurchase,
                  ) /
                  group.length;
        return '${segment.name}: ${group.length} customers, '
            '${formatRand(averageSpend.round())} average spend, '
            '${averageRecency.round()} average recency days';
      }).toList();
      return stats.join('. ');
    }

    if (matchedSegment != null &&
        (query.contains('most likely') || query.contains('customer'))) {
      final customer = predictions
          .where((prediction) => matchedSegment.matches(prediction.customer))
          .firstOrNull;
      return customer == null
          ? 'There is no customer currently in the ${matchedSegment.name} segment.'
          : '${customer.customer.name} is the most likely buyer in '
                '${matchedSegment.name}, with a ${customer.score}% likelihood '
                'and ${customer.confidence}% model confidence'
                '${customer.likelyProduct == null ? '.' : ', most likely buying ${customer.likelyProduct}.'
                '${customer.nextPurchaseDays == null ? '' : ' Predicted purchase window: about ${customer.nextPurchaseDays} days.'}'}';
    }

    if (query.contains('buy') ||
        query.contains('likely') ||
        query.contains('recommend')) {
      final top = predictions.firstOrNull;
      if (top == null) return 'There are no customer records to analyze.';
      final products = _rankProducts(
        widget.orders
            .where(
              (order) =>
                  order.status != CustomerOrderStatus.cancelled &&
                  order.customerEmail.toLowerCase().trim() ==
                      top.customer.email.toLowerCase().trim(),
            )
            .toList(),
      );
      final product = products.firstOrNull;
      return '${top.customer.name} has the highest likelihood at ${top.score}%'
          '${product == null ? '.' : ' and is most likely to buy ${product.name}.'}'
          ' Model confidence is ${top.confidence}%';
    }

    return 'I can compare segment size, spend, and recency, or identify the most likely buyer in a named segment.';
  }

  void _send() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    setState(() {
      _messages
        ..add(_AnalystChatMessage(isUser: true, text: question))
        ..add(_AnalystChatMessage(isUser: false, text: _answer(question)));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: const ValueKey('analyst-chatbot'),
      leading: const Icon(Icons.smart_toy_outlined, color: forest),
      title: const Text(
        'Ask the analyst assistant',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Compare segments or identify likely buyers',
        style: TextStyle(fontSize: 10),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser ? forest : const Color(0xFFF0F5F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : ink,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('analyst-chat-input'),
                controller: _controller,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Ask about a segment or customer...',
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('analyst-chat-send'),
              onPressed: _send,
              tooltip: 'Send question',
              icon: const Icon(Icons.send_rounded, color: forest),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PurchasePredictions extends StatelessWidget {
  const _PurchasePredictions({required this.customers, required this.orders});

  final List<Customer> customers;
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    final predictions = _rankCustomersByBehaviour(customers, orders).take(6);
    final predictionList = predictions.toList();
    final popularProducts = _rankProducts(orders);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('analyst-purchase-predictions'),
        initiallyExpanded: true,
        leading: const Icon(Icons.auto_awesome_rounded, color: forest),
        title: const Text(
          'Shopping behaviour predictions',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          predictionList.isEmpty
              ? 'No customer records available'
              : '${predictionList.length} customers ranked by purchase behaviour',
          style: const TextStyle(fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (popularProducts.isNotEmpty) ...[
            const Text(
              'TOP SHOPPED PRODUCTS',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final product in popularProducts.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${product.name} · ${product.quantity}',
                      style: const TextStyle(
                        color: forest,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
          ],
          for (var index = 0; index < predictionList.length; index++)
            Builder(
              builder: (context) {
                final prediction = predictionList[index];
                final customer = prediction.customer;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: lime.withValues(alpha: 0.55),
                    foregroundColor: forest,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.historySummary,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                      if (prediction.likelyProduct != null)
                        Text(
                          'Likely item: ${prediction.likelyProduct}'
                          '${prediction.nextPurchaseDays == null ? '' : ' · In about ${prediction.nextPurchaseDays} days'}'
                          ' · ${prediction.confidence}% confidence',
                          style: const TextStyle(
                            color: forest,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (prediction.factors.isNotEmpty)
                        Text(
                          prediction.factors.first,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    constraints: const BoxConstraints(minWidth: 76),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${prediction.score}% likely',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: forest,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
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
