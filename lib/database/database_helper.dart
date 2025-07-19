// lib/database/database_helper.dart
// This file handles database operations for the project management application.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project.dart';
import '../models/activity.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('projects.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        richTextContent TEXT NOT NULL,
        section INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE project_status(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        status TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER,
        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    // Add to database_helper.dart in _createDB method:
    await db.execute('''
  CREATE TABLE activities(
    id TEXT PRIMARY KEY,
    projectId TEXT NOT NULL,
    description TEXT NOT NULL,
    startTime INTEGER NOT NULL,
    endTime INTEGER,
    duration INTEGER NOT NULL,
    createdAt INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'finished',
    FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
  )
''');
  }

  Future<Project> createProject(Project project) async {
    final db = await instance.database;
    await db.insert('projects', project.toMap());

    // Add initial status
    final initialStatus = ProjectStatus(
      projectId: project.id,
      status: project.section.toString().split('.').last,
      startDate: DateTime.now(),
    );
    await db.insert('project_status', initialStatus.toMap());

    return project;
  }

  Future<List<Project>> getAllProjects() async {
    final db = await instance.database;
    final result = await db.query('projects', orderBy: 'updatedAt DESC');

    List<Project> projects = result.map((map) => Project.fromMap(map)).toList();

    // Load status history for each project
    for (var project in projects) {
      project.statusHistory.addAll(await getProjectStatusHistory(project.id));
    }

    return projects;
  }

  Future<List<ProjectStatus>> getProjectStatusHistory(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'project_status',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'startDate DESC',
    );

    return result.map((map) => ProjectStatus.fromMap(map)).toList();
  }

  Future<int> updateProject(Project project) async {
    final db = await instance.database;
    return db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> moveProjectToSection(
    String projectId,
    ProjectSection newSection,
  ) async {
    final db = await instance.database;

    // End current status
    final currentStatuses = await db.query(
      'project_status',
      where: 'projectId = ? AND endDate IS NULL',
      whereArgs: [projectId],
    );

    if (currentStatuses.isNotEmpty) {
      await db.update(
        'project_status',
        {'endDate': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [currentStatuses.first['id']],
      );
    }

    // Add new status
    final newStatus = ProjectStatus(
      projectId: projectId,
      status: newSection.toString().split('.').last,
      startDate: DateTime.now(),
    );
    await db.insert('project_status', newStatus.toMap());

    // Update project section
    await db.update(
      'projects',
      {
        'section': newSection.index,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<int> deleteProject(String id) async {
    final db = await instance.database;
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'projects.db');
  }

  Future<List<Map<String, dynamic>>> getProjectStatusByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
    SELECT
      DATE(startDate / 1000, 'unixepoch') as date,
      COUNT(DISTINCT projectId) as project_count,
      COUNT(*) as status_changes
    FROM project_status
    WHERE startDate >= ? AND startDate <= ?
    GROUP BY date
    ORDER BY date DESC
  ''',
      [startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
    );
  }

  Future<Map<String, int>> getYearlyProjectActivity() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
    SELECT
      strftime('%m', datetime(createdAt / 1000, 'unixepoch')) as month,
      COUNT(*) as count
    FROM projects
    WHERE createdAt >= ?
    GROUP BY month
  ''',
      [
        DateTime.now()
            .subtract(const Duration(days: 365))
            .millisecondsSinceEpoch,
      ],
    );

    Map<String, int> monthlyData = {};
    for (var row in result) {
      monthlyData[(int.parse(row['month'] as String) - 1).toString()] =
          row['count'] as int;
    }
    return monthlyData;
  }

  // Add these methods to DatabaseHelper class:
  Future<Activity> createActivity(Activity activity) async {
    final db = await instance.database;
    await db.insert('activities', activity.toMap());
    return activity;
  }

  // Get all activities for a project (including active and paused ones)
  Future<List<Activity>> getProjectActivities(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'activities',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => Activity.fromMap(map)).toList();
  }

  Future<int> getTotalProjectDuration(String projectId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(duration) as total FROM activities WHERE projectId = ?',
      [projectId],
    );

    return result.first['total'] as int? ?? 0;
  }

  // Get the currently active (running) activity for a project
  Future<Activity?> getActiveActivity(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'activities',
      where: 'projectId = ? AND status = ?',
      whereArgs: [projectId, 'running'],
      limit: 1,
      orderBy: 'createdAt DESC',
    );

    if (result.isEmpty) return null;
    return Activity.fromMap(result.first);
  }

  // Get paused activities for a project
  Future<List<Activity>> getPausedActivities(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'activities',
      where: 'projectId = ? AND status = ?',
      whereArgs: [projectId, 'paused'],
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => Activity.fromMap(map)).toList();
  }

  Future<int> updateActivityStatus(
    String activityId,
    ActivityStatus status, {
    int? newDuration,
    DateTime? endTime,
  }) async {
    final db = await instance.database;

    Map<String, dynamic> updates = {'status': status.name};

    if (newDuration != null) {
      updates['duration'] = newDuration;
    }

    if (endTime != null) {
      updates['endTime'] = endTime.millisecondsSinceEpoch;
    }

    return db.update(
      'activities',
      updates,
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  Future<int> updateActivity(Activity activity) async {
    final db = await instance.database;
    return db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  // Pause all running activities for a project (useful when switching projects)
  Future<void> pauseAllRunningActivities(String projectId) async {
    final db = await instance.database;
    await db.update(
      'activities',
      {'status': 'paused'},
      where: 'projectId = ? AND status = ?',
      whereArgs: [projectId, 'running'],
    );
  }

  // Resume a paused activity
  Future<void> resumeActivity(String activityId) async {
    final db = await instance.database;
    await db.update(
      'activities',
      {'status': 'running'},
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  Future<int> deleteActivity(String id) async {
    final db = await instance.database;
    return db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  // Add this new method for handling database upgrades
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the status column to existing activities table
      await db.execute('''
      ALTER TABLE activities
      ADD COLUMN status TEXT NOT NULL DEFAULT 'finished'
    ''');
    }
  }
}
