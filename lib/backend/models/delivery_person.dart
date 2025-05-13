class DeliveryPersonnelModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? fcmToken;
  final String? profileImageUrl;

  DeliveryPersonnelModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.fcmToken,
    this.profileImageUrl,
  });

  // Create a copy of this user with some fields replaced
  DeliveryPersonnelModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? fcmToken,
    String? profileImageUrl,
  }) {
    return DeliveryPersonnelModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fcmToken: fcmToken ?? this.fcmToken,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  // Create a model from a map (e.g., Firestore document)
  factory DeliveryPersonnelModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryPersonnelModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      fcmToken: map['fcmToken'],
      profileImageUrl: map['profileImageUrl'],
    );
  }

  // Convert this model to a map (e.g., for storing in Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'fcmToken': fcmToken,
      'profileImageUrl': profileImageUrl,
    };
  }
}
