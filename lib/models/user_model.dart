class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String rollNumber;
  final String classSection;
  final String role;
  final bool approved;

  UserModel({
    this.id = '',
    this.fullName = '',
    this.email = '',
    this.rollNumber = '',
    this.classSection = '',
    this.role = '',
    this.approved = false,
  });

  factory UserModel.fromDoc(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      classSection: data['classSection'] ?? '',
      role: data['role'] ?? '',
      approved: data['approved'] ?? false,
    );
  }
}
