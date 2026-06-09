import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:habo/model/category.dart';
import 'package:provider/provider.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  void _confirmDelete(
      BuildContext context, HabitsManager manager, Category category) {
    final affectedHabits = manager.allHabits
        .where((h) => h.habitData.categories.any((c) => c.id == category.id))
        .map((h) => h.habitData.title)
        .toList();

    final desc = affectedHabits.isEmpty
        ? '"${category.title}" will be permanently removed.'
        : '"${category.title}" will be removed. The ${affectedHabits.length} habit${affectedHabits.length == 1 ? '' : 's'} listed below will keep all their data — only the category label is removed.';

    AwesomeDialog(
      context: context,
      dialogBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
      dialogType: DialogType.warning,
      headerAnimationLoop: false,
      animType: AnimType.bottomSlide,
      title: 'Remove category?',
      desc: desc,
      btnCancelText: 'Cancel',
      btnOkText: 'Remove',
      btnCancelColor: Colors.grey,
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        if (category.id != null) {
          await manager.deleteCategory(category.id!);
        }
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: Colors.transparent,
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: Consumer<HabitsManager>(
        builder: (context, manager, _) {
          final categories = manager.allCategories;

          if (categories.isEmpty) {
            return Center(
              child: Text(
                'No categories yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final cat = categories[i];
              final habitNames = manager.allHabits
                  .where((h) =>
                      h.habitData.categories.any((c) => c.id == cat.id))
                  .map((h) => h.habitData.title)
                  .toList();

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        HaboColors.primary.withValues(alpha: 0.12),
                    child: Icon(cat.icon, color: HaboColors.primary, size: 20),
                  ),
                  title: Text(cat.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: habitNames.isEmpty
                        ? Text(
                            'None',
                            style: TextStyle(color: Colors.grey[400]),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: habitNames
                                .map((name) => Text(
                                      '• $name',
                                      style: const TextStyle(height: 1.6),
                                    ))
                                .toList(),
                          ),
                  ),
                  isThreeLine: habitNames.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove category',
                    onPressed: () => _confirmDelete(context, manager, cat),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
