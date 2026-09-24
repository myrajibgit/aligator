import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studycompete/features/auth/models/user_model.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/features/stats/providers/stats_provider.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';
import 'package:studycompete/shared/utils/hunter_rank.dart';

// -----------------------------------------------------------------------------
// SETTINGS & ACCOUNT MANAGEMENT SCREEN
//
// WHY THIS EXISTS: Mandatory for Google Play Store and Apple App Store
// publication (Apple Guideline 5.1.1(v) & Google Play User Data Policy).
// Allows students to edit their profile, view legal policies in-app,
// toggle notification/haptic preferences, sign out, or permanently purge
// their account and all associated data.
// -----------------------------------------------------------------------------

class SettingsScreen extends ConsumerStatefulWidget {
  final String uid;
  const SettingsScreen({super.key, required this.uid});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;

  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _soundEnabled = true;

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProfileProvider).value;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar(UserModel user) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final file = File(picked.path);
      final refStorage = FirebaseStorage.instance.ref().child('profiles/${user.uid}/avatar.jpg');
      await refStorage.putFile(file);
      final downloadUrl = await refStorage.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'avatarUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      HapticFeedbackUtils.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your current session?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _confirmDeleteAccount(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 8),
            Text('Permanent Deletion', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is IRREVERSIBLE. In compliance with Google Play & Apple App Store data policies:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text('• Your Hunter Guild profile and RPG stats will be permanently wiped.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            SizedBox(height: 6),
            Text('• All streak records, supply drops, and relic inventory will be erased.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            SizedBox(height: 6),
            Text('• Your avatar images and study verification history will be deleted.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            SizedBox(height: 6),
            Text('• Your Firebase Authentication account will be permanently closed.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Account', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('PURGE EVERYTHING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeletingAccount = true);
      try {
        final uid = user.uid;

        // 1. Purge Firestore Subcollections & Document
        final firestore = FirebaseFirestore.instance;
        
        // Streaks
        final streaks = await firestore.collection('users').doc(uid).collection('streaks').get();
        for (final doc in streaks.docs) {
          await doc.reference.delete();
        }

        // Inventory
        final inventory = await firestore.collection('users').doc(uid).collection('inventory').get();
        for (final doc in inventory.docs) {
          await doc.reference.delete();
        }

        // Study hashes
        final hashes = await firestore.collection('users').doc(uid).collection('studyHashes').get();
        for (final doc in hashes.docs) {
          await doc.reference.delete();
        }

        // Main User Doc
        await firestore.collection('users').doc(uid).delete();

        // 2. Purge Storage Avatar
        try {
          await FirebaseStorage.instance.ref().child('profiles/$uid/avatar.jpg').delete();
        } catch (_) {}

        // 3. Delete Firebase Auth Account
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null) {
          await authUser.delete();
        }

        HapticFeedbackUtils.success();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account permanently purged.'), backgroundColor: Color(0xFFEF4444)),
          );
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deletion failed: $e. You may need to re-login to verify identity.'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeletingAccount = false);
      }
    }
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: Color(0xFF38BDF8)),
                    SizedBox(width: 8),
                    Text('Privacy Policy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text('Effective Date: September 2026\nVersion: 1.0.0\n', style: TextStyle(color: Colors.white54, fontSize: 12)),
            _buildLegalSection(
              title: '1. Student & Child Safety (COPPA, GDPR-K, DPDP)',
              body: 'StudyCompete is strictly restricted to students aged 13 and older. We do not knowingly collect personal data from children under 13. Registration requires age verification. In accordance with COPPA (US), GDPR-K (EU), and the DPDP Act (India), students under 13 are locked out and no records are preserved.',
            ),
            _buildLegalSection(
              title: '2. Locality & Zero-GPS Tracking',
              body: 'StudyCompete never accesses, requests, or stores live GPS coordinates, geofences, or physical pin-drop locations. All community, class, and area leaderboards are derived strictly from the administrative municipality of the registered school entity.',
            ),
            _buildLegalSection(
              title: '3. Study Notes & Optical OCR Processing',
              body: 'Handwritten and textbook photos captured for syllabus verification are analyzed with on-device ML Kit and Google Generative AI (Gemini). Verification crops uploaded to Cloud Storage are automatically scrubbed via 30-day lifecycle retention rules.',
            ),
            _buildLegalSection(
              title: '4. Physical Fitness Telemetry',
              body: 'Step counts and workout minutes accessed via Apple HealthKit or Android Health Connect are processed solely on-device to confirm the daily 30-minute fitness mission. No biometric, heart rate, or health diagnostic data is transmitted to third parties.',
            ),
            _buildLegalSection(
              title: '5. Account Deletion & Right to be Forgotten',
              body: 'Students possess the unconditional right to delete their account at any time via the Danger Zone in this Settings screen. Deletion immediately and irrevocably erases all profile records, stats, inventory, and authentication credentials.',
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: Color(0xFFFFD700)),
                    SizedBox(width: 8),
                    Text('Terms of Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text('Effective Date: September 2026\nVersion: 1.0.0\n', style: TextStyle(color: Colors.white54, fontSize: 12)),
            _buildLegalSection(
              title: '1. Code of Conduct & Fair Play',
              body: 'StudyCompete is built to foster academic excellence and healthy competition. Cheating, photo fraud, quiz automation, harassment, or offensive language in DMs or Study Parties will result in immediate suspension of Hunter status and permanent bans.',
            ),
            _buildLegalSection(
              title: '2. Academic Integrity & Anti-Farming',
              body: 'To prevent stat inflation, Head-to-Head duels are governed by the strict Anti-Farming Rule (maximum 2 battles against the same opponent per week). Verification quests must represent the student\'s authentic study notes.',
            ),
            _buildLegalSection(
              title: '3. Intellectual Property',
              body: 'Curriculum questions, Hunter Guild assets, Solo-Leveling themes, and gamification mechanics are the proprietary property of StudyCompete.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userModelProvider(widget.uid));
    final currentUser = ref.watch(currentUserProfileProvider).value;
    final user = userAsync.value ?? currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Settings & Guild Registry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.white10)),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── AVATAR & BASIC PROFILE ──────────────────────────────────
                _buildProfileCard(user),
                const SizedBox(height: 20),

                // ── ACADEMIC ENROLLMENT DETAILS ──────────────────────────────
                _buildAcademicCard(user),
                const SizedBox(height: 20),

                // ── PREFERENCES & TELEMETRY ─────────────────────────────────
                _buildPreferencesCard(),
                const SizedBox(height: 20),

                // ── LEGAL & STORE COMPLIANCE ────────────────────────────────
                _buildLegalCard(),
                const SizedBox(height: 20),

                // ── DANGER ZONE ─────────────────────────────────────────────
                _buildDangerZone(user),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildProfileCard(UserModel user) {
    final level = (user.xp ~/ 200) + 1;
    final rankInfo = HunterRankUtils.getRankInfo(level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: rankInfo.color, size: 18),
                const SizedBox(width: 8),
                Text('HUNTER IDENTIFICATION', style: TextStyle(color: rankInfo.color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: rankInfo.color.withOpacity(0.2),
                      backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                          ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?', style: TextStyle(fontSize: 28, color: rankInfo.color, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    PositionMeshBadge(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _isUploadingAvatar ? null : () => _pickAndUploadAvatar(user),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: rankInfo.color, shape: BoxShape.circle),
                          child: _isUploadingAvatar
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('@${user.username}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: rankInfo.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: rankInfo.color.withOpacity(0.3))),
                        child: Text('${rankInfo.name}  •  ${rankInfo.title}', style: TextStyle(color: rankInfo.color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Name cannot be empty' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Hunter Motto / Bio',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: rankInfo.color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : () => _saveProfile(user),
                child: _isSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Save Profile Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 8),
              Text('ACADEMIC GUILD REGISTRY', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('School ID', user.schoolId),
          const Divider(color: Colors.white10, height: 18),
          _buildInfoRow('Class / Cohort', user.classId),
          const Divider(color: Colors.white10, height: 18),
          _buildInfoRow('Enrolled Subjects', '${user.subjectIds.length} Subjects Active'),
          const Divider(color: Colors.white10, height: 18),
          _buildInfoRow('Account Created', user.createdAt != null ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}' : 'Active'),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFFA855F7), size: 18),
              SizedBox(width: 8),
              Text('PREFERENCES & TELEMETRY', style: TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push Notifications', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Mission briefings, duel alerts & streak reminders', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _notificationsEnabled,
            activeColor: const Color(0xFFA855F7),
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          const Divider(color: Colors.white10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tactile Haptic Feedback', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Combat impacts, combo hits, and level-up rumbles', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _hapticsEnabled,
            activeColor: const Color(0xFFA855F7),
            onChanged: (val) => setState(() => _hapticsEnabled = val),
          ),
          const Divider(color: Colors.white10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound Effects (SFX)', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Audio cues during quiz gauntlets & duels', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _soundEnabled,
            activeColor: const Color(0xFFA855F7),
            onChanged: (val) => setState(() => _soundEnabled = val),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text('LEGAL & APP STORE COMPLIANCE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF38BDF8), size: 20),
            title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('COPPA, GDPR-K, DPDP & Zero-GPS Locality', style: TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: _showPrivacyPolicyModal,
          ),
          const Divider(color: Colors.white10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_rounded, color: Color(0xFFFFD700), size: 20),
            title: const Text('Terms of Service', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Student Code of Conduct & Fair Play Rules', style: TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: _showTermsModal,
          ),
          const Divider(color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Application Version', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: const Text('v1.0.0 (Build 1)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1014),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 18),
              SizedBox(width: 8),
              Text('DANGER ZONE', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout, color: Color(0xFFF59E0B), size: 18),
              label: const Text('Sign Out', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
              onPressed: _confirmSignOut,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isDeletingAccount
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever, color: Colors.white, size: 18),
              label: Text(
                _isDeletingAccount ? 'Purging Account Data...' : 'Delete Account & Purge Data',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              onPressed: _isDeletingAccount ? null : () => _confirmDeleteAccount(user),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mandatory App Store Guideline 5.1.1(v) & Google Play compliance. Permanently erases all records.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class PositionMeshBadge extends StatelessWidget {
  final double? bottom;
  final double? right;
  final Widget child;
  const PositionMeshBadge({super.key, this.bottom, this.right, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      right: right,
      child: child,
    );
  }
}
