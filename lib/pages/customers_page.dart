import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'customer_profile_page.dart';

enum CustomerSort { highestSpend, mostOrders, recentlyActive, highestChurnRisk }

extension CustomerSortLabel on CustomerSort {
  String get label => switch (this) {
    CustomerSort.highestSpend => 'Highest spend',
    CustomerSort.mostOrders => 'Most orders',
    CustomerSort.recentlyActive => 'Recently active',
    CustomerSort.highestChurnRisk => 'Highest churn risk',
  };
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({
    super.key,
    required this.customers,
    required this.favorites,
    required this.notes,
    required this.onToggleFavorite,
    required this.onSaveNote,
    required this.onSignOut,
  });

  final List<Customer> customers;
  final Set<String> favorites;
  final Map<String, String> notes;
  final ValueChanged<String> onToggleFavorite;
  final Future<void> Function(String email, String note) onSaveNote;
  final VoidCallback onSignOut;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String query = '';
  String selectedSegment = 'All';
  CustomerSort sort = CustomerSort.highestSpend;
  int? recentDays;
  bool favoritesOnly = false;
  String selectedRfmTier = 'All';
  String selectedRiskTier = 'All';
  int minimumSpend = 0;
  bool isSelectionMode = false;
  final Set<String> selectedCustomerEmails = {};

  int get activeAdvancedFilters =>
      (selectedRfmTier == 'All' ? 0 : 1) +
      (selectedRiskTier == 'All' ? 0 : 1) +
      (minimumSpend == 0 ? 0 : 1);

  List<Customer> get visibleCustomers {
    final filtered = widget.customers.where((customer) {
      final matchesQuery =
          '${customer.name} ${customer.email} ${customer.segmentName}'
              .toLowerCase()
              .contains(query.toLowerCase());
      final matchesSegment =
          selectedSegment == 'All' || customer.segmentName == selectedSegment;
      final matchesRecency =
          recentDays == null || customer.daysSincePurchase <= recentDays!;
      final matchesFavorite =
          !favoritesOnly || widget.favorites.contains(customer.email);
      final matchesRfmTier =
          selectedRfmTier == 'All' || customer.rfmTier == selectedRfmTier;
      final matchesRiskTier =
          selectedRiskTier == 'All' ||
          customer.churnRiskTier == selectedRiskTier;
      final matchesMinimumSpend = customer.lifetimeSpend >= minimumSpend;
      return matchesQuery &&
          matchesSegment &&
          matchesRecency &&
          matchesFavorite &&
          matchesRfmTier &&
          matchesRiskTier &&
          matchesMinimumSpend;
    }).toList();

    filtered.sort(
      (first, second) => switch (sort) {
        CustomerSort.highestSpend => second.lifetimeSpend.compareTo(
          first.lifetimeSpend,
        ),
        CustomerSort.mostOrders => second.orderCount.compareTo(
          first.orderCount,
        ),
        CustomerSort.recentlyActive => first.daysSincePurchase.compareTo(
          second.daysSincePurchase,
        ),
        CustomerSort.highestChurnRisk => second.churnRiskScore.compareTo(
          first.churnRiskScore,
        ),
      },
    );
    return filtered;
  }

  Future<void> _showAdvancedFilters() async {
    var pendingRfmTier = selectedRfmTier;
    var pendingRiskTier = selectedRiskTier;
    var pendingMinimumSpend = minimumSpend.toDouble();
    final spendCeiling = widget.customers.fold<int>(
      2000,
      (maximum, customer) =>
          customer.lifetimeSpend > maximum ? customer.lifetimeSpend : maximum,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Advanced filters',
                        style: TextStyle(
                          color: ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setModalState(() {
                        pendingRfmTier = 'All';
                        pendingRiskTier = 'All';
                        pendingMinimumSpend = 0;
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('rfm-tier-filter'),
                  initialValue: pendingRfmTier,
                  decoration: const InputDecoration(labelText: 'RFM tier'),
                  items: [
                    for (final tier in [
                      'All',
                      'Top value',
                      'Loyal',
                      'Growing',
                      'Needs attention',
                    ])
                      DropdownMenuItem(value: tier, child: Text(tier)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => pendingRfmTier = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const ValueKey('risk-tier-filter'),
                  initialValue: pendingRiskTier,
                  decoration: const InputDecoration(labelText: 'Churn risk'),
                  items: [
                    for (final tier in [
                      'All',
                      'High risk',
                      'Watch',
                      'Low risk',
                    ])
                      DropdownMenuItem(value: tier, child: Text(tier)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => pendingRiskTier = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('Minimum lifetime spend')),
                    Text(
                      formatRand(pendingMinimumSpend.round()),
                      style: const TextStyle(
                        color: forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: pendingMinimumSpend,
                  min: 0,
                  max: spendCeiling.toDouble(),
                  divisions: 20,
                  label: formatRand(pendingMinimumSpend.round()),
                  onChanged: (value) =>
                      setModalState(() => pendingMinimumSpend = value),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedRfmTier = pendingRfmTier;
                      selectedRiskTier = pendingRiskTier;
                      minimumSpend = pendingMinimumSpend.round();
                    });
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.filter_alt_rounded),
                  label: const Text('Apply filters'),
                  style: FilledButton.styleFrom(
                    backgroundColor: forest,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyFilteredCsv(List<Customer> customers) async {
    String escapeCsvField(Object? value) {
      final field = value?.toString() ?? '';
      if (!field.contains(RegExp('[,\\"\\r\\n]'))) return field;
      return '"${field.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      [
        'name',
        'email',
        'segment',
        'lifetime_spend_zar',
        'orders',
        'days_since_purchase',
        'rfm_score',
        'rfm_tier',
        'churn_risk_score',
        'churn_risk_tier',
      ],
      for (final customer in customers)
        [
          customer.name,
          customer.email,
          customer.segmentName,
          customer.lifetimeSpend,
          customer.orderCount,
          customer.daysSincePurchase,
          customer.rfmScore,
          customer.rfmTier,
          customer.churnRiskScore,
          customer.churnRiskTier,
        ],
    ];
    await Clipboard.setData(
      ClipboardData(
        text: rows.map((row) => row.map(escapeCsvField).join(',')).join('\n'),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customers.length} customer rows copied as CSV.'),
      ),
    );
  }

  void _toggleCustomerSelection(Customer customer) {
    setState(() {
      if (!selectedCustomerEmails.add(customer.email)) {
        selectedCustomerEmails.remove(customer.email);
      }
    });
  }

  void _startSelection(Customer customer) {
    setState(() {
      isSelectionMode = true;
      selectedCustomerEmails.add(customer.email);
    });
  }

  void _toggleVisibleSelection(List<Customer> customers) {
    final allSelected = customers.every(
      (customer) => selectedCustomerEmails.contains(customer.email),
    );
    setState(() {
      if (allSelected) {
        selectedCustomerEmails.removeAll(
          customers.map((customer) => customer.email),
        );
      } else {
        selectedCustomerEmails.addAll(
          customers.map((customer) => customer.email),
        );
      }
    });
  }

  Future<void> _copySelectedEmails(List<Customer> customers) async {
    await Clipboard.setData(
      ClipboardData(
        text: customers.map((customer) => customer.email).join('\n'),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${customers.length} customer emails copied.')),
    );
  }

  Future<void> _compareCustomers(List<Customer> customers) async {
    final compared = customers.take(3).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compare customers (${compared.length})',
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Metric')),
                    for (final customer in compared)
                      DataColumn(
                        label: SizedBox(
                          width: 112,
                          child: Text(
                            customer.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                  rows: [
                    _comparisonRow(
                      'Segment',
                      compared.map((customer) => customer.segmentName),
                    ),
                    _comparisonRow(
                      'Lifetime spend',
                      compared.map(
                        (customer) => formatRand(customer.lifetimeSpend),
                      ),
                    ),
                    _comparisonRow(
                      'Orders',
                      compared.map((customer) => '${customer.orderCount}'),
                    ),
                    _comparisonRow(
                      'Days since purchase',
                      compared.map(
                        (customer) => '${customer.daysSincePurchase}',
                      ),
                    ),
                    _comparisonRow(
                      'RFM score',
                      compared.map((customer) => '${customer.rfmScore} / 15'),
                    ),
                    _comparisonRow(
                      'Churn risk',
                      compared.map((customer) => customer.churnRiskTier),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _comparisonRow(String label, Iterable<String> values) => DataRow(
    cells: [
      DataCell(Text(label)),
      for (final value in values)
        DataCell(SizedBox(width: 112, child: Text(value))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final visible = visibleCustomers;
    final selectedVisible = visible
        .where((customer) => selectedCustomerEmails.contains(customer.email))
        .toList();
    final segmentNames =
        widget.customers
            .map((customer) => customer.segmentName)
            .toSet()
            .toList()
          ..sort();
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            children: [
              BrandHeader(onSignOut: widget.onSignOut),
              const SizedBox(height: 28),
              const PageHeading(
                eyebrow: 'CUSTOMER DIRECTORY',
                title: 'Customers',
                subtitle: 'Search, filter, and inspect RFM profiles.',
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search name, email, or segment',
                  hintStyle: const TextStyle(color: muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: muted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', ...segmentNames].map((name) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: selectedSegment == name,
                        onSelected: (selected) => setState(
                          () => selectedSegment = selected ? name : 'All',
                        ),
                        selectedColor: lime,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: ink,
                          fontSize: 11,
                          fontWeight: selectedSegment == name
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final days in [30, 90])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text('Recent $days days'),
                          selected: recentDays == days,
                          onSelected: (selected) => setState(
                            () => recentDays = selected ? days : null,
                          ),
                          selectedColor: lime,
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                        ),
                      ),
                    ChoiceChip(
                      avatar: const Icon(Icons.star_rounded, size: 15),
                      label: const Text('Saved'),
                      selected: favoritesOnly,
                      onSelected: (value) =>
                          setState(() => favoritesOnly = value),
                      selectedColor: lime,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${visible.length} customer records',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: activeAdvancedFilters == 0
                        ? 'Advanced filters'
                        : 'Advanced filters ($activeAdvancedFilters active)',
                    onPressed: _showAdvancedFilters,
                    icon: Badge(
                      isLabelVisible: activeAdvancedFilters > 0,
                      label: Text('$activeAdvancedFilters'),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                  IconButton(
                    tooltip: isSelectionMode
                        ? 'Finish selecting customers'
                        : 'Select customers',
                    onPressed: () => setState(() {
                      isSelectionMode = !isSelectionMode;
                      if (!isSelectionMode) selectedCustomerEmails.clear();
                    }),
                    icon: Icon(
                      isSelectionMode
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy filtered customer CSV',
                    onPressed: visible.isEmpty
                        ? null
                        : () => _copyFilteredCsv(visible),
                    icon: const Icon(Icons.table_view_rounded),
                  ),
                  DropdownButton<CustomerSort>(
                    value: sort,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: forest, fontSize: 12),
                    icon: const Icon(
                      Icons.sort_rounded,
                      color: forest,
                      size: 19,
                    ),
                    items: [
                      for (final option in CustomerSort.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => sort = value);
                    },
                  ),
                ],
              ),
              if (isSelectionMode) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selectedVisible.length} selected',
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: visible.isEmpty
                            ? null
                            : () => _toggleVisibleSelection(visible),
                        icon: const Icon(Icons.select_all_rounded, size: 18),
                        label: Text(
                          visible.isNotEmpty &&
                                  visible.every(
                                    (customer) => selectedCustomerEmails
                                        .contains(customer.email),
                                  )
                              ? 'Clear visible'
                              : 'Select visible',
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: selectedVisible.length < 2
                          ? null
                          : () => _compareCustomers(selectedVisible),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      label: Text(
                        'Compare (${selectedVisible.length.clamp(0, 3)})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedVisible.isEmpty
                          ? null
                          : () => _copySelectedEmails(selectedVisible),
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      label: const Text('Copy emails'),
                    ),
                  ],
                ),
              ],
              if (visible.isNotEmpty) ...[
                const SizedBox(height: 5),
                _CohortSummary(customers: visible),
              ],
              const SizedBox(height: 5),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'No customers match those filters.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              else
                for (final customer in visible)
                  _CustomerRow(
                    customer: customer,
                    isFavorite: widget.favorites.contains(customer.email),
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedCustomerEmails.contains(customer.email),
                    onToggleSelection: () => _toggleCustomerSelection(customer),
                    onStartSelection: () => _startSelection(customer),
                    onToggleFavorite: () =>
                        widget.onToggleFavorite(customer.email),
                    onTap: isSelectionMode
                        ? () => _toggleCustomerSelection(customer)
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CustomerProfilePage(
                                customer: customer,
                                isFavorite: widget.favorites.contains(
                                  customer.email,
                                ),
                                initialNote: widget.notes[customer.email] ?? '',
                                onToggleFavorite: () =>
                                    widget.onToggleFavorite(customer.email),
                                onSaveNote: (note) =>
                                    widget.onSaveNote(customer.email, note),
                              ),
                            ),
                          ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.isFavorite,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onStartSelection,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Customer customer;
  final bool isFavorite;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onStartSelection;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final matchingSegments = customerSegments.where(
      (item) => item.name == customer.segmentName,
    );
    final segmentColor = matchingSegments.isEmpty
        ? sky
        : matchingSegments.first.color;
    final initials = customer.name
        .split(' ')
        .map((part) => part[0])
        .take(2)
        .join();

    return InkWell(
      onTap: onTap,
      onLongPress: isSelectionMode ? null : onStartSelection,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE1E6DF))),
        ),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Checkbox(
                key: ValueKey('customer-selection-${customer.email}'),
                value: isSelected,
                onChanged: (_) => onToggleSelection(),
                activeColor: forest,
              ),
              const SizedBox(width: 4),
            ],
            CircleAvatar(
              radius: 21,
              backgroundColor: segmentColor.withValues(alpha: 0.45),
              child: Text(
                initials,
                style: const TextStyle(
                  color: forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${customer.segmentName}  /  ${customer.orderCount} orders',
                    style: const TextStyle(
                      color: forest,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
                  formatRand(customer.lifetimeSpend),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'lifetime',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: isFavorite ? 'Remove from saved' : 'Save customer',
              onPressed: onToggleFavorite,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite ? forest : muted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CohortSummary extends StatelessWidget {
  const _CohortSummary({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    final totalSpend = customers.fold<int>(
      0,
      (total, customer) => total + customer.lifetimeSpend,
    );
    final highRiskCount = customers
        .where((customer) => customer.churnRiskTier == 'High risk')
        .length;
    final averageSpend = (totalSpend / customers.length).round();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFE1E6DF)),
        ),
      ),
      child: Row(
        children: [
          _SummaryValue(label: 'COHORT SPEND', value: formatRand(totalSpend)),
          _SummaryValue(label: 'AVERAGE', value: formatRand(averageSpend)),
          _SummaryValue(
            label: 'HIGH RISK',
            value: '$highRiskCount / ${customers.length}',
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
