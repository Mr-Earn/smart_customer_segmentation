import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';

class CampaignDraftPage extends StatefulWidget {
  const CampaignDraftPage({
    super.key,
    required this.segment,
    this.onSaveCampaign,
  });

  final CustomerSegment segment;
  final ValueChanged<Campaign>? onSaveCampaign;

  @override
  State<CampaignDraftPage> createState() => _CampaignDraftPageState();
}

class _CampaignDraftPageState extends State<CampaignDraftPage> {
  late final TextEditingController draftController;
  late final TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    draftController = TextEditingController(
      text: _suggestedDraft(widget.segment),
    );
    nameController = TextEditingController(
      text: '${widget.segment.name} audience campaign',
    );
  }

  @override
  void dispose() {
    draftController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Campaign draft')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.segment.name.toUpperCase(),
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A message for this audience',
          style: TextStyle(
            color: ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.segment.count} customers in this segment',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        if (widget.onSaveCampaign != null) ...[
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Campaign name',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: draftController,
          minLines: 8,
          maxLines: 14,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            alignLabelWithHint: true,
            labelText: 'Campaign copy',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: draftController.text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Campaign copy copied.')),
              );
            }
          },
          icon: const Icon(Icons.content_copy_rounded),
          label: const Text('Copy campaign copy'),
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        if (widget.onSaveCampaign != null) ...[
          const SizedBox(height: 9),
          FilledButton.icon(
            onPressed: nameController.text.trim().isEmpty
                ? null
                : () {
                    widget.onSaveCampaign!(
                      Campaign(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: nameController.text.trim(),
                        segmentName: widget.segment.name,
                        message: draftController.text.trim(),
                        status: CampaignStatus.pendingApproval,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Campaign submitted for admin review.'),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit for approval'),
            style: FilledButton.styleFrom(
              backgroundColor: forest,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String _suggestedDraft(CustomerSegment segment) => switch (segment.name) {
  'Champions' =>
    'You are one of our most valued customers. Get an early look at what is coming next, just for you.',
  'Regulars' =>
    'Thanks for making us part of your routine. Your next order comes with a little something extra.',
  'At risk' =>
    'It has been a while. We would love to welcome you back with a special offer on your next visit.',
  'New customers' =>
    'Welcome to the community. Here is a little thank-you for your next order.',
  _ =>
    'We have something selected for you. Take a look at what is new and find your next favourite.',
};
