import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/stats/models/hunter_relic_model.dart';
import 'package:studycompete/features/stats/services/hunter_relic_service.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';

class RelicsVaultScreen extends ConsumerStatefulWidget {
  const RelicsVaultScreen({super.key});

  @override
  ConsumerState<RelicsVaultScreen> createState() => _RelicsVaultScreenState();
}

class _RelicsVaultScreenState extends ConsumerState<RelicsVaultScreen> {
  RelicSlot? _selectedSlotFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    final inventoryAsync = ref.watch(hunterInventoryProvider(uid));
    final equipped = ref.watch(equippedRelicsProvider(uid));
    final activeBuffs = ref.watch(activeHunterBuffsProvider(uid));
    final service = ref.read(hunterRelicServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFFFFD700), size: 22),
            SizedBox(width: 8),
            Text(
              "MONARCH'S VAULT",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          NotificationBell(uid: uid),
        ],
      ),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white70))),
        data: (inventory) {
          final filteredList = _selectedSlotFilter == null
              ? inventory
              : inventory.where((r) => r.slot == _selectedSlotFilter).toList();

          return CustomScrollView(
            slivers: [
              // ── Active Buffs HUD ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildBuffsBanner(activeBuffs),
              ),

              // ── Equipped Loadout (4 Slots) ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.military_tech, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'ACTIVE EQUIPMENT LOADOUT',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSlotCard(context, uid, RelicSlot.weapon, equipped[RelicSlot.weapon], service)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildSlotCard(context, uid, RelicSlot.amulet, equipped[RelicSlot.amulet], service)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildSlotCard(context, uid, RelicSlot.ring, equipped[RelicSlot.ring], service)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildSlotCard(context, uid, RelicSlot.armor, equipped[RelicSlot.armor], service)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filter Chips ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text(
                        'RELIC STASH',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      _buildFilterChip('All', null),
                      const SizedBox(width: 4),
                      _buildFilterChip('⚔️', RelicSlot.weapon),
                      const SizedBox(width: 4),
                      _buildFilterChip('🔮', RelicSlot.amulet),
                      const SizedBox(width: 4),
                      _buildFilterChip('💍', RelicSlot.ring),
                      const SizedBox(width: 4),
                      _buildFilterChip('🛡️', RelicSlot.armor),
                    ],
                  ),
                ),
              ),

              // ── Relic Grid ────────────────────────────────────────────────
              if (filteredList.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No relics found in this category.\nRaid Dungeon Gates to unlock legendary drops!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.5),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final relic = filteredList[index];
                        return _buildRelicTile(context, uid, relic, service);
                      },
                      childCount: filteredList.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBuffsBanner(ActiveHunterBuffs buffs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 18),
              SizedBox(width: 6),
              Text(
                'EQUIPPED RELIC PASSIVES',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (buffs.xpMultiplierBoost > 0)
                _buildBuffBadge('⚡ +${(buffs.xpMultiplierBoost * 100).toInt()}% Study XP', const Color(0xFF38BDF8)),
              if (buffs.fatigueReduction > 0)
                _buildBuffBadge('🛡️ -${(buffs.fatigueReduction * 100).toInt()}% Fatigue', const Color(0xFF22C55E)),
              if (buffs.gateDamageMultiplier > 1.0)
                _buildBuffBadge('🗡️ +${((buffs.gateDamageMultiplier - 1.0) * 100).toInt()}% Raid Strike', const Color(0xFFEF4444)),
              if (buffs.battleIqBonus > 0)
                _buildBuffBadge('🧠 +${(buffs.battleIqBonus * 100).toInt()}% Battle IQ', const Color(0xFFA855F7)),
              if (buffs.hasStreakShield)
                _buildBuffBadge('🔥 Streak Grace Shield', const Color(0xFFFFD700)),
              if (buffs.xpMultiplierBoost == 0 &&
                  buffs.fatigueReduction == 0 &&
                  buffs.gateDamageMultiplier == 1.0 &&
                  !buffs.hasStreakShield)
                const Text(
                  'No active buffs. Equip relics below to boost your stats.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuffBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    String uid,
    RelicSlot slot,
    HunterRelic? relic,
    HunterRelicService service,
  ) {
    final hasItem = relic != null;
    final color = hasItem ? relic.rarityColor : Colors.white24;

    return InkWell(
      onTap: () {
        if (hasItem) {
          _showRelicDetailsDialog(context, uid, relic, service);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasItem ? color.withOpacity(0.8) : Colors.white12,
            width: hasItem ? 1.5 : 1.0,
          ),
          boxShadow: hasItem
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasItem ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hasItem ? color.withOpacity(0.4) : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(
                hasItem ? relic.iconEmoji : _slotDefaultEmoji(slot),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasItem ? relic.slotDisplayName : _slotName(slot),
                    style: TextStyle(
                      color: hasItem ? color : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasItem ? relic.name : 'Empty Slot',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasItem ? Colors.white : Colors.white30,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasItem) ...[
                    const SizedBox(height: 2),
                    Text(
                      relic.statBuff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RelicSlot? slot) {
    final isSelected = _selectedSlotFilter == slot;
    return InkWell(
      onTap: () {
        setState(() => _selectedSlotFilter = slot);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8).withOpacity(0.25) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRelicTile(
    BuildContext context,
    String uid,
    HunterRelic relic,
    HunterRelicService service,
  ) {
    final color = relic.rarityColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: relic.isEquipped ? color.withOpacity(0.7) : Colors.white10,
          width: relic.isEquipped ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => _showRelicDetailsDialog(context, uid, relic, service),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Text(relic.iconEmoji, style: const TextStyle(fontSize: 24)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                relic.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                relic.rarityDisplayName,
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              relic.statBuff,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              relic.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        trailing: FilledButton(
          onPressed: () async {
            if (relic.isEquipped) {
              await service.unequipRelic(uid, relic);
              HapticFeedbackUtils.mediumImpact();
            } else {
              await service.equipRelic(uid, relic);
              HapticFeedbackUtils.questComplete();
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: relic.isEquipped ? Colors.white12 : color,
            foregroundColor: relic.isEquipped ? Colors.white70 : Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            relic.isEquipped ? 'EQUIPPED' : 'EQUIP',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ),
    );
  }

  void _showRelicDetailsDialog(
    BuildContext context,
    String uid,
    HunterRelic relic,
    HunterRelicService service,
  ) {
    final color = relic.rarityColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.6), width: 1.5),
        ),
        title: Row(
          children: [
            Text(relic.iconEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relic.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${relic.rarityDisplayName} • ${relic.slotDisplayName}',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      relic.statBuff,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              relic.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LORE INSCRIPTION',
                    style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relic.lore,
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Acquired: ${relic.source}',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (relic.isEquipped) {
                await service.unequipRelic(uid, relic);
                HapticFeedbackUtils.mediumImpact();
              } else {
                await service.equipRelic(uid, relic);
                HapticFeedbackUtils.questComplete();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(
              relic.isEquipped ? 'Unequip' : 'Equip Relic',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _slotDefaultEmoji(RelicSlot slot) {
    switch (slot) {
      case RelicSlot.weapon:
        return '⚔️';
      case RelicSlot.amulet:
        return '🔮';
      case RelicSlot.ring:
        return '💍';
      case RelicSlot.armor:
        return '🛡️';
    }
  }

  String _slotName(RelicSlot slot) {
    switch (slot) {
      case RelicSlot.weapon:
        return 'WEAPON';
      case RelicSlot.amulet:
        return 'AMULET';
      case RelicSlot.ring:
        return 'RING';
      case RelicSlot.armor:
        return 'ARMOR';
    }
  }
}
