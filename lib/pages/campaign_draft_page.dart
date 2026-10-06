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
  static const _maxMessageLength = 500;
  late final TextEditingController draftController;
  late final TextEditingController nameController;

  bool get hasUnsupportedFields => RegExp(r'\{([^{}]+)\}')
      .allMatches(draftController.text)
      .any((match) => !{'first_name', 'segment'}.contains(match[1]));

  bool get hasCallToAction => RegExp(
    r'\b(shop|browse|claim|explore|visit|use|get|order|discover|reply|save)\b',
    caseSensitive: false,
  ).hasMatch(draftController.text);

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

  void insertMergeField(String field) {
    final value = draftController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final updatedText = value.text.replaceRange(start, end, '{$field}');
    draftController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + field.length + 2),
    );
    setState(() {});
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
            key: const ValueKey('campaign-draft-name'),
            controller: nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Campaign name',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('campaign-draft-copy'),
          controller: draftController,
          minLines: 8,
          maxLines: 14,
          maxLength: _maxMessageLength,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            alignLabelWithHint: true,
            labelText: 'Campaign copy',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'PERSONALIZATION',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 7,
          children: [
            ActionChip(
              key: const ValueKey('insert-first-name-field'),
              label: const Text('{first_name}'),
              onPressed: () => insertMergeField('first_name'),
            ),
            ActionChip(
              key: const ValueKey('insert-segment-field'),
              label: const Text('{segment}'),
              onPressed: () => insertMergeField('segment'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _CampaignCheck(
          icon: hasUnsupportedFields
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          label: hasUnsupportedFields
              ? 'Unsupported field. Use {first_name} or {segment}.'
              : 'Personalization fields are ready.',
          isWarning: hasUnsupportedFields,
        ),
        _CampaignCheck(
          icon: hasCallToAction
              ? Icons.check_circle_outline_rounded
              : Icons.tips_and_updates_outlined,
          label: hasCallToAction
              ? 'Call to action detected.'
              : 'Consider adding a clear call to action.',
          isWarning: !hasCallToAction,
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('campaign-message-preview'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: forest.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SAMPLE PREVIEW',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                personalizeCampaignMessage(
                  draftController.text,
                  firstName: 'Maya',
                  segmentName: widget.segment.name,
                ),
                style: const TextStyle(color: ink, fontSize: 12, height: 1.4),
              ),
            ],
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
            key: const ValueKey('campaign-submit-approval'),
            onPressed:
                nameController.text.trim().isEmpty ||
                    draftController.text.trim().isEmpty ||
                    hasUnsupportedFields
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

class _CampaignCheck extends StatelessWidget {
  const _CampaignCheck({
    required this.icon,
    required this.label,
    required this.isWarning,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: isWarning ? coral : forest),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: isWarning ? coral : muted, fontSize: 11),
          ),
        ),
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
