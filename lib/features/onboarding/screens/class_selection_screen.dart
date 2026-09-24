import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';

class ClassSelectionScreen extends ConsumerStatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  ConsumerState<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends ConsumerState<ClassSelectionScreen> {
  final List<String> _streams = ['Science', 'Commerce', 'Arts', 'Engineering', 'Medical', 'Other'];
  String _selectedStream = 'Science';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);
    final schoolId = state.selectedSchool?.id ?? '';
    
    final classesAsync = ref.watch(classesForSchoolProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select your class'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: 0.75), // 3/4
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Choose your stream', style: Theme.of(context).textTheme.titleMedium),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: _streams.map((stream) {
                final isSelected = _selectedStream == stream;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(stream),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStream = stream);
                        // Reset selected class when stream changes if needed
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 32),
          Expanded(
            child: classesAsync.when(
              data: (classes) {
                // Filter classes by stream or show all if needed
                final filteredClasses = classes.where((c) => c.stream == _selectedStream).toList();
                
                if (filteredClasses.isEmpty) {
                  return const Center(child: Text('No classes found for this stream.'));
                }
                
                return ListView.builder(
                  itemCount: filteredClasses.length,
                  itemBuilder: (context, index) {
                    final classModel = filteredClasses[index];
                    final isSelected = state.selectedClass?.id == classModel.id;
                    
                    return RadioListTile(
                      title: Text('Grade ${classModel.grade}'),
                      subtitle: Text(classModel.stream),
                      value: classModel.id,
                      groupValue: state.selectedClass?.id,
                      onChanged: (val) {
                        ref.read(onboardingNotifierProvider.notifier)
                            .selectClass(classModel, _selectedStream);
                      },
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
              onPressed: state.selectedClass != null 
                  ? () => context.push('/onboarding/subjects') 
                  : null,
              child: const SizedBox(
                width: double.infinity,
                child: Center(child: Text('Next')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
