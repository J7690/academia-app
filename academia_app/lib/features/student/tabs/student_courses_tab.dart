import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_courses_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class StudentCoursesTab extends StatefulWidget {
  const StudentCoursesTab({super.key});

  @override
  State<StudentCoursesTab> createState() => _StudentCoursesTabState();
}

class _StudentCoursesTabState extends State<StudentCoursesTab> {
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentCoursesProvider>().loadStudentCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentCoursesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.courses.isEmpty) {
          return const LoadingWidget(message: 'Chargement de vos cours...');
        }

        if (provider.error != null) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadStudentCourses(),
          );
        }

        final courses = provider.courses;

        if (courses.isEmpty) {
          return const Center(
            child: Text('Vous n\'êtes inscrit à aucun cours pour le moment.'),
          );
        }

        return Row(
          children: [
            // Liste des cours
            SizedBox(
              width: 260,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  final selected = course['course_id'] == _selectedCourseId;
                  return Card(
                    color:
                        selected ? Theme.of(context).colorScheme.primaryContainer : null,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(course['title']?.toString() ?? ''),
                      subtitle: Text(
                        'Inscrit le: ${course['enrolled_at'] ?? ''}',
                      ),
                      onTap: () async {
                        final id = course['course_id']?.toString();
                        if (id == null) return;
                        setState(() {
                          _selectedCourseId = id;
                        });
                        await provider.loadCourseExercises(id);
                      },
                    ),
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            // Exercices du cours sélectionné
            Expanded(
              child: _buildExercisesColumn(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExercisesColumn(
      BuildContext context, StudentCoursesProvider provider) {
    if (_selectedCourseId == null) {
      return const Center(
        child: Text('Sélectionnez un cours pour voir les exercices.'),
      );
    }

    final exercises = provider.exercises;

    if (provider.isLoading && exercises.isEmpty) {
      return const LoadingWidget(message: 'Chargement des exercices...');
    }

    if (provider.error != null) {
      return CustomErrorWidget(
        error: provider.error!,
        onRetry: () {
          final id = _selectedCourseId;
          if (id != null) {
            provider.loadCourseExercises(id);
          }
        },
      );
    }

    if (exercises.isEmpty) {
      return const Center(
        child: Text('Aucun exercice pour ce cours.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index];
        final title = ex['title']?.toString() ?? '';
        final description = ex['description']?.toString() ?? '';
        final url = ex['resource_url']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) Text(description),
                if (url.isNotEmpty)
                  Text(
                    url,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
