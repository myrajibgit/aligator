import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubjectsConfirmScreen extends ConsumerStatefulWidget {
  const SubjectsConfirmScreen({super.key});

  @override
  ConsumerState<SubjectsConfirmScreen> createState() => _SubjectsConfirmScreenState();
}

class _SubjectsConfirmScreenState extends ConsumerState<SubjectsConfirmScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);
    final classId = state.selectedClass?.id ?? '';
    
    final subjectsAsync = ref.watch(subjectsForClassProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your subjects'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: 1.0), // 4/4
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'These subjects will appear as your daily missions. You can update them later.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: subjectsAsync.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return const Center(child: Text('No subjects found for this class.'));
                }
                
                // Pre-select all subjects on first load
                if (!_initialized) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(onboardingNotifierProvider.notifier).selectAllSubjects(subjects);
                    setState(() => _initialized = true);
                  });
                }
                
                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    final isSelected = state.selectedSubjects.any((s) => s.id == subject.id);
                    
                    return InkWell(
                      onTap: () {
                        ref.read(onboardingNotifierProvider.notifier).toggleSubject(subject);
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            if (subject.iconUrl.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: subject.iconUrl,
                                width: 20,
                                height: 20,
                                placeholder: (ctx, url) => const Icon(Icons.book, size: 20),
                                errorWidget: (ctx, url, err) => const Icon(Icons.book, size: 20),
                              )
                            else
                              const Icon(Icons.book, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                subject.name, 
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, size: 20, color: Colors.green),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: FilledButton(
              onPressed: state.isLoading 
                ? null 
                : () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
                    
                    try {
                      await ref.read(onboardingNotifierProvider.notifier).complete(uid);
                      if (context.mounted) {
                        context.go('/home/missions');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'))
                        );
                      }
                    }
                  },
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: state.isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Finish'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
