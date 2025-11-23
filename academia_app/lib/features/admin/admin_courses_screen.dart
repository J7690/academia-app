import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_courses_provider.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCoursesProvider>().loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Cours - Admin'),
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<AdminCoursesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.courses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadCourses,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final courses = provider.courses;
          if (courses.isEmpty) {
            return const Center(
              child: Text('Aucun cours disponible.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final title = course['title']?.toString() ?? '';
              final programTitle = course['program_title']?.toString() ?? '';
              final universityName = course['university_name']?.toString() ?? '';
              final credits = course['credits'];
              final instructor = course['instructor']?.toString() ?? '';
              final isActive = course['is_active'] == true;
              final courseId = course['id']?.toString();

              final metaParts = <String>[];
              if (credits is int) {
                metaParts.add('$credits crédits');
              } else if (credits is String && credits.isNotEmpty) {
                metaParts.add('$credits crédits');
              }
              if (instructor.isNotEmpty) {
                metaParts.add(instructor);
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              programTitle,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              universityName,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (metaParts.isNotEmpty)
                                  Chip(label: Text(metaParts.join(' • '))),
                                Chip(
                                  label: Text(
                                    isActive ? 'Actif' : 'Inactif',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isActive
                                          ? const Color(0xFF1EA75C)
                                          : const Color(0xFFFF3B30),
                                    ),
                                  ),
                                  backgroundColor: isActive
                                      ? const Color(0xFFE5F9E7)
                                      : const Color(0xFFFEE2E2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (value) async {
                          if (courseId == null) return;
                          await provider.updateCourseStatus(
                            courseId: courseId,
                            isActive: value,
                          );
                        },
                      ),
                    ],
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
