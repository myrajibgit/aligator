import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';
import '../models/school_model.dart';

class SchoolSelectionScreen extends ConsumerStatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  ConsumerState<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends ConsumerState<SchoolSelectionScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.trim();
      });
    });
  }

  void _showRequestSchoolSheet() {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Request to add school', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'School Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: countryCtrl,
                decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await ref.read(onboardingNotifierProvider.notifier).submitRequest(
                    name: nameCtrl.text,
                    city: cityCtrl.text,
                    country: countryCtrl.text,
                    submittedBy: 'test_uid_replace_me',
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request submitted successfully!')),
                    );
                  }
                },
                child: const Text('Submit Request'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);
    final searchResults = ref.watch(schoolSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find your school'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: LinearProgressIndicator(value: 0.50), // 2/4
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search for your school...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _searchQuery.isEmpty
                ? const Center(child: Text('Type to search for your school.'))
                : searchResults.when(
                    data: (schools) {
                      if (schools.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('School not found?'),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _showRequestSchoolSheet,
                                child: const Text('Request to add'),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: schools.length,
                        itemBuilder: (context, index) {
                          final school = schools[index];
                          final isSelected = state.selectedSchool?.id == school.id;
                          return ListTile(
                            title: Text(school.name),
                            subtitle: Text('${school.city}, ${school.country}'),
                            trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                            onTap: () {
                              ref.read(onboardingNotifierProvider.notifier).selectSchool(school);
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
              onPressed: state.selectedSchool != null 
                  ? () => context.push('/onboarding/class') 
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
