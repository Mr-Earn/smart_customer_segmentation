import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';
import 'pages/customers_page.dart';
import 'pages/admin_console_page.dart';
import 'pages/analyst_workspace_page.dart';
import 'pages/auth_page.dart';
import 'pages/customer_portal_page.dart';
import 'pages/data_import_page.dart';
import 'pages/marketing_workspace_page.dart';
import 'pages/segments_page.dart';
import 'pages/splash_page.dart';
import 'services/local_store.dart';
import 'services/supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await SupabaseBackend.initialize();
  runApp(CustomerSegmentationApp(supabaseBackend: backend));
}

class CustomerSegmentationApp extends StatelessWidget {
  const CustomerSegmentationApp({super.key, this.supabaseBackend});

  final SupabaseBackend? supabaseBackend;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Customer Segmentation',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: AuthGate(supabaseBackend: supabaseBackend),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.supabaseBackend});

  final SupabaseBackend? supabaseBackend;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalStore store = LocalStore();
  AppUser? currentUser;
  bool isRestoring = true;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    AppUser? savedUser;
    try {
      savedUser = widget.supabaseBackend == null
          ? await store.loadSessionUser()
          : await widget.supabaseBackend!.restoreUser();
    } catch (_) {
      savedUser = null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      currentUser = savedUser;
      isRestoring = false;
    });
  }

  Future<AuthOutcome> startSession(AuthCredentials credentials) async {
    final backend = widget.supabaseBackend;
    if (backend != null) {
      final outcome = await backend.authenticate(credentials);
      if (outcome.user case final user?) {
        if (mounted) setState(() => currentUser = user);
      }
      return outcome;
    }

    final candidate = credentials.profile;
    final users = await store.loadUsers();
    final existing = users.where((user) => user.id == candidate.id);
    final user = existing.isEmpty ? candidate : existing.first;
    if (existing.isEmpty) {
      await store.saveUsers([...users, user]);
    }
    await store.saveSessionUser(user);
    if (!mounted) return const AuthOutcome();
    setState(() => currentUser = user);
    return AuthOutcome(user: user);
  }

  Future<void> updateSessionUser(AppUser user) async {
    if (widget.supabaseBackend case final backend?) {
      await backend.updateProfile(user);
      if (mounted) setState(() => currentUser = user);
      return;
    }
    final users = await store.loadUsers();
    final updatedUsers = [
      for (final account in users)
        if (account.id == user.id) user else account,
    ];
    if (!updatedUsers.any((account) => account.id == user.id)) {
      updatedUsers.add(user);
    }
    await store.saveUsers(updatedUsers);
    await store.saveSessionUser(user);
    if (!mounted) return;
    setState(() => currentUser = user);
  }

  Future<void> signOut() async {
    if (widget.supabaseBackend case final backend?) {
      await backend.signOut();
    } else {
      await store.clearSession();
    }
    if (!mounted) return;
    setState(() => currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    if (isRestoring) return const SplashPage();
    if (currentUser case final user?) {
      return HomeShell(
        key: const ValueKey('home-shell'),
        currentUser: user,
        onSignOut: () => unawaited(signOut()),
        onUpdateSessionUser: updateSessionUser,
        supabaseBackend: widget.supabaseBackend,
      );
    }
    return AuthPage(
      key: const ValueKey('auth-page'),
      onAuthenticated: startSession,
      onPasswordReset: widget.supabaseBackend?.requestPasswordReset,
      onResendConfirmation: widget.supabaseBackend?.resendSignupConfirmation,
      usesSupabase: widget.supabaseBackend != null,
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.currentUser,
    required this.onSignOut,
    required this.onUpdateSessionUser,
    this.supabaseBackend,
  });

  final AppUser currentUser;
  final VoidCallback onSignOut;
  final ValueChanged<AppUser> onUpdateSessionUser;
  final SupabaseBackend? supabaseBackend;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedTab = 0;
  final List<CustomerSegment> customSegments = [];
  final Set<String> favorites = {};
  final Map<String, String> customerNotes = {};
  final List<AppUser> users = [];
  final List<AdminAuditEvent> auditEvents = [];
  final List<Campaign> campaigns = [];
  final List<StaffMessage> staffMessages = [];
  final List<CustomerOrder> customerOrders = [];
  final Set<String> savedCampaignIds = {};
  final List<Customer> importedCustomers = [];
  final Map<String, bool> customerPreferences = {};
  SegmentationSettings settings = const SegmentationSettings();
  String? auditError;
  final LocalStore store = LocalStore();

  List<Customer> get customers =>
      importedCustomers.isEmpty && widget.supabaseBackend == null
      ? sampleCustomers
      : importedCustomers;

  @override
  void initState() {
    super.initState();
    restoreLocalState();
  }

  Future<void> restoreLocalState() async {
    final backend = widget.supabaseBackend;
    final savedCustomers = backend == null
        ? await store.loadImportedCustomers()
        : await backend.loadCustomers();
    final savedSegments = backend == null
        ? await store.loadSegments()
        : await backend.loadSegments(savedCustomers);
    final savedState = backend == null
        ? <String, dynamic>{}
        : await backend.loadUserState();
    final savedFavorites = backend == null
        ? await store.loadFavorites()
        : ((savedState['favorites'] as List<dynamic>? ?? [])
              .cast<String>()
              .toSet());
    final savedNotes = backend == null
        ? await store.loadNotes()
        : ((savedState['notes'] as Map<dynamic, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ));
    final savedUsers = backend == null
        ? await store.loadUsers()
        : await backend.loadUsers();
    final savedCampaigns = backend == null
        ? await store.loadCampaigns()
        : await backend.loadCampaigns();
    final savedSettings = backend == null
        ? await store.loadSegmentationSettings()
        : await backend.loadSegmentationSettings();
    final savedPreferences = backend == null
        ? await store.loadCustomerPreferences(widget.currentUser.id)
        : ((savedState['preferences'] as Map<dynamic, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key.toString(), value == true),
          ));
    final savedCampaignIds = backend == null
        ? await store.loadSavedCampaigns(widget.currentUser.id)
        : ((savedState['saved_campaigns'] as List<dynamic>? ?? [])
              .cast<String>()
              .toSet());
    final savedCustomerOrders = backend == null
        ? widget.currentUser.role == AppRole.admin
              ? await store.loadAllCustomerOrders()
              : await store.loadCustomerOrders(widget.currentUser.id)
        : await backend.loadCustomerOrders(
            includeAll: widget.currentUser.role == AppRole.admin,
          );
    var restoredUsers = [...savedUsers];
    var restoredCampaigns = savedCampaigns;
    if (backend == null && !await store.hasSeededDemoData()) {
      for (final demoUser in sampleDemoUsers) {
        if (!restoredUsers.any((user) => user.id == demoUser.id)) {
          restoredUsers.add(demoUser);
        }
      }
      if (restoredUsers.length != savedUsers.length) {
        await store.saveUsers(restoredUsers);
      }
      if (restoredCampaigns.isEmpty) {
        restoredCampaigns = sampleCampaigns;
        await store.saveCampaigns(restoredCampaigns);
      }
      await store.markDemoDataSeeded();
    }
    final restoredStaffMessages = backend == null
        ? await store.loadStaffMessages()
        : await backend.loadStaffMessages([
            ...restoredUsers,
            widget.currentUser,
          ]);
    var restoredAuditEvents = <AdminAuditEvent>[];
    String? restoredAuditError;
    if (widget.currentUser.role == AppRole.admin) {
      if (backend == null) {
        restoredAuditError =
            'Audit history is available when Supabase is configured.';
      } else {
        try {
          restoredAuditEvents = await backend.loadAdminAuditLog();
        } catch (_) {
          restoredAuditError =
              'Audit history is unavailable. Apply the latest Supabase schema and refresh.';
        }
      }
    }
    if (!mounted) return;
    setState(() {
      customSegments.addAll(savedSegments);
      favorites.addAll(savedFavorites);
      customerNotes.addAll(savedNotes);
      users.addAll(restoredUsers);
      auditEvents.addAll(restoredAuditEvents);
      campaigns.addAll(restoredCampaigns);
      staffMessages.addAll(restoredStaffMessages);
      customerOrders.addAll(savedCustomerOrders);
      this.savedCampaignIds.addAll(savedCampaignIds);
      importedCustomers.addAll(savedCustomers);
      settings = savedSettings;
      customerPreferences.addAll(savedPreferences);
      auditError = restoredAuditError;
    });
  }

  void addSegment(CustomerSegment segment) {
    setState(() => customSegments.add(segment));
    unawaited(
      widget.supabaseBackend == null
          ? store.saveSegments(customSegments)
          : widget.supabaseBackend!.saveSegment(segment),
    );
  }

  void toggleFavorite(String email) {
    setState(() {
      if (!favorites.add(email)) favorites.remove(email);
    });
    unawaited(_saveUserState());
  }

  Future<void> saveNote(String email, String note) async {
    setState(() {
      if (note.trim().isEmpty) {
        customerNotes.remove(email);
      } else {
        customerNotes[email] = note.trim();
      }
    });
    if (widget.supabaseBackend == null) {
      await store.saveNote(email, note);
    } else {
      await _saveUserState();
    }
  }

  Future<void> _saveUserState() async {
    if (widget.supabaseBackend == null) {
      await store.saveFavorites(favorites);
      await store.saveNotes(customerNotes);
      await store.saveCustomerPreferences(
        widget.currentUser.id,
        customerPreferences,
      );
      await store.saveSavedCampaigns(widget.currentUser.id, savedCampaignIds);
      return;
    }
    await widget.supabaseBackend!.saveUserState(
      favorites: favorites,
      notes: customerNotes,
      preferences: customerPreferences,
      savedCampaigns: savedCampaignIds,
    );
  }

  Future<void> addUser(AppUser user) async {
    if (widget.supabaseBackend case final backend?) {
      final savedUser = await backend.inviteUser(user);
      if (mounted) setState(() => users.add(savedUser));
      return;
    }
    final updatedUsers = [...users, user];
    await store.saveUsers(updatedUsers);
    if (mounted) setState(() => users.add(user));
  }

  Future<void> updateUser(AppUser user) async {
    if (widget.supabaseBackend case final backend?) {
      await backend.assignRole(user);
    } else {
      final updatedUsers = [
        for (final account in users)
          if (account.id == user.id) user else account,
      ];
      await store.saveUsers(updatedUsers);
    }
    if (!mounted) return;
    final index = users.indexWhere((account) => account.id == user.id);
    setState(() {
      if (index < 0) {
        users.add(user);
      } else {
        users[index] = user;
      }
    });
  }

  Future<void> removeUser(AppUser user) async {
    if (widget.supabaseBackend case final backend?) {
      await backend.deleteUser(user);
    } else {
      final updatedUsers = users
          .where((account) => account.id != user.id)
          .toList();
      await store.saveUsers(updatedUsers);
    }
    if (mounted) {
      setState(() => users.removeWhere((account) => account.id == user.id));
    }
  }

  Future<void> saveSettings(SegmentationSettings value) async {
    if (widget.supabaseBackend case final backend?) {
      await backend.saveSegmentationSettings(value);
    } else {
      await store.saveSegmentationSettings(value);
    }
    if (mounted) setState(() => settings = value);
  }

  Future<SegmentationRunReport> runSegmentation() async {
    final previousCustomers = [...customers];
    final classifiedCustomers = [
      for (final customer in previousCustomers)
        customer.copyWith(segmentName: classifyCustomer(customer, settings)),
    ];
    final updatedCount = widget.supabaseBackend == null
        ? classifiedCustomers.length
        : await widget.supabaseBackend!.refreshCustomerSegments(
            classifiedCustomers,
          );
    if (widget.supabaseBackend == null) {
      await store.saveImportedCustomers(classifiedCustomers);
    }
    if (mounted) {
      setState(() {
        importedCustomers
          ..clear()
          ..addAll(classifiedCustomers);
      });
    }
    return SegmentationRunReport(
      updatedRecords: updatedCount,
      segmentCounts: {
        for (final segment in customerSegments)
          segment.name: classifiedCustomers
              .where((customer) => customer.segmentName == segment.name)
              .length,
      },
      changes: [
        for (var index = 0; index < classifiedCustomers.length; index++)
          if (previousCustomers[index].segmentName !=
              classifiedCustomers[index].segmentName)
            SegmentAssignmentChange(
              customerName: classifiedCustomers[index].name,
              email: classifiedCustomers[index].email,
              previousSegment: previousCustomers[index].segmentName,
              currentSegment: classifiedCustomers[index].segmentName,
            ),
      ],
    );
  }

  void addCampaign(Campaign campaign) {
    setState(() => campaigns.add(campaign));
    unawaited(_saveCampaign(campaign));
  }

  Future<void> updateCampaign(Campaign campaign) async {
    final index = campaigns.indexWhere((item) => item.id == campaign.id);
    if (index < 0) return;
    if (widget.supabaseBackend case final backend?) {
      await backend.updateCampaign(campaign);
    } else {
      final updatedCampaigns = [...campaigns]..[index] = campaign;
      await store.saveCampaigns(updatedCampaigns);
    }
    if (mounted) setState(() => campaigns[index] = campaign);
  }

  Future<void> _saveCampaign(Campaign campaign) async {
    if (widget.supabaseBackend == null) {
      await store.saveCampaigns(campaigns);
    } else {
      final saved = await widget.supabaseBackend!.saveCampaign(campaign);
      final index = campaigns.indexWhere((item) => item.name == campaign.name);
      if (mounted && index >= 0) setState(() => campaigns[index] = saved);
    }
  }

  Future<void> sendStaffMessage(AppUser recipient, String body) async {
    final message = widget.supabaseBackend == null
        ? StaffMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            senderId: widget.currentUser.id,
            senderName: widget.currentUser.name,
            senderRole: widget.currentUser.role,
            recipientId: recipient.id,
            recipientName: recipient.name,
            recipientRole: recipient.role,
            body: body.trim(),
            createdAt: DateTime.now().toUtc(),
          )
        : await widget.supabaseBackend!.sendStaffMessage(
            sender: widget.currentUser,
            recipient: recipient,
            body: body,
          );
    if (widget.supabaseBackend == null) {
      await store.saveStaffMessages([...staffMessages, message]);
    }
    if (mounted) setState(() => staffMessages.add(message));
  }

  Future<void> markStaffMessageRead(StaffMessage message) async {
    final updated = message.copyWith(readAt: DateTime.now().toUtc());
    if (widget.supabaseBackend == null) {
      final updatedMessages = [
        for (final item in staffMessages)
          if (item.id == message.id) updated else item,
      ];
      await store.saveStaffMessages(updatedMessages);
    } else {
      await widget.supabaseBackend!.markStaffMessageRead(message.id);
    }
    if (!mounted) return;
    final index = staffMessages.indexWhere((item) => item.id == message.id);
    if (index >= 0) setState(() => staffMessages[index] = updated);
  }

  Future<void> refreshStaffMessages() async {
    final refreshed = widget.supabaseBackend == null
        ? await store.loadStaffMessages()
        : await widget.supabaseBackend!.loadStaffMessages(users);
    if (!mounted) return;
    setState(() {
      staffMessages
        ..clear()
        ..addAll(refreshed);
    });
  }

  Future<void> refreshAdminAudit() async {
    final backend = widget.supabaseBackend;
    if (backend == null) {
      setState(() {
        auditEvents.clear();
        auditError = 'Audit history is available when Supabase is configured.';
      });
      return;
    }
    try {
      final refreshed = await backend.loadAdminAuditLog();
      if (!mounted) return;
      setState(() {
        auditEvents
          ..clear()
          ..addAll(refreshed);
        auditError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        auditError =
            'Audit history is unavailable. Apply the latest Supabase schema and refresh.';
      });
    }
  }

  Widget _staffMessagesWorkspace() => MarketingWorkspacePage(
    teamOnly: true,
    currentUser: widget.currentUser,
    staffUsers: users,
    customers: const [],
    segments: const [],
    campaigns: const [],
    staffMessages: staffMessages,
    onCreateCampaign: (_) {},
    onLaunchCampaign: (_) {},
    onSendMessage: sendStaffMessage,
    onMarkMessageRead: markStaffMessageRead,
    onRefreshMessages: refreshStaffMessages,
    onSignOut: widget.onSignOut,
  );

  Future<void> acceptImport(List<Customer> customers, String source) async {
    setState(() {
      importedCustomers
        ..clear()
        ..addAll(customers);
    });
    if (widget.supabaseBackend == null) {
      await store.saveImportedCustomers(customers);
    } else {
      await widget.supabaseBackend!.saveCustomers(customers);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customers.length} records loaded from $source.'),
      ),
    );
  }

  void openImport() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DataImportPage(onImport: acceptImport),
      ),
    );
  }

  void saveCustomerPreferences(Map<String, bool> value) {
    setState(() {
      customerPreferences
        ..clear()
        ..addAll(value);
    });
    unawaited(_saveUserState());
  }

  void saveCustomerCampaigns(Set<String> value) {
    setState(() {
      savedCampaignIds
        ..clear()
        ..addAll(value);
    });
    unawaited(_saveUserState());
  }

  Future<CustomerOrder> placeCustomerOrder(CustomerOrder order) async {
    final savedOrder = widget.supabaseBackend == null
        ? order
        : await widget.supabaseBackend!.placeCustomerOrder(order);
    if (widget.supabaseBackend == null) {
      await store.saveCustomerOrder(savedOrder);
    }
    if (mounted) setState(() => customerOrders.add(savedOrder));
    return savedOrder;
  }

  Future<void> updateCustomerOrder(CustomerOrder order) async {
    final updatedOrder = widget.supabaseBackend == null
        ? order
        : await widget.supabaseBackend!.updateCustomerOrder(order);
    if (widget.supabaseBackend == null) {
      await store.saveCustomerOrder(updatedOrder);
    }
    if (!mounted) return;
    setState(() {
      final index = customerOrders.indexWhere((item) => item.id == order.id);
      if (index < 0) {
        customerOrders.add(updatedOrder);
      } else {
        customerOrders[index] = updatedOrder;
      }
    });
  }

  Future<void> refreshCustomerOrders() async {
    final refreshedOrders = widget.supabaseBackend == null
        ? await store.loadCustomerOrders(widget.currentUser.id)
        : await widget.supabaseBackend!.loadCustomerOrders();
    if (!mounted) return;
    setState(() {
      customerOrders
        ..clear()
        ..addAll(refreshedOrders);
    });
  }

  Widget _buildAdminWorkspace() {
    final pages = [
      AdminConsolePage(
        currentUser: widget.currentUser,
        users: users,
        campaigns: campaigns,
        orders: customerOrders,
        auditEvents: auditEvents,
        auditError: auditError,
        settings: settings,
        onAddUser: addUser,
        onUpdateUser: updateUser,
        onRemoveUser: removeUser,
        onSaveSettings: saveSettings,
        onApproveCampaign: (campaign) =>
            updateCampaign(campaign.copyWith(status: CampaignStatus.approved)),
        onScheduleCampaign: (campaign, date) => updateCampaign(
          campaign.copyWith(
            status: CampaignStatus.scheduled,
            scheduledAt: date,
          ),
        ),
        onUpdateOrder: updateCustomerOrder,
        onRefreshAudit: refreshAdminAudit,
        onImport: openImport,
        onSignOut: widget.onSignOut,
      ),
      AnalystWorkspacePage(
        customers: customers,
        segments: [...customerSegments, ...customSegments],
        settings: settings,
        onRunSegmentation: runSegmentation,
        onImport: openImport,
        onCreateCampaign: addCampaign,
        onViewSegments: () => setState(() => selectedTab = 2),
        onSignOut: widget.onSignOut,
      ),
      CustomersPage(
        customers: customers,
        favorites: favorites,
        notes: customerNotes,
        onToggleFavorite: toggleFavorite,
        onSaveNote: saveNote,
        onSignOut: widget.onSignOut,
      ),
      _staffMessagesWorkspace(),
    ];
    return _navigationShell(pages, [
      NavigationDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        label: 'Admin',
      ),
      NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Data'),
      NavigationDestination(
        icon: Icon(Icons.people_alt_rounded),
        label: 'People',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: staffMessages.any(
            (message) =>
                message.recipientId ==
                    (widget.currentUser.authId ?? widget.currentUser.id) &&
                !message.isRead,
          ),
          child: Icon(Icons.forum_outlined),
        ),
        label: 'Team',
      ),
    ]);
  }

  Widget _buildAnalystWorkspace() {
    final pages = [
      AnalystWorkspacePage(
        customers: customers,
        segments: [...customerSegments, ...customSegments],
        settings: settings,
        onRunSegmentation: runSegmentation,
        onImport: openImport,
        onCreateCampaign: addCampaign,
        onViewSegments: () => setState(() => selectedTab = 1),
        onSignOut: widget.onSignOut,
      ),
      SegmentsPage(
        customSegments: customSegments,
        onSegmentCreated: addSegment,
        onSignOut: widget.onSignOut,
        customers: customers,
        settings: settings,
      ),
      CustomersPage(
        customers: customers,
        favorites: favorites,
        notes: customerNotes,
        onToggleFavorite: toggleFavorite,
        onSaveNote: saveNote,
        onSignOut: widget.onSignOut,
      ),
      _staffMessagesWorkspace(),
    ];
    return _navigationShell(pages, [
      NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Data'),
      NavigationDestination(
        icon: Icon(Icons.donut_large_rounded),
        label: 'Segments',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_alt_rounded),
        label: 'People',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: staffMessages.any(
            (message) =>
                message.recipientId ==
                    (widget.currentUser.authId ?? widget.currentUser.id) &&
                !message.isRead,
          ),
          child: Icon(Icons.forum_outlined),
        ),
        label: 'Team',
      ),
    ]);
  }

  Widget _navigationShell(
    List<Widget> pages,
    List<NavigationDestination> destinations,
  ) => Scaffold(
    body: IndexedStack(index: selectedTab, children: pages),
    bottomNavigationBar: NavigationBar(
      height: 68,
      backgroundColor: Colors.white,
      indicatorColor: lime.withValues(alpha: 0.45),
      selectedIndex: selectedTab,
      onDestinationSelected: (index) => setState(() => selectedTab = index),
      destinations: destinations,
    ),
  );

  @override
  Widget build(BuildContext context) => switch (widget.currentUser.role) {
    AppRole.admin => _buildAdminWorkspace(),
    AppRole.analyst => _buildAnalystWorkspace(),
    AppRole.marketing => Scaffold(
      body: MarketingWorkspacePage(
        currentUser: widget.currentUser,
        staffUsers: users,
        customers: customers,
        segments: [...customerSegments, ...customSegments],
        campaigns: campaigns,
        staffMessages: staffMessages,
        onCreateCampaign: addCampaign,
        onLaunchCampaign: (campaign) =>
            updateCampaign(campaign.copyWith(status: CampaignStatus.active)),
        onSendMessage: sendStaffMessage,
        onMarkMessageRead: markStaffMessageRead,
        onRefreshMessages: refreshStaffMessages,
        onSignOut: widget.onSignOut,
      ),
    ),
    AppRole.customer => CustomerPortalPage(
      currentUser: widget.currentUser,
      campaigns: campaigns,
      savedCampaignIds: Set.of(savedCampaignIds),
      orders: customerOrders,
      onPlaceOrder: placeCustomerOrder,
      onUpdateOrder: updateCustomerOrder,
      onRefreshOrders: refreshCustomerOrders,
      customer: customers
          .where(
            (customer) =>
                customer.email.trim().toLowerCase() == widget.currentUser.id,
          )
          .firstOrNull,
      preferences: customerPreferences,
      onSaveSavedCampaigns: saveCustomerCampaigns,
      onUpdateProfile: widget.onUpdateSessionUser,
      onSavePreferences: saveCustomerPreferences,
      onSignOut: widget.onSignOut,
    ),
  };
}
