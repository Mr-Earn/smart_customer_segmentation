import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';

enum SegmentMetric { lifetimeSpend, orderCount, daysSincePurchase }

extension SegmentMetricDetails on SegmentMetric {
  String get label => switch (this) {
    SegmentMetric.lifetimeSpend => 'Lifetime spend',
    SegmentMetric.orderCount => 'Orders placed',
    SegmentMetric.daysSincePurchase => 'Days since purchase',
  };

  String get ruleLabel => switch (this) {
    SegmentMetric.lifetimeSpend => 'Spend is at least',
    SegmentMetric.orderCount => 'Orders are at least',
    SegmentMetric.daysSincePurchase => 'Last purchase was within',
  };

  double get maxThreshold => switch (this) {
    SegmentMetric.lifetimeSpend => 2000,
    SegmentMetric.orderCount => 30,
    SegmentMetric.daysSincePurchase => 180,
  };

  String formatThreshold(double value) => switch (this) {
    SegmentMetric.lifetimeSpend => formatRand(value.round()),
    SegmentMetric.orderCount => '${value.round()} orders',
    SegmentMetric.daysSincePurchase => '${value.round()} days',
  };
}

String formatRand(num amount, {int decimalDigits = 0}) => NumberFormat.currency(
  locale: 'en_ZA',
  name: 'ZAR',
  symbol: 'R',
  decimalDigits: decimalDigits,
).format(amount);

enum AppRole { admin, analyst, marketing, customer }

extension AppRoleDetails on AppRole {
  String get label => switch (this) {
    AppRole.admin => 'Admin',
    AppRole.analyst => 'Business Manager / Analyst',
    AppRole.marketing => 'Marketing Staff',
    AppRole.customer => 'Customer',
  };

  String get shortLabel => switch (this) {
    AppRole.admin => 'Admin',
    AppRole.analyst => 'Analyst',
    AppRole.marketing => 'Marketing',
    AppRole.customer => 'Customer',
  };

  bool get canManageUsers => this == AppRole.admin;
  bool get canConfigureModels => this == AppRole.admin;
  bool get canUploadData => this == AppRole.analyst || this == AppRole.admin;
  bool get canEditSegments => this == AppRole.analyst || this == AppRole.admin;
  bool get canReviewCampaigns => this == AppRole.admin;
  bool get canManageCampaigns =>
      this == AppRole.marketing ||
      this == AppRole.analyst ||
      this == AppRole.admin;
  bool get canViewAnalytics => this != AppRole.customer;
}

class AppUser {
  const AppUser({
    required this.email,
    required this.name,
    required this.role,
    this.authId,
  });

  final String email;
  final String name;
  final AppRole role;
  final String? authId;

  String get id => email.trim().toLowerCase();

  AppUser copyWith({String? name, AppRole? role, String? authId}) => AppUser(
    email: email,
    name: name ?? this.name,
    role: role ?? this.role,
    authId: authId ?? this.authId,
  );

  Map<String, Object> toJson() => {
    'email': email,
    'name': name,
    'role': role.name,
    'authId': ?authId,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    email: json['email'] as String,
    name: json['name'] as String,
    role: AppRole.values.byName(json['role'] as String),
    authId: json['authId'] as String?,
  );
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.actorName,
    required this.actorRole,
    required this.eventType,
    required this.entityType,
    required this.summary,
    required this.createdAt,
    this.entityId,
  });

  final String id;
  final String actorName;
  final String actorRole;
  final String eventType;
  final String entityType;
  final String? entityId;
  final String summary;
  final DateTime createdAt;
}

class AuthCredentials {
  const AuthCredentials({
    required this.profile,
    required this.password,
    required this.isSignUp,
  });

  final AppUser profile;
  final String password;
  final bool isSignUp;
}

class AuthOutcome {
  const AuthOutcome({
    this.user,
    this.message,
    this.requiresEmailConfirmation = false,
  });

  final AppUser? user;
  final String? message;
  final bool requiresEmailConfirmation;
}

enum SegmentationAlgorithm { rfm, ruleBased }

class SegmentationSettings {
  const SegmentationSettings({
    this.algorithm = SegmentationAlgorithm.rfm,
    this.highValueSpend = 500,
    this.atRiskDays = 60,
  });

  final SegmentationAlgorithm algorithm;
  final int highValueSpend;
  final int atRiskDays;

  SegmentationSettings copyWith({
    SegmentationAlgorithm? algorithm,
    int? highValueSpend,
    int? atRiskDays,
  }) => SegmentationSettings(
    algorithm: algorithm ?? this.algorithm,
    highValueSpend: highValueSpend ?? this.highValueSpend,
    atRiskDays: atRiskDays ?? this.atRiskDays,
  );

  Map<String, Object> toJson() => {
    'algorithm': algorithm.name,
    'highValueSpend': highValueSpend,
    'atRiskDays': atRiskDays,
  };

  factory SegmentationSettings.fromJson(Map<String, dynamic> json) =>
      SegmentationSettings(
        algorithm: SegmentationAlgorithm.values.byName(
          json['algorithm'] as String,
        ),
        highValueSpend: (json['highValueSpend'] as num).toInt(),
        atRiskDays: (json['atRiskDays'] as num).toInt(),
      );
}

enum CampaignStatus { draft, pendingApproval, approved, scheduled, active }

extension CampaignStatusDetails on CampaignStatus {
  String get label => switch (this) {
    CampaignStatus.draft => 'Draft',
    CampaignStatus.pendingApproval => 'Pending approval',
    CampaignStatus.approved => 'Approved',
    CampaignStatus.scheduled => 'Scheduled',
    CampaignStatus.active => 'Active',
  };
}

class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.segmentName,
    required this.message,
    required this.status,
    this.scheduledAt,
  });

  final String id;
  final String name;
  final String segmentName;
  final String message;
  final CampaignStatus status;
  final DateTime? scheduledAt;

  Campaign copyWith({CampaignStatus? status, DateTime? scheduledAt}) =>
      Campaign(
        id: id,
        name: name,
        segmentName: segmentName,
        message: message,
        status: status ?? this.status,
        scheduledAt: scheduledAt ?? this.scheduledAt,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'segmentName': segmentName,
    'message': message,
    'status': status.name,
    'scheduledAt': scheduledAt?.toIso8601String(),
  };

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
    id: json['id'] as String,
    name: json['name'] as String,
    segmentName: json['segmentName'] as String,
    message: json['message'] as String,
    status: CampaignStatus.values.byName(json['status'] as String),
    scheduledAt: json['scheduledAt'] == null
        ? null
        : DateTime.parse(json['scheduledAt'] as String),
  );
}

String personalizeCampaignMessage(
  String message, {
  required String firstName,
  required String segmentName,
}) => message.replaceAllMapped(RegExp(r'\{(first_name|segment)\}'), (match) {
  return switch (match[1]) {
    'first_name' => firstName,
    'segment' => segmentName,
    _ => match[0]!,
  };
});

class StaffMessage {
  const StaffMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final AppRole senderRole;
  final String recipientId;
  final String recipientName;
  final AppRole recipientRole;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  StaffMessage copyWith({DateTime? readAt}) => StaffMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    senderRole: senderRole,
    recipientId: recipientId,
    recipientName: recipientName,
    recipientRole: recipientRole,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'senderRole': senderRole.name,
    'recipientId': recipientId,
    'recipientName': recipientName,
    'recipientRole': recipientRole.name,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
  };

  factory StaffMessage.fromJson(Map<String, dynamic> json) => StaffMessage(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    senderName: json['senderName'] as String,
    senderRole: AppRole.values.byName(json['senderRole'] as String),
    recipientId: json['recipientId'] as String,
    recipientName: json['recipientName'] as String,
    recipientRole: AppRole.values.byName(json['recipientRole'] as String),
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    readAt: json['readAt'] == null
        ? null
        : DateTime.parse(json['readAt'] as String),
  );
}

class Customer {
  const Customer({
    required this.name,
    required this.email,
    required this.segmentName,
    required this.lifetimeSpend,
    required this.orderCount,
    required this.daysSincePurchase,
  });

  final String name;
  final String email;
  final String segmentName;
  final int lifetimeSpend;
  final int orderCount;
  final int daysSincePurchase;

  Customer copyWith({String? segmentName}) => Customer(
    name: name,
    email: email,
    segmentName: segmentName ?? this.segmentName,
    lifetimeSpend: lifetimeSpend,
    orderCount: orderCount,
    daysSincePurchase: daysSincePurchase,
  );

  int get recencyScore => switch (daysSincePurchase) {
    <= 14 => 5,
    <= 30 => 4,
    <= 60 => 3,
    <= 90 => 2,
    _ => 1,
  };

  int get frequencyScore => switch (orderCount) {
    >= 15 => 5,
    >= 10 => 4,
    >= 5 => 3,
    >= 2 => 2,
    _ => 1,
  };

  int get monetaryScore => switch (lifetimeSpend) {
    >= 1000 => 5,
    >= 500 => 4,
    >= 250 => 3,
    >= 100 => 2,
    _ => 1,
  };

  int get rfmScore => recencyScore + frequencyScore + monetaryScore;

  String get rfmTier => switch (rfmScore) {
    >= 13 => 'Top value',
    >= 10 => 'Loyal',
    >= 7 => 'Growing',
    _ => 'Needs attention',
  };

  int get churnRiskScore {
    final inactivity = daysSincePurchase.clamp(0, 180) / 180 * 75;
    final lowFrequency = (5 - frequencyScore) * 5;
    final lowSpend = (5 - monetaryScore) * 2;
    return (inactivity + lowFrequency + lowSpend).round().clamp(0, 100);
  }

  String get churnRiskTier => switch (churnRiskScore) {
    >= 70 => 'High risk',
    >= 40 => 'Watch',
    _ => 'Low risk',
  };

  int get purchaseLikelihoodScore {
    final recency = recencyScore * 8;
    final frequency = frequencyScore * 7;
    final monetary = monetaryScore * 5;
    return (recency + frequency + monetary).clamp(0, 100);
  }

  Map<String, Object> toJson() => {
    'name': name,
    'email': email,
    'segmentName': segmentName,
    'lifetimeSpend': lifetimeSpend,
    'orderCount': orderCount,
    'daysSincePurchase': daysSincePurchase,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    name: json['name'] as String,
    email: json['email'] as String,
    segmentName: json['segmentName'] as String,
    lifetimeSpend: (json['lifetimeSpend'] as num).round(),
    orderCount: (json['orderCount'] as num).toInt(),
    daysSincePurchase: (json['daysSincePurchase'] as num).toInt(),
  );
}

String classifyCustomer(Customer customer, SegmentationSettings settings) {
  if (customer.daysSincePurchase >= settings.atRiskDays) return 'At risk';

  if (settings.algorithm == SegmentationAlgorithm.ruleBased) {
    if (customer.lifetimeSpend >= settings.highValueSpend &&
        customer.orderCount >= 3) {
      return 'Champions';
    }
    return customer.orderCount <= 1 ? 'New customers' : 'Regulars';
  }

  if (customer.lifetimeSpend >= settings.highValueSpend &&
      customer.rfmScore >= 12) {
    return 'Champions';
  }
  if (customer.orderCount <= 2) return 'New customers';
  return 'Regulars';
}

class SegmentAssignmentChange {
  const SegmentAssignmentChange({
    required this.customerName,
    required this.email,
    required this.previousSegment,
    required this.currentSegment,
  });

  final String customerName;
  final String email;
  final String previousSegment;
  final String currentSegment;
}

class SegmentationRunReport {
  const SegmentationRunReport({
    required this.updatedRecords,
    required this.segmentCounts,
    required this.changes,
  });

  final int updatedRecords;
  final Map<String, int> segmentCounts;
  final List<SegmentAssignmentChange> changes;
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final IconData icon;
}

const demoProducts = <StoreProduct>[
  StoreProduct(
    id: 'coffee',
    name: 'House blend coffee',
    description: 'A smooth, medium-roast everyday blend.',
    price: 145,
    icon: Icons.coffee_rounded,
  ),
  StoreProduct(
    id: 'honey',
    name: 'Wildflower honey',
    description: 'Small-batch honey from local growers.',
    price: 95,
    icon: Icons.spa_outlined,
  ),
  StoreProduct(
    id: 'tote',
    name: 'Mosaic canvas tote',
    description: 'A reusable cotton tote for everyday errands.',
    price: 120,
    icon: Icons.shopping_bag_outlined,
  ),
];

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final int unitPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;

  Map<String, Object> toJson() => {
    'productId': productId,
    'productName': productName,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    unitPrice: (json['unitPrice'] as num).round(),
    quantity: (json['quantity'] as num).toInt(),
  );
}

enum CustomerOrderStatus { received, processing, fulfilled, cancelled }

extension CustomerOrderStatusDetails on CustomerOrderStatus {
  String get label => switch (this) {
    CustomerOrderStatus.received => 'Received',
    CustomerOrderStatus.processing => 'Processing',
    CustomerOrderStatus.fulfilled => 'Fulfilled',
    CustomerOrderStatus.cancelled => 'Cancelled',
  };
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerEmail,
    required this.items,
    required this.createdAt,
    this.status = CustomerOrderStatus.received,
  });

  final String id;
  final String customerEmail;
  final List<OrderLine> items;
  final DateTime createdAt;
  final CustomerOrderStatus status;

  int get total => items.fold(0, (sum, item) => sum + item.subtotal);

  CustomerOrder copyWith({CustomerOrderStatus? status}) => CustomerOrder(
    id: id,
    customerEmail: customerEmail,
    items: items,
    createdAt: createdAt,
    status: status ?? this.status,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'customerEmail': customerEmail,
    'items': items.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory CustomerOrder.fromJson(Map<String, dynamic> json) => CustomerOrder(
    id: json['id'] as String,
    customerEmail: json['customerEmail'] as String,
    items: (json['items'] as List<dynamic>)
        .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: CustomerOrderStatus.values.byName(
      json['status'] as String? ?? 'received',
    ),
  );
}

enum SegmentJoin { all, any }

class SegmentCondition {
  const SegmentCondition({required this.metric, required this.threshold});

  final SegmentMetric metric;
  final int threshold;

  String get description =>
      '${metric.ruleLabel} ${metric.formatThreshold(threshold.toDouble())}';

  bool matches(Customer customer) => switch (metric) {
    SegmentMetric.lifetimeSpend => customer.lifetimeSpend >= threshold,
    SegmentMetric.orderCount => customer.orderCount >= threshold,
    SegmentMetric.daysSincePurchase => customer.daysSincePurchase <= threshold,
  };

  Map<String, Object> toJson() => {
    'metric': metric.name,
    'threshold': threshold,
  };

  factory SegmentCondition.fromJson(Map<String, dynamic> json) =>
      SegmentCondition(
        metric: SegmentMetric.values.byName(json['metric'] as String),
        threshold: (json['threshold'] as num).toInt(),
      );
}

class SegmentRule {
  const SegmentRule({required this.conditions, this.join = SegmentJoin.all});

  final List<SegmentCondition> conditions;
  final SegmentJoin join;

  bool matches(Customer customer) {
    if (conditions.isEmpty) return false;
    return join == SegmentJoin.all
        ? conditions.every((condition) => condition.matches(customer))
        : conditions.any((condition) => condition.matches(customer));
  }

  String get summary => conditions
      .map((condition) => condition.description)
      .join(join == SegmentJoin.all ? ' AND ' : ' OR ');

  Map<String, Object> toJson() => {
    'join': join.name,
    'conditions': conditions.map((condition) => condition.toJson()).toList(),
  };

  factory SegmentRule.fromJson(Map<String, dynamic> json) => SegmentRule(
    join: SegmentJoin.values.byName(json['join'] as String),
    conditions: (json['conditions'] as List<dynamic>)
        .map(
          (condition) =>
              SegmentCondition.fromJson(condition as Map<String, dynamic>),
        )
        .toList(),
  );
}

class CustomerSegment {
  const CustomerSegment({
    required this.name,
    required this.description,
    required this.count,
    required this.color,
    required this.icon,
    required this.averageSpend,
    this.rule,
  });

  final String name;
  final String description;
  final int count;
  final Color color;
  final IconData icon;
  final int averageSpend;
  final SegmentRule? rule;

  bool matches(Customer customer) =>
      rule?.matches(customer) ?? customer.segmentName == name;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'count': count,
    'color': color.toARGB32(),
    'averageSpend': averageSpend,
    'rule': rule?.toJson(),
  };

  factory CustomerSegment.fromJson(Map<String, dynamic> json) =>
      CustomerSegment(
        name: json['name'] as String,
        description: json['description'] as String,
        count: (json['count'] as num).toInt(),
        color: Color((json['color'] as num).toInt()),
        icon: Icons.auto_awesome_rounded,
        averageSpend: (json['averageSpend'] as num).toInt(),
        rule: json['rule'] == null
            ? null
            : SegmentRule.fromJson(json['rule'] as Map<String, dynamic>),
      );
}

const customerSegments = <CustomerSegment>[
  CustomerSegment(
    name: 'Champions',
    description: 'Your most engaged, highest-value customers',
    count: 3420,
    color: lime,
    icon: Icons.workspace_premium_rounded,
    averageSpend: 142,
  ),
  CustomerSegment(
    name: 'Regulars',
    description: 'Steady customers who keep coming back',
    count: 10140,
    color: mint,
    icon: Icons.repeat_rounded,
    averageSpend: 68,
  ),
  CustomerSegment(
    name: 'At risk',
    description: 'Previously active, ready for a nudge',
    count: 4380,
    color: coral,
    icon: Icons.notifications_active_rounded,
    averageSpend: 54,
  ),
  CustomerSegment(
    name: 'New customers',
    description: 'Recently discovered your brand',
    count: 6920,
    color: sky,
    icon: Icons.waving_hand_rounded,
    averageSpend: 38,
  ),
];

const sampleCustomers = <Customer>[
  Customer(
    name: 'Olivia Chen',
    email: 'olivia.chen@email.com',
    segmentName: 'Champions',
    lifetimeSpend: 1248,
    orderCount: 18,
    daysSincePurchase: 12,
  ),
  Customer(
    name: 'Marcus Johnson',
    email: 'marcus.j@email.com',
    segmentName: 'Regulars',
    lifetimeSpend: 682,
    orderCount: 11,
    daysSincePurchase: 21,
  ),
  Customer(
    name: 'Sofia Patel',
    email: 'sofia.patel@email.com',
    segmentName: 'At risk',
    lifetimeSpend: 534,
    orderCount: 8,
    daysSincePurchase: 86,
  ),
  Customer(
    name: 'Noah Williams',
    email: 'noah.w@email.com',
    segmentName: 'New customers',
    lifetimeSpend: 186,
    orderCount: 2,
    daysSincePurchase: 6,
  ),
  Customer(
    name: 'Amara Okafor',
    email: 'amara.o@email.com',
    segmentName: 'Champions',
    lifetimeSpend: 1104,
    orderCount: 16,
    daysSincePurchase: 18,
  ),
  Customer(
    name: 'Ethan Rivera',
    email: 'ethan.r@email.com',
    segmentName: 'Regulars',
    lifetimeSpend: 428,
    orderCount: 7,
    daysSincePurchase: 14,
  ),
  Customer(
    name: 'Priya Nair',
    email: 'priya.n@email.com',
    segmentName: 'At risk',
    lifetimeSpend: 388,
    orderCount: 6,
    daysSincePurchase: 104,
  ),
  Customer(
    name: 'Liam Brooks',
    email: 'liam.b@email.com',
    segmentName: 'New customers',
    lifetimeSpend: 74,
    orderCount: 1,
    daysSincePurchase: 3,
  ),
];

const sampleDemoUsers = <AppUser>[
  AppUser(
    email: 'admin@example.co.za',
    name: 'Alex Morgan',
    role: AppRole.admin,
  ),
  AppUser(
    email: 'analyst@example.co.za',
    name: 'Sam Ndlovu',
    role: AppRole.analyst,
  ),
  AppUser(
    email: 'marketing@example.co.za',
    name: 'Nia Khumalo',
    role: AppRole.marketing,
  ),
  AppUser(
    email: 'olivia.chen@email.com',
    name: 'Olivia Chen',
    role: AppRole.customer,
  ),
];

const sampleCampaigns = <Campaign>[
  Campaign(
    id: 'demo-champions-thank-you',
    name: 'Champions thank-you',
    segmentName: 'Champions',
    message:
        'Thanks for being one of our most valued customers. Enjoy a reward on your next order.',
    status: CampaignStatus.active,
  ),
  Campaign(
    id: 'demo-regulars-reward',
    name: 'Regulars loyalty reward',
    segmentName: 'Regulars',
    message:
        'Your loyalty means a lot. Here is something extra for your next visit.',
    status: CampaignStatus.active,
  ),
  Campaign(
    id: 'demo-at-risk-win-back',
    name: 'At-risk welcome back',
    segmentName: 'At risk',
    message:
        'It has been a while. We would love to welcome you back with a special offer.',
    status: CampaignStatus.pendingApproval,
  ),
  Campaign(
    id: 'demo-new-customer-welcome',
    name: 'New customer welcome',
    segmentName: 'New customers',
    message:
        'Welcome to the community. Enjoy a little extra on your next order.',
    status: CampaignStatus.approved,
  ),
  Campaign(
    id: 'demo-new-customer-live',
    name: 'New customer first-order offer',
    segmentName: 'New customers',
    message: 'Welcome. Your first order comes with a little something extra.',
    status: CampaignStatus.active,
  ),
  Campaign(
    id: 'demo-champions-preview',
    name: 'Champions early access',
    segmentName: 'Champions',
    message: 'Get an early look at what is coming next, just for you.',
    status: CampaignStatus.scheduled,
  ),
];

List<Customer> membersOf(
  CustomerSegment segment,
  Iterable<Customer> customers,
) => customers.where(segment.matches).toList();
