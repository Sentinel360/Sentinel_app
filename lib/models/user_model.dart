import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? activeTripId;
  final String role;
  final List<EmergencyContact> emergencyContacts;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.activeTripId,
    this.role = 'user',
    this.emergencyContacts = const [],
    required this.createdAt,
  });

  // Convert Firestore document into a UserModel object
  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      activeTripId: data['activeTripId'],
      role: data['role'] ?? 'user',
      emergencyContacts: (data['emergencyContacts'] as List<dynamic>? ?? [])
          .map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Convert UserModel object into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'activeTripId': activeTripId,
      'role': role,
      'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> data) {
    return EmergencyContact(
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      relationship: data['relationship'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }
}
