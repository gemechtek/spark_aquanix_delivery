class DeliveryPersonnelModel {
  final String id;
  final String name;
  final String email;
  final String phone;

  DeliveryPersonnelModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  factory DeliveryPersonnelModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryPersonnelModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}
