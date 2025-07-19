// lib/screens/project_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sreerajp_project_board/screens/activity_screen.dart';
import 'dart:convert';
import '../models/project.dart';
import '../providers/project_provider.dart';
import 'project_editor_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late QuillController _quillController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _focusNode = FocusNode();
    _initializeQuillController();
  }

  void _initializeQuillController() {
    final doc = Document.fromJson(jsonDecode(widget.project.richTextContent));
    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            'Are you sure you want to delete "${widget.project.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<ProjectProvider>(
                  context,
                  listen: false,
                ).deleteProject(widget.project.id);
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to home screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
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

  IconData _getSectionIcon(ProjectSection section) {
    switch (section) {
      case ProjectSection.inbox:
        return Icons.inbox_rounded;
      case ProjectSection.preparing:
        return Icons.build_circle_rounded;
      case ProjectSection.processing:
        return Icons.loop_rounded;
      case ProjectSection.working:
        return Icons.engineering_rounded;
      case ProjectSection.parked:
        return Icons.pause_circle_rounded;
      case ProjectSection.completed:
        return Icons.check_circle_rounded;
    }
  }

  String _formatTimeDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionColor = _getSectionColor(widget.project.section);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.project.title,
          style: TextStyle(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: sectionColor),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProjectEditorScreen(project: widget.project),
                ),
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          // ADD THIS NEW BUTTON HERE
          IconButton(
            icon: Icon(Icons.timer_outlined, color: sectionColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActivityScreen(project: widget.project),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: sectionColor,
              indicatorWeight: 3,
              labelColor: sectionColor,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(sectionColor),
          _buildHistoryTab(sectionColor),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Color sectionColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoCard(sectionColor),
          const SizedBox(height: 20),
          _buildNotesCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Color sectionColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  sectionColor.withOpacity(0.1),
                  sectionColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sectionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getSectionIcon(widget.project.section),
                    color: sectionColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sectionColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.project.section
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: TextStyle(
                            color: sectionColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.calendar_today_rounded,
                  'Created',
                  DateFormat(
                    'MMMM d, yyyy at h:mm a',
                  ).format(widget.project.createdAt),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.update_rounded,
                  'Last Updated',
                  DateFormat(
                    'MMMM d, yyyy at h:mm a',
                  ).format(widget.project.updatedAt),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.history_rounded,
                  'Status Changes',
                  '${widget.project.statusHistory.length} total movements',
                ),
                // Add Total Time Tracked
                FutureBuilder<int>(
                  future: Provider.of<ProjectProvider>(
                    context,
                    listen: false,
                  ).getTotalProjectDuration(widget.project.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.timer_outlined,
                            'Total Time Tracked',
                            _formatTimeDuration(snapshot.data!),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.notes_rounded, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 200),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: QuillEditor.basic(
              controller: _quillController,
              focusNode: _focusNode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Color sectionColor) {
    if (widget.project.statusHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status changes will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.project.statusHistory.length,
      itemBuilder: (context, index) {
        final status = widget.project.statusHistory[index];
        final isFirst = index == 0;
        final isLast = index == widget.project.statusHistory.length - 1;

        return _buildHistoryItem(status, isFirst, isLast);
      },
    );
  }

  Widget _buildHistoryItem(ProjectStatus status, bool isFirst, bool isLast) {
    final statusSection = ProjectSection.values.firstWhere(
      (s) => s.toString().split('.').last == status.status,
      orElse: () => ProjectSection.inbox,
    );
    final statusColor = _getSectionColor(statusSection);
    final duration = status.endDate != null
        ? status.endDate!.difference(status.startDate)
        : DateTime.now().difference(status.startDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isFirst ? statusColor : statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getSectionIcon(statusSection),
                  color: isFirst ? Colors.white : statusColor,
                  size: 20,
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 80, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFirst
                      ? statusColor.withOpacity(0.3)
                      : Colors.grey.shade200,
                  width: isFirst ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        status.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (isFirst)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.login_rounded,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'MMM d, yyyy at h:mm a',
                        ).format(status.startDate),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (status.endDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'MMM d, yyyy at h:mm a',
                          ).format(status.endDate!),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quillController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
