import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/social/models/chat_model.dart';
import 'package:studycompete/features/social/providers/social_provider.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';
import 'package:studycompete/shared/widgets/notification_bell.dart';
import 'package:studycompete/features/social/widgets/hunter_profile_sheet.dart';
import 'package:timeago/timeago.dart' as timeago;

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen>
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Social Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Messages'),
            Tab(icon: Icon(Icons.people_outline), text: 'Classmates'),
          ],
        ),
        actions: [
          NotificationBell(uid: uid),
          IconButton(
            icon: const Icon(Icons.castle_rounded),
            tooltip: 'Dungeon Gates',
            color: const Color(0xFF8B5CF6),
            onPressed: () => context.push('/home/social/parties'),
          ),
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Study Parties',
            onPressed: () => context.push('/home/social/parties'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MessagesTab(),
          _ClassmatesTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGES TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _MessagesTab extends ConsumerWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(myChatsProvider);
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (chats) {
        if (chats.isEmpty) {
          return _EmptyState(
            icon: Icons.chat_bubble_outline,
            message: 'No conversations yet',
            subMessage: 'Go to Classmates to start a DM!',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            final chat = chats[i];
            return _ChatTile(chat: chat, myUid: myUid);
          },
        );
      },
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat, required this.myUid});
  final ChatModel chat;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // Get partner UID for DMs
    final partnerUid = chat.type == 'dm'
        ? chat.memberUids.firstWhere((uid) => uid != myUid,
            orElse: () => myUid)
        : null;

    final partnerAsync = partnerUid != null
        ? ref.watch(chatPartnerProfileProvider(partnerUid))
        : null;

    final title = chat.type == 'party'
        ? (chat.partyName ?? 'Study Party')
        : partnerAsync?.value?.displayName ?? '…';

    final subtitle = chat.lastMessage?.text ?? 'Start a conversation';
    final time = chat.lastMessage?.timestamp != null
        ? timeago.format(chat.lastMessage!.timestamp!)
        : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.secondary.withOpacity(0.15),
        child: chat.type == 'party'
            ? Icon(Icons.groups, color: AppColors.secondary, size: 28)
            : Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
      ),
      trailing: Text(time,
          style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 11)),
      onTap: () => context.push('/home/social/chat/${chat.id}',
          extra: {'chatTitle': title, 'type': chat.type}),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLASSMATES TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _ClassmatesTab extends ConsumerWidget {
  const _ClassmatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classmatesAsync = ref.watch(classmatesProvider);

    return classmatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (classmates) {
        if (classmates.isEmpty) {
          return _EmptyState(
            icon: Icons.school_outlined,
            message: 'No classmates found',
            subMessage: 'You\'re the first from your class!',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: classmates.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) => _ClassmateTile(peer: classmates[i]),
        );
      },
    );
  }
}

class _ClassmateTile extends ConsumerWidget {
  const _ClassmateTile({required this.peer});
  final UserModel peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final level = (peer.xp ~/ 200) + 1;
    final hunterRank = HunterRankUtils.getRankInfo(level);

    return ListTile(
      onTap: () => HunterProfileSheet.show(context, peer),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: hunterRank.color.withOpacity(0.18),
            backgroundImage:
                peer.photoUrl != null ? NetworkImage(peer.photoUrl!) : null,
            child: peer.photoUrl == null
                ? Text(
                    peer.displayName.isNotEmpty
                        ? peer.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: hunterRank.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              child: Text(
                hunterRank.badgeAssetOrEmoji,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      title: Text(peer.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Row(
        children: [
          Text('@${peer.username}',
              style: TextStyle(
                  color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hunterRank.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: hunterRank.color.withOpacity(0.35)),
            ),
            child: Text(
              '${hunterRank.code}-RANK • Lv.$level',
              style: TextStyle(
                  color: hunterRank.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
            tooltip: 'Challenge Duel',
            onPressed: () => context.push('/home/compete/new-challenge'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                minimumSize: const Size(56, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: () async {
              final service = ref.read(socialServiceProvider);
              try {
                final chatId = await service.openOrCreateDm(peer.uid);
                if (context.mounted) {
                  context.push('/home/social/chat/$chatId',
                      extra: {'chatTitle': peer.displayName, 'type': 'dm'});
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Message', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.message, required this.subMessage});
  final IconData icon;
  final String message;
  final String subMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
          const SizedBox(height: 6),
          Text(subMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurface.withOpacity(0.35))),
        ],
      ),
    );
  }
}
