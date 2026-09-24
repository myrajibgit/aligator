import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/social/models/chat_model.dart';
import 'package:studycompete/features/social/models/party_model.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:uuid/uuid.dart';

class SocialService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SocialService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // CLASSMATE DIRECTORY
  // ============================================================

  /// Fetches classmates in the same school + class, excluding blocked users.
  Stream<List<UserModel>> getClassmates({
    required String schoolId,
    required String classId,
    required List<String> blockedUids,
  }) {
    final currentUid = _auth.currentUser?.uid;
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('schoolId', isEqualTo: schoolId)
        .where('classId', isEqualTo: classId)
        .where('onboardingComplete', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserModel.fromFirestore(d))
            .where((u) =>
                u.uid != currentUid &&
                !blockedUids.contains(u.uid))
            .toList());
  }

  // ============================================================
  // DM CHATS
  // ============================================================

  /// Returns the existing DM chatId between two users, or null.
  Future<String?> findDmChat(String otherUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _firestore
        .collection(AppConstants.chatsCollection)
        .where('type', isEqualTo: 'dm')
        .where('memberUids', arrayContains: myUid)
        .get();

    for (final doc in snap.docs) {
      final members = List<String>.from(doc['memberUids'] ?? []);
      if (members.contains(otherUid)) return doc.id;
    }
    return null;
  }

  /// Opens an existing DM or creates a new one. Returns the chatId.
  Future<String> openOrCreateDm(String otherUid) async {
    final existing = await findDmChat(otherUid);
    if (existing != null) return existing;

    final myUid = _auth.currentUser!.uid;
    final docRef = _firestore.collection(AppConstants.chatsCollection).doc();
    await docRef.set({
      'id': docRef.id,
      'type': 'dm',
      'memberUids': [myUid, otherUid],
      'lastMessage': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Returns all DM chats for the current user ordered by updatedAt.
  Stream<List<ChatModel>> getMyChats() {
    final myUid = _auth.currentUser!.uid;
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('memberUids', arrayContains: myUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatModel.fromFirestore(d)).toList());
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  /// Stream of messages for a given chatId, ordered ascending.
  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  /// Sends a message and updates the chat's lastMessage metadata.
  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final myUid = _auth.currentUser!.uid;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msgRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection('messages')
        .doc();

    final batch = _firestore.batch();

    batch.set(msgRef, {
      'id': msgRef.id,
      'senderUid': myUid,
      'text': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'reported': false,
    });

    batch.update(
        _firestore.collection(AppConstants.chatsCollection).doc(chatId), {
      'lastMessage': {
        'text': trimmed,
        'senderUid': myUid,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ============================================================
  // BLOCKING
  // ============================================================

  Future<void> blockUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(myUid)
        .update({
      'blockedUids': FieldValue.arrayUnion([targetUid]),
    });
  }

  Future<void> unblockUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(myUid)
        .update({
      'blockedUids': FieldValue.arrayRemove([targetUid]),
    });
  }

  // ============================================================
  // REPORTING
  // ============================================================

  Future<void> reportMessage({
    required String chatId,
    required String messageId,
    required String messageText,
    required String senderUid,
    required String category,
  }) async {
    final myUid = _auth.currentUser!.uid;
    await _firestore.collection('moderationReports').add({
      'reporterUid': myUid,
      'chatId': chatId,
      'messageId': messageId,
      'messageText': messageText,
      'senderUid': senderUid,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mark message as reported
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'reported': true});
  }

  // ============================================================
  // STUDY PARTIES
  // ============================================================

  /// Returns all parties for the current user's school+class.
  Stream<List<PartyModel>> getClassParties({
    required String schoolId,
    required String classId,
  }) {
    return _firestore
        .collection(AppConstants.partiesCollection)
        .where('schoolId', isEqualTo: schoolId)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PartyModel.fromFirestore(d)).toList());
  }

  /// Returns parties that the current user is a member of.
  Stream<List<PartyModel>> getMyParties() {
    final myUid = _auth.currentUser!.uid;
    return _firestore
        .collection(AppConstants.partiesCollection)
        .where('memberUids', arrayContains: myUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PartyModel.fromFirestore(d)).toList());
  }

  /// Creates a new Study Party and its group chat. Returns partyId.
  Future<String> createParty({required String name, required String schoolId, required String classId}) async {
    final myUid = _auth.currentUser!.uid;
    final inviteCode = const Uuid().v4().substring(0, 6).toUpperCase();

    // Create the group chat first
    final chatRef = _firestore.collection(AppConstants.chatsCollection).doc();
    final partyRef = _firestore.collection(AppConstants.partiesCollection).doc();

    final batch = _firestore.batch();

    batch.set(chatRef, {
      'id': chatRef.id,
      'type': 'party',
      'memberUids': [myUid],
      'partyId': partyRef.id,
      'partyName': name,
      'lastMessage': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(partyRef, {
      'id': partyRef.id,
      'name': name,
      'schoolId': schoolId,
      'classId': classId,
      'leaderUid': myUid,
      'memberUids': [myUid],
      'inviteCode': inviteCode,
      'chatId': chatRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return partyRef.id;
  }

  /// Joins a party by invite code.
  Future<void> joinPartyByCode(String code) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _firestore
        .collection(AppConstants.partiesCollection)
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw Exception('Party not found for this code.');
    final partyDoc = snap.docs.first;
    final party = PartyModel.fromFirestore(partyDoc);

    if (party.memberUids.length >= AppConstants.maxPartySize) {
      throw Exception('Party is full (max ${AppConstants.maxPartySize} members).');
    }
    if (party.memberUids.contains(myUid)) {
      throw Exception('You are already in this party.');
    }

    final batch = _firestore.batch();
    batch.update(partyDoc.reference, {
      'memberUids': FieldValue.arrayUnion([myUid]),
    });
    batch.update(
        _firestore.collection(AppConstants.chatsCollection).doc(party.chatId), {
      'memberUids': FieldValue.arrayUnion([myUid]),
    });
    await batch.commit();
  }

  /// Leaves a party. Transfers leadership if current user is leader.
  Future<void> leaveParty(PartyModel party) async {
    final myUid = _auth.currentUser!.uid;
    final batch = _firestore.batch();

    final partyRef = _firestore
        .collection(AppConstants.partiesCollection)
        .doc(party.id);

    final newMembers =
        party.memberUids.where((uid) => uid != myUid).toList();

    if (newMembers.isEmpty) {
      // Delete the party if no members remain
      batch.delete(partyRef);
    } else {
      String newLeader = party.leaderUid;
      if (party.leaderUid == myUid) newLeader = newMembers.first;
      batch.update(partyRef, {
        'memberUids': FieldValue.arrayRemove([myUid]),
        'leaderUid': newLeader,
      });
    }

    batch.update(
        _firestore.collection(AppConstants.chatsCollection).doc(party.chatId), {
      'memberUids': FieldValue.arrayRemove([myUid]),
    });

    await batch.commit();
  }

  /// Returns a single user's profile.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }
}
