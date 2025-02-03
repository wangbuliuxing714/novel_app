class User {
  final int id;
  final String username;
  final String email;
  final bool isVip;
  final bool isAdmin;
  final DateTime? vipExpireTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.isVip = false,
    this.isAdmin = false,
    this.vipExpireTime,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isVip: json['is_vip'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      vipExpireTime: json['vip_expire_time'] != null
          ? DateTime.parse(json['vip_expire_time'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_vip': isVip,
      'is_admin': isAdmin,
      'vip_expire_time': vipExpireTime?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}