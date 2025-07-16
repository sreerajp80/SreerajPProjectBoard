// lib/models/project.dart
// This file defines the Project model and its associated sections and statuses.
import 'package:uuid/uuid.dart';

enum ProjectSection { inbox, preparing, processing, working, parked, completed }

class ProjectStatus {
  final String id;
  final String projectId;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;

  ProjectStatus({
    String? id,
    required this.projectId,
    required this.status,
    required this.startDate,
    this.endDate,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'status': status,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
    };
  }

  factory ProjectStatus.fromMap(Map<String, dynamic> map) {
    return ProjectStatus(
      id: map['id'],
      projectId: map['projectId'],
      status: map['status'],
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate']),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : null,
    );
  }
}

class Project {
  final String id;
  final String title;
  final String richTextContent;
  final ProjectSection section;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProjectStatus> statusHistory;

  Project({
    String? id,
    required this.title,
    required this.richTextContent,
    required this.section,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProjectStatus>? statusHistory,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       statusHistory = statusHistory ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'richTextContent': richTextContent,
      'section': section.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      title: map['title'],
      richTextContent: map['richTextContent'],
      section: ProjectSection.values[map['section']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }

  Project copyWith({
    String? title,
    String? richTextContent,
    ProjectSection? section,
    DateTime? updatedAt,
    List<ProjectStatus>? statusHistory,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      richTextContent: richTextContent ?? this.richTextContent,
      section: section ?? this.section,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}
