// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../models/activity.dart';
import '../providers/project_provider.dart';

class ActivityScreen extends StatefulWidget {
  final Project project;

  const ActivityScreen({super.key, required this.project});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with WidgetsBindingObserver {
  final TextEditingController _newActivityController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;

  List<Activity> _runningActivities = [];
  List<Activity> _pausedActivities = [];
  List<Activity> _finishedActivities = [];
  int _totalDuration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadActivities();
    _startGlobalTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _newActivityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground, recalculate running activities
        _recalculateRunningActivities();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App going to background, save current state
        _saveRunningActivitiesState();
        break;
    }
  }

  void _recalculateRunningActivities() {
    // Recalculate durations for all running activities based on actual elapsed time
    if (_runningActivities.isNotEmpty) {
      setState(() {
        for (var activity in _runningActivities) {
          final now = DateTime.now();
          final elapsed = now.difference(activity.startTime).inSeconds;
          activity.duration = elapsed;
        }
      });
    }
  }

  void _saveRunningActivitiesState() async {
    // Update running activities in database with current duration
    final provider = Provider.of<ProjectProvider>(context, listen: false);

    for (var activity in _runningActivities) {
      final now = DateTime.now();
      final elapsed = now.difference(activity.startTime).inSeconds;
      activity.duration = elapsed;

      // Save to database
      await provider.updateActivity(activity);
    }
  }

  void _loadActivities() async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final allActivities = await provider.getProjectActivities(
      widget.project.id,
    );
    final totalDuration = await provider.getTotalProjectDuration(
      widget.project.id,
    );

    setState(() {
      _runningActivities = allActivities.where((a) => a.isRunning).toList();
      _pausedActivities = allActivities.where((a) => a.isPaused).toList();
      _finishedActivities = allActivities.where((a) => a.isFinished).toList();
      _totalDuration = totalDuration;
    });

    // Recalculate running activities immediately after loading
    _recalculateRunningActivities();
  }

  void _startGlobalTimer() {
    // Global timer that updates UI every second for all running activities
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_runningActivities.isNotEmpty) {
        setState(() {
          final now = DateTime.now();
          for (var activity in _runningActivities) {
            // Calculate actual elapsed time from start time to now
            final elapsed = now.difference(activity.startTime).inSeconds;
            activity.duration = elapsed;
          }
        });
      }
    });
  }

  Future<void> _createNewActivity() async {
    if (_newActivityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter activity description'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final activity = Activity(
      projectId: widget.project.id,
      description: _newActivityController.text.trim(),
      startTime: now,
      duration: 0,
      status: ActivityStatus.running,
    );

    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.addActivity(activity);

    setState(() {
      _runningActivities.add(activity);
    });

    _newActivityController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New activity started'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pauseActivity(Activity activity) async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);

    // Calculate final duration before pausing
    final now = DateTime.now();
    final finalDuration = now.difference(activity.startTime).inSeconds;

    await provider.updateActivityStatus(
      activity.id,
      ActivityStatus.paused,
      newDuration: finalDuration,
    );

    setState(() {
      _runningActivities.remove(activity);
      activity.status = ActivityStatus.paused;
      activity.duration = finalDuration;
      _pausedActivities.add(activity);
    });
  }

  Future<void> _resumeActivity(Activity activity) async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);

    // Calculate new start time: current time minus already accumulated duration
    final now = DateTime.now();
    final newStartTime = now.subtract(Duration(seconds: activity.duration));

    final updatedActivity = activity.copyWith(
      startTime: newStartTime,
      status: ActivityStatus.running,
    );

    await provider.updateActivityStatus(activity.id, ActivityStatus.running);

    setState(() {
      _pausedActivities.remove(activity);
      // Remove old activity and add updated one
      final index = _runningActivities.indexWhere((a) => a.id == activity.id);
      if (index != -1) {
        _runningActivities[index] = updatedActivity;
      } else {
        _runningActivities.add(updatedActivity);
      }
    });
  }

  Future<void> _finishActivity(Activity activity) async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);

    // Calculate final duration
    final now = DateTime.now();
    final finalDuration = activity.isRunning
        ? now.difference(activity.startTime).inSeconds
        : activity.duration;

    await provider.updateActivityStatus(
      activity.id,
      ActivityStatus.finished,
      newDuration: finalDuration,
      endTime: now,
    );

    setState(() {
      if (_runningActivities.contains(activity)) {
        _runningActivities.remove(activity);
      } else if (_pausedActivities.contains(activity)) {
        _pausedActivities.remove(activity);
      }

      activity.status = ActivityStatus.finished;
      activity.duration = finalDuration;
      activity.endTime = now;
      _finishedActivities.insert(0, activity);
    });

    _loadActivities(); // Refresh total duration

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity finished'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteActivity(Activity activity) async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.deleteActivity(activity.id);

    setState(() {
      _runningActivities.remove(activity);
      _pausedActivities.remove(activity);
      _finishedActivities.remove(activity);
    });

    _loadActivities(); // Refresh total duration

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity deleted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _editActivityDescription(Activity activity) async {
    final controller = TextEditingController(text: activity.description);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Activity Description'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != activity.description) {
      activity.updateDescription(result);

      // Update in database
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.updateActivityDescription(activity.id, result);

      setState(() {}); // Refresh UI

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity description updated'),
          backgroundColor: Colors.green,
        ),
      );
    }

    controller.dispose();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  int _getCurrentTotalTime() {
    // Calculate current running time based on actual elapsed time
    final now = DateTime.now();
    int runningTime = _runningActivities.fold(
      0,
      (sum, activity) => sum + now.difference(activity.startTime).inSeconds,
    );

    int pausedTime = _pausedActivities.fold(
      0,
      (sum, activity) => sum + activity.duration,
    );

    return _totalDuration + runningTime + pausedTime;
  }

  @override
  Widget build(BuildContext context) {
    final sectionColor = _getSectionColor(widget.project.section);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Tracker',
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              widget.project.title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey.shade700),
            onPressed: _loadActivities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // New Activity Creation Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start New Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newActivityController,
                        decoration: InputDecoration(
                          hintText: 'What are you working on?',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: sectionColor,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _createNewActivity(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _createNewActivity,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sectionColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total Duration Card
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timer, color: sectionColor, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Project Time',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatDuration(_getCurrentTotalTime()),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Activities List
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: sectionColor,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: sectionColor,
                    tabs: [
                      Tab(
                        text: 'Running (${_runningActivities.length})',
                        icon: const Icon(Icons.play_circle, size: 20),
                      ),
                      Tab(
                        text: 'Paused (${_pausedActivities.length})',
                        icon: const Icon(Icons.pause_circle, size: 20),
                      ),
                      Tab(
                        text: 'Finished (${_finishedActivities.length})',
                        icon: const Icon(Icons.check_circle, size: 20),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRunningActivitiesList(),
                        _buildPausedActivitiesList(),
                        _buildFinishedActivitiesList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningActivitiesList() {
    if (_runningActivities.isEmpty) {
      return _buildEmptyState(
        'No running activities',
        'Start a new activity to begin tracking your work',
        Icons.play_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _runningActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_runningActivities[index], Colors.green, [
          _buildActionButton(
            Icons.pause,
            'Pause',
            Colors.orange,
            () => _pauseActivity(_runningActivities[index]),
          ),
          _buildActionButton(
            Icons.stop,
            'Finish',
            Colors.green,
            () => _finishActivity(_runningActivities[index]),
          ),
          _buildActionButton(
            Icons.edit,
            'Edit',
            Colors.blue,
            () => _editActivityDescription(_runningActivities[index]),
          ),
          _buildActionButton(
            Icons.delete,
            'Delete',
            Colors.red,
            () => _deleteActivity(_runningActivities[index]),
          ),
        ]);
      },
    );
  }

  Widget _buildPausedActivitiesList() {
    if (_pausedActivities.isEmpty) {
      return _buildEmptyState(
        'No paused activities',
        'Activities you pause will appear here',
        Icons.pause_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pausedActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_pausedActivities[index], Colors.orange, [
          _buildActionButton(
            Icons.play_arrow,
            'Resume',
            Colors.green,
            () => _resumeActivity(_pausedActivities[index]),
          ),
          _buildActionButton(
            Icons.stop,
            'Finish',
            Colors.green,
            () => _finishActivity(_pausedActivities[index]),
          ),
          _buildActionButton(
            Icons.edit,
            'Edit',
            Colors.blue,
            () => _editActivityDescription(_pausedActivities[index]),
          ),
          _buildActionButton(
            Icons.delete,
            'Delete',
            Colors.red,
            () => _deleteActivity(_pausedActivities[index]),
          ),
        ]);
      },
    );
  }

  Widget _buildFinishedActivitiesList() {
    if (_finishedActivities.isEmpty) {
      return _buildEmptyState(
        'No completed activities',
        'Activities you finish will appear here',
        Icons.check_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _finishedActivities.length,
      itemBuilder: (context, index) {
        final activity = _finishedActivities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(activity.duration),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'MMM d, h:mm a',
                          ).format(activity.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: const Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Description'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _editActivityDescription(activity);
                  } else if (value == 'delete') {
                    _deleteActivity(activity);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityCard(
    Activity activity,
    Color statusColor,
    List<Widget> actions,
  ) {
    // Calculate real-time duration for running activities
    final displayDuration = activity.isRunning
        ? DateTime.now().difference(activity.startTime).inSeconds
        : activity.duration;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  activity.isRunning ? Icons.play_circle : Icons.pause_circle,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.timer, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(displayDuration),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(activity.startTime),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getSectionColor(ProjectSection section) {
    switch (section) {
      case ProjectSection.inbox:
        return const Color(0xFF7C3AED);
      case ProjectSection.preparing:
        return const Color(0xFFF59E0B);
      case ProjectSection.processing:
        return const Color(0xFF3B82F6);
      case ProjectSection.working:
        return const Color(0xFF10B981);
      case ProjectSection.parked:
        return const Color(0xFFEF4444);
      case ProjectSection.completed:
        return const Color(0xFF6366F1);
    }
  }
}
