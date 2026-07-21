class Tenant {
  final String id;
  final String name;
  final String slug;
  final String orgName;
  final String plan;
  final Map<String, dynamic> theme;
  final int totalQueries;
  final int totalDocuments;
  final String createdAt;

  Tenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.orgName,
    required this.plan,
    this.theme = const {},
    this.totalQueries = 0,
    this.totalDocuments = 0,
    required this.createdAt,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    orgName: json['org_name'] ?? '',
    plan: json['plan'] ?? 'free',
    theme: json['theme'] is Map ? Map<String, dynamic>.from(json['theme']) : {},
    totalQueries: json['total_queries'] ?? 0,
    totalDocuments: json['total_documents'] ?? 0,
    createdAt: json['created_at'] ?? '',
  );
}

class TenantDetail {
  final String id;
  final String name;
  final String slug;
  final String orgName;
  final String plan;
  final bool isActive;
  final Map<String, dynamic> theme;
  final int totalQueries;
  final int totalDocuments;
  final Map<String, dynamic> vectorStats;
  final String embedCode;

  TenantDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.orgName,
    required this.plan,
    required this.isActive,
    required this.theme,
    this.totalQueries = 0,
    this.totalDocuments = 0,
    required this.vectorStats,
    required this.embedCode,
  });

  factory TenantDetail.fromJson(Map<String, dynamic> json) => TenantDetail(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    orgName: json['org_name'] ?? '',
    plan: json['plan'] ?? 'free',
    isActive: json['is_active'] ?? true,
    theme: json['theme'] ?? {},
    totalQueries: json['total_queries'] ?? 0,
    totalDocuments: json['total_documents'] ?? 0,
    vectorStats: json['vector_stats'] ?? {},
    embedCode: json['embed_code'] ?? '',
  );
}
