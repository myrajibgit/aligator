import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/social/models/chat_model.dart';
import 'package:studycompete/features/social/models/party_model.dart';
import 'package:studycompete/features/social/services/social_service.dart';
import 'package:studycompete/shared/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Service provider ──────────────────────────────────────────────────────────
final socialServiceProvider = Provider<SocialService>((ref) => SocialService());

// ── Classmates stream ─────────────────────────────────────────────────────────
final classmatesProvider = StreamProvider<List<UserModel>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return Stream.value([]);
  final service = ref.watch(socialServiceProvider);
  return service.getClassmates(
    schoolId: profile.schoolId,
    classId: profile.classId,
    blockedUids: profile.blockedUids,
  );
});

// ── My chats (DMs + party chats) ──────────────────────────────────────────────
final myChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final service = ref.watch(socialServiceProvider);
  return service.getMyChats();
});

// ── Messages for a given chatId ────────────────────────────────────────────────
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  final service = ref.watch(socialServiceProvider);
  return service.getMessages(chatId);
});

// ── Chat partner user profile ─────────────────────────────────────────────────
final chatPartnerProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  final service = ref.watch(socialServiceProvider);
  return service.getUserProfile(uid);
});

// ── Class parties ─────────────────────────────────────────────────────────────
final classPartiesProvider = StreamProvider<List<PartyModel>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile == null) return Stream.value([]);
  final service = ref.watch(socialServiceProvider);
  return service.getClassParties(
    schoolId: profile.schoolId,
    classId: profile.classId,
  );
});

// ── My parties ────────────────────────────────────────────────────────────────
final myPartiesProvider = StreamProvider<List<PartyModel>>((ref) {
  final service = ref.watch(socialServiceProvider);
  return service.getMyParties();
});
