import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/school_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';

class OnboardingService {
  final FirebaseFirestore _firestore;

  OnboardingService(this._firestore);

  Future<bool> isUsernameTaken(String username) async {
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> saveUserProfile({
    required String uid,
    required String displayName,
    required String username,
    required String bio,
    String? photoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'displayName': displayName,
      'username': username,
      'bio': bio,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<SchoolModel>> searchSchools(String query) async {
    if (query.isEmpty) return [];
    
    // Prefix search trick
    final endQuery = '$query\uf8ff';
    
    final snapshot = await _firestore
        .collection('schools')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: endQuery)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return SchoolModel.fromJson(data);
    }).toList();
  }

  Future<void> submitSchoolRequest({
    required String name,
    required String city,
    required String country,
    required String submittedBy,
  }) async {
    await _firestore.collection('schoolRequests').add({
      'name': name,
      'city': city,
      'country': country,
      'submittedBy': submittedBy,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<ClassModel>> getClassesForSchool(String schoolId) async {
    final snapshot = await _firestore
        .collection('classes')
        .where('schoolId', isEqualTo: schoolId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return ClassModel.fromJson(data);
    }).toList();
  }

  Future<List<SubjectModel>> getSubjectsForClass(String classId) async {
    final snapshot = await _firestore
        .collection('subjects')
        .where('classId', isEqualTo: classId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return SubjectModel.fromJson(data);
    }).toList();
  }

  Future<void> completeOnboarding({
    required String uid,
    required String schoolId,
    required String classId,
    required String streamId,
    required String area,
    required List<String> subjectIds,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'schoolId': schoolId,
      'classId': classId,
      'streamId': streamId,
      'area': area,
      'subjectIds': subjectIds,
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
