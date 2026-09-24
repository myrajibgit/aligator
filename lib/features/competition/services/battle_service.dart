import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/competition/models/battle_model.dart';
import 'package:studycompete/shared/constants/app_constants.dart';

class BattleService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  BattleService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // ─── Stream User's Battles ────────────────────────────────────────────────

  /// Watches all battles involving the user (challenger or challenged)
  Stream<List<BattleModel>> watchUserBattles(String uid) {
    return _firestore
        .collection(AppConstants.battlesCollection)
        .where(Filter.or(
          Filter('challengerUid', isEqualTo: uid),
          Filter('challengedUid', isEqualTo: uid),
        ))
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BattleModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Watches incoming pending challenges for user
  Stream<List<BattleModel>> watchPendingChallenges(String uid) {
    return _firestore
        .collection(AppConstants.battlesCollection)
        .where('challengedUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => BattleModel.fromFirestore(doc)).toList());
  }

  // ─── Anti-Farming Rule Check ──────────────────────────────────────────────

  /// Checks if challenger has already battled the challenged user twice in the last 7 days.
  Future<bool> canChallenge({
    required String challengerUid,
    required String challengedUid,
  }) async {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    final recentBattles = await _firestore
        .collection(AppConstants.battlesCollection)
        .where('challengerUid', isEqualTo: challengerUid)
        .where('challengedUid', isEqualTo: challengedUid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
        .get();

    return recentBattles.docs.length < 2;
  }

  /// Count of battles between two users in the last 7 days (max 2)
  Future<int> weeklyBattleCount({
    required String userA,
    required String userB,
  }) async {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    final q1 = await _firestore
        .collection(AppConstants.battlesCollection)
        .where('challengerUid', isEqualTo: userA)
        .where('challengedUid', isEqualTo: userB)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
        .get();

    final q2 = await _firestore
        .collection(AppConstants.battlesCollection)
        .where('challengerUid', isEqualTo: userB)
        .where('challengedUid', isEqualTo: userA)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
        .get();

    return q1.docs.length + q2.docs.length;
  }

  // ─── Initiate Battle ──────────────────────────────────────────────────────

  Future<String> createChallenge({
    required UserModel challenger,
    required UserModel challenged,
  }) async {
    if (challenger.uid == challenged.uid) {
      throw Exception('Choose another student to challenge.');
    }
    final result = await _functions
        .httpsCallable('createBattle')
        .call<Map<String, dynamic>>({'challengedUid': challenged.uid});
    final battleId = result.data['battleId'] as String?;
    if (battleId == null || battleId.isEmpty) {
      throw Exception('The challenge could not be created. Please try again.');
    }
    return battleId;
  }

  // ─── Decline Battle ───────────────────────────────────────────────────────

  Future<void> declineBattle(String battleId) async {
    await _functions
        .httpsCallable('declineBattle')
        .call<Map<String, dynamic>>({'battleId': battleId});
  }

  // ─── Accept & Resolve 3-Round Duel ────────────────────────────────────────

  Future<BattleModel> acceptAndResolveBattle(String battleId) async {
    await _functions
        .httpsCallable('resolveBattle')
        .call<Map<String, dynamic>>({'battleId': battleId});
    final battleDoc = await _firestore
        .collection(AppConstants.battlesCollection)
        .doc(battleId)
        .get();
    if (!battleDoc.exists) throw Exception('Battle not found.');
    return BattleModel.fromFirestore(battleDoc);
  }

}
