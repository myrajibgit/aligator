import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_model.dart';

final userModelProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists && doc.data() != null ? UserModel.fromJson(doc.data()!) : null);
});

final userStatsProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (doc.exists && doc.data() != null) {
    return UserModel.fromJson(doc.data()!);
  }
  return null;
});
