// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:smart_customer_segmentation/models.dart';
import 'package:smart_customer_segmentation/app_theme.dart';
import 'package:smart_customer_segmentation/main.dart';
import 'package:smart_customer_segmentation/pages/segment_builder_page.dart';
import 'package:smart_customer_segmentation/pages/auth_page.dart';
import 'package:smart_customer_segmentation/pages/splash_page.dart';
import 'package:smart_customer_segmentation/pages/customer_profile_page.dart';
import 'package:smart_customer_segmentation/services/local_store.dart';
import 'package:smart_customer_segmentation/services/customer_import_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('splash, sign-up, session restore, and sign-out work', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CustomerSegmentationApp());
    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);

    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-name')),
      'Amina Khumalo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'amina@localhost',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'securepass123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'securepass123',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'amina@example.co.za',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'differentpass',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'securepass123',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Audience intelligence'), findsOneWidget);

    await tester.pumpWidget(
      const CustomerSegmentationApp(key: ValueKey('restarted-app')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);
  });

  test('currency formatter returns rand in South African format', () {
    expect(formatRand(1234), startsWith('R'));
    expect(formatRand(68.4, decimalDigits: 2), contains('68'));
    expect(formatRand(68.4, decimalDigits: 2), isNot(contains('\$')));
  });

  test('customer orders calculate and preserve line totals', () {
    final order = CustomerOrder(
      id: 'order-test',
      customerEmail: 'olivia.chen@email.com',
      items: const [
        OrderLine(
          productId: 'coffee',
          productName: 'House blend coffee',
          unitPrice: 145,
          quantity: 2,
        ),
        OrderLine(
          productId: 'honey',
          productName: 'Wildflower honey',
          unitPrice: 95,
          quantity: 1,
        ),
      ],
      createdAt: DateTime.utc(2026, 10, 2),
    );

    expect(order.total, 385);
    final restored = CustomerOrder.fromJson(order.toJson());
    expect(restored.total, 385);
    expect(restored.items.first.quantity, 2);
    expect(restored.customerEmail, order.customerEmail);
    expect(restored.status, CustomerOrderStatus.received);
    expect(
      restored.copyWith(status: CustomerOrderStatus.processing).status.label,
      'Processing',
    );
  });

  test('AND and OR rules match customer profiles', () {
    final andRule = SegmentRule(
      conditions: [
        SegmentCondition(metric: SegmentMetric.lifetimeSpend, threshold: 500),
        SegmentCondition(
          metric: SegmentMetric.daysSincePurchase,
          threshold: 30,
        ),
      ],
    );
    final orRule = SegmentRule(
      join: SegmentJoin.any,
      conditions: [
        SegmentCondition(metric: SegmentMetric.lifetimeSpend, threshold: 1000),
        SegmentCondition(metric: SegmentMetric.daysSincePurchase, threshold: 6),
      ],
    );

    expect(sampleCustomers.where(andRule.matches).length, 3);
    expect(sampleCustomers.where(orRule.matches).length, 4);
  });

  test('role capabilities follow the app access matrix', () {
    expect(AppRole.admin.canManageUsers, isTrue);
    expect(AppRole.admin.canConfigureModels, isTrue);
    expect(AppRole.admin.canReviewCampaigns, isTrue);
    expect(AppRole.analyst.canUploadData, isTrue);
    expect(AppRole.analyst.canViewAnalytics, isTrue);
    expect(AppRole.analyst.canManageUsers, isFalse);
    expect(AppRole.marketing.canManageCampaigns, isTrue);
    expect(AppRole.marketing.canEditSegments, isFalse);
    expect(AppRole.marketing.canConfigureModels, isFalse);
    expect(AppRole.customer.canViewAnalytics, isFalse);
    expect(AppRole.customer.canManageCampaigns, isFalse);
  });

  test('customer importer parses CSV and JSON records', () {
    final importer = CustomerImportService();
    final csvCustomers = importer.parseCsv(
      'name,email,lifetime spend,orders,days since purchase,segment\n'
      '"Kea Molefe",kea@example.co.za,"R1,250",5,7,Champions',
    );
    final jsonCustomers = importer.parseJson(
      '[{"name":"Sipho Dlamini","email":"sipho@example.co.za",'
      '"lifetimeSpend":840,"orderCount":9,"daysSincePurchase":22}]',
    );

    expect(csvCustomers.single.lifetimeSpend, 1250);
    expect(csvCustomers.single.segmentName, 'Champions');
    expect(jsonCustomers.single.orderCount, 9);
    expect(jsonCustomers.single.daysSincePurchase, 22);
  });

  test('local store persists custom segments, favorites, and notes', () async {
    final store = LocalStore();
    final segment = CustomerSegment(
      name: 'Recent champions',
      description: 'High spend and recent activity',
      count: 2,
      color: lime,
      icon: Icons.auto_awesome_rounded,
      averageSpend: 1176,
      rule: const SegmentRule(
        conditions: [
          SegmentCondition(
            metric: SegmentMetric.lifetimeSpend,
            threshold: 1000,
          ),
          SegmentCondition(
            metric: SegmentMetric.daysSincePurchase,
            threshold: 30,
          ),
        ],
      ),
    );

    await store.saveSegments([segment]);
    await store.saveFavorites({'olivia.chen@email.com'});
    await store.saveNote('olivia.chen@email.com', 'Prefers email updates');

    final restored = await store.loadSegments();
    expect(restored.single.name, segment.name);
    expect(restored.single.matches(sampleCustomers.first), isTrue);
    expect(await store.loadFavorites(), {'olivia.chen@email.com'});
    expect(
      (await store.loadNotes())['olivia.chen@email.com'],
      'Prefers email updates',
    );
  });

  testWidgets('dashboard displays metrics and opens segments', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);

    expect(find.text('Audience intelligence'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.donut_large_rounded).first);
    await tester.pumpAndSettle();

    expect(
      find.text('Explore customer value and build precise audiences.'),
      findsOneWidget,
    );
  });

  testWidgets('customer filters open an RFM profile', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.tap(find.byIcon(Icons.people_alt_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('At risk'));
    await tester.pumpAndSettle();
    expect(find.text('2 customer records'), findsOneWidget);
    expect(find.text('Sofia Patel'), findsOneWidget);
    expect(find.text('Olivia Chen'), findsNothing);

    await tester.tap(find.text('Sofia Patel'));
    await tester.pumpAndSettle();
    expect(find.text('RFM SNAPSHOT'), findsOneWidget);
    expect(find.text('86 days'), findsOneWidget);
  });

  testWidgets('advanced customer filters refine and export the cohort', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.tap(find.byIcon(Icons.people_alt_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('risk-tier-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(find.text('Sofia Patel'), findsOneWidget);
    expect(find.text('Olivia Chen'), findsNothing);
    expect(find.byTooltip('Advanced filters (1 active)'), findsOneWidget);

    final exportButton = find.ancestor(
      of: find.byTooltip('Copy filtered customer CSV'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(exportButton.first).onPressed, isNotNull);
  });

  testWidgets('customer selection supports comparison and bulk email actions', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.tap(find.byIcon(Icons.people_alt_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Select customers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select visible'));
    await tester.pumpAndSettle();

    expect(find.text('Clear visible'), findsOneWidget);
    final copyEmailsButton = find.ancestor(
      of: find.text('Copy emails'),
      matching: find.byType(OutlinedButton),
    );
    expect(
      tester.widget<OutlinedButton>(copyEmailsButton.first).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Compare (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Compare customers (3)'), findsOneWidget);
    expect(find.text('Lifetime spend'), findsOneWidget);
    expect(find.text('RFM score'), findsOneWidget);
  });

  testWidgets('rule builder previews and saves a custom segment', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.tap(find.byIcon(Icons.donut_large_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Build a segment'));
    await tester.tap(find.text('Build a segment'));
    await tester.pumpAndSettle();

    expect(find.text('Segment builder'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Frequent buyers');
    final builderScroll = find
        .descendant(
          of: find.byType(SegmentBuilderPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('4 matching profiles'),
      180,
      scrollable: builderScroll,
    );
    expect(find.text('4 matching profiles'), findsOneWidget);
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<SegmentMetric>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<SegmentMetric>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders placed').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('6 matching profiles'),
      180,
      scrollable: builderScroll,
    );
    expect(find.text('6 matching profiles'), findsOneWidget);
    await tester.tap(find.text('Save segment'));
    await tester.pumpAndSettle();
    expect(find.text('Frequent buyers'), findsOneWidget);
  });

  testWidgets('saved customer filters and profile notes work', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.tap(find.byIcon(Icons.people_alt_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At risk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sofia Patel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save customer'));
    await tester.scrollUntilVisible(
      find.text('Save note'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomerProfilePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.byType(TextField), 'Prefers email updates');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('1 customer records'), findsOneWidget);
    expect(find.text('Sofia Patel'), findsOneWidget);
    expect(find.text('Olivia Chen'), findsNothing);
  });

  testWidgets('segments compare and draft campaign actions open', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.tap(find.byIcon(Icons.donut_large_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare segments'));
    await tester.pumpAndSettle();
    expect(find.text('Average RFM score'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('At risk'));
    await tester.tap(find.text('At risk'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Draft a campaign'));
    expect(find.byTooltip('Copy member CSV'), findsOneWidget);
    await tester.tap(find.text('Draft a campaign'));
    await tester.pumpAndSettle();
    final draft = tester.widget<TextField>(find.byType(TextField));
    expect(draft.controller!.text, contains('welcome you back'));
  });

  testWidgets('analyst campaign drafts enter the admin approval queue', (
    WidgetTester tester,
  ) async {
    await signIntoDemo(tester);
    await tester.ensureVisible(find.byTooltip('Draft for At risk'));
    await tester.tap(find.byTooltip('Draft for At risk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'At-risk win-back');
    await tester.ensureVisible(find.text('Submit for approval'));
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();
    expect(find.text('Campaign submitted for admin review.'), findsOneWidget);

    await signOutFromShell(tester);
    await signIntoRole(tester, AppRole.admin);
    await tester.tap(find.text('Campaigns'));
    await tester.pumpAndSettle();
    expect(find.text('Pending approval (2)'), findsOneWidget);
    expect(find.text('At-risk welcome back'), findsWidgets);
    expect(find.text('Approve'), findsWidgets);
  });

  testWidgets('admin can manage accounts and segmentation settings', (
    WidgetTester tester,
  ) async {
    await signIntoRole(tester, AppRole.admin);

    await tester.enterText(find.byType(TextField).at(0), 'Tebogo Mokoena');
    await tester.enterText(
      find.byType(TextField).at(1),
      'tebogo@example.co.za',
    );
    await tester.ensureVisible(find.text('Add account').last);
    await tester.tap(find.text('Add account').last);
    await tester.pumpAndSettle();
    expect(find.text('Tebogo Mokoena'), findsOneWidget);
    expect(find.textContaining('tebogo@example.co.za'), findsOneWidget);

    await tester.ensureVisible(find.text('Models'));
    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<SegmentationAlgorithm>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rule-based segments').last);
    await tester.pumpAndSettle();
    expect(find.text('Rule-based segments'), findsOneWidget);
  });

  testWidgets('marketing can create a campaign from a segment', (
    WidgetTester tester,
  ) async {
    await signIntoRole(tester, AppRole.marketing);

    await tester.tap(find.byTooltip('Draft for At risk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Marketing win-back');
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();

    expect(find.text('MARKETING WORKSPACE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.campaign_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Marketing win-back'), findsOneWidget);
    expect(find.textContaining('Pending approval'), findsWidgets);
    expect(find.text('IN REVIEW'), findsOneWidget);
    expect(find.text('Review (2)'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Preview Marketing win-back'));
    await tester.tap(find.byTooltip('Preview Marketing win-back'));
    await tester.pumpAndSettle();
    expect(find.text('MESSAGE PREVIEW'), findsOneWidget);
    expect(find.textContaining('It has been a while.'), findsOneWidget);
    expect(find.textContaining('customers in At risk'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Draft (0)'));
    await tester.tap(find.text('Draft (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Marketing win-back'), findsNothing);
    expect(find.text('No campaigns match this status.'), findsOneWidget);

    await tester.tap(find.text('Review (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Marketing win-back'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('marketing-campaign-search')),
      'unknown audience',
    );
    await tester.pumpAndSettle();
    expect(find.text('No campaigns match your search.'), findsOneWidget);
  });

  testWidgets('customer can update profile and preferences', (
    WidgetTester tester,
  ) async {
    await signIntoRole(tester, AppRole.customer);

    expect(find.text('Your activity'), findsOneWidget);
    expect(
      find.text(
        'Your purchase activity will appear here once your account is linked.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lerato Mokoena');
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile updated on this device.'), findsOneWidget);

    await tester.ensureVisible(find.text('Special offers'));
    final offersSwitch = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(offersSwitch).value, isTrue);
    await tester.tap(offersSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(offersSwitch).value, isFalse);
  });

  testWidgets('customer workspace shows linked customer activity', (
    WidgetTester tester,
  ) async {
    await LocalStore().saveImportedCustomers([
      const Customer(
        name: 'Customer User',
        email: 'customer@example.co.za',
        segmentName: 'Champions',
        lifetimeSpend: 1248,
        orderCount: 18,
        daysSincePurchase: 12,
      ),
    ]);
    await signIntoRole(tester, AppRole.customer);

    expect(find.text(formatRand(1248)), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('12 days ago'), findsOneWidget);
    expect(find.text('Customer group: Champions'), findsOneWidget);
    expect(find.text('Loyalty insights'), findsOneWidget);
    expect(find.text('Top value'), findsOneWidget);
    expect(find.text('15 / 15'), findsOneWidget);
    expect(find.text(formatRand(69)), findsOneWidget);
    expect(find.text('Recency'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
  });

  testWidgets('customer can place and restore a demo order', (
    WidgetTester tester,
  ) async {
    await signIntoRole(tester, AppRole.customer);
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add one House blend coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add one House blend coffee'));
    await tester.pumpAndSettle();
    expect(find.text('Total  ${formatRand(290)}'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('place-demo-order')));
    await tester.tap(find.byKey(const ValueKey('place-demo-order')));
    await tester.pumpAndSettle();
    expect(find.textContaining('total ${formatRand(290)}.'), findsOneWidget);
    await tester.tap(find.text('Confirm order'));
    await tester.pumpAndSettle();

    expect(find.text('2 x House blend coffee'), findsOneWidget);
    expect(find.text('Total  ${formatRand(290)}'), findsOneWidget);
    await tester.ensureVisible(find.text('Buy again').first);
    await tester.tap(find.text('Buy again').first);
    await tester.pumpAndSettle();
    expect(find.text('DEMO SHOP'), findsOneWidget);
    expect(find.text('2 items in your cart'), findsOneWidget);
    expect(find.text('Total  ${formatRand(290)}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await signOutFromShell(tester);
    await signIntoRole(tester, AppRole.customer);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('2 x House blend coffee'), findsOneWidget);
    expect(find.text('Total  ${formatRand(290)}'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
  });

  testWidgets('admin updates order status for the customer', (
    WidgetTester tester,
  ) async {
    await LocalStore().saveCustomerOrder(
      CustomerOrder(
        id: 'fulfillment-order-1',
        customerEmail: 'customer@example.co.za',
        items: const [
          OrderLine(
            productId: 'coffee',
            productName: 'House blend coffee',
            unitPrice: 145,
            quantity: 1,
          ),
        ],
        createdAt: DateTime.utc(2026, 10, 2),
      ),
    );

    await signIntoRole(tester, AppRole.admin);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    final statusDropdown = find.byKey(
      const ValueKey('order-status-fulfillment-order-1'),
    );
    await tester.ensureVisible(statusDropdown);
    await tester.tap(statusDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Processing').last);
    await tester.pumpAndSettle();

    expect(
      (await LocalStore().loadAllCustomerOrders()).single.status,
      CustomerOrderStatus.processing,
    );

    await signOutFromShell(tester);
    await signIntoRole(
      tester,
      AppRole.customer,
      email: 'customer@example.co.za',
    );
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    expect(find.text('Open (1)'), findsOneWidget);
    await tester.tap(find.text('Fulfilled (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No fulfilled orders.'), findsOneWidget);
    await tester.tap(find.text('Open (1)'));
    await tester.pumpAndSettle();
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cancel-customer-order-fulfillment-order-1')),
      findsNothing,
    );
  });

  testWidgets('customer can refresh order status without signing in again', (
    WidgetTester tester,
  ) async {
    final receivedOrder = CustomerOrder(
      id: 'refresh-order-1',
      customerEmail: 'customer@example.co.za',
      items: const [
        OrderLine(
          productId: 'coffee',
          productName: 'House blend coffee',
          unitPrice: 145,
          quantity: 1,
        ),
      ],
      createdAt: DateTime.utc(2026, 10, 2),
    );
    await LocalStore().saveCustomerOrder(receivedOrder);
    await signIntoRole(
      tester,
      AppRole.customer,
      email: 'customer@example.co.za',
    );
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('RECEIVED'), findsOneWidget);

    await LocalStore().saveCustomerOrder(
      receivedOrder.copyWith(status: CustomerOrderStatus.processing),
    );
    await tester.tap(find.byKey(const ValueKey('refresh-customer-orders')));
    await tester.pumpAndSettle();

    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('Orders refreshed.'), findsOneWidget);
  });

  testWidgets('customer can cancel an order before processing', (
    WidgetTester tester,
  ) async {
    await LocalStore().saveCustomerOrder(
      CustomerOrder(
        id: 'cancelable-order-1',
        customerEmail: 'customer@example.co.za',
        items: const [
          OrderLine(
            productId: 'honey',
            productName: 'Wildflower honey',
            unitPrice: 95,
            quantity: 1,
          ),
        ],
        createdAt: DateTime.utc(2026, 10, 2),
      ),
    );

    await signIntoRole(
      tester,
      AppRole.customer,
      email: 'customer@example.co.za',
    );
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    final cancelButton = find.byKey(
      const ValueKey('cancel-customer-order-cancelable-order-1'),
    );
    expect(cancelButton, findsOneWidget);
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel order').last);
    await tester.pumpAndSettle();

    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.text('Order cancelled'), findsOneWidget);
    expect(cancelButton, findsNothing);
    expect(
      (await LocalStore().loadCustomerOrders(
        'customer@example.co.za',
      )).single.status,
      CustomerOrderStatus.cancelled,
    );
  });

  testWidgets('unlinked demo customer sees New customers campaign', (
    WidgetTester tester,
  ) async {
    await signIntoRole(tester, AppRole.customer);

    expect(find.text('New customers'), findsOneWidget);
    expect(find.text('New customer first-order offer'), findsOneWidget);
    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('New customer first-order offer'), findsOneWidget);
  });

  testWidgets('customer sees only active campaigns for their segment', (
    WidgetTester tester,
  ) async {
    await LocalStore().saveImportedCustomers([
      const Customer(
        name: 'Customer User',
        email: 'customer@example.co.za',
        segmentName: 'Champions',
        lifetimeSpend: 1248,
        orderCount: 18,
        daysSincePurchase: 12,
      ),
    ]);
    await LocalStore().saveCampaigns([
      const Campaign(
        id: 'active-champions',
        name: 'Champions reward',
        segmentName: 'Champions',
        message: 'Enjoy a reward on your next order.',
        status: CampaignStatus.active,
      ),
      const Campaign(
        id: 'active-at-risk',
        name: 'At-risk offer',
        segmentName: 'At risk',
        message: 'We miss you.',
        status: CampaignStatus.active,
      ),
      const Campaign(
        id: 'draft-champions',
        name: 'Upcoming reward',
        segmentName: 'Champions',
        message: 'Coming soon.',
        status: CampaignStatus.draft,
      ),
    ]);
    await signIntoRole(tester, AppRole.customer);

    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('Champions reward'), findsOneWidget);
    expect(find.text('At-risk offer'), findsNothing);
    expect(find.text('Upcoming reward'), findsNothing);
    await tester.tap(find.byTooltip('Save Champions reward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Champions reward'), findsOneWidget);
    expect(find.text('All offers (1)'), findsOneWidget);
    await signOutFromShell(tester);
    await signIntoRole(tester, AppRole.customer);
    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('Saved (1)'), findsOneWidget);
    await tester.tap(find.text('Saved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Champions reward'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Remove Champions reward from saved offers'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No saved offers yet. Bookmark an offer to keep it here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('All offers (1)'));
    await tester.pumpAndSettle();
    final copyButton = find.ancestor(
      of: find.byIcon(Icons.copy_rounded),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(copyButton);
    expect(tester.widget<IconButton>(copyButton).onPressed, isNotNull);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Special offers'));
    final offersSwitch = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(offersSwitch).value, isTrue);
    await tester.tap(offersSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(offersSwitch).value, isFalse);
    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('Champions reward'), findsNothing);
    expect(
      find.textContaining('Promotional offers are paused.'),
      findsOneWidget,
    );
  });

  testWidgets('all roles see their workspace with shared demo data', (
    WidgetTester tester,
  ) async {
    await signIntoRole(tester, AppRole.admin);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Admin console'), findsOneWidget);
    expect(find.text('Import customer data'), findsOneWidget);
    expect(find.text('Users (4)'), findsOneWidget);
    await tester.ensureVisible(find.text('Olivia Chen'));
    expect(find.text('Olivia Chen'), findsOneWidget);
    await tester.ensureVisible(find.text('Campaigns'));
    await tester.tap(find.text('Campaigns'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pending approval (1)'));
    expect(find.text('Pending approval (1)'), findsOneWidget);
    await signOutFromShell(tester);

    await signIntoRole(tester, AppRole.analyst);
    expect(find.text('Audience intelligence'), findsOneWidget);
    expect(find.text('Run segmentation'), findsOneWidget);
    expect(find.text('Your current dataset'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.text('Run segmentation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('RFM scoring refreshed'), findsOneWidget);
    expect(find.text('Admin console'), findsNothing);
    await signOutFromShell(tester);

    await signIntoRole(tester, AppRole.marketing);
    expect(find.text('MARKETING WORKSPACE'), findsOneWidget);
    expect(find.text('Reach the right people.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.campaign_outlined));
    await tester.pumpAndSettle();
    expect(find.text('At-risk welcome back'), findsOneWidget);
    expect(find.text('Champions thank-you'), findsOneWidget);
    expect(find.text('Admin console'), findsNothing);
    await signOutFromShell(tester);

    await signIntoRole(
      tester,
      AppRole.customer,
      email: 'olivia.chen@email.com',
    );
    expect(find.text('YOUR CUSTOMER SPACE'), findsOneWidget);
    expect(find.text('Audience intelligence'), findsNothing);
    expect(find.text('SYSTEM CONTROL'), findsNothing);
    expect(find.text('Customer group: Champions'), findsOneWidget);
    expect(find.text('Champions thank-you'), findsOneWidget);
    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.text('Champions thank-you'), findsOneWidget);
  });
}

Future<void> signIntoDemo(WidgetTester tester) async {
  await tester.pumpWidget(const CustomerSegmentationApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('auth-email')),
    'analyst@example.co.za',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password')),
    'previewpass123',
  );
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

Future<void> signIntoRole(
  WidgetTester tester,
  AppRole role, {
  String? email,
}) async {
  await tester.pumpWidget(const CustomerSegmentationApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(DropdownButtonFormField<AppRole>));
  await tester.tap(find.byType(DropdownButtonFormField<AppRole>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(role.label).last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('auth-email')),
    email ?? '${role.name}@example.co.za',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password')),
    'previewpass123',
  );
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

Future<void> signOutFromShell(WidgetTester tester) async {
  final accountMenu = find.byTooltip('Account').first;
  await tester.ensureVisible(accountMenu);
  await tester.tap(accountMenu);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign out'));
  await tester.pumpAndSettle();
  expect(find.byType(AuthPage), findsOneWidget);
}
