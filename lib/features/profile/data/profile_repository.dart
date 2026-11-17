import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile stored at `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.name = '',
    this.bio = '',
    this.photoBase64,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String bio;
  final String? photoBase64;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? name,
    String? bio,
    String? photoBase64,
    bool clearPhoto = false,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'bio': bio,
      'photoBase64': photoBase64,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawUpdated = data['updatedAt'];
    return UserProfile(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      photoBase64: data['photoBase64'] as String?,
      updatedAt: rawUpdated is Timestamp ? rawUpdated.toDate() : null,
    );
  }
}

/// Contract for reading and saving user profile details.
abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Future<void> saveProfile(UserProfile profile);
}

/// Cloud Firestore implementation storing profile fields on `users/{uid}`.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return UserProfile(uid: uid);
      return UserProfile.fromFirestore(snapshot);
    });
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _doc(profile.uid).set(profile.toFirestore(), SetOptions(merge: true));
  }
}
