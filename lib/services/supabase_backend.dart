import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models.dart';

class SupabaseBackend {
  SupabaseBackend._(this.client);

  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yrbfbexdojzvdkazpggd.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_lh_ILFP1tBXA55fPwgxHYw_azpnjd2r',
  );

  static bool get isConfigured =>
      projectUrl.isNotEmpty && publishableKey.isNotEmpty;

  final SupabaseClient client;

  static Future<SupabaseBackend?> initialize() async {
    if (!isConfigured) return null;
    await Supabase.initialize(
      url: projectUrl,
      publishableKey: publishableKey,
      debug: false,
    );
    return SupabaseBackend._(Supabase.instance.client);
  }

  Future<AppUser?> restoreUser() async {
    final user = client.auth.currentUser;
    return user == null ? null : _loadProfile(user);
  }

  Future<List<AppUser>> loadUsers() async {
    final rows = await client
        .from('profiles')
        .select('id, email, full_name, role')
        .order('created_at');
    return [for (final row in rows) _profileFromRow(row)];
  }

  Future<AppUser> inviteUser(AppUser user) async {
    final response = await client.functions.invoke(
      'admin-user',
      body: {
        'action': 'invite',
        'email': user.email,
        'full_name': user.name,
        'role': user.role.name,
      },
    );
    final authId = (response.data as Map<String, dynamic>)['id'] as String;
    return user.copyWith(authId: authId);
  }

  Future<void> assignRole(AppUser user) async {
    final authId = user.authId;
    if (authId == null) {
      throw StateError('The account has no Supabase user ID.');
    }
    await client.rpc(
      'admin_assign_role',
      params: {'target_user_id': authId, 'target_role': user.role.name},
    );
  }

  Future<void> deleteUser(AppUser user) async {
    final authId = user.authId;
    if (authId == null) {
      throw StateError('The account has no Supabase user ID.');
    }
    await client.functions.invoke(
      'admin-user',
      body: {'action': 'delete', 'user_id': authId},
    );
  }

  Future<List<Customer>> loadCustomers() async {
    final rows = await client
        .from('customer_records')
        .select(
          'name,email,segment_name,lifetime_spend,order_count,days_since_purchase',
        )
        .order('name');
    return [
      for (final row in rows)
        Customer(
          name: row['name'] as String,
          email: row['email'] as String,
          segmentName: row['segment_name'] as String,
          lifetimeSpend: (row['lifetime_spend'] as num).round(),
          orderCount: (row['order_count'] as num).toInt(),
          daysSincePurchase: (row['days_since_purchase'] as num).toInt(),
        ),
    ];
  }

  Future<void> saveCustomers(List<Customer> customers) async {
    final authId = client.auth.currentUser?.id;
    if (authId == null) throw StateError('Sign in before importing customers.');
    await client.from('customer_records').upsert([
      for (final customer in customers)
        {
          'created_by': authId,
          'email': customer.email.toLowerCase(),
          'name': customer.name,
          'segment_name': customer.segmentName,
          'lifetime_spend': customer.lifetimeSpend,
          'order_count': customer.orderCount,
          'days_since_purchase': customer.daysSincePurchase,
        },
    ], onConflict: 'created_by,email');
  }

  Future<List<CustomerOrder>> loadCustomerOrders({
    bool includeAll = false,
  }) async {
    final profileId = client.auth.currentUser?.id;
    if (profileId == null) return [];
    final rows = includeAll
        ? await client
              .from('customer_orders')
              .select('id,customer_email,items,created_at,status')
              .order('created_at', ascending: false)
        : await client
              .from('customer_orders')
              .select('id,customer_email,items,created_at,status')
              .eq('profile_id', profileId)
              .order('created_at', ascending: false);
    return [for (final row in rows) _customerOrderFromRow(row)];
  }

  Future<CustomerOrder> updateCustomerOrder(CustomerOrder order) async {
    final row = await client
        .from('customer_orders')
        .update({'status': order.status.name})
        .eq('id', order.id)
        .select('id,customer_email,items,created_at,status')
        .single();
    return _customerOrderFromRow(row);
  }

  Future<CustomerOrder> placeCustomerOrder(CustomerOrder order) async {
    final profileId = client.auth.currentUser?.id;
    if (profileId == null) throw StateError('Sign in before placing an order.');
    final row = await client
        .from('customer_orders')
        .insert({
          'profile_id': profileId,
          'customer_email': order.customerEmail,
          'items': order.items.map((item) => item.toJson()).toList(),
          'total': order.total,
          'status': 'received',
        })
        .select('id,customer_email,items,created_at,status')
        .single();
    return _customerOrderFromRow(row);
  }

  CustomerOrder _customerOrderFromRow(Map<String, dynamic> row) =>
      CustomerOrder(
        id: row['id'] as String,
        customerEmail: row['customer_email'] as String,
        items: (row['items'] as List<dynamic>)
            .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(row['created_at'] as String),
        status: CustomerOrderStatus.values.byName(row['status'] as String),
      );

  Future<List<CustomerSegment>> loadSegments(List<Customer> customers) async {
    final rows = await client
        .from('customer_segments')
        .select('name, description, rule')
        .order('name');
    return [for (final row in rows) _segmentFromRow(row, customers)];
  }

  Future<void> saveSegment(CustomerSegment segment) async {
    final authId = client.auth.currentUser?.id;
    if (authId == null) throw StateError('Sign in before saving segments.');
    await client.from('customer_segments').upsert({
      'created_by': authId,
      'name': segment.name,
      'description': segment.description,
      'rule': segment.rule?.toJson() ?? <String, Object>{},
    }, onConflict: 'created_by,name');
  }

  Future<SegmentationSettings> loadSegmentationSettings() async {
    final row = await client
        .from('segmentation_settings')
        .select('algorithm, high_value_spend, at_risk_days')
        .eq('id', 1)
        .maybeSingle();
    if (row == null) return const SegmentationSettings();
    return SegmentationSettings(
      algorithm: SegmentationAlgorithm.values.byName(
        row['algorithm'] as String,
      ),
      highValueSpend: (row['high_value_spend'] as num).toInt(),
      atRiskDays: (row['at_risk_days'] as num).toInt(),
    );
  }

  Future<void> saveSegmentationSettings(SegmentationSettings settings) async {
    final authId = client.auth.currentUser?.id;
    await client.from('segmentation_settings').upsert({
      'id': 1,
      'algorithm': settings.algorithm.name,
      'high_value_spend': settings.highValueSpend,
      'at_risk_days': settings.atRiskDays,
      'updated_by': authId,
    });
  }

  Future<List<Campaign>> loadCampaigns() async {
    final rows = await client
        .from('campaigns')
        .select('id,name,segment_name,message,status,scheduled_at')
        .order('created_at', ascending: false);
    return [for (final row in rows) _campaignFromRow(row)];
  }

  Future<Campaign> saveCampaign(Campaign campaign) async {
    final authId = client.auth.currentUser?.id;
    if (authId == null) throw StateError('Sign in before saving campaigns.');
    final row = await client
        .from('campaigns')
        .upsert({
          'created_by': authId,
          'name': campaign.name,
          'segment_name': campaign.segmentName,
          'message': campaign.message,
          'status': campaign.status.name,
          'scheduled_at': campaign.scheduledAt?.toIso8601String(),
        }, onConflict: 'created_by,name')
        .select('id,name,segment_name,message,status,scheduled_at')
        .single();
    return _campaignFromRow(row);
  }

  Future<void> updateCampaign(Campaign campaign) async {
    await client
        .from('campaigns')
        .update({
          'status': campaign.status.name,
          'scheduled_at': campaign.scheduledAt?.toIso8601String(),
        })
        .eq('id', campaign.id);
  }

  Future<Map<String, dynamic>> loadUserState() async {
    final authId = client.auth.currentUser?.id;
    if (authId == null) return {};
    final row = await client
        .from('app_user_state')
        .select('favorites,notes,preferences,saved_campaigns')
        .eq('profile_id', authId)
        .maybeSingle();
    return row ?? {};
  }

  Future<void> saveUserState({
    required Set<String> favorites,
    required Map<String, String> notes,
    required Map<String, bool> preferences,
    required Set<String> savedCampaigns,
  }) async {
    final authId = client.auth.currentUser?.id;
    if (authId == null) throw StateError('Sign in before saving preferences.');
    await client.from('app_user_state').upsert({
      'profile_id': authId,
      'favorites': favorites.toList(),
      'notes': notes,
      'preferences': preferences,
      'saved_campaigns': savedCampaigns.toList(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  AppUser _profileFromRow(Map<String, dynamic> row) => AppUser(
    authId: row['id'] as String,
    email: row['email'] as String,
    name: row['full_name'] as String? ?? '',
    role: AppRole.values.byName(row['role'] as String),
  );

  CustomerSegment _segmentFromRow(
    Map<String, dynamic> row,
    List<Customer> customers,
  ) {
    final ruleJson = row['rule'];
    final rule = ruleJson is Map<String, dynamic>
        ? SegmentRule.fromJson(ruleJson)
        : null;
    final segment = CustomerSegment(
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      count: 0,
      color: sky,
      icon: Icons.auto_awesome_rounded,
      averageSpend: 0,
      rule: rule,
    );
    final members = membersOf(segment, customers);
    final average = members.isEmpty
        ? 0
        : (members.fold<int>(
                    0,
                    (sum, customer) => sum + customer.lifetimeSpend,
                  ) /
                  members.length)
              .round();
    return CustomerSegment(
      name: segment.name,
      description: segment.description,
      count: members.length,
      color: segment.color,
      icon: segment.icon,
      averageSpend: average,
      rule: rule,
    );
  }

  Campaign _campaignFromRow(Map<String, dynamic> row) => Campaign(
    id: row['id'] as String,
    name: row['name'] as String,
    segmentName: row['segment_name'] as String,
    message: row['message'] as String,
    status: CampaignStatus.values.byName(row['status'] as String),
    scheduledAt: row['scheduled_at'] == null
        ? null
        : DateTime.parse(row['scheduled_at'] as String),
  );

  Future<AuthOutcome> authenticate(AuthCredentials credentials) async {
    final authResponse = credentials.isSignUp
        ? await client.auth.signUp(
            email: credentials.profile.email,
            password: credentials.password,
            data: {
              'full_name': credentials.profile.name,
              'requested_role': credentials.profile.role.name,
            },
          )
        : await client.auth.signInWithPassword(
            email: credentials.profile.email,
            password: credentials.password,
          );

    final user = authResponse.user;
    if (user == null) {
      return const AuthOutcome(
        message: 'No user was returned. Check your credentials and try again.',
      );
    }
    if (credentials.isSignUp && authResponse.session == null) {
      return const AuthOutcome(
        message: 'Check your email to confirm your account, then sign in.',
        requiresEmailConfirmation: true,
      );
    }
    return AuthOutcome(user: await _loadProfile(user));
  }

  Future<void> requestPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email);

  Future<void> resendSignupConfirmation(String email) =>
      client.auth.resend(type: OtpType.signup, email: email);

  Future<AppUser> _loadProfile(User authUser) async {
    Map<String, dynamic>? profile;
    try {
      profile = await client
          .from('profiles')
          .select('full_name, role')
          .eq('id', authUser.id)
          .maybeSingle();
    } catch (_) {
      profile = null;
    }

    final email = authUser.email ?? '';
    final metadataName = authUser.userMetadata?['full_name'] as String?;
    final roleName = profile?['role'] as String?;
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
      name:
          profile?['full_name'] as String? ??
          metadataName ??
          email.split('@').first,
      role: role,
      authId: authUser.id,
    );
  }

  Future<void> updateProfile(AppUser user) async {
    final authId = user.authId;
    if (authId == null) return;
    await client.auth.updateUser(
      UserAttributes(data: {'full_name': user.name}),
    );
    await client
        .from('profiles')
        .update({'full_name': user.name})
        .eq('id', authId);
  }

  Future<void> signOut() => client.auth.signOut();
}
