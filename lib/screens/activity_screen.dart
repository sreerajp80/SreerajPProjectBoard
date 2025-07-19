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

class _ActivityScreenState extends State<ActivityScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  Activity? _currentActivity;

  List<Activity> _activities = [];
  List<Activity> _pausedActivities = [];
  int _totalDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _loadActiveActivity();
    _loadPausedActivities();
  }

  void _loadActivities() async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final activities = await provider.getProjectActivities(widget.project.id);
    final totalDuration = await provider.getTotalProjectDuration(
      widget.project.id,
    );

    setState(() {
      _activities = activities.where((a) => a.isFinished).toList();
      _totalDuration = totalDuration;
    });
  }

  void _loadActiveActivity() async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final activeActivity = await provider.getActiveActivity(widget.project.id);

    if (activeActivity != null) {
      setState(() {
        _currentActivity = activeActivity;
        _isRunning = true;
        _descriptionController.text = activeActivity.description;

        // Calculate elapsed time since activity started
        final now = DateTime.now();
        final elapsed = now.difference(activeActivity.startTime).inSeconds;
        _seconds = elapsed;
      });

      // Start the timer to continue tracking
      _startTimer();
    }
  }

  void _loadPausedActivities() async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final pausedActivities = await provider.getPausedActivities(
      widget.project.id,
    );

    setState(() {
      _pausedActivities = pausedActivities;
    });
  }

  void _startTimer() {
    // Validate description is provided
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter activity description before starting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _startTimerExecution();
  }

  void _startTimerExecution() async {
    // If no current activity, create a new one
    if (_currentActivity == null) {
      final activity = Activity(
        projectId: widget.project.id,
        description: _descriptionController.text.trim(),
        startTime: DateTime.now(),
        duration: _seconds,
        status: ActivityStatus.running,
      );

      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.addActivity(activity);

      setState(() {
        _currentActivity = activity;
      });
    } else {
      // Resume existing activity
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.updateActivityStatus(
        _currentActivity!.id,
        ActivityStatus.running,
      );

      setState(() {
        _currentActivity = _currentActivity!.copyWith(
          status: ActivityStatus.running,
        );
      });
    }

    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });

      // Update activity duration in database periodically (every 30 seconds)
      if (_seconds % 30 == 0 && _currentActivity != null) {
        _updateActivityDuration();
      }
    });
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();

    if (_currentActivity != null) {
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.updateActivityStatus(
        _currentActivity!.id,
        ActivityStatus.paused,
        newDuration: _seconds,
      );

      setState(() {
        _currentActivity = _currentActivity!.copyWith(
          status: ActivityStatus.paused,
          duration: _seconds,
        );
        _isRunning = false;
      });

      _loadPausedActivities(); // Refresh paused activities list
    }
  }

  void _stopTimer() async {
    _timer?.cancel();

    if (_currentActivity != null) {
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.updateActivityStatus(
        _currentActivity!.id,
        ActivityStatus.finished,
        newDuration: _seconds,
        endTime: DateTime.now(),
      );
    }

    setState(() {
      _isRunning = false;
      _currentActivity = null;
      _seconds = 0;
    });

    _descriptionController.clear();
    _loadActivities(); // Refresh finished activities list
    _loadPausedActivities(); // Refresh paused activities list

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity finished and saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetTimer() async {
    _timer?.cancel();

    if (_currentActivity != null) {
      // Delete the current activity if it was just started
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.deleteActivity(_currentActivity!.id);
    }

    setState(() {
      _isRunning = false;
      _currentActivity = null;
      _seconds = 0;
    });

    _descriptionController.clear();
    _loadActivities();
    _loadPausedActivities();
  }

  void _resumePausedActivity(Activity activity) async {
    // Stop current timer if running
    if (_isRunning) {
      await _pauseTimer();
    }

    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.updateActivityStatus(activity.id, ActivityStatus.running);

    setState(() {
      _currentActivity = activity.copyWith(status: ActivityStatus.running);
      _descriptionController.text = activity.description;
      _seconds = activity.duration;
      _isRunning = true;
    });

    _startTimerExecution();
    _loadPausedActivities(); // Refresh paused activities list
  }

  void _deletePausedActivity(Activity activity) async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.deleteActivity(activity.id);
    _loadPausedActivities();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paused activity deleted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _updateActivityDuration() async {
    if (_currentActivity != null) {
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      await provider.updateActivityStatus(
        _currentActivity!.id,
        ActivityStatus.running,
        newDuration: _seconds,
      );
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
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
          onPressed: () async {
            // Save current activity state before leaving
            if (_isRunning && _currentActivity != null) {
              await _updateActivityDuration();
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Timer and Note Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                // Timer Display
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sectionColor.withValues(alpha: 0.1),
                        sectionColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sectionColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: sectionColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _formatDuration(_seconds),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: sectionColor,
                          fontFamily: 'monospace',
                          shadows: [
                            Shadow(
                              color: sectionColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                            Shadow(
                              color: Colors.white,
                              blurRadius: 8,
                              offset: const Offset(-1, -1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildIconButton(
                            icon: _isRunning ? Icons.pause : Icons.play_arrow,
                            tooltip: _isRunning ? 'Pause' : 'Start',
                            onPressed: _isRunning ? _pauseTimer : _startTimer,
                            color: _isRunning ? Colors.orange : sectionColor,
                          ),
                          const SizedBox(width: 15),
                          _buildIconButton(
                            icon: Icons.stop,
                            tooltip: 'Finish',
                            onPressed: _isRunning ? _stopTimer : null,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 15),
                          _buildIconButton(
                            icon: Icons.refresh,
                            tooltip: 'Reset',
                            onPressed: _resetTimer,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Activity Description
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  enabled: !_isRunning, // Disable editing while running
                  decoration: InputDecoration(
                    labelText: 'Activity Description *',
                    hintText: 'What are you working on?',
                    filled: true,
                    fillColor: _isRunning
                        ? Colors.grey.shade100
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: sectionColor, width: 2),
                    ),
                    suffixIcon: Icon(
                      Icons.edit,
                      color: _isRunning ? Colors.grey.shade400 : sectionColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Paused Activities Section (if any)
          if (_pausedActivities.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paused Activities',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._pausedActivities.map(
                    (activity) => _buildPausedActivityItem(activity),
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
                      _formatDuration(
                        _totalDuration + (_isRunning ? _seconds : 0),
                      ),
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

          // Activities List Header
          if (_activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Completed Activities',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),

          // Activities List
          Expanded(
            child: _activities.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      return _buildActivityItem(_activities[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed != null ? color : Colors.grey.shade300,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            elevation: 0,
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }

  Widget _buildPausedActivityItem(Activity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.pause, color: Colors.orange, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(activity.duration),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: () => _resumePausedActivity(activity),
            tooltip: 'Resume',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deletePausedActivity(activity),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Activity activity) {
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
                      DateFormat('MMM d, h:mm a').format(activity.createdAt),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No activities completed yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your work by adding a description and clicking start',
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

  @override
  void dispose() {
    // Save activity state before disposing
    if (_isRunning && _currentActivity != null) {
      _updateActivityDuration();
    }
    _timer?.cancel();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
