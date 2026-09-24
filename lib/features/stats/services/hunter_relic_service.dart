import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/stats/models/hunter_relic_model.dart';
import 'package:studycompete/shared/services/notifications_service.dart';

/// Service managing Hunter equipment, relic inventory, and passive RPG buffs.
class HunterRelicService {
  final FirebaseFirestore _db;
  final NotificationsService _notifService;

  HunterRelicService({
    FirebaseFirestore? db,
    NotificationsService? notifService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _notifService = notifService ?? NotificationsService(db: db);

  CollectionReference<Map<String, dynamic>> _inventoryCol(String uid) =>
      _db.collection('users').doc(uid).collection('inventory');

  DocumentReference<Map<String, dynamic>> _loadoutDoc(String uid) =>
      _db.collection('users').doc(uid).collection('equipment').doc('current');

  /// Streams the hunter's full inventory of relics, indicating equipped status.
  Stream<List<HunterRelic>> watchInventory(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _inventoryCol(uid).snapshots().asyncMap((snap) async {
      // Fetch currently equipped slot IDs
      final loadoutSnap = await _loadoutDoc(uid).get();
      final loadout = loadoutSnap.data() ?? {};

      // If user has zero records yet, grant a beginner Kasaka's Venom Dagger
      if (snap.docs.isEmpty) {
        await _inventoryCol(uid).doc('kasaka_fang').set({
          'relicId': 'kasaka_fang',
          'acquiredAt': FieldValue.serverTimestamp(),
        });
        return [
          RelicCatalog.allRelics.first.copyWith(isEquipped: false),
        ];
      }

      final results = <HunterRelic>[];
      for (final doc in snap.docs) {
        final relicId = doc.id;
        final base = RelicCatalog.find(relicId) ??
            HunterRelic.fromMap(relicId, doc.data());

        final isEquipped = loadout[base.slot.name] == relicId;
        results.add(base.copyWith(isEquipped: isEquipped));
      }
      return results;
    });
  }

  /// Equips a relic to its respective equipment slot (Weapon, Amulet, Ring, Armor).
  Future<void> equipRelic(String uid, HunterRelic relic) async {
    await _loadoutDoc(uid).set({
      relic.slot.name: relic.id,
    }, SetOptions(merge: true));
  }

  /// Unequips a relic from its slot.
  Future<void> unequipRelic(String uid, HunterRelic relic) async {
    await _loadoutDoc(uid).set({
      relic.slot.name: FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Awards a new relic to the hunter (e.g. from Dungeon Gate Boss Defeat).
  Future<void> awardRelic(String uid, String relicId) async {
    final docRef = _inventoryCol(uid).doc(relicId);
    final exists = (await docRef.get()).exists;
    if (!exists) {
      await docRef.set({
        'relicId': relicId,
        'acquiredAt': FieldValue.serverTimestamp(),
      });

      final relic = RelicCatalog.find(relicId);
      final relicName = relic?.name ?? 'Legendary Relic';

      // Send in-app system notification
      await _notifService.sendNotification(
        uid: uid,
        type: NotificationType.systemAlert,
        title: '💎 NEW RELIC OBTAINED!',
        body: 'You conquered the gate and acquired [$relicName]! Equip it in your Vault.',
      );
    }
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final hunterRelicServiceProvider = Provider<HunterRelicService>((ref) {
  return HunterRelicService();
});

final hunterInventoryProvider =
    StreamProvider.family<List<HunterRelic>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value([]);
  return ref.watch(hunterRelicServiceProvider).watchInventory(uid);
});

/// Map of currently equipped relics keyed by slot.
final equippedRelicsProvider =
    Provider.family<Map<RelicSlot, HunterRelic?>, String>((ref, uid) {
  final inventoryAsync = ref.watch(hunterInventoryProvider(uid));
  final map = <RelicSlot, HunterRelic?>{
    RelicSlot.weapon: null,
    RelicSlot.amulet: null,
    RelicSlot.ring: null,
    RelicSlot.armor: null,
  };

  inventoryAsync.whenData((list) {
    for (final r in list) {
      if (r.isEquipped) {
        map[r.slot] = r;
      }
    }
  });

  return map;
});

/// Passive combat and study buffs aggregated across all currently equipped relics.
class ActiveHunterBuffs {
  final double xpMultiplierBoost;
  final double fatigueReduction;
  final double gateDamageMultiplier;
  final double battleIqBonus;
  final bool hasStreakShield;

  const ActiveHunterBuffs({
    this.xpMultiplierBoost = 0.0,
    this.fatigueReduction = 0.0,
    this.gateDamageMultiplier = 1.0,
    this.battleIqBonus = 0.0,
    this.hasStreakShield = false,
  });
}

final activeHunterBuffsProvider =
    Provider.family<ActiveHunterBuffs, String>((ref, uid) {
  final equipped = ref.watch(equippedRelicsProvider(uid));

  double xp = 0.0;
  double fatigue = 0.0;
  double gateDmg = 1.0;
  double battleIq = 0.0;
  bool shield = false;

  for (final relic in equipped.values) {
    if (relic == null) continue;
    switch (relic.buffType) {
      case RelicBuffType.xpBoost:
        xp += relic.buffMultiplier;
        break;
      case RelicBuffType.fatigueReduction:
        fatigue += relic.buffMultiplier;
        break;
      case RelicBuffType.gateDamage:
        gateDmg += relic.buffMultiplier;
        break;
      case RelicBuffType.battleIq:
        battleIq += relic.buffMultiplier;
        break;
      case RelicBuffType.streakShield:
        shield = true;
        break;
      case RelicBuffType.allStats:
        xp += 0.15;
        fatigue += 0.15;
        gateDmg += 0.20;
        battleIq += 0.20;
        break;
    }
  }

  return ActiveHunterBuffs(
    xpMultiplierBoost: xp,
    fatigueReduction: fatigue,
    gateDamageMultiplier: gateDmg,
    battleIqBonus: battleIq,
    hasStreakShield: shield,
  );
});
