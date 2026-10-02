import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

enum _AdminSection { accounts, models, campaigns, orders }

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    super.key,
    required this.currentUser,
    required this.users,
    required this.campaigns,
    required this.orders,
    required this.settings,
    required this.onAddUser,
    required this.onUpdateUser,
    required this.onRemoveUser,
    required this.onSaveSettings,
    required this.onApproveCampaign,
    required this.onScheduleCampaign,
    required this.onUpdateOrder,
    required this.onImport,
    required this.onSignOut,
  });

  final AppUser currentUser;
  final List<AppUser> users;
  final List<Campaign> campaigns;
  final List<CustomerOrder> orders;
  final SegmentationSettings settings;
  final Future<void> Function(AppUser) onAddUser;
  final Future<void> Function(AppUser) onUpdateUser;
  final Future<void> Function(AppUser) onRemoveUser;
  final Future<void> Function(SegmentationSettings) onSaveSettings;
  final Future<void> Function(Campaign) onApproveCampaign;
  final Future<void> Function(Campaign campaign, DateTime date)
  onScheduleCampaign;
  final Future<void> Function(CustomerOrder order) onUpdateOrder;
  final VoidCallback onImport;
  final VoidCallback onSignOut;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  AppRole newRole = AppRole.analyst;
  _AdminSection section = _AdminSection.accounts;
  SegmentationSettings settings = const SegmentationSettings();
  String? accountError;
  String? operationError;

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
      if (mounted)
        setState(() => operationError = 'Could not save changes: $error');
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
        selected: {section},
        onSelectionChanged: (selection) =>
            setState(() => section = selection.first),
      ),
      if (operationError != null) ...[
        const SizedBox(height: 8),
        Text(operationError!, style: const TextStyle(color: Color(0xFFAD4A31))),
      ],
      const SizedBox(height: 18),
      switch (section) {
        _AdminSection.accounts => _accountsSection(),
        _AdminSection.models => _modelsSection(),
        _AdminSection.campaigns => _campaignsSection(),
        _AdminSection.orders => _ordersSection(),
      },
      const SizedBox(height: 10),
      Text(
        'Shop orders are demo requests only; no payment is processed.',
        style: const TextStyle(color: muted, fontSize: 10, height: 1.4),
      ),
    ],
  );

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: 'Order queue (${orders.length})'),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const Text(
            'No customer orders have been submitted.',
            style: TextStyle(color: muted),
          ),
        for (final order in orders) _orderCard(order),
      ],
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
