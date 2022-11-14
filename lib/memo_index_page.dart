import 'package:flutter/material.dart';

import 'collections/category.dart';
import 'collections/memo.dart';
import 'memo_repository.dart';

/// Memo list screen
class MemoIndexPage extends StatefulWidget {
  const MemoIndexPage({
    super.key,
    required this.memoRepository,
  });

  /// Notes repository
  final MemoRepository memoRepository;

  @override
  State<MemoIndexPage> createState() => MemoIndexPageState();
}

@visibleForTesting
class MemoIndexPageState extends State<MemoIndexPage> {
  /// List of memos to display
  final memos = <Memo>[];

  @override
  void initState() {
    super.initState();

    /// Monitor the memo list and update the screen if there is any change
    widget.memoRepository.memoStream.listen(_refresh);

    // Get the memo list and update the screen
    () async {
      _refresh(await widget.memoRepository.findMemos());
    }();
  }

  /// Update memo list screen
  void _refresh(List<Memo> memos) {
    if (!mounted) {
      return;
    }

    setState(() {
      this.memos
        ..clear()
        ..addAll(memos);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO APP'),
      ),
      body: ListView.builder(
        itemBuilder: (context, index) {
          final memo = memos[index];
          final category = memo.category.value;
          return ListTile(
            // Show memo update dialog when tapped
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => MemoUpsertDialog(
                widget.memoRepository,
                memo: memo,
              ),
              barrierDismissible: false,
            ),
            title: Text(memo.content),
            subtitle: Text(category?.name ?? ''),
            // Delete the memo immediately when the delete button is pressed
            trailing: IconButton(
              onPressed: () => widget.memoRepository.deleteMemo(memo),
              icon: const Icon(Icons.close),
            ),
          );
        },
        itemCount: memos.length,
      ),
      floatingActionButton: FloatingActionButton(
        // Show add memo dialog
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => MemoUpsertDialog(widget.memoRepository),
          barrierDismissible: false,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Note registration/update dialog
class MemoUpsertDialog extends StatefulWidget {
  const MemoUpsertDialog(
    this.memoRepository, {
    super.key,
    this.memo,
  });

  /// Notes repository
  final MemoRepository memoRepository;

  /// Note to update (null on registration)
  final Memo? memo;

  @override
  State<MemoUpsertDialog> createState() => MemoUpsertDialogState();
}

@visibleForTesting
class MemoUpsertDialogState extends State<MemoUpsertDialog> {
  /// List of categories to display
  final categories = <Category>[];

  /// Selected category
  Category? _selectedCategory;
  Category? get selectedCategory => _selectedCategory;

  /// Note content being typed
  final _textController = TextEditingController();
  String get content => _textController.text;

  @override
  void initState() {
    super.initState();

    () async {
      // Get category list
      categories.addAll(await widget.memoRepository.findCategories());

      // Set initial value
      _selectedCategory = categories.firstWhere(
        (category) => category.id == widget.memo?.category.value?.id,
        orElse: () => categories.first,
      );
      _textController.text = widget.memo?.content ?? '';

      // redraw
      setState(() {});
    }();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          children: [
            // Select category with drop button
            DropdownButton<Category>(
              value: _selectedCategory,
              items: categories
                  .map(
                    (category) => DropdownMenuItem<Category>(
                      value: category,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: (category) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              isExpanded: true,
            ),
            TextField(
              controller: _textController,
              onChanged: (_) {
                // Refresh the screen to update the activation/deactivation of the "Save" button
                setState(() {});
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          // Activate "Save" button only when there is more than one character
          // of memo content being entered
          onPressed: content.isNotEmpty
              ? () async {
                  final memo = widget.memo;
                  if (memo == null) {
                    // registration process
                    await widget.memoRepository.addMemo(
                      category: _selectedCategory!,
                      content: content,
                    );
                  } else {
                    // Update process
                    await widget.memoRepository.updateMemo(
                      memo: memo,
                      category: _selectedCategory!,
                      content: content,
                    );
                  }
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
