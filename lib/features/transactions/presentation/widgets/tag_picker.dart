import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/transaction_providers.dart';

/// A compact chip picker for tags: toggle existing ones, or type a new
/// name and add it (get-or-create — see TagRepository.getOrCreateTag).
class TagPicker extends ConsumerStatefulWidget {
  const TagPicker({super.key, required this.selectedTagIds, required this.onChanged});

  final Set<String> selectedTagIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  ConsumerState<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<TagPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addTyped() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final tag = await ref.read(tagRepositoryProvider).getOrCreateTag(name);
    _controller.clear();
    widget.onChanged({...widget.selectedTagIds, tag.id});
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: widget.selectedTagIds.contains(tag.id),
                  onSelected: (selected) {
                    final next = {...widget.selectedTagIds};
                    selected ? next.add(tag.id) : next.remove(tag.id);
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'New tag', isDense: true),
                onSubmitted: (_) => _addTyped(),
              ),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: _addTyped),
          ],
        ),
      ],
    );
  }
}
