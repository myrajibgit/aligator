import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/social/models/chat_model.dart';
import 'package:studycompete/features/social/models/party_model.dart';
import 'package:studycompete/features/social/providers/social_provider.dart';
import 'package:studycompete/features/social/services/social_service.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:studycompete/shared/theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.chatType,
  });

  final String chatId;
  final String chatTitle;
  final String chatType;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await ref.read(socialServiceProvider).sendMessage(
            chatId: widget.chatId,
            text: text,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showPartyDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PartyDetailsModal(
        chatId: widget.chatId,
        partyTitle: widget.chatTitle,
      ),
    );
  }

  void _showReportDialog(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ReportBottomSheet(
        message: message,
        chatId: widget.chatId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    messagesAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              widget.chatType == 'party' ? 'Study Party' : 'Direct Message',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (widget.chatType == 'party')
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Party Details',
              onPressed: () => _showPartyDetails(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages list ──────────────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.waving_hand_outlined,
                            size: 56,
                            color: cs.onSurface.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text('Say hello!',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: cs.onSurface.withOpacity(0.4))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderUid == myUid;
                    final showDate = i == 0 ||
                        _isDifferentDay(
                            messages[i - 1].timestamp, msg.timestamp);

                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.timestamp),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          onLongPress: !isMe
                              ? () => _showReportDialog(msg)
                              : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ──────────────────────────────────────────────────────
          _MessageInputBar(
            controller: _controller,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE BUBBLE
// ═══════════════════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  const _MessageBubble(
      {required this.message, required this.isMe, this.onLongPress});
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = message.timestamp != null
        ? DateFormat('HH:mm').format(message.timestamp!)
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 48 : 0,
            right: isMe ? 0 : 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primary
                : cs.surfaceVariant,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: isMe ? Colors.white : cs.onSurface,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                time,
                style: TextStyle(
                  color: isMe
                      ? Colors.white.withOpacity(0.65)
                      : cs.onSurface.withOpacity(0.45),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATE DIVIDER
// ═══════════════════════════════════════════════════════════════════════════════
class _DateDivider extends StatelessWidget {
  const _DateDivider({this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = date != null ? DateFormat('MMMM d, yyyy').format(date!) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE INPUT BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar(
      {required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: cs.surfaceVariant.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              child: FloatingActionButton.small(
                onPressed: sending ? null : onSend,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPORT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _ReportBottomSheet extends ConsumerWidget {
  const _ReportBottomSheet({required this.message, required this.chatId});
  final ChatMessage message;
  final String chatId;

  static const _categories = [
    'Harassment',
    'Inappropriate Content',
    'Spam',
    'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
          ),
          Text('Report Message',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('"${message.text}"',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: cs.onSurface.withOpacity(0.55),
                  fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          ..._categories.map((cat) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flag_outlined, color: cs.error),
                title: Text(cat),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref.read(socialServiceProvider).reportMessage(
                          chatId: chatId,
                          messageId: message.id,
                          messageText: message.text,
                          senderUid: message.senderUid,
                          category: cat,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message reported. Thank you.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARTY DETAILS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _PartyDetailsModal extends ConsumerWidget {
  const _PartyDetailsModal({
    required this.chatId,
    required this.partyTitle,
  });

  final String chatId;
  final String partyTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.partiesCollection)
          .where('chatId', isEqualTo: chatId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final party = PartyModel.fromFirestore(snapshot.data!.docs.first);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: const Icon(Icons.group, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            party.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${party.memberUids.length} of ${AppConstants.maxPartySize} Members',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.copy, size: 14),
                      label: Text('Code: ${party.inviteCode}'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: party.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite code copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MEMBERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<UserModel?>>(
                  future: Future.wait(
                    party.memberUids.map(
                      (uid) => ref.read(socialServiceProvider).getUserProfile(uid),
                    ),
                  ),
                  builder: (context, memberSnap) {
                    if (!memberSnap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final members = memberSnap.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: members.length,
                      itemBuilder: (context, idx) {
                        final member = members[idx];
                        if (member == null) return const SizedBox.shrink();
                        final isLeader = member.uid == party.leaderUid;
                        final isMe = member.uid == myUid;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.secondaryContainer,
                            backgroundImage: (member.photoUrl != null && member.photoUrl!.isNotEmpty)
                                ? NetworkImage(member.photoUrl!)
                                : null,
                            child: (member.photoUrl == null || member.photoUrl!.isEmpty)
                                ? Text(member.displayName.isNotEmpty
                                    ? member.displayName[0].toUpperCase()
                                    : '?')
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('You',
                                      style: TextStyle(fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text('@${member.username}',
                              style: TextStyle(fontSize: 12, color: cs.outline)),
                          trailing: isLeader
                              ? Chip(
                                  label: const Text('Leader',
                                      style: TextStyle(fontSize: 11)),
                                  avatar: const Icon(Icons.star,
                                      size: 14, color: Colors.amber),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text('Leave Party',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (alertCtx) => AlertDialog(
                          title: const Text('Leave Party?'),
                          content: Text(
                            'Are you sure you want to leave "${party.name}"? '
                            '${party.leaderUid == myUid ? "Leadership will be transferred to another member." : ""}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(alertCtx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () async {
                                Navigator.pop(alertCtx); // Pop alert
                                Navigator.pop(context); // Pop bottom sheet
                                try {
                                  await ref
                                      .read(socialServiceProvider)
                                      .leaveParty(party);
                                  if (context.mounted) {
                                    context.pop(); // Pop chat screen
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'You left "${party.name}".'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Leave'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

