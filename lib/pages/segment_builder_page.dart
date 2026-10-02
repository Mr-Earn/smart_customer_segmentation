import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

class SegmentBuilderPage extends StatefulWidget {
  const SegmentBuilderPage({super.key, required this.customers});

  final List<Customer> customers;

  @override
  State<SegmentBuilderPage> createState() => _SegmentBuilderPageState();
}

class _SegmentBuilderPageState extends State<SegmentBuilderPage> {
  final TextEditingController nameController = TextEditingController(
    text: 'High-value buyers',
  );
  final List<_RuleDraft> conditions = [
    _RuleDraft(SegmentMetric.lifetimeSpend, 500),
  ];
  SegmentJoin join = SegmentJoin.all;

  SegmentRule get rule => SegmentRule(
    conditions: [
      for (final draft in conditions)
        SegmentCondition(
          metric: draft.metric,
          threshold: draft.threshold.round(),
        ),
    ],
    join: join,
  );

  List<Customer> get matches => widget.customers.where(rule.matches).toList();

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void saveSegment() {
    final name = nameController.text.trim();
    if (name.isEmpty || matches.isEmpty) return;
    final averageSpend =
        (matches.fold<int>(0, (sum, customer) => sum + customer.lifetimeSpend) /
                matches.length)
            .round();
    Navigator.of(context).pop(
      CustomerSegment(
        name: name,
        description: rule.summary,
        count: matches.length,
        color: sky,
        icon: Icons.auto_awesome_rounded,
        averageSpend: averageSpend,
        rule: rule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMatches = matches;
    return Scaffold(
      appBar: AppBar(title: const Text('Segment builder')),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: canvas,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FilledButton.icon(
                onPressed:
                    nameController.text.trim().isNotEmpty &&
                        currentMatches.isNotEmpty
                    ? saveSegment
                    : null,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save segment'),
                style: FilledButton.styleFrom(
                  backgroundColor: forest,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const PageHeading(
                  eyebrow: 'SMART SEGMENTATION',
                  title: 'Build a segment',
                  subtitle: 'Choose a customer signal and preview the matches.',
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Segment name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Combine conditions',
                  style: TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<SegmentJoin>(
                  segments: const [
                    ButtonSegment(
                      value: SegmentJoin.all,
                      label: Text('Match all'),
                    ),
                    ButtonSegment(
                      value: SegmentJoin.any,
                      label: Text('Match any'),
                    ),
                  ],
                  selected: {join},
                  onSelectionChanged: (selection) =>
                      setState(() => join = selection.first),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < conditions.length; index++) ...[
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Text(
                          join == SegmentJoin.all ? 'AND' : 'OR',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  _RuleConditionEditor(
                    draft: conditions[index],
                    canRemove: conditions.length > 1,
                    onMetricChanged: (value) => setState(() {
                      conditions[index]
                        ..metric = value
                        ..threshold = _defaultThreshold(value);
                    }),
                    onThresholdChanged: (value) =>
                        setState(() => conditions[index].threshold = value),
                    onRemove: () => setState(() => conditions.removeAt(index)),
                  ),
                ],
                if (conditions.length < 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => conditions.add(
                          _RuleDraft(SegmentMetric.daysSincePurchase, 30),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add condition'),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: forest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        color: lime,
                        size: 25,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${currentMatches.length} matching profiles',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Live preview from ${widget.customers.length} customers',
                              style: TextStyle(
                                color: Color(0xFFB7C9BD),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final customer in currentMatches.take(4))
                  _MatchedCustomer(customer: customer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchedCustomer extends StatelessWidget {
  const _MatchedCustomer({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: forest, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            customer.name,
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${formatRand(customer.lifetimeSpend)} lifetime',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _RuleDraft {
  _RuleDraft(this.metric, this.threshold);

  SegmentMetric metric;
  double threshold;
}

double _defaultThreshold(SegmentMetric metric) => switch (metric) {
  SegmentMetric.lifetimeSpend => 500,
  SegmentMetric.orderCount => 5,
  SegmentMetric.daysSincePurchase => 30,
};

class _RuleConditionEditor extends StatelessWidget {
  const _RuleConditionEditor({
    required this.draft,
    required this.canRemove,
    required this.onMetricChanged,
    required this.onThresholdChanged,
    required this.onRemove,
  });

  final _RuleDraft draft;
  final bool canRemove;
  final ValueChanged<SegmentMetric> onMetricChanged;
  final ValueChanged<double> onThresholdChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<SegmentMetric>(
                initialValue: draft.metric,
                decoration: const InputDecoration(
                  labelText: 'Customer signal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final option in SegmentMetric.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) {
                  if (value != null) onMetricChanged(value);
                },
              ),
            ),
            IconButton(
              tooltip: 'Remove condition',
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                draft.metric.ruleLabel,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            Text(
              draft.metric.formatThreshold(draft.threshold),
              style: const TextStyle(
                color: forest,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: draft.threshold,
          min: 0,
          max: draft.metric.maxThreshold,
          divisions: 40,
          label: draft.metric.formatThreshold(draft.threshold),
          activeColor: forest,
          onChanged: onThresholdChanged,
        ),
      ],
    ),
  );
}
