// lib/widgets/project_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../screens/project_detail_screen.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final Color sectionColor;

  const ProjectCard({
    super.key,
    required this.project,
    required this.sectionColor,
  });

  String _getSectionDisplayName(ProjectSection section) {
    switch (section) {
      case ProjectSection.inbox:
        return 'Inbox';
      case ProjectSection.preparing:
        return 'Preparing';
      case ProjectSection.processing:
        return 'Processing';
      case ProjectSection.working:
        return 'Working';
      case ProjectSection.parked:
        return 'Parked';
      case ProjectSection.completed:
        return 'Completed';
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

  void _showMoveMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      // Changed to String type
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        // Add existing section items
        ...ProjectSection.values.map((section) {
          final isCurrentSection = section == project.section;
          return PopupMenuItem<String>(
            value: section.toString(),
            enabled: !isCurrentSection,
            child: Row(
              children: [
                Icon(
                  _getSectionIcon(section),
                  color: isCurrentSection
                      ? Colors.grey
                      : _getSectionColor(section),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _getSectionDisplayName(section),
                  style: TextStyle(
                    color: isCurrentSection ? Colors.grey : null,
                    fontWeight: isCurrentSection
                        ? FontWeight.w400
                        : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isCurrentSection)
                  const Icon(Icons.check, color: Colors.grey, size: 18),
              ],
            ),
          );
        }).toList(),
        // Add divider
        const PopupMenuDivider(),
        // Add delete option
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 12),
              Text(
                'Delete Project',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      if (value == 'delete') {
        // Show confirmation dialog
        _showDeleteConfirmation(context);
      } else {
        // Handle section change
        final newSection = ProjectSection.values.firstWhere(
          (s) => s.toString() == value,
        );
        if (newSection != project.section) {
          Provider.of<ProjectProvider>(
            context,
            listen: false,
          ).moveProjectToSection(project.id, newSection);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Moved to ${_getSectionDisplayName(newSection)}'),
              duration: const Duration(seconds: 2),
              backgroundColor: _getSectionColor(newSection),
            ),
          );
        }
      }
    });
  }

  // Add this method to project_card.dart
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            'Are you sure you want to delete "${project.title}"? This action cannot be undone.',
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
                ).deleteProject(project.id);
                Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Draggable<Map<String, dynamic>>(
      data: {'projectId': project.id, 'section': project.section},
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            project.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildCard(context)),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: sectionColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Three dots menu button
                      Builder(
                        builder: (context) => InkWell(
                          onTap: () => _showMoveMenu(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.more_vert,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d').format(project.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const Spacer(),
                      if (project.statusHistory.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sectionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${project.statusHistory.length} updates',
                            style: TextStyle(
                              fontSize: 11,
                              color: sectionColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
