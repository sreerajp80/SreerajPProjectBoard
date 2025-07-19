// lib/models/activity.dart
import 'package:uuid/uuid.dart';

enum ActivityStatus { running, paused, finished }

class Activity {
  final String id;
  final String projectId;
  String description; // Changed from final to allow editing
  final DateTime startTime;
  DateTime? endTime;
  int duration; // in seconds
  final DateTime createdAt;
  ActivityStatus status;

  Activity({
    String? id,
    required this.projectId,
    required this.description,
    required this.startTime,
    this.endTime,
    required this.duration,
    DateTime? createdAt,
    this.status = ActivityStatus.running,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'description': description,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'duration': duration,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.name,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'],
      projectId: map['projectId'],
      description: map['description'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      duration: map['duration'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      status: ActivityStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ActivityStatus.finished,
      ),
    );
  }

  // Helper methods
  bool get isRunning => status == ActivityStatus.running;
  bool get isPaused => status == ActivityStatus.paused;
  bool get isFinished => status == ActivityStatus.finished;

  // Create a copy with updated fields
  Activity copyWith({
    String? id,
    String? projectId,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    DateTime? createdAt,
    ActivityStatus? status,
  }) {
    return Activity(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  // Method to update description
  void updateDescription(String newDescription) {
    description = newDescription;
  }
}
