// lib/models/project_status_report.dart
import 'project.dart';

class ProjectStatusReport {
  final DateTime date;
  final int totalProjects;
  final int statusChanges;
  final Map<ProjectSection, int> sectionCounts;

  ProjectStatusReport({
    required this.date,
    required this.totalProjects,
    required this.statusChanges,
    required this.sectionCounts,
  });
}
