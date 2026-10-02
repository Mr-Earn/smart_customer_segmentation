import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'campaign_draft_page.dart';

enum _MarketingSection { segments, campaigns }

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
    required this.segments,
    required this.campaigns,
    required this.onCreateCampaign,
    required this.onLaunchCampaign,
    required this.onSignOut,
  });

  final List<CustomerSegment> segments;
  final List<Campaign> campaigns;
  final ValueChanged<Campaign> onCreateCampaign;
  final ValueChanged<Campaign> onLaunchCampaign;
  final VoidCallback onSignOut;

  @override
  State<MarketingWorkspacePage> createState() => _MarketingWorkspacePageState();
}

class _MarketingWorkspacePageState extends State<MarketingWorkspacePage> {
  _MarketingSection section = _MarketingSection.segments;
  _CampaignFilter campaignFilter = _CampaignFilter.all;
  String campaignQuery = '';

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
    final targetSegment = widget.segments
        .where((segment) => segment.name == campaign.segmentName)
        .firstOrNull;
    final targetSummary = targetSegment == null
        ? campaign.segmentName
        : '${targetSegment.count} customers in ${campaign.segmentName}';
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
              Text(campaign.message),
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
              await Clipboard.setData(ClipboardData(text: campaign.message));
              if (!dialogContext.mounted) return;
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
          const PageHeading(
            eyebrow: 'MARKETING WORKSPACE',
            title: 'Reach the right people.',
            subtitle: 'Explore your audiences and keep campaigns moving.',
          ),
          const SizedBox(height: 18),
          if (section == _MarketingSection.segments) _segmentsSection(),
          if (section == _MarketingSection.campaigns) _campaignsSection(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
        ],
      ),
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
