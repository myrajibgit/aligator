import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/social/models/party_model.dart';
import 'package:studycompete/features/social/providers/social_provider.dart';
import 'package:studycompete/features/social/services/social_service.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';

class PartiesScreen extends ConsumerStatefulWidget {
  const PartiesScreen({super.key});

  @override
  ConsumerState<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends ConsumerState<PartiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePartyDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Study Party'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: 'e.g. Calculus Crusaders',
            labelText: 'Party Name',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final profile = ref.read(currentUserProfileProvider).value;
              if (profile == null) return;
              try {
                await ref.read(socialServiceProvider).createParty(
                      name: name,
                      schoolId: profile.schoolId,
                      classId: profile.classId,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Party "$name" created!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinByCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Party by Code'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'XXXXXX',
            labelText: 'Invite Code',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.length != 6) return;
              Navigator.pop(ctx);
              try {
                await ref.read(socialServiceProvider).joinPartyByCode(code);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You joined the party!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Parties',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Parties'),
            Tab(text: 'Class Parties'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Join by Code',
            onPressed: _showJoinByCodeDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePartyDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Party'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyPartiesTab(),
          _ClassPartiesTab(),
        ],
      ),
    );
  }
}

// ─── My Parties Tab ──────────────────────────────────────────────────────────
class _MyPartiesTab extends ConsumerWidget {
  const _MyPartiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myParties = ref.watch(myPartiesProvider);
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';

    return myParties.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (parties) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── DUNGEON BOSS RAID BANNER ──
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🗿', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              '⚔️ C-RANK GATE: MATH GOLEM',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Co-op Boss Raid available for study parties!',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/home/social/dungeon-gate/${parties.isNotEmpty ? parties.first.id : "default"}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('RAID ⚔️', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
            ),

            if (parties.isEmpty)
              const _EmptyPartyState(
                message: 'You haven\'t joined any parties yet',
                subMessage: 'Create one or use an invite code!',
              )
            else
              ...parties.map((p) => _PartyCard(party: p, myUid: myUid, showLeave: true)),
          ],
        );
      },
    );
  }
}

// ─── Class Parties Tab ───────────────────────────────────────────────────────
class _ClassPartiesTab extends ConsumerWidget {
  const _ClassPartiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classParties = ref.watch(classPartiesProvider);
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';

    return classParties.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (parties) {
        if (parties.isEmpty) {
          return _EmptyPartyState(
            message: 'No parties in your class yet',
            subMessage: 'Be the first to create one!',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: parties.length,
          itemBuilder: (context, i) =>
              _PartyCard(party: parties[i], myUid: myUid, showLeave: false),
        );
      },
    );
  }
}

// ─── Party Card ──────────────────────────────────────────────────────────────
class _PartyCard extends ConsumerWidget {
  const _PartyCard(
      {required this.party, required this.myUid, required this.showLeave});
  final PartyModel party;
  final String myUid;
  final bool showLeave;

  bool get _isMember => party.memberUids.contains(myUid);
  bool get _isLeader => party.leaderUid == myUid;
  bool get _isFull => party.memberUids.length >= AppConstants.maxPartySize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups,
                      color: AppColors.secondary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              party.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          if (_isLeader)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Leader',
                                  style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${party.memberUids.length}/${AppConstants.maxPartySize} members',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.55),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Invite code row
            if (_isMember)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key,
                        size: 16,
                        color: AppColors.primary.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'Invite Code: ',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.55), fontSize: 12),
                    ),
                    Text(
                      party.inviteCode,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (_isMember) ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Open Chat'),
                      onPressed: () => context.push(
                          '/home/social/chat/${party.chatId}',
                          extra: {
                            'chatTitle': party.name,
                            'type': 'party'
                          }),
                    ),
                  ),
                  if (showLeave) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _leaveParty(context, ref),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withOpacity(0.5))),
                      child: const Text('Leave'),
                    ),
                  ],
                ] else ...[
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _isFull
                          ? null
                          : () => _joinParty(context, ref),
                      child: Text(_isFull ? 'Party Full' : 'Join Party'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinParty(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(socialServiceProvider).joinPartyByCode(party.inviteCode);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You joined the party!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _leaveParty(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Party?'),
        content: const Text('Are you sure you want to leave this study party?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Leave')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(socialServiceProvider).leaveParty(party);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('You left the party.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _EmptyPartyState extends StatelessWidget {
  const _EmptyPartyState({required this.message, required this.subMessage});
  final String message;
  final String subMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined,
                size: 72, color: cs.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
            const SizedBox(height: 6),
            Text(subMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurface.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }
}
