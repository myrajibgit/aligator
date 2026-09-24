import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/stats/models/shadow_soldier.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';

class ShadowArmyScreen extends ConsumerStatefulWidget {
  const ShadowArmyScreen({super.key});

  @override
  ConsumerState<ShadowArmyScreen> createState() => _ShadowArmyScreenState();
}

class _ShadowArmyScreenState extends ConsumerState<ShadowArmyScreen> {
  // Equip up to 2 active shadows
  final Set<String> _equippedShadowIds = {'igris'};

  void _toggleEquip(ShadowSoldier soldier, bool isUnlocked) {
    if (!isUnlocked) {
      HapticFeedbackUtils.alertWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 Level ${soldier.unlockLevel} required to extract ${soldier.name}.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedbackUtils.questComplete();
    setState(() {
      if (_equippedShadowIds.contains(soldier.id)) {
        _equippedShadowIds.remove(soldier.id);
      } else {
        if (_equippedShadowIds.length >= 2) {
          // Remove the first one
          _equippedShadowIds.remove(_equippedShadowIds.first);
        }
        _equippedShadowIds.add(soldier.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final level = user != null ? (user.xp ~/ 200) + 1 : 1;
    final allShadows = ShadowCatalog.allShadows;
    final unlockedShadows = allShadows.where((s) => level >= s.unlockLevel).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep Abyss
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1329),
        title: const Row(
          children: [
            Text('🥷', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'SHADOW ARMY BARRACKS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── ACTIVE LOADOUT BANNER ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA855F7).withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTIVE SHADOW LOADOUT (MAX 2)',
                      style: TextStyle(
                        color: Color(0xFFA855F7),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${_equippedShadowIds.length}/2 Deployed',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // LOADOUT SLOTS ROW
                Row(
                  children: [
                    Expanded(child: _buildEquippedSlot(0, allShadows)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildEquippedSlot(1, allShadows)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── SHADOW ROSTER TITLE ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shadow Legion Roster',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                '${unlockedShadows.length}/${allShadows.length} Extracted',
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── ROSTER CARDS ──
          ...allShadows.map((soldier) {
            final isUnlocked = level >= soldier.unlockLevel;
            final isEquipped = _equippedShadowIds.contains(soldier.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUnlocked ? const Color(0xFF0F172A) : Colors.black38,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isEquipped
                      ? soldier.shadowColor
                      : (isUnlocked ? Colors.white24 : Colors.white10),
                  width: isEquipped ? 2.0 : 1.0,
                ),
                boxShadow: isEquipped
                    ? [
                        BoxShadow(
                          color: soldier.shadowColor.withOpacity(0.3),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Emoji Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: soldier.shadowColor.withOpacity(isUnlocked ? 0.2 : 0.05),
                          border: Border.all(
                            color: isUnlocked ? soldier.shadowColor : Colors.white12,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            soldier.emoji,
                            style: TextStyle(
                              fontSize: 26,
                              color: isUnlocked ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Name & Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              soldier.name,
                              style: TextStyle(
                                color: isUnlocked ? Colors.white : Colors.white54,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              soldier.title,
                              style: TextStyle(
                                color: isUnlocked ? soldier.shadowColor : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Button
                      if (isUnlocked)
                        ElevatedButton(
                          onPressed: () => _toggleEquip(soldier, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEquipped ? soldier.shadowColor : const Color(0xFF1E293B),
                            foregroundColor: isEquipped ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isEquipped ? 'DEPLOYED ✓' : 'DEPLOY',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, size: 12, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(
                                'Lv.${soldier.unlockLevel}',
                                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // BUFF DESCRIPTION PILL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: isUnlocked ? soldier.shadowColor : Colors.white38,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            soldier.buffDescription,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // QUOTE
                  Text(
                    soldier.quote,
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEquippedSlot(int slotIndex, List<ShadowSoldier> allShadows) {
    final equippedList = _equippedShadowIds.toList();
    final soldierId = slotIndex < equippedList.length ? equippedList[slotIndex] : null;
    final soldier = soldierId != null ? allShadows.firstWhere((s) => s.id == soldierId) : null;

    if (soldier != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: soldier.shadowColor),
        ),
        child: Row(
          children: [
            Text(soldier.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soldier.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    soldier.buffStat,
                    style: TextStyle(color: soldier.shadowColor, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: Colors.white38),
              onPressed: () => _toggleEquip(soldier, true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Text(
            '+ EMPTY SLOT',
            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }
}
