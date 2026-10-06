import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'campaign_draft_page.dart';

enum _MarketingSection { segments, campaigns, team }

enum _CampaignFilter {
  all,
  draft,
  pendingApproval,
  approved,
  scheduled,
  active,
}

extension _CampaignFilterLabel on _CampaignFilter {
  String get label => switch (this) {
    _CampaignFilter.all => 'All',
    _CampaignFilter.draft => 'Draft',
    _CampaignFilter.pendingApproval => 'Review',
    _CampaignFilter.approved => 'Approved',
    _CampaignFilter.scheduled => 'Scheduled',
    _CampaignFilter.active => 'Active',
  };

  bool matches(Campaign campaign) => switch (this) {
    _CampaignFilter.all => true,
    _CampaignFilter.draft => campaign.status == CampaignStatus.draft,
    _CampaignFilter.pendingApproval =>
      campaign.status == CampaignStatus.pendingApproval,
    _CampaignFilter.approved => campaign.status == CampaignStatus.approved,
    _CampaignFilter.scheduled => campaign.status == CampaignStatus.scheduled,
    _CampaignFilter.active => campaign.status == CampaignStatus.active,
  };
}

class MarketingWorkspacePage extends StatefulWidget {
  const MarketingWorkspacePage({
    super.key,
    required this.currentUser,
    required this.staffUsers,
    required this.customers,
    required this.segments,
    required this.campaigns,
    required this.staffMessages,
    required this.onCreateCampaign,
    required this.onLaunchCampaign,
    required this.onSendMessage,
    required this.onMarkMessageRead,
    required this.onRefreshMessages,
    required this.onSignOut,
    this.teamOnly = false,
  });

  final AppUser currentUser;
  final List<AppUser> staffUsers;
  final List<Customer> customers;
  final List<CustomerSegment> segments;
  final List<Campaign> campaigns;
  final List<StaffMessage> staffMessages;
  final ValueChanged<Campaign> onCreateCampaign;
  final ValueChanged<Campaign> onLaunchCampaign;
  final Future<void> Function(AppUser recipient, String body) onSendMessage;
  final Future<void> Function(StaffMessage message) onMarkMessageRead;
  final Future<void> Function() onRefreshMessages;
  final VoidCallback onSignOut;
  final bool teamOnly;

  @override
  State<MarketingWorkspacePage> createState() => _MarketingWorkspacePageState();
}

class _MarketingWorkspacePageState extends State<MarketingWorkspacePage> {
  _MarketingSection section = _MarketingSection.segments;
  _CampaignFilter campaignFilter = _CampaignFilter.all;
  String campaignQuery = '';
  bool showingSentMessages = false;
  bool isRefreshingMessages = false;

  String get _currentUserId =>
      widget.currentUser.authId ?? widget.currentUser.id;

  List<AppUser> get _staffContacts => [
    for (final user in widget.staffUsers)
      if (user.role != AppRole.customer && user.id != widget.currentUser.id)
        user,
  ];

  int get _unreadCount => widget.staffMessages
      .where(
        (message) => message.recipientId == _currentUserId && !message.isRead,
      )
      .length;

  List<Customer> _audienceFor(Campaign campaign) => widget.customers
      .where((customer) => customer.segmentName == campaign.segmentName)
      .toList();

  void openDraft(CustomerSegment segment) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CampaignDraftPage(
          segment: segment,
          onSaveCampaign: widget.onCreateCampaign,
        ),
      ),
    );
  }

  void openCampaignPreview(Campaign campaign) {
    final audience = _audienceFor(campaign);
    final targetSummary =
        '${audience.length} customer records match ${campaign.segmentName}';
    final averageSpend = audience.isEmpty
        ? 0
        : audience.fold<int>(
                0,
                (total, customer) => total + customer.lifetimeSpend,
              ) ~/
              audience.length;
    final recentCount = audience
        .where((customer) => customer.daysSincePurchase <= 30)
        .length;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(campaign.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$targetSummary  |  ${campaign.status.label}',
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (audience.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  '$recentCount purchased in the last 30 days  |  Avg. recorded spend ${formatRand(averageSpend)}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
              if (campaign.scheduledAt != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Scheduled ${MaterialLocalizations.of(context).formatMediumDate(campaign.scheduledAt!)}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'MESSAGE PREVIEW',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                personalizeCampaignMessage(
                  campaign.message,
                  firstName:
                      audience.firstOrNull?.name
                          .trim()
                          .split(RegExp(r'\s+'))
                          .firstOrNull ??
                      'Maya',
                  segmentName: campaign.segmentName,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: personalizeCampaignMessage(
                    campaign.message,
                    firstName:
                        audience.firstOrNull?.name
                            .trim()
                            .split(RegExp(r'\s+'))
                            .firstOrNull ??
                        'Maya',
                    segmentName: campaign.segmentName,
                  ),
                ),
              );
              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Campaign message copied.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy message'),
          ),
        ],
      ),
    );
  }

  Future<void> composeMessage({AppUser? initialRecipient}) async {
    final contacts = _staffContacts;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other staff accounts are available.')),
      );
      return;
    }
    final result = await showDialog<(AppUser, String)>(
      context: context,
      builder: (_) => _ComposeStaffMessageDialog(
        contacts: contacts,
        initialRecipient: initialRecipient,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.onSendMessage(result.$1, result.$2);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent to ${result.$1.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message could not be sent: $error')),
      );
    }
  }

  Future<void> openStaffMessage(StaffMessage message) async {
    final incoming = message.recipientId == _currentUserId;
    if (incoming && !message.isRead) {
      try {
        await widget.onMarkMessageRead(message);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Read receipt could not be saved: $error')),
        );
      }
    }
    if (!mounted) return;
    final replyTo = incoming
        ? _staffContacts
              .where(
                (user) =>
                    user.authId == message.senderId ||
                    user.id == message.senderId,
              )
              .firstOrNull
        : null;
    final shouldReply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          incoming ? message.senderName : 'To ${message.recipientName}',
        ),
        content: SingleChildScrollView(child: Text(message.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          if (incoming && replyTo != null)
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.reply_rounded, size: 17),
              label: const Text('Reply'),
            ),
        ],
      ),
    );
    if (shouldReply == true && replyTo != null) {
      await composeMessage(initialRecipient: replyTo);
    }
  }

  Future<void> refreshMessages() async {
    setState(() => isRefreshingMessages = true);
    try {
      await widget.onRefreshMessages();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Messages could not be refreshed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => isRefreshingMessages = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingApproval)
        .length;

    return Scaffold(
      body: AppPage(
        children: [
          BrandHeader(onSignOut: widget.onSignOut),
          const SizedBox(height: 24),
          PageHeading(
            eyebrow: widget.teamOnly ? 'STAFF MESSAGES' : 'MARKETING WORKSPACE',
            title: widget.teamOnly ? 'Team inbox' : 'Reach the right people.',
            subtitle: widget.teamOnly
                ? 'Coordinate campaign work with your staff teammates.'
                : 'Explore your audiences and keep campaigns moving.',
          ),
          const SizedBox(height: 18),
          if (!widget.teamOnly && section == _MarketingSection.campaigns) ...[
            _priorityPanel(),
            const SizedBox(height: 10),
          ],
          if (!widget.teamOnly && section == _MarketingSection.segments)
            _segmentsSection(),
          if (!widget.teamOnly && section == _MarketingSection.campaigns)
            _campaignsSection(),
          if (widget.teamOnly || section == _MarketingSection.team)
            _teamSection(),
        ],
      ),
      bottomNavigationBar: widget.teamOnly
          ? null
          : NavigationBar(
              height: 68,
              backgroundColor: Colors.white,
              indicatorColor: lime.withValues(alpha: 0.45),
              selectedIndex: section.index,
              onDestinationSelected: (index) =>
                  setState(() => section = _MarketingSection.values[index]),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Segments',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.campaign_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.campaign_rounded),
                  ),
                  label: 'Campaigns',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text('$_unreadCount'),
                    child: const Icon(Icons.forum_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text('$_unreadCount'),
                    child: const Icon(Icons.forum_rounded),
                  ),
                  label: 'Team',
                ),
              ],
            ),
    );
  }

  Widget _priorityPanel() {
    final reviewCount = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingApproval)
        .length;
    final launchCount = widget.campaigns
        .where(
          (campaign) =>
              campaign.status == CampaignStatus.approved ||
              campaign.status == CampaignStatus.scheduled,
        )
        .length;
    final action = reviewCount > 0
        ? '$reviewCount campaign${reviewCount == 1 ? '' : 's'} waiting for review'
        : launchCount > 0
        ? '$launchCount approved campaign${launchCount == 1 ? '' : 's'} ready to launch'
        : 'Campaigns are up to date';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: forest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: lime, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (reviewCount > 0 || launchCount > 0)
            TextButton(
              onPressed: () =>
                  setState(() => section = _MarketingSection.campaigns),
              style: TextButton.styleFrom(foregroundColor: lime),
              child: const Text('Open'),
            ),
        ],
      ),
    );
  }

  Widget _teamSection() {
    final visibleMessages =
        widget.staffMessages
            .where(
              (message) => showingSentMessages
                  ? message.senderId == _currentUserId
                  : message.recipientId == _currentUserId,
            )
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'TEAM INBOX',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh messages',
              onPressed: isRefreshingMessages ? null : refreshMessages,
              icon: isRefreshingMessages
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
            FilledButton.icon(
              onPressed: composeMessage,
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: const Text('Compose'),
              style: FilledButton.styleFrom(
                backgroundColor: forest,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Inbox')),
            ButtonSegment(value: true, label: Text('Sent')),
          ],
          selected: {showingSentMessages},
          onSelectionChanged: (selection) =>
              setState(() => showingSentMessages = selection.first),
        ),
        const SizedBox(height: 12),
        if (visibleMessages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.forum_outlined, color: muted, size: 28),
                const SizedBox(height: 9),
                Text(
                  showingSentMessages
                      ? 'Messages you send will appear here.'
                      : 'Your inbox is clear.',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        for (final message in visibleMessages)
          _StaffMessageTile(
            message: message,
            currentUserId: _currentUserId,
            onTap: () => openStaffMessage(message),
          ),
      ],
    );
  }

  Widget _workspaceSnapshot() {
    final audienceCount = widget.segments.fold<int>(
      0,
      (total, segment) => total + segment.count,
    );
    final liveCount = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.active)
        .length;
    final reviewCount = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingApproval)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: forest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WorkspaceMetric(label: 'AUDIENCE', value: '$audienceCount'),
          ),
          Expanded(
            child: _WorkspaceMetric(label: 'LIVE', value: '$liveCount'),
          ),
          Expanded(
            child: _WorkspaceMetric(label: 'IN REVIEW', value: '$reviewCount'),
          ),
        ],
      ),
    );
  }

  Widget _segmentsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: lime.withValues(alpha: 0.23),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: forest),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'At-risk customers are a strong candidate for a thoughtful win-back offer.',
                style: TextStyle(color: forest, fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (final segment in widget.segments)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SegmentIcon(segment: segment),
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
                          '${segment.count} customers  |  Avg. ${formatRand(segment.averageSpend)}',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Draft for ${segment.name}',
                    onPressed: () => openDraft(segment),
                    icon: const Icon(Icons.edit_note_rounded, color: forest),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 10),
      _workspaceSnapshot(),
    ],
  );

  Widget _campaignsSection() {
    if (widget.campaigns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text('No campaigns yet. Draft one from a customer segment.'),
        ),
      );
    }
    final query = campaignQuery.trim().toLowerCase();
    final filteredCampaigns = widget.campaigns.where((campaign) {
      final matchesQuery =
          query.isEmpty ||
          '${campaign.name} ${campaign.segmentName} ${campaign.message}'
              .toLowerCase()
              .contains(query);
      return campaignFilter.matches(campaign) && matchesQuery;
    }).toList();
    final pendingCount = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingApproval)
        .length;
    final readyCount = widget.campaigns
        .where(
          (campaign) =>
              campaign.status == CampaignStatus.approved ||
              campaign.status == CampaignStatus.scheduled,
        )
        .length;
    final activeCount = widget.campaigns
        .where((campaign) => campaign.status == CampaignStatus.active)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _CampaignStatusCount(
                label: 'IN REVIEW',
                value: pendingCount,
                color: coral,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CampaignStatusCount(
                label: 'READY',
                value: readyCount,
                color: sky,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CampaignStatusCount(
                label: 'LIVE',
                value: activeCount,
                color: mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('marketing-campaign-search'),
          onChanged: (value) => setState(() => campaignQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search campaigns or audiences',
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
              for (final filter in _CampaignFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(
                      '${filter.label} (${widget.campaigns.where(filter.matches).length})',
                    ),
                    selected: campaignFilter == filter,
                    onSelected: (_) => setState(() => campaignFilter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filteredCampaigns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                query.isEmpty
                    ? 'No campaigns match this status.'
                    : 'No campaigns match your search.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ),
        for (final campaign in filteredCampaigns)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_outlined, color: forest),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.name,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${campaign.segmentName}  |  ${campaign.status.label}',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                      _campaignAudienceSnapshot(campaign),
                      if (campaign.scheduledAt != null)
                        Text(
                          'Scheduled ${MaterialLocalizations.of(context).formatMediumDate(campaign.scheduledAt!)}',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Preview ${campaign.name}',
                  onPressed: () => openCampaignPreview(campaign),
                  icon: const Icon(Icons.visibility_outlined),
                ),
                if (campaign.status == CampaignStatus.approved ||
                    campaign.status == CampaignStatus.scheduled)
                  FilledButton(
                    onPressed: () => widget.onLaunchCampaign(campaign),
                    style: FilledButton.styleFrom(
                      backgroundColor: forest,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Launch'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _campaignAudienceSnapshot(Campaign campaign) {
    final audience = _audienceFor(campaign);
    final averageSpend = audience.isEmpty
        ? 0
        : audience.fold<int>(
                0,
                (total, customer) => total + customer.lifetimeSpend,
              ) ~/
              audience.length;
    final recentCount = audience
        .where((customer) => customer.daysSincePurchase <= 30)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        audience.isEmpty
            ? 'No matching customer records'
            : '${audience.length} matching records  |  $recentCount recent  |  Avg. spend ${formatRand(averageSpend)}',
        key: ValueKey('marketing-audience-reach-${campaign.id}'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: forest, fontSize: 10),
      ),
    );
  }
}

class _ComposeStaffMessageDialog extends StatefulWidget {
  const _ComposeStaffMessageDialog({
    required this.contacts,
    this.initialRecipient,
  });

  final List<AppUser> contacts;
  final AppUser? initialRecipient;

  @override
  State<_ComposeStaffMessageDialog> createState() =>
      _ComposeStaffMessageDialogState();
}

class _ComposeStaffMessageDialogState
    extends State<_ComposeStaffMessageDialog> {
  final TextEditingController controller = TextEditingController();
  late AppUser recipient;

  @override
  void initState() {
    super.initState();
    recipient = widget.initialRecipient ?? widget.contacts.first;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New team message'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<AppUser>(
            initialValue: recipient,
            decoration: const InputDecoration(labelText: 'To'),
            items: [
              for (final contact in widget.contacts)
                DropdownMenuItem(
                  value: contact,
                  child: Text(
                    '${contact.name} · ${contact.role.shortLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => recipient = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.of(
                context,
              ).pop((recipient, controller.text.trim())),
        icon: const Icon(Icons.send_rounded, size: 17),
        label: const Text('Send'),
      ),
    ],
  );
}

class _StaffMessageTile extends StatelessWidget {
  const _StaffMessageTile({
    required this.message,
    required this.currentUserId,
    required this.onTap,
  });

  final StaffMessage message;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final incoming = message.recipientId == currentUserId;
    final otherName = incoming ? message.senderName : message.recipientName;
    final otherRole = incoming ? message.senderRole : message.recipientRole;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: incoming && !message.isRead ? lime : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: incoming && !message.isRead
              ? lime.withValues(alpha: 0.45)
              : canvas,
          child: Text(
            otherName.isEmpty ? '?' : otherName.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: forest, fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              DateFormat('MMM d, h:mm a').format(message.createdAt.toLocal()),
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                otherRole.shortLabel,
                style: const TextStyle(color: forest, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                message.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        trailing: incoming && !message.isRead
            ? const Icon(Icons.circle, color: forest, size: 9)
            : const Icon(Icons.chevron_right_rounded, color: muted),
      ),
    );
  }
}

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB7C9BD),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _CampaignStatusCount extends StatelessWidget {
  const _CampaignStatusCount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 9,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
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
