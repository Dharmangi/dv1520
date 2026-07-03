class User {
  User({
    required this.id,
    required this.username,
    this.name,
    this.token,
  });

  final String id;
  final String username;
  final String? name;
  final String? token;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      username: json['username'] as String,
      name: json['name'] as String?,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        if (name != null) 'name': name,
        if (token != null) 'token': token,
      };

  @override
  bool operator ==(Object other) => other is User && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
