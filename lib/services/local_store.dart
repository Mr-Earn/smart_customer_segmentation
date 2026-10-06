import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalStore {
  static const _segmentsKey = 'custom_segments_v1';
  static const _favoritesKey = 'favorite_customers_v1';
  static const _notesKey = 'customer_notes_v1';
  static const _sessionEmailKey = 'demo_session_email_v1';
  static const _sessionNameKey = 'demo_session_name_v1';
  static const _sessionRoleKey = 'demo_session_role_v1';
  static const _usersKey = 'demo_users_v1';
  static const _settingsKey = 'segmentation_settings_v1';
  static const _campaignsKey = 'campaigns_v1';
  static const _staffMessagesKey = 'staff_messages_v1';
  static const _customerOrdersKey = 'customer_orders_v1';
  static const _customersKey = 'imported_customers_v1';
  static const _customerPreferencesKey = 'customer_preferences_v1';
  static const _savedCampaignsKey = 'saved_campaigns_v1';
  static const _rememberedEmailKey = 'remembered_auth_email_v1';
  static const _demoDataSeededKey = 'demo_data_seeded_v1';

  final SharedPreferencesAsync preferences = SharedPreferencesAsync();

  Future<String?> loadSessionEmail() => preferences.getString(_sessionEmailKey);

  Future<String?> loadRememberedEmail() =>
      preferences.getString(_rememberedEmailKey);

  Future<void> saveRememberedEmail(String email) =>
      preferences.setString(_rememberedEmailKey, email);

  Future<void> clearRememberedEmail() =>
      preferences.remove(_rememberedEmailKey);

  Future<void> saveSessionEmail(String email) =>
      preferences.setString(_sessionEmailKey, email);

  Future<void> clearSession() async {
    await preferences.remove(_sessionEmailKey);
    await preferences.remove(_sessionNameKey);
    await preferences.remove(_sessionRoleKey);
  }

  Future<AppUser?> loadSessionUser() async {
    final email = await preferences.getString(_sessionEmailKey);
    if (email == null || email.isEmpty) return null;
    final name = await preferences.getString(_sessionNameKey);
    final roleName = await preferences.getString(_sessionRoleKey);
    var role = AppRole.analyst;
    if (roleName != null) {
      try {
        role = AppRole.values.byName(roleName);
      } on ArgumentError {
        role = AppRole.analyst;
      }
    }
    return AppUser(
      email: email,
      name: name ?? email.split('@').first,
      role: role,
    );
  }

  Future<void> saveSessionUser(AppUser user) async {
    await preferences.setString(_sessionEmailKey, user.id);
    await preferences.setString(_sessionNameKey, user.name);
    await preferences.setString(_sessionRoleKey, user.role.name);
  }

  Future<List<AppUser>> loadUsers() =>
      _loadJsonList(_usersKey, AppUser.fromJson);

  Future<void> saveUsers(List<AppUser> users) =>
      _saveJsonList(_usersKey, users.map((user) => user.toJson()).toList());

  Future<bool> hasSeededDemoData() async =>
      await preferences.getBool(_demoDataSeededKey) ?? false;

  Future<void> markDemoDataSeeded() =>
      preferences.setBool(_demoDataSeededKey, true);

  Future<SegmentationSettings> loadSegmentationSettings() async {
    final value = await preferences.getString(_settingsKey);
    if (value == null) return const SegmentationSettings();
    try {
      return SegmentationSettings.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on FormatException {
      return const SegmentationSettings();
    } on TypeError {
      return const SegmentationSettings();
    } on ArgumentError {
      return const SegmentationSettings();
    }
  }

  Future<void> saveSegmentationSettings(SegmentationSettings settings) =>
      preferences.setString(_settingsKey, jsonEncode(settings.toJson()));

  Future<List<Campaign>> loadCampaigns() =>
      _loadJsonList(_campaignsKey, Campaign.fromJson);

  Future<void> saveCampaigns(List<Campaign> campaigns) => _saveJsonList(
    _campaignsKey,
    campaigns.map((campaign) => campaign.toJson()).toList(),
  );

  Future<List<StaffMessage>> loadStaffMessages() =>
      _loadJsonList(_staffMessagesKey, StaffMessage.fromJson);

  Future<void> saveStaffMessages(List<StaffMessage> messages) => _saveJsonList(
    _staffMessagesKey,
    messages.map((message) => message.toJson()).toList(),
  );

  Future<List<CustomerOrder>> loadCustomerOrders(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final orders = await loadAllCustomerOrders();
    return orders
        .where((order) => order.customerEmail.toLowerCase() == normalizedEmail)
        .toList();
  }

  Future<List<CustomerOrder>> loadAllCustomerOrders() =>
      _loadJsonList(_customerOrdersKey, CustomerOrder.fromJson);

  Future<void> saveCustomerOrder(CustomerOrder order) async {
    final orders = await _loadJsonList(
      _customerOrdersKey,
      CustomerOrder.fromJson,
    );
    orders.removeWhere((existing) => existing.id == order.id);
    orders.add(order);
    await _saveJsonList(
      _customerOrdersKey,
      orders.map((item) => item.toJson().cast<String, Object?>()).toList(),
    );
  }

  Future<List<Customer>> loadImportedCustomers() =>
      _loadJsonList(_customersKey, Customer.fromJson);

  Future<void> saveImportedCustomers(List<Customer> customers) => _saveJsonList(
    _customersKey,
    customers.map((customer) => customer.toJson()).toList(),
  );

  Future<Map<String, bool>> loadCustomerPreferences(String email) async {
    final encoded = await preferences.getString(_customerPreferencesKey);
    if (encoded == null) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic> && decoded[email] is Map) {
        return (decoded[email] as Map).map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
      }
    } on FormatException {
      return {};
    }
    return {};
  }

  Future<void> saveCustomerPreferences(
    String email,
    Map<String, bool> preferencesForCustomer,
  ) async {
    final encoded = await preferences.getString(_customerPreferencesKey);
    Map<String, dynamic> allPreferences = {};
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map<String, dynamic>) allPreferences = decoded;
      } on FormatException {
        allPreferences = {};
      }
    }
    allPreferences[email] = preferencesForCustomer;
    await preferences.setString(
      _customerPreferencesKey,
      jsonEncode(allPreferences),
    );
  }

  Future<Set<String>> loadSavedCampaigns(String email) async {
    final encoded = await preferences.getString(_savedCampaignsKey);
    if (encoded == null) return {};
    try {
      final decoded = jsonDecode(encoded);
      final campaigns = decoded is Map<String, dynamic> ? decoded[email] : null;
      if (campaigns is List) return campaigns.cast<String>().toSet();
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
    return {};
  }

  Future<void> saveSavedCampaigns(String email, Set<String> campaignIds) async {
    final encoded = await preferences.getString(_savedCampaignsKey);
    Map<String, dynamic> allSavedCampaigns = {};
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map<String, dynamic>) allSavedCampaigns = decoded;
      } on FormatException {
        allSavedCampaigns = {};
      }
    }
    allSavedCampaigns[email] = campaignIds.toList();
    await preferences.setString(
      _savedCampaignsKey,
      jsonEncode(allSavedCampaigns),
    );
  }

  Future<List<T>> _loadJsonList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final records = await preferences.getStringList(key) ?? [];
    final values = <T>[];
    for (final record in records) {
      try {
        final decoded = jsonDecode(record);
        if (decoded is Map<String, dynamic>) values.add(fromJson(decoded));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      } on ArgumentError {
        continue;
      }
    }
    return values;
  }

  Future<void> _saveJsonList(String key, List<Map<String, Object?>> records) =>
      preferences.setStringList(key, records.map(jsonEncode).toList());

  Future<List<CustomerSegment>> loadSegments() async {
    final saved = await preferences.getStringList(_segmentsKey) ?? [];
    final segments = <CustomerSegment>[];
    for (final item in saved) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          segments.add(CustomerSegment.fromJson(decoded));
        }
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return segments;
  }

  Future<void> saveSegments(List<CustomerSegment> segments) =>
      preferences.setStringList(
        _segmentsKey,
        segments.map((segment) => jsonEncode(segment.toJson())).toList(),
      );

  Future<Set<String>> loadFavorites() async =>
      (await preferences.getStringList(_favoritesKey) ?? []).toSet();

  Future<void> saveFavorites(Set<String> emails) =>
      preferences.setStringList(_favoritesKey, emails.toList());

  Future<Map<String, String>> loadNotes() async {
    final value = await preferences.getString(_notesKey);
    if (value == null) return {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } on FormatException {
      return {};
    }
    return {};
  }

  Future<void> saveNote(String email, String note) async {
    final notes = await loadNotes();
    if (note.trim().isEmpty) {
      notes.remove(email);
    } else {
      notes[email] = note.trim();
    }
    await preferences.setString(_notesKey, jsonEncode(notes));
  }

  Future<void> saveNotes(Map<String, String> notes) =>
      preferences.setString(_notesKey, jsonEncode(notes));
}
