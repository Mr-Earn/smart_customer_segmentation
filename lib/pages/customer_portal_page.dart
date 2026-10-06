import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

enum _CustomerOrderFilter { all, open, fulfilled, cancelled }

extension _CustomerOrderFilterDetails on _CustomerOrderFilter {
  String get label => switch (this) {
    _CustomerOrderFilter.all => 'All',
    _CustomerOrderFilter.open => 'Open',
    _CustomerOrderFilter.fulfilled => 'Fulfilled',
    _CustomerOrderFilter.cancelled => 'Cancelled',
  };

  bool matches(CustomerOrder order) => switch (this) {
    _CustomerOrderFilter.all => true,
    _CustomerOrderFilter.open =>
      order.status == CustomerOrderStatus.received ||
          order.status == CustomerOrderStatus.processing,
    _CustomerOrderFilter.fulfilled =>
      order.status == CustomerOrderStatus.fulfilled,
    _CustomerOrderFilter.cancelled =>
      order.status == CustomerOrderStatus.cancelled,
  };
}

class CustomerPortalPage extends StatefulWidget {
  const CustomerPortalPage({
    super.key,
    required this.currentUser,
    required this.campaigns,
    required this.customer,
    required this.preferences,
    required this.savedCampaignIds,
    required this.orders,
    required this.onPlaceOrder,
    required this.onUpdateOrder,
    required this.onRefreshOrders,
    required this.onSaveSavedCampaigns,
    required this.onUpdateProfile,
    required this.onSavePreferences,
    required this.onSignOut,
  });

  final AppUser currentUser;
  final List<Campaign> campaigns;
  final Customer? customer;
  final Map<String, bool> preferences;
  final Set<String> savedCampaignIds;
  final List<CustomerOrder> orders;
  final Future<CustomerOrder> Function(CustomerOrder) onPlaceOrder;
  final Future<void> Function(CustomerOrder) onUpdateOrder;
  final Future<void> Function() onRefreshOrders;
  final ValueChanged<Set<String>> onSaveSavedCampaigns;
  final ValueChanged<AppUser> onUpdateProfile;
  final ValueChanged<Map<String, bool>> onSavePreferences;
  final VoidCallback onSignOut;

  @override
  State<CustomerPortalPage> createState() => _CustomerPortalPageState();
}

class _CustomerPortalPageState extends State<CustomerPortalPage> {
  int selectedTab = 0;
  late final TextEditingController nameController;
  late Map<String, bool> preferences;
  late Set<String> savedCampaignIds;
  final Map<String, int> cart = {};
  bool showSavedOffers = false;
  _CustomerOrderFilter orderFilter = _CustomerOrderFilter.all;
  bool isRefreshingOrders = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentUser.name);
    preferences = {
      'offers': widget.preferences['offers'] ?? true,
      'productNews': widget.preferences['productNews'] ?? true,
      'recommendations': widget.preferences['recommendations'] ?? false,
    };
    savedCampaignIds = Set.of(widget.savedCampaignIds);
  }

  @override
  void didUpdateWidget(covariant CustomerPortalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences) {
      preferences = {
        'offers': widget.preferences['offers'] ?? true,
        'productNews': widget.preferences['productNews'] ?? true,
        'recommendations': widget.preferences['recommendations'] ?? false,
      };
    }
    if (oldWidget.savedCampaignIds != widget.savedCampaignIds) {
      savedCampaignIds
        ..clear()
        ..addAll(widget.savedCampaignIds);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void updatePreference(String key, bool value) {
    setState(() => preferences[key] = value);
    widget.onSavePreferences(preferences);
  }

  String _campaignCopy(Campaign campaign) {
    final customerName = (widget.customer?.name ?? widget.currentUser.name)
        .trim();
    final firstName = customerName.isEmpty
        ? 'there'
        : customerName.split(RegExp(r'\s+')).first;
    return personalizeCampaignMessage(
      campaign.message,
      firstName: firstName,
      segmentName: campaign.segmentName,
    );
  }

  Future<void> exportCustomerData() async {
    final orders = [...widget.orders]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    final export = {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': {
        'name': widget.currentUser.name,
        'email': widget.currentUser.email,
        'role': widget.currentUser.role.name,
      },
      'customerRecord': widget.customer?.toJson(),
      'preferences': Map<String, bool>.of(preferences),
      'savedCampaigns': [
        for (final campaign in widget.campaigns)
          if (savedCampaignIds.contains(campaign.id))
            {
              'id': campaign.id,
              'name': campaign.name,
              'segmentName': campaign.segmentName,
              'status': campaign.status.name,
            },
      ],
      'orders': [for (final order in orders) order.toJson()],
    };
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer data copied as JSON.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segmentName = widget.customer?.segmentName ?? 'New customers';
    final activeCampaigns = widget.campaigns
        .where(
          (campaign) =>
              campaign.status == CampaignStatus.active &&
              campaign.segmentName == segmentName,
        )
        .toList();
    final offer = switch (segmentName) {
      'Champions' => 'A little something for our top customers',
      'Regulars' => 'Your loyalty just unlocked a new reward',
      'At risk' => 'Come back and enjoy a welcome-back offer',
      _ => 'Welcome. Enjoy a little extra on your next order',
    };

    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          _homePage(activeCampaigns),
          _shopPage(),
          _offersPage(offer, activeCampaigns),
          _ordersPage(),
          _profilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: lime.withValues(alpha: 0.45),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer_rounded),
            label: 'Offers',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _homePage(List<Campaign> activeCampaigns) => AppPage(
    children: [
      _pageHeading(
        section: 'YOUR CUSTOMER SPACE',
        title: 'Hello, ${widget.currentUser.name.split(' ').first}.',
        subtitle: widget.currentUser.email,
      ),
      const SizedBox(height: 20),
      _customerWelcomeCard(activeCampaigns.length),
      const SizedBox(height: 22),
      _homeCampaignsPreview(activeCampaigns),
      const SizedBox(height: 26),
      const Text(
        'Your activity',
        style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      _CustomerActivity(customer: widget.customer),
      const SizedBox(height: 18),
      _CustomerInsights(customer: widget.customer),
    ],
  );

  Widget _homeCampaignsPreview(List<Campaign> activeCampaigns) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Campaigns for you',
              style: TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => selectedTab = 1),
            child: const Text('All offers'),
          ),
        ],
      ),
      if (activeCampaigns.isEmpty)
        Text(
          'No live campaigns for ${widget.customer?.segmentName ?? 'your group'} right now.',
          style: const TextStyle(color: muted, fontSize: 12),
        )
      else
        for (final campaign in activeCampaigns.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                leading: const Icon(Icons.local_offer_outlined, color: forest),
                title: Text(
                  campaign.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _campaignCopy(campaign),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                onTap: () => setState(() => selectedTab = 1),
              ),
            ),
          ),
    ],
  );

  Widget _customerWelcomeCard(int activeOfferCount) {
    final groupName = widget.customer?.segmentName ?? 'New customers';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: forest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.loyalty_rounded, color: lime, size: 26),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR CUSTOMER GROUP',
                  style: TextStyle(
                    color: Color(0xFFB7C9BD),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$activeOfferCount active ${activeOfferCount == 1 ? 'offer' : 'offers'} for you',
                  style: const TextStyle(
                    color: Color(0xFFB7C9BD),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View your offers',
            onPressed: () => setState(() => selectedTab = 1),
            color: lime,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _offersPage(String offer, List<Campaign> activeCampaigns) {
    final savedCampaigns = activeCampaigns
        .where((campaign) => savedCampaignIds.contains(campaign.id))
        .toList();
    final visibleCampaigns = showSavedOffers ? savedCampaigns : activeCampaigns;

    return AppPage(
      children: [
        _pageHeading(
          section: 'OFFERS',
          title: 'For you',
          subtitle: 'Promotions matched to your customer group.',
        ),
        const SizedBox(height: 24),
        if (preferences['offers'] ?? true) ...[
          _personalOffer(offer),
          const SizedBox(height: 22),
          const Text(
            'Campaigns for you',
            style: TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (activeCampaigns.isNotEmpty) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('All offers (${activeCampaigns.length})'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Saved (${savedCampaigns.length})'),
                ),
              ],
              selected: {showSavedOffers},
              onSelectionChanged: (selection) =>
                  setState(() => showSavedOffers = selection.first),
            ),
            const SizedBox(height: 12),
          ],
          if (activeCampaigns.isEmpty)
            const Text(
              'No active campaigns for your customer group right now.',
              style: TextStyle(color: muted, fontSize: 12),
            )
          else if (visibleCampaigns.isEmpty)
            const Text(
              'No saved offers yet. Bookmark an offer to keep it here.',
              style: TextStyle(color: muted, fontSize: 12),
            )
          else
            for (final campaign in visibleCampaigns)
              _CampaignOffer(
                campaign: campaign,
                displayMessage: _campaignCopy(campaign),
                isSaved: savedCampaignIds.contains(campaign.id),
                onToggleSaved: () => setState(() {
                  if (!savedCampaignIds.add(campaign.id)) {
                    savedCampaignIds.remove(campaign.id);
                  }
                  widget.onSaveSavedCampaigns(Set.of(savedCampaignIds));
                }),
                onCopy: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _campaignCopy(campaign)),
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Campaign message copied.')),
                  );
                },
              ),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Promotional offers are paused. You can turn them back on in Profile preferences.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.4),
            ),
          ),
      ],
    );
  }

  Widget _shopPage() {
    final cartItems = demoProducts
        .where((product) => (cart[product.id] ?? 0) > 0)
        .toList();
    final total = cartItems.fold<int>(
      0,
      (sum, product) => sum + product.price * cart[product.id]!,
    );

    return AppPage(
      children: [
        _pageHeading(
          section: 'DEMO SHOP',
          title: 'Find your favourites.',
          subtitle: 'A sample catalogue for exploring the order flow.',
        ),
        const SizedBox(height: 10),
        const Text(
          'Demo checkout only. No payment will be collected.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        for (final product in demoProducts) _productRow(product),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cartItems.isEmpty
                    ? 'Your cart is empty'
                    : '${cartItems.fold<int>(0, (sum, item) => sum + cart[item.id]!)} items in your cart',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total  ${formatRand(total)}',
                style: const TextStyle(
                  color: lime,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('place-demo-order'),
                  onPressed: cartItems.isEmpty ? null : _confirmOrder,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Place demo order'),
                  style: FilledButton.styleFrom(
                    backgroundColor: lime,
                    foregroundColor: forest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _productRow(StoreProduct product) {
    final quantity = cart[product.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lime.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(product.icon, color: forest),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  product.description,
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  formatRand(product.price),
                  style: const TextStyle(
                    color: forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove one ${product.name}',
            onPressed: quantity == 0
                ? null
                : () => setState(() {
                    if (quantity == 1) {
                      cart.remove(product.id);
                    } else {
                      cart[product.id] = quantity - 1;
                    }
                  }),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Add one ${product.name}',
            onPressed: () => setState(() => cart[product.id] = quantity + 1),
            icon: const Icon(Icons.add_circle_outline_rounded, color: forest),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOrder() async {
    final lines = [
      for (final product in demoProducts)
        if ((cart[product.id] ?? 0) > 0)
          OrderLine(
            productId: product.id,
            productName: product.name,
            unitPrice: product.price,
            quantity: cart[product.id]!,
          ),
    ];
    if (lines.isEmpty) return;

    final order = CustomerOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      customerEmail: widget.currentUser.email.trim().toLowerCase(),
      items: lines,
      createdAt: DateTime.now().toUtc(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm demo order'),
        content: Text(
          '${lines.length} product types, total ${formatRand(order.total)}. No payment will be collected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep shopping'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.onPlaceOrder(order);
      if (!mounted) return;
      setState(() {
        cart.clear();
        selectedTab = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo order placed. No payment was taken.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not place order: $error')));
    }
  }

  Future<void> _cancelOrder(CustomerOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'This request can only be cancelled before processing begins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.onUpdateOrder(
        order.copyWith(status: CustomerOrderStatus.cancelled),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancellation requested.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel order: $error')));
    }
  }

  Future<void> _refreshOrders() async {
    setState(() => isRefreshingOrders = true);
    try {
      await widget.onRefreshOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Orders refreshed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh orders: $error')),
      );
    } finally {
      if (mounted) setState(() => isRefreshingOrders = false);
    }
  }

  void _buyAgain(CustomerOrder order) {
    final availableProductIds = demoProducts
        .map((product) => product.id)
        .toSet();
    var restoredQuantity = 0;
    setState(() {
      for (final item in order.items) {
        if (!availableProductIds.contains(item.productId)) continue;
        cart[item.productId] = (cart[item.productId] ?? 0) + item.quantity;
        restoredQuantity += item.quantity;
      }
      selectedTab = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restoredQuantity == 0
              ? 'Those products are no longer available in the demo shop.'
              : 'Items added to your cart at current demo catalog prices.',
        ),
      ),
    );
  }

  Widget _orderProgress(CustomerOrder order) {
    if (order.status == CustomerOrderStatus.cancelled) {
      return Container(
        key: ValueKey('order-progress-${order.id}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: coral, size: 18),
            SizedBox(width: 7),
            Text(
              'Order cancelled',
              style: TextStyle(
                color: coral,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final stages = [
      ('Received', Icons.inventory_2_outlined),
      ('Processing', Icons.autorenew_rounded),
      ('Fulfilled', Icons.check_circle_outline_rounded),
    ];
    return Padding(
      key: ValueKey('order-progress-${order.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          for (var index = 0; index < stages.length; index++)
            Expanded(
              child: Column(
                children: [
                  Icon(
                    index <= order.status.index
                        ? Icons.check_circle_rounded
                        : stages[index].$2,
                    color: index <= order.status.index ? forest : muted,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stages[index].$1,
                    style: TextStyle(
                      color: index == order.status.index ? forest : muted,
                      fontSize: 10,
                      fontWeight: index == order.status.index
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ordersPage() {
    final allOrders = [...widget.orders]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    final visibleOrders = allOrders.where(orderFilter.matches).toList();
    return AppPage(
      children: [
        _pageHeading(
          section: 'ORDERS',
          title: 'Your orders.',
          subtitle: 'Track the demo order requests you have submitted.',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const ValueKey('refresh-customer-orders'),
            tooltip: 'Refresh orders',
            onPressed: isRefreshingOrders ? null : _refreshOrders,
            icon: isRefreshingOrders
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 18),
        if (allOrders.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_CustomerOrderFilter>(
              showSelectedIcon: false,
              segments: [
                for (final filter in _CustomerOrderFilter.values)
                  ButtonSegment(
                    value: filter,
                    label: Text(
                      '${filter.label} (${allOrders.where(filter.matches).length})',
                    ),
                  ),
              ],
              selected: {orderFilter},
              onSelectionChanged: (selection) =>
                  setState(() => orderFilter = selection.first),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (allOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No orders yet. Visit Shop to place a demo order.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          )
        else if (visibleOrders.isEmpty)
          Text(
            'No ${orderFilter.label.toLowerCase()} orders.',
            style: const TextStyle(color: muted, fontSize: 12),
          )
        else
          for (final order in visibleOrders)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
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
                          'Order ${order.id.substring(order.id.length > 8 ? order.id.length - 8 : 0)}',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        order.status.label.toUpperCase(),
                        style: const TextStyle(
                          color: forest,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(order.createdAt.toLocal()),
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  _orderProgress(order),
                  const Divider(height: 18),
                  for (final line in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.quantity} x ${line.productName}',
                              style: const TextStyle(color: ink, fontSize: 12),
                            ),
                          ),
                          Text(
                            formatRand(line.subtotal),
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total  ${formatRand(order.total)}',
                      style: const TextStyle(
                        color: forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: ValueKey('buy-again-${order.id}'),
                      onPressed: () => _buyAgain(order),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: const Text('Buy again'),
                    ),
                  ),
                  if (order.status == CustomerOrderStatus.received)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: ValueKey('cancel-customer-order-${order.id}'),
                        onPressed: () => _cancelOrder(order),
                        icon: const Icon(Icons.cancel_outlined, size: 17),
                        label: const Text('Cancel order'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFAD4A31),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _profilePage() => AppPage(
    children: [
      _pageHeading(
        section: 'ACCOUNT',
        title: 'Your profile',
        subtitle: widget.currentUser.email,
      ),
      const SizedBox(height: 24),
      TextField(
        controller: nameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Display name',
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            widget.onUpdateProfile(
              AppUser(
                email: widget.currentUser.email,
                name: name,
                role: widget.currentUser.role,
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated on this device.')),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save profile'),
          style: FilledButton.styleFrom(backgroundColor: forest),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Preferences',
        style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Special offers'),
        subtitle: const Text('Personalized promotions and rewards'),
        value: preferences['offers'] ?? true,
        activeThumbColor: forest,
        onChanged: (value) => updatePreference('offers', value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Product news'),
        subtitle: const Text('Updates about new arrivals'),
        value: preferences['productNews'] ?? true,
        activeThumbColor: forest,
        onChanged: (value) => updatePreference('productNews', value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Recommendations'),
        subtitle: const Text('Suggestions based on your interests'),
        value: preferences['recommendations'] ?? false,
        activeThumbColor: forest,
        onChanged: (value) => updatePreference('recommendations', value),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const ValueKey('customer-export-data'),
        onPressed: exportCustomerData,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Copy my data as JSON'),
        style: OutlinedButton.styleFrom(foregroundColor: forest),
      ),
    ],
  );

  Widget _pageHeading({
    required String section,
    required String title,
    required String subtitle,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BrandHeader(onSignOut: widget.onSignOut),
      const SizedBox(height: 26),
      Text(
        section,
        style: const TextStyle(
          color: muted,
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 29,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );

  Widget _personalOffer(String offer) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.card_giftcard_rounded, color: lime, size: 24),
        const SizedBox(height: 13),
        const Text(
          'A PERSONAL OFFER',
          style: TextStyle(
            color: Color(0xFFB7C9BD),
            fontSize: 10,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          offer,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your preferences help us make these more relevant.',
          style: TextStyle(color: Color(0xFFB7C9BD), fontSize: 11),
        ),
      ],
    ),
  );
}

class _CampaignOffer extends StatelessWidget {
  const _CampaignOffer({
    required this.campaign,
    required this.displayMessage,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onCopy,
  });

  final Campaign campaign;
  final String displayMessage;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.local_offer_outlined, color: forest, size: 20),
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
              const SizedBox(height: 4),
              Text(
                displayMessage,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isSaved
              ? 'Remove ${campaign.name} from saved offers'
              : 'Save ${campaign.name}',
          onPressed: onToggleSaved,
          icon: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 18,
          ),
        ),
        IconButton(
          tooltip: 'Copy campaign message',
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _CustomerActivity extends StatelessWidget {
  const _CustomerActivity({required this.customer});

  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    final record = customer;
    if (record == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Your purchase activity will appear here once your account is linked.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.4),
        ),
      );
    }

    final lastPurchase = record.daysSincePurchase == 0
        ? 'Today'
        : '${record.daysSincePurchase} days ago';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                child: _ActivityMetric(
                  label: 'Lifetime spend',
                  value: formatRand(record.lifetimeSpend),
                ),
              ),
              Expanded(
                child: _ActivityMetric(
                  label: 'Orders',
                  value: '${record.orderCount}',
                ),
              ),
              Expanded(
                child: _ActivityMetric(
                  label: 'Last purchase',
                  value: lastPurchase,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Customer group: ${record.segmentName}',
            style: const TextStyle(
              color: forest,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerInsights extends StatelessWidget {
  const _CustomerInsights({required this.customer});

  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    final record = customer;
    if (record == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Loyalty insights will appear when your customer activity is linked.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.4),
        ),
      );
    }

    final averageOrderValue = record.orderCount == 0
        ? null
        : (record.lifetimeSpend / record.orderCount).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Loyalty insights',
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: lime.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.rfmTier,
                  style: const TextStyle(
                    color: forest,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActivityMetric(
                  label: 'RFM score',
                  value: '${record.rfmScore} / 15',
                ),
              ),
              Expanded(
                child: _ActivityMetric(
                  label: 'Average order',
                  value: averageOrderValue == null
                      ? 'Not available'
                      : formatRand(averageOrderValue),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _RfmScoreRow(label: 'Recency', score: record.recencyScore),
          const SizedBox(height: 10),
          _RfmScoreRow(label: 'Frequency', score: record.frequencyScore),
          const SizedBox(height: 10),
          _RfmScoreRow(label: 'Spend', score: record.monetaryScore),
        ],
      ),
    );
  }
}

class _RfmScoreRow extends StatelessWidget {
  const _RfmScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 76,
        child: Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      ),
      Expanded(
        child: LinearProgressIndicator(
          value: score / 5,
          minHeight: 6,
          color: forest,
          backgroundColor: canvas,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      SizedBox(
        width: 38,
        child: Text(
          '$score / 5',
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
