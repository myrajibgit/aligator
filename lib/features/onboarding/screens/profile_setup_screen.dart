import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/onboarding_provider.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  Uint8List? _avatarBytes;
  String? _uploadedPhotoUrl;
  bool _isUploadingAvatar = false;
  bool _isAgeAndTermsAccepted = false;

  Timer? _debounce;
  bool _isUsernameChecking = false;
  bool? _isUsernameAvailable;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() {
      _isUsernameChecking = true;
      _isUsernameAvailable = null;
    });

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (value.length >= 3) {
        final service = ref.read(onboardingServiceProvider);
        final isTaken = await service.isUsernameTaken(value);
        setState(() {
          _isUsernameChecking = false;
          _isUsernameAvailable = !isTaken;
        });
      } else {
        setState(() {
          _isUsernameChecking = false;
          _isUsernameAvailable = null;
        });
      }
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _isUploadingAvatar = true;
    });

    try {
      final user = ref.read(currentUserProvider);
      final uid = user?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final refStorage =
          FirebaseStorage.instance.ref().child('profiles/$uid/avatar.jpg');
      await refStorage.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await refStorage.getDownloadURL();

      if (mounted) {
        setState(() {
          _uploadedPhotoUrl = url;
        });
      }

      ref.read(onboardingNotifierProvider.notifier).updateProfileData(
            displayName: _displayNameCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            photoUrl: url,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isUsernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a valid and available username')),
      );
      return;
    }

    if (!_isAgeAndTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 13 years old and accept the terms to continue.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please sign in again.')),
      );
      return;
    }

    ref.read(onboardingNotifierProvider.notifier).updateProfileData(
          displayName: _displayNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
          photoUrl: _uploadedPhotoUrl,
        );

    try {
      await ref.read(onboardingNotifierProvider.notifier).saveProfile(uid);
      if (mounted) context.push('/onboarding/school');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: 0.25), // 1/4
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage:
                          _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                      child: _avatarBytes != null
                          ? null
                          : Text(
                              _displayNameCtrl.text.isNotEmpty
                                  ? _displayNameCtrl.text[0].toUpperCase()
                                  : '?',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                    ),
                    if (_isUploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: _isUploadingAvatar ? null : _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'e.g. Alex Hunter',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2 || val.trim().length > 50) {
                    return 'Must be between 2 and 50 characters';
                  }
                  return null;
                },
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. shadow_monarch',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: _isUsernameChecking
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (_isUsernameAvailable == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : (_isUsernameAvailable == false
                              ? const Icon(Icons.cancel, color: Colors.red)
                              : null)),
                ),
                onChanged: _onUsernameChanged,
                validator: (val) {
                  if (val == null || val.length < 3 || val.length > 20) {
                    return 'Must be 3-20 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
                    return 'Only letters, numbers, and underscores allowed';
                  }
                  if (_isUsernameAvailable == false) {
                    return 'Username is already taken';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Share your study ambitions or favorite subjects...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAgeAndTermsAccepted
                        ? Colors.green.withOpacity(0.5)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: CheckboxListTile(
                  value: _isAgeAndTermsAccepted,
                  onChanged: (val) => setState(() => _isAgeAndTermsAccepted = val ?? false),
                  title: const Text(
                    'I certify that I am at least 13 years old and agree to StudyCompete’s Terms of Service and Privacy Policy.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: (state.isLoading || _isUploadingAvatar) ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Next: Select School', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
