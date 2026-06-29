class Category {
  Category({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final String type; // 'income' | 'expense'

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['_id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
      };
}
