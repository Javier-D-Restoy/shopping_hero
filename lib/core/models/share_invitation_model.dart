import 'package:cloud_firestore/cloud_firestore.dart';

class ShareInvitation {
  const ShareInvitation({
    required this.id,
    required this.listId,
    required this.listName,
    required this.ownerDisplayName,
    required this.ownerEmail,
    required this.createdAt,
  });

  final String id;
  final String listId;
  final String listName;
  final String ownerDisplayName;
  final String ownerEmail;
  final DateTime createdAt;

  factory ShareInvitation.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : createdAtValue is DateTime
        ? createdAtValue
        : DateTime.fromMillisecondsSinceEpoch(0);

    return ShareInvitation(
      id: id,
      listId: (map['listId'] ?? id).toString(),
      listName: (map['listName'] ?? '').toString(),
      ownerDisplayName: (map['ownerDisplayName'] ?? 'Usuario').toString(),
      ownerEmail: (map['ownerEmail'] ?? '').toString(),
      createdAt: createdAt,
    );
  }
}
