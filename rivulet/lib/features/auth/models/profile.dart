/// Represents a user profile in the Rivulet app.
/// Each account can have multiple profiles (similar to Netflix).
class Profile {
  final String id;
  final String accountId;
  final String name;
  final String avatar;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    required this.accountId,
    required this.name,
    required this.avatar,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['ID'] as String? ?? json['id'] as String? ?? '',
      accountId:
          json['AccountID'] as String? ?? json['account_id'] as String? ?? '',
      name: json['Name'] as String? ?? json['name'] as String? ?? 'Unknown',
      avatar: json['Avatar'] as String? ?? json['avatar'] as String? ?? '',
      createdAt: json['CreatedAt'] != null
          ? DateTime.tryParse(json['CreatedAt'] as String)
          : json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['UpdatedAt'] != null
          ? DateTime.tryParse(json['UpdatedAt'] as String)
          : json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'account_id': accountId, 'name': name, 'avatar': avatar};
  }
}
