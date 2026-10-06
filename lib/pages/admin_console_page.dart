import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

enum _AdminSection { overview, accounts, models, campaigns, orders, audit }

enum _AdminOrderFilter { all, open, received, processing, fulfilled, cancelled }

enum _AuditCategory { all, staff, campaigns, orders, settings }

enum _AuditTimeFilter { all, today, lastSevenDays }

extension _AuditCategoryDetails on _AuditCategory {
  String get label => switch (this) {
    _AuditCategory.all => 'All',
    _AuditCategory.staff => 'Staff',
    _AuditCategory.campaigns => 'Campaigns',
    _AuditCategory.orders => 'Orders',
    _AuditCategory.settings => 'Model',
  };

  bool matches(AdminAuditEvent event) => switch (this) {
    _AuditCategory.all => true,
    _AuditCategory.staff => event.entityType == 'profile',
    _AuditCategory.campaigns => event.entityType == 'campaign',
    _AuditCategory.orders => event.entityType == 'customer_order',
    _AuditCategory.settings => event.entityType == 'segmentation_settings',
  };
}

extension _AuditTimeFilterDetails on _AuditTimeFilter {
  String get label => switch (this) {
    _AuditTimeFilter.all => 'All time',
    _AuditTimeFilter.today => 'Today',
    _AuditTimeFilter.lastSevenDays => '7 days',
  };

  bool matches(DateTime timestamp, DateTime now) => switch (this) {
    _AuditTimeFilter.all => true,
    _AuditTimeFilter.today =>
      timestamp.year == now.year &&
          timestamp.month == now.month &&
          timestamp.day == now.day,
    _AuditTimeFilter.lastSevenDays => !timestamp.isBefore(
      now.subtract(const Duration(days: 7)),
    ),
  };
}

extension _AdminOrderFilterDetails on _AdminOrderFilter {
  String get label => switch (this) {
    _AdminOrderFilter.all => 'All',
    _AdminOrderFilter.open => 'Open',
    _AdminOrderFilter.received => 'Received',
    _AdminOrderFilter.processing => 'Processing',
    _AdminOrderFilter.fulfilled => 'Fulfilled',
    _AdminOrderFilter.cancelled => 'Cancelled',
  };

  bool matches(CustomerOrder order) => switch (this) {
    _AdminOrderFilter.all => true,
    _AdminOrderFilter.open =>
      order.status == CustomerOrderStatus.received ||
          order.status == CustomerOrderStatus.processing,
    _AdminOrderFilter.received => order.status == CustomerOrderStatus.received,
    _AdminOrderFilter.processing =>
      order.status == CustomerOrderStatus.processing,
    _AdminOrderFilter.fulfilled =>
      order.status == CustomerOrderStatus.fulfilled,
    _AdminOrderFilter.cancelled =>
      order.status == CustomerOrderStatus.cancelled,
  };
}

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    super.key,
    required this.currentUser,
    required this.users,
    required this.campaigns,
    required this.orders,
    required this.auditEvents,
    required this.auditError,
    required this.settings,
    required this.onAddUser,
    required this.onUpdateUser,
    required this.onRemoveUser,
    required this.onSaveSettings,
    required this.onApproveCampaign,
    required this.onScheduleCampaign,
    required this.onUpdateOrder,
    required this.onRefreshAudit,
    required this.onImport,
    required this.onSignOut,
  });

  final AppUser currentUser;
  final List<AppUser> users;
  final List<Campaign> campaigns;
  final List<CustomerOrder> orders;
  final List<AdminAuditEvent> auditEvents;
  final String? auditError;
  final SegmentationSettings settings;
  final Future<void> Function(AppUser) onAddUser;
  final Future<void> Function(AppUser) onUpdateUser;
  final Future<void> Function(AppUser) onRemoveUser;
  final Future<void> Function(SegmentationSettings) onSaveSettings;
  final Future<void> Function(Campaign) onApproveCampaign;
  final Future<void> Function(Campaign campaign, DateTime date)
  onScheduleCampaign;
  final Future<void> Function(CustomerOrder order) onUpdateOrder;
  final Future<void> Function() onRefreshAudit;
  final VoidCallback onImport;
  final VoidCallback onSignOut;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  AppRole newRole = AppRole.analyst;
  _AdminSection section = _AdminSection.overview;
  SegmentationSettings settings = const SegmentationSettings();
  String? accountError;
  String? operationError;
  String orderSearch = '';
  _AdminOrderFilter orderFilter = _AdminOrderFilter.all;
  final Set<String> selectedOrderIds = {};
  String auditQuery = '';
  bool isRefreshingAudit = false;
  _AuditCategory auditCategory = _AuditCategory.all;
  _AuditTimeFilter auditTimeFilter = _AuditTimeFilter.all;

  @override
  void initState() {
    super.initState();
    settings = widget.settings;
  }

  @override
  void didUpdateWidget(covariant AdminConsolePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) settings = widget.settings;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> addAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    if (name.isEmpty || !email.contains('@')) {
      setState(() => accountError = 'Enter a name and valid email address.');
      return;
    }
    if (widget.users.any((user) => user.id == email)) {
      setState(() => accountError = 'That email already has an account.');
      return;
    }
    final saved = await _performAdminAction(
      () => widget.onAddUser(AppUser(email: email, name: name, role: newRole)),
    );
    if (!saved) return;
    nameController.clear();
    emailController.clear();
    setState(() => accountError = null);
  }

  Future<void> scheduleCampaign(Campaign campaign) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      await _performAdminAction(
        () => widget.onScheduleCampaign(campaign, date),
      );
    }
  }

  Future<bool> _performAdminAction(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => operationError = null);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => operationError = 'Could not save changes: $error');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    children: [
      BrandHeader(onSignOut: widget.onSignOut),
      const SizedBox(height: 24),
      const PageHeading(
        eyebrow: 'SYSTEM CONTROL',
        title: 'Admin console',
        subtitle: 'Manage access, segmentation rules, and campaign approvals.',
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: widget.onImport,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Import customer data'),
        style: OutlinedButton.styleFrom(foregroundColor: forest),
      ),
      Row(
        children: [
          TextButton.icon(
            key: const ValueKey('admin-open-overview'),
            onPressed: () => setState(() => section = _AdminSection.overview),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Overview'),
          ),
          const Spacer(),
          TextButton.icon(
            key: const ValueKey('admin-open-audit'),
            onPressed: () => setState(() => section = _AdminSection.audit),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Audit'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SegmentedButton<_AdminSection>(
        segments: const [
          ButtonSegment(value: _AdminSection.accounts, label: Text('Accounts')),
          ButtonSegment(value: _AdminSection.models, label: Text('Models')),
          ButtonSegment(
            value: _AdminSection.campaigns,
            label: Text('Campaigns'),
          ),
          ButtonSegment(value: _AdminSection.orders, label: Text('Orders')),
        ],
        selected: section == _AdminSection.overview ? {} : {section},
        emptySelectionAllowed: true,
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            setState(() => section = selection.first);
          }
        },
      ),
      if (operationError != null) ...[
        const SizedBox(height: 8),
        Text(operationError!, style: const TextStyle(color: Color(0xFFAD4A31))),
      ],
      const SizedBox(height: 18),
      switch (section) {
        _AdminSection.overview => _overviewSection(),
        _AdminSection.accounts => _accountsSection(),
        _AdminSection.models => _modelsSection(),
        _AdminSection.campaigns => _campaignsSection(),
        _AdminSection.orders => _ordersSection(),
        _AdminSection.audit => _auditSection(),
      },
      const SizedBox(height: 10),
      Text(
        'Shop orders are demo requests only; no payment is processed.',
        style: const TextStyle(color: muted, fontSize: 10, height: 1.4),
      ),
    ],
  );

  Future<void> _refreshAudit() async {
    setState(() => isRefreshingAudit = true);
    try {
      await widget.onRefreshAudit();
    } catch (error) {
      if (mounted) {
        setState(
          () => operationError = 'Could not refresh audit history: $error',
        );
      }
    } finally {
      if (mounted) setState(() => isRefreshingAudit = false);
    }
  }

  Future<void> _copyAuditCsv(List<AdminAuditEvent> events) async {
    final csv = CsvEncoder().convert([
      ['Timestamp (UTC)', 'Actor', 'Role', 'Event', 'Entity', 'Summary'],
      for (final event in events)
        [
          event.createdAt.toUtc().toIso8601String(),
          event.actorName,
          event.actorRole,
          event.eventType,
          event.entityType,
          event.summary,
        ],
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${events.length} audit events as CSV.')),
    );
  }

  Widget _auditSection() {
    final query = auditQuery.trim().toLowerCase();
    final now = DateTime.now();
    final events = widget.auditEvents.where((event) {
      final matchesQuery =
          query.isEmpty ||
          '${event.actorName} ${event.actorRole} ${event.eventType} ${event.entityType} ${event.summary}'
              .toLowerCase()
              .contains(query);
      return matchesQuery &&
          auditCategory.matches(event) &&
          auditTimeFilter.matches(event.createdAt.toLocal(), now);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionLabel(
                title: 'Audit history (${widget.auditEvents.length})',
              ),
            ),
            IconButton(
              key: const ValueKey('admin-refresh-audit'),
              tooltip: 'Refresh audit history',
              onPressed: isRefreshingAudit ? null : _refreshAudit,
              icon: isRefreshingAudit
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              key: const ValueKey('admin-export-audit-csv'),
              tooltip: 'Copy filtered audit as CSV',
              onPressed: events.isEmpty ? null : () => _copyAuditCsv(events),
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('admin-audit-search'),
          onChanged: (value) => setState(() => auditQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search audit events',
            prefixIcon: Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in _AuditCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('admin-audit-category-${category.name}'),
                    label: Text(category.label),
                    selected: auditCategory == category,
                    onSelected: (_) => setState(() => auditCategory = category),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final timeFilter in _AuditTimeFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('admin-audit-time-${timeFilter.name}'),
                    label: Text(timeFilter.label),
                    selected: auditTimeFilter == timeFilter,
                    onSelected: (_) =>
                        setState(() => auditTimeFilter = timeFilter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (widget.auditError != null)
          _AuditEmptyState(message: widget.auditError!)
        else if (events.isEmpty)
          _AuditEmptyState(
            message: query.isEmpty
                ? 'No audit events have been recorded yet.'
                : 'No audit events match your search.',
          )
        else
          for (final event in events) _AuditEventTile(event: event),
      ],
    );
  }

  Widget _overviewSection() {
    final pendingCampaigns = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingApproval)
        .length;
    final openOrders = widget.orders
        .where(
          (order) =>
              order.status == CustomerOrderStatus.received ||
              order.status == CustomerOrderStatus.processing,
        )
        .length;
    final staffCount = widget.users
        .where((user) => user.role != AppRole.customer)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: 'Operations overview'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OverviewMetric(
                label: 'STAFF',
                value: staffCount,
                icon: Icons.badge_outlined,
                color: sky,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewMetric(
                label: 'TO REVIEW',
                value: pendingCampaigns,
                icon: Icons.campaign_outlined,
                color: coral,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewMetric(
                label: 'OPEN ORDERS',
                value: openOrders,
                icon: Icons.local_shipping_outlined,
                color: mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionLabel(title: 'Needs attention'),
        const SizedBox(height: 8),
        if (pendingCampaigns > 0)
          _OverviewAction(
            icon: Icons.campaign_outlined,
            title:
                '$pendingCampaigns campaign${pendingCampaigns == 1 ? '' : 's'} awaiting review',
            subtitle: 'Approve or schedule submitted campaign drafts.',
            onTap: () => setState(() => section = _AdminSection.campaigns),
          ),
        if (openOrders > 0)
          _OverviewAction(
            icon: Icons.local_shipping_outlined,
            title: '$openOrders order${openOrders == 1 ? '' : 's'} in progress',
            subtitle: 'Review requests and update their fulfillment status.',
            onTap: () => setState(() => section = _AdminSection.orders),
          ),
        if (pendingCampaigns == 0 && openOrders == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Nothing needs attention right now.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('admin-overview-accounts'),
          onPressed: () => setState(() => section = _AdminSection.accounts),
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('Manage staff accounts'),
          style: OutlinedButton.styleFrom(foregroundColor: forest),
        ),
      ],
    );
  }

  Widget _accountsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel(title: 'Add account'),
      const SizedBox(height: 10),
      TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Full name',
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 9),
      TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email address',
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 9),
      DropdownButtonFormField<AppRole>(
        initialValue: newRole,
        decoration: const InputDecoration(
          labelText: 'Assigned role',
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          for (final role in AppRole.values)
            DropdownMenuItem(value: role, child: Text(role.label)),
        ],
        onChanged: (role) {
          if (role != null) setState(() => newRole = role);
        },
      ),
      if (accountError != null) ...[
        const SizedBox(height: 8),
        Text(accountError!, style: const TextStyle(color: Color(0xFFAD4A31))),
      ],
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: addAccount,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Add account'),
        style: FilledButton.styleFrom(backgroundColor: forest),
      ),
      const SizedBox(height: 24),
      _SectionLabel(title: 'Users (${widget.users.length})'),
      const SizedBox(height: 7),
      for (final user in widget.users)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: user.role == AppRole.admin
                ? lime
                : const Color(0xFFE6EADD),
            child: Text(
              user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
              style: const TextStyle(
                color: forest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(user.name),
          subtitle: Text('${user.email}  |  ${user.role.shortLabel}'),
          trailing: user.id == widget.currentUser.id
              ? const Text('You', style: TextStyle(color: muted, fontSize: 11))
              : PopupMenuButton<String>(
                  tooltip: 'Manage ${user.name}',
                  onSelected: (action) async {
                    if (action == 'remove') {
                      await _performAdminAction(
                        () => widget.onRemoveUser(user),
                      );
                    } else {
                      final role = AppRole.values.byName(action);
                      await _performAdminAction(
                        () => widget.onUpdateUser(user.copyWith(role: role)),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    for (final role in AppRole.values)
                      PopupMenuItem(
                        value: role.name,
                        child: Text('Assign ${role.shortLabel}'),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove account'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, color: muted),
                ),
        ),
    ],
  );

  Widget _modelsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel(title: 'Segmentation algorithm'),
      const SizedBox(height: 10),
      DropdownButtonFormField<SegmentationAlgorithm>(
        initialValue: settings.algorithm,
        decoration: const InputDecoration(
          labelText: 'Model',
          filled: true,
          fillColor: Colors.white,
        ),
        items: const [
          DropdownMenuItem(
            value: SegmentationAlgorithm.rfm,
            child: Text('RFM scoring'),
          ),
          DropdownMenuItem(
            value: SegmentationAlgorithm.ruleBased,
            child: Text('Rule-based segments'),
          ),
        ],
        onChanged: (algorithm) async {
          if (algorithm != null) {
            final previous = settings;
            final next = settings.copyWith(algorithm: algorithm);
            setState(() => settings = next);
            if (!await _performAdminAction(() => widget.onSaveSettings(next))) {
              setState(() => settings = previous);
            }
          }
        },
      ),
      const SizedBox(height: 18),
      _ThresholdSetting(
        label: 'High-value spend threshold',
        value: settings.highValueSpend.toDouble(),
        min: 100,
        max: 2000,
        divisions: 19,
        valueLabel: formatRand(settings.highValueSpend),
        onChanged: (value) async {
          final previous = settings;
          final next = settings.copyWith(highValueSpend: value.round());
          setState(() => settings = next);
          if (!await _performAdminAction(() => widget.onSaveSettings(next))) {
            setState(() => settings = previous);
          }
        },
      ),
      const SizedBox(height: 12),
      _ThresholdSetting(
        label: 'At-risk inactivity threshold',
        value: settings.atRiskDays.toDouble(),
        min: 14,
        max: 180,
        divisions: 33,
        valueLabel: '${settings.atRiskDays} days',
        onChanged: (value) async {
          final previous = settings;
          final next = settings.copyWith(atRiskDays: value.round());
          setState(() => settings = next);
          if (!await _performAdminAction(() => widget.onSaveSettings(next))) {
            setState(() => settings = previous);
          }
        },
      ),
    ],
  );

  Widget _campaignsSection() {
    final pending = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingApproval)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: 'Pending approval (${pending.length})'),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Text(
            'No campaigns are waiting for approval.',
            style: TextStyle(color: muted),
          ),
        for (final campaign in pending)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.name,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${campaign.segmentName}  |  ${campaign.status.label}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  campaign.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _performAdminAction(
                        () => widget.onApproveCampaign(campaign),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Approve'),
                    ),
                    TextButton.icon(
                      onPressed: () => scheduleCampaign(campaign),
                      icon: const Icon(Icons.schedule_rounded, size: 17),
                      label: const Text('Schedule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const _SectionLabel(title: 'All campaigns'),
        for (final campaign in widget.campaigns)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.campaign_outlined, color: forest),
            title: Text(campaign.name),
            subtitle: Text(campaign.segmentName),
            trailing: Text(
              campaign.status.label,
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _ordersSection() {
    final orders = [...widget.orders]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    final query = orderSearch.trim().toLowerCase();
    final visibleOrders = orders.where((order) {
      final searchable =
          '${order.customerEmail} ${order.id} ${order.items.map((item) => item.productName).join(' ')}'
              .toLowerCase();
      return orderFilter.matches(order) && searchable.contains(query);
    }).toList();
    final selectedOrders = visibleOrders
        .where((order) => selectedOrderIds.contains(order.id))
        .toList();
    final processingOrders = selectedOrders
        .where((order) => order.status == CustomerOrderStatus.received)
        .toList();
    final fulfilledOrders = selectedOrders
        .where((order) => order.status == CustomerOrderStatus.processing)
        .toList();
    final cancellableOrders = selectedOrders
        .where(
          (order) =>
              order.status == CustomerOrderStatus.received ||
              order.status == CustomerOrderStatus.processing,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: 'Order queue (${orders.length})'),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('admin-order-search'),
          onChanged: (value) => setState(() {
            orderSearch = value;
            selectedOrderIds.clear();
          }),
          decoration: const InputDecoration(
            hintText: 'Search by customer, order ID, or item',
            prefixIcon: Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _AdminOrderFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      '${filter.label} (${orders.where(filter.matches).length})',
                    ),
                    selected: orderFilter == filter,
                    onSelected: (_) => setState(() {
                      orderFilter = filter;
                      selectedOrderIds.clear();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                selectedOrders.isEmpty
                    ? '${visibleOrders.length} orders shown'
                    : '${selectedOrders.length} selected',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('admin-select-visible-orders'),
              onPressed: visibleOrders.isEmpty
                  ? null
                  : () => setState(() {
                      final allSelected = visibleOrders.every(
                        (order) => selectedOrderIds.contains(order.id),
                      );
                      if (allSelected) {
                        selectedOrderIds.removeAll(
                          visibleOrders.map((order) => order.id),
                        );
                      } else {
                        selectedOrderIds.addAll(
                          visibleOrders.map((order) => order.id),
                        );
                      }
                    }),
              icon: const Icon(Icons.select_all_rounded, size: 18),
              label: const Text('Select visible'),
            ),
          ],
        ),
        if (selectedOrders.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (processingOrders.isNotEmpty)
                OutlinedButton.icon(
                  key: const ValueKey('bulk-order-processing'),
                  onPressed: () => _bulkUpdateOrders(
                    processingOrders,
                    CustomerOrderStatus.processing,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: Text('Process (${processingOrders.length})'),
                ),
              if (fulfilledOrders.isNotEmpty)
                OutlinedButton.icon(
                  key: const ValueKey('bulk-order-fulfilled'),
                  onPressed: () => _bulkUpdateOrders(
                    fulfilledOrders,
                    CustomerOrderStatus.fulfilled,
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: Text('Fulfill (${fulfilledOrders.length})'),
                ),
              if (cancellableOrders.isNotEmpty)
                TextButton.icon(
                  key: const ValueKey('bulk-order-cancelled'),
                  onPressed: () => _bulkUpdateOrders(
                    cancellableOrders,
                    CustomerOrderStatus.cancelled,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 17),
                  label: Text('Cancel (${cancellableOrders.length})'),
                ),
            ],
          ),
        if (orders.isEmpty)
          const Text(
            'No customer orders have been submitted.',
            style: TextStyle(color: muted),
          ),
        if (orders.isNotEmpty && visibleOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                'No orders match these filters.',
                style: TextStyle(color: muted),
              ),
            ),
          ),
        for (final order in visibleOrders) _orderCard(order),
      ],
    );
  }

  Future<void> _bulkUpdateOrders(
    List<CustomerOrder> orders,
    CustomerOrderStatus status,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${status.label} orders?'),
        content: Text(
          'Update ${orders.length} selected order${orders.length == 1 ? '' : 's'} to ${status.label.toLowerCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep orders'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm update'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var updatedCount = 0;
    for (final order in orders) {
      if (await _performAdminAction(
        () => widget.onUpdateOrder(order.copyWith(status: status)),
      )) {
        updatedCount++;
      }
    }
    if (!mounted) return;
    setState(() => selectedOrderIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated $updatedCount of ${orders.length} orders.'),
      ),
    );
  }

  Widget _orderCard(CustomerOrder order) {
    final availableStatuses = switch (order.status) {
      CustomerOrderStatus.received => [
        CustomerOrderStatus.received,
        CustomerOrderStatus.processing,
        CustomerOrderStatus.cancelled,
      ],
      CustomerOrderStatus.processing => [
        CustomerOrderStatus.processing,
        CustomerOrderStatus.fulfilled,
        CustomerOrderStatus.cancelled,
      ],
      CustomerOrderStatus.fulfilled => [CustomerOrderStatus.fulfilled],
      CustomerOrderStatus.cancelled => [CustomerOrderStatus.cancelled],
    };

    return Container(
      key: ValueKey('admin-order-${order.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
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
              Checkbox(
                value: selectedOrderIds.contains(order.id),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    selectedOrderIds.add(order.id);
                  } else {
                    selectedOrderIds.remove(order.id);
                  }
                }),
              ),
              Expanded(
                child: Text(
                  order.customerEmail,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              DropdownButton<CustomerOrderStatus>(
                key: ValueKey('order-status-${order.id}'),
                value: order.status,
                items: [
                  for (final status in availableStatuses)
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: availableStatuses.length == 1
                    ? null
                    : (status) {
                        if (status == null || status == order.status) return;
                        _performAdminAction(
                          () => widget.onUpdateOrder(
                            order.copyWith(status: status),
                          ),
                        );
                      },
              ),
            ],
          ),
          Text(
            'Order ${order.id.substring(order.id.length > 8 ? order.id.length - 8 : 0)}',
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          const Divider(height: 18),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} x ${item.productName}',
                      style: const TextStyle(color: ink, fontSize: 11),
                    ),
                  ),
                  Text(
                    formatRand(item.subtotal),
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatRand(order.total),
              style: const TextStyle(
                color: forest,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: ink,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.history_rounded, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _AuditEventTile extends StatelessWidget {
  const _AuditEventTile({required this.event});

  final AdminAuditEvent event;

  String get title => switch (event.eventType) {
    'role_changed' => 'Staff role changed',
    'campaign_created' => 'Campaign created',
    'campaign_status_changed' => 'Campaign status updated',
    'order_created' => 'Customer order received',
    'order_status_changed' => 'Order status updated',
    'segmentation_settings_changed' => 'Segmentation settings changed',
    _ => event.eventType.replaceAll('_', ' '),
  };

  IconData get icon => switch (event.entityType) {
    'profile' => Icons.badge_outlined,
    'campaign' => Icons.campaign_outlined,
    'customer_order' => Icons.local_shipping_outlined,
    'segmentation_settings' => Icons.tune_rounded,
    _ => Icons.history_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final localTime = event.createdAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(localTime);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(localTime));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: forest),
          title: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(event.summary),
              const SizedBox(height: 3),
              Text(
                '${event.actorName} · ${event.actorRole} · $date, $time',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
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

class _OverviewAction extends StatelessWidget {
  const _OverviewAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: forest),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded, color: muted),
      ),
    ),
  );
}

class _ThresholdSetting extends StatelessWidget {
  const _ThresholdSetting({
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
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            valueLabel,
            style: const TextStyle(
              color: forest,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        activeColor: forest,
        onChanged: onChanged,
      ),
    ],
  );
}
