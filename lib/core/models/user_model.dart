import 'package:cloud_firestore/cloud_firestore.dart';

// --------------------------------------------------- ][ ESTRUCTURA DE DATOS ][ --------------------------------------------------- //

// Define los campos del usuario y convierte entre Dart y Firestore.

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final updatedAtValue = map['updatedAt'];

    return UserModel(
      uid: uid,
      email: (map['email'] ?? '').toString(),
      displayName: map['displayName']?.toString(),
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : (createdAtValue is DateTime ? createdAtValue : DateTime.now()),
      updatedAt: updatedAtValue is Timestamp
          ? updatedAtValue.toDate()
          : (updatedAtValue is DateTime ? updatedAtValue : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
