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
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(
      _showArchived ? categoriesWithArchivedProvider(_tab) : categoriesProvider(_tab),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.visibility_off_outlined : Icons.archive_outlined),
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context, categories.value ?? const []),
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

  void _showCreateSheet(BuildContext context, List<Category> existing) {
    final nameController = TextEditingController();
    // Only non-archived top-level categories of the current type make
    // sense as a parent.
    final topLevel = existing.where((c) => c.isTopLevel && !c.archived).toList();
    String? parentId;

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New ${_tab.name} category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (topLevel.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration: const InputDecoration(labelText: 'Parent category (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None — top level')),
                    for (final p in topLevel) DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (value) => setSheetState(() => parentId = value),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  await ref.read(categoryRepositoryProvider).createCategory(
                        NewCategoryInput(name: nameController.text, type: _tab, parentId: parentId),
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGroup extends ConsumerWidget {
  const _CategoryGroup({required this.parent, required this.children});

  final Category parent;
  final List<Category> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (children.isEmpty) {
      return _CategoryTile(category: parent);
    }
    return ExpansionTile(
      title: Text(
        parent.name,
        style: parent.archived ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      trailing: _ArchiveButton(category: parent),
      children: [for (final c in children) _CategoryTile(category: c, indent: true)],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, this.indent = false});

  final Category category;
  final bool indent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: indent ? const EdgeInsets.only(left: 32) : null,
      title: Text(
        category.name,
        style: category.archived ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      trailing: _ArchiveButton(category: category),
    );
  }
}

class _ArchiveButton extends ConsumerWidget {
  const _ArchiveButton({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(category.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
      tooltip: category.archived ? 'Unarchive' : 'Archive',
      onPressed: () {
        final repo = ref.read(categoryRepositoryProvider);
        category.archived ? repo.unarchiveCategory(category.id) : repo.archiveCategory(category.id);
      },
    );
  }
}
