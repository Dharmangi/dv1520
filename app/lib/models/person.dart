class Person {
  Person({
    required this.id,
    required this.name,
    this.mobile,
    this.address,
    this.notes,
    this.isOwner = false,
    this.ownerId,
    this.ownerName,
    this.tokenNo,
    this.place,
  });

  final String id;
  final String name;
  final String? mobile;
  final String? address;
  final String? notes;
  final bool isOwner;
  final String? ownerId;
  final String? ownerName;
  final String? tokenNo;
  final String? place;

  factory Person.fromJson(Map<String, dynamic> json) {
    final owner = json['ownerId'];
    return Person(
      id: json['_id'] as String,
      name: json['name'] as String,
      mobile: json['mobile'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      isOwner: json['isOwner'] as bool? ?? false,
      ownerId: owner is Map ? owner['_id'] as String? : owner as String?,
      ownerName: owner is Map ? owner['name'] as String? : null,
      tokenNo: json['tokenNo'] as String?,
      place: json['place'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (mobile != null) 'mobile': mobile,
        if (address != null) 'address': address,
        if (notes != null) 'notes': notes,
        'isOwner': isOwner,
        if (ownerId != null) 'ownerId': ownerId,
        if (tokenNo != null) 'tokenNo': tokenNo,
        if (place != null) 'place': place,
      };
}
