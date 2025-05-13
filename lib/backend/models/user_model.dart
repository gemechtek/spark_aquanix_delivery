// lib/models/user_model.dart
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.fcmToken = '',
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
