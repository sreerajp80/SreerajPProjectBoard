// lib/providers/project_provider.dart
// This provider manages the state of projects in the application.
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_status_report.dart';
import '../database/database_helper.dart';
import '../models/activity.dart';

class ProjectProvider with ChangeNotifier {
  List<Project> _projects = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Project> get projects => _projects;

  List<Project> getProjectsBySection(ProjectSection section) {
    return _projects.where((project) => project.section == section).toList();
  }

  Future<void> loadProjects() async {
    _projects = await _dbHelper.getAllProjects();
    notifyListeners();
  }

  Future<void> addProject(Project project) async {
    await _dbHelper.createProject(project);
    await loadProjects();
  }

  Future<void> updateProject(Project project) async {
    await _dbHelper.updateProject(project);
    await loadProjects();
  }

  Future<void> moveProjectToSection(
    String projectId,
    ProjectSection section,
  ) async {
    await _dbHelper.moveProjectToSection(projectId, section);
    await loadProjects();
  }

  Future<void> deleteProject(String projectId) async {
    await _dbHelper.deleteProject(projectId);
    await loadProjects();
  }

  Future<List<ProjectStatusReport>> getProjectStatusReports(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final data = await _dbHelper.getProjectStatusByDateRange(
      startDate,
      endDate,
    );

    List<ProjectStatusReport> reports = [];
    for (var row in data) {
      final date = DateTime.parse(row['date']);
      final sectionCounts = await _getProjectCountsBySection(date);

      reports.add(
        ProjectStatusReport(
          date: date,
          totalProjects: row['project_count'] as int,
          statusChanges: row['status_changes'] as int,
          sectionCounts: sectionCounts,
        ),
      );
    }

    return reports;
  }

  Future<Map<String, int>> getYearlyProjectData() async {
    return await _dbHelper.getYearlyProjectActivity();
  }

  Future<Map<ProjectSection, int>> _getProjectCountsBySection(
    DateTime date,
  ) async {
    Map<ProjectSection, int> counts = {};
    for (var section in ProjectSection.values) {
      counts[section] = 0;
    }

    // Get projects active on the given date
    final projectsOnDate = _projects.where(
      (p) =>
          p.createdAt.isBefore(date.add(const Duration(days: 1))) &&
          (p.statusHistory.isEmpty ||
              p.statusHistory.any(
                (s) => s.startDate.isBefore(date.add(const Duration(days: 1))),
              )),
    );

    for (var project in projectsOnDate) {
      counts[project.section] = (counts[project.section] ?? 0) + 1;
    }

    return counts;
  }

  // Add these methods to project_provider.dart:

  Future<void> addActivity(Activity activity) async {
    await _dbHelper.createActivity(activity);
    notifyListeners();
  }

  Future<List<Activity>> getProjectActivities(String projectId) async {
    return await _dbHelper.getProjectActivities(projectId);
  }

  Future<int> getTotalProjectDuration(String projectId) async {
    return await _dbHelper.getTotalProjectDuration(projectId);
  }

  Future<void> updateActivity(Activity activity) async {
    await _dbHelper.updateActivity(activity);
    notifyListeners();
  }

  Future<void> deleteActivity(String activityId) async {
    await _dbHelper.deleteActivity(activityId);
    notifyListeners();
  }

  Future<Activity?> getActiveActivity(String projectId) async {
    return await _dbHelper.getActiveActivity(projectId);
  }

  Future<List<Activity>> getPausedActivities(String projectId) async {
    return await _dbHelper.getPausedActivities(projectId);
  }

  Future<void> updateActivityStatus(
    String activityId,
    ActivityStatus status, {
    int? newDuration,
    DateTime? endTime,
  }) async {
    await _dbHelper.updateActivityStatus(
      activityId,
      status,
      newDuration: newDuration,
      endTime: endTime,
    );
    notifyListeners();
  }

  Future<void> updateActivityDescription(
    String activityId,
    String newDescription,
  ) async {
    final db = await _dbHelper.database;

    await db.update(
      'activities',
      {'description': newDescription},
      where: 'id = ?',
      whereArgs: [activityId],
    );

    notifyListeners();
  }
}
