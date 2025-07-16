// lib/database/database_helper.dart
// This file handles database operations for the project management application.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
}
