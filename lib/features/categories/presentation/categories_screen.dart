import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/category_providers.dart';
import '../domain/category_entity.dart';
import '../domain/category_repository.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType _tab = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider(_tab));
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<CategoryType>(
              segments: const [
                ButtonSegment(value: CategoryType.expense, label: Text('Expense')),
                ButtonSegment(value: CategoryType.income, label: Text('Income')),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) => setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: categories.when(
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No categories yet. Tap + to add one.'))
                  : ListView(
                      children: [
                        for (final c in list.where((c) => c.isTopLevel))
                          _CategoryGroup(
                            parent: c,
                            children: list.where((child) => child.parentId == c.id).toList(),
                          ),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('Could not load: $error')),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New ${_tab.name} category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                await ref.read(categoryRepositoryProvider).createCategory(
                      NewCategoryInput(name: nameController.text, type: _tab),
                    );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.parent, required this.children});

  final Category parent;
  final List<Category> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return ListTile(title: Text(parent.name));
    }
    return ExpansionTile(
      title: Text(parent.name),
      children: [for (final c in children) ListTile(title: Text(c.name))],
    );
  }
}
